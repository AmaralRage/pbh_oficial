import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'initial_notification_permission.dart';

class MobilePushService {
  static bool get isSupported => Platform.isAndroid;
  static bool get isConfigured => _ready;
  static Future<bool> get deviceEnabled async =>
      await SharedPreferencesAsync().getBool(
        InitialNotificationPermission.enabledKey,
      ) ??
      true;
  static bool _ready = false;
  static String? _pausedUser;
  static SupabaseClient? _client;
  static StreamSubscription<AuthState>? _auth;
  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _messages;
  static Future<void> _pending = Future.value();
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<String> _installation() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('pbh.push.installation');
    if (existing != null) return existing;
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await prefs.setString('pbh.push.installation', id);
    return id;
  }

  static Future<void> bind(SupabaseClient client) async {
    if (!isSupported) return;
    _client = client;
    if (!_ready) {
      try {
        await Firebase.initializeApp();
        // Token collection starts only after the system permission is granted.
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await _notifications.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_pbh_prominent'),
          ),
        );
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            'pbh_announcements',
            'Avisos do PBH',
            description: 'Mensagens da administração do projeto',
            importance: Importance.high,
          ),
        );
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            'pbh_announcements_silent',
            'Avisos silenciosos do PBH',
            importance: Importance.high,
            playSound: false,
            enableVibration: false,
          ),
        );
        _messages ??= FirebaseMessaging.onMessage.listen((message) {
          if (_pausedUser == _client?.auth.currentUser?.id &&
              _pausedUser != null) {
            return;
          }
          if (_client?.auth.currentUser?.id != message.data['recipient_id'])
            return;
          final notice = message.notification;
          if (notice == null) return;
          final silent = message.data['silent'] == 'true';
          unawaited(
            _notifications.show(
              48000,
              notice.title,
              notice.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  silent ? 'pbh_announcements_silent' : 'pbh_announcements',
                  silent ? 'Avisos silenciosos do PBH' : 'Avisos do PBH',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: 'ic_stat_pbh_prominent',
                  color: const Color(0xFF6D28D9),
                  largeIcon: const DrawableResourceAndroidBitmap(
                    'pbh_notification_large',
                  ),
                  playSound: !silent,
                  enableVibration: !silent,
                ),
              ),
            ),
          );
        });
        _ready = true;
      } catch (_) {
        // Missing Firebase configuration must never prevent PBH from opening.
        return;
      }
    }
    await _auth?.cancel();
    await _refresh?.cancel();
    _auth = client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) _pausedUser = null;
      _syncSoon();
    });
    _refresh = FirebaseMessaging.instance.onTokenRefresh.listen(
      (_) => _syncSoon(),
    );
    _syncSoon();
    unawaited(_requestInitialPermission());
  }

  static Future<void> _requestInitialPermission() async {
    try {
      await InitialNotificationPermission().requestOnce(() async {
        final result = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        return result.authorizationStatus == AuthorizationStatus.authorized;
      });
      _syncSoon();
    } catch (_) {
      // Permission or network failures must not interrupt opening the app.
    }
  }

  static Future<void> disable() async {
    await SharedPreferencesAsync().setBool(
      InitialNotificationPermission.enabledKey,
      false,
    );
    await unregister();
  }

  static void _syncSoon() {
    _pending = _pending
        .then<void>((_) async {
          await _sync();
        })
        .catchError((Object _) {});
  }

  static Future<bool> _sync() async {
    final client = _client;
    final user = client?.auth.currentUser?.id;
    if (!_ready || client == null || user == null || user == _pausedUser)
      return false;
    if (await SharedPreferencesAsync().getBool(
          InitialNotificationPermission.enabledKey,
        ) ==
        false)
      return false;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized)
      return false;
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty || client.auth.currentUser?.id != user)
      return false;
    final installation = await _installation();
    if (client.auth.currentUser?.id != user) return false;
    await client.rpc(
      'register_native_push',
      params: {'p_installation_id': installation, 'p_token': token},
    );
    return true;
  }

  static Future<void> subscribe() async {
    if (!_ready)
      throw StateError(
        'A configuração das notificações Android ainda está pendente.',
      );
    if (_client?.auth.currentUser == null)
      throw StateError('Entre na sua conta para ativar notificações.');
    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (result.authorizationStatus != AuthorizationStatus.authorized)
      throw StateError('Permita notificações nas configurações do Android.');
    await SharedPreferencesAsync().setBool(
      InitialNotificationPermission.enabledKey,
      true,
    );
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    _pausedUser = null;
    await _pending;
    final registered = await _sync().timeout(const Duration(seconds: 30));
    if (!registered) {
      throw StateError(
        'O cadastro deste celular não foi concluído. Confira a conexão, mantenha sua conta conectada e tente ativar novamente.',
      );
    }
  }

  static Future<void> unregister() async {
    if (!_ready || _client?.auth.currentUser == null) return;
    _pausedUser = _client!.auth.currentUser!.id;
    await _pending;
    await _client!.rpc(
      'unregister_native_push',
      params: {'p_installation_id': await _installation()},
    );
    await FirebaseMessaging.instance.deleteToken();
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await _notifications.cancel(48000);
  }
}
