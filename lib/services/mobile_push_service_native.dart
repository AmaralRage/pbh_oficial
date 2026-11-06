import 'dart:async';
import 'dart:convert';
import 'community_post_navigation.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'initial_notification_permission.dart';
import 'routine_local_notification_scheduler.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

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
  static StreamSubscription<RemoteMessage>? _opened;
  static Future<void> _pending = Future.value();
  static AppLifecycleListener? _lifecycle;
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
          onDidReceiveNotificationResponse: (response) {
            CommunityPostNavigation.fromLocalPayload(
              response.payload,
              _client?.auth.currentUser?.id,
            );
          },
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
            'pbh_community_posts',
            'Comunidade',
            description: 'Publicações em destaque do PROJETO BOM HOMEM',
            importance: Importance.high,
          ),
        );
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            'pbh_community_posts_silent',
            'Comunidade (sem som)',
            importance: Importance.high,
            playSound: false,
            enableVibration: false,
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
        _messages ??= FirebaseMessaging.onMessage.listen((message) async {
          if (_pausedUser == _client?.auth.currentUser?.id &&
              _pausedUser != null) {
            return;
          }
          if (_client?.auth.currentUser?.id != message.data['recipient_id'])
            return;
          final notice = message.notification;
          if (notice == null) return;
          if (!await deviceEnabled) return;
          final sound =
              await SharedPreferencesAsync().getBool(
                'pbh.notifications.${_client!.auth.currentUser?.id}.sound',
              ) ??
              true;
          if (_client?.auth.currentUser?.id != message.data['recipient_id'])
            return;
          final silent = message.data['silent'] == 'true' || !sound;
          final community =
              communityPostFromNotificationUrl(
                message.data['destination_url'] as String?,
              ) !=
              null;
          unawaited(
            _notifications.show(
              48000,
              notice.title,
              notice.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  community
                      ? silent
                            ? 'pbh_community_posts_silent'
                            : 'pbh_community_posts'
                      : silent
                      ? 'pbh_announcements_silent'
                      : 'pbh_announcements',
                  community
                      ? 'Comunidade'
                      : silent
                      ? 'Avisos silenciosos do PBH'
                      : 'Avisos do PBH',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: community
                      ? 'ic_stat_pbh_community'
                      : 'ic_stat_pbh_prominent',
                  color: community
                      ? const Color(0xFFFF6B2C)
                      : const Color(0xFF6D28D9),
                  subText: community ? 'Comunidade' : null,
                  groupKey: community ? 'pbh.community' : null,
                  category: community
                      ? AndroidNotificationCategory.social
                      : null,
                  styleInformation: community
                      ? BigTextStyleInformation(
                          notice.body ?? '',
                          contentTitle: notice.title,
                          summaryText: 'Comunidade · PBH Oficial',
                        )
                      : null,
                  largeIcon: DrawableResourceAndroidBitmap(
                    community
                        ? 'pbh_community_large'
                        : 'pbh_notification_large',
                  ),
                  playSound: !silent,
                  enableVibration: !silent,
                ),
              ),
              payload: jsonEncode({
                'recipient_id': message.data['recipient_id'],
                'destination_url': message.data['destination_url'],
              }),
            ),
          );
        });
        _opened ??= FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => CommunityPostNavigation.fromNotification(
            message.data,
            _client?.auth.currentUser?.id,
          ),
        );
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null)
          CommunityPostNavigation.fromNotification(
            initial.data,
            _client?.auth.currentUser?.id,
          );
        final launch = await _notifications.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          try {
            CommunityPostNavigation.fromNotification(
              Map<String, dynamic>.from(
                jsonDecode(launch!.notificationResponse?.payload ?? '{}')
                    as Map,
              ),
              _client?.auth.currentUser?.id,
            );
          } catch (_) {}
        }
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
    _lifecycle ??= AppLifecycleListener(onResume: _syncSoon);
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
    try {
      await unregister();
    } finally {
      await RoutineLocalNotificationScheduler.cancel();
    }
  }

  static Future<void> setSound(bool enabled) async {
    final account = _client?.auth.currentUser?.id ?? 'guest';
    await SharedPreferencesAsync().setBool(
      'pbh.notifications.$account.sound',
      enabled,
    );
    if (_ready && await deviceEnabled) {
      await _pending;
      await _sync();
    }
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
      'register_native_push_v2',
      params: {
        'p_installation_id': installation,
        'p_token': token,
        'p_sound_enabled':
            await SharedPreferencesAsync().getBool(
              'pbh.notifications.$user.sound',
            ) ??
            true,
      },
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
