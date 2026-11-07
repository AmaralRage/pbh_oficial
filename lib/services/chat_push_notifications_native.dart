import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../core/config/supabase_config.dart';
import 'chat_navigation.dart';
import 'community_post_navigation.dart';
import 'chat_push_payload.dart';
import 'initial_notification_permission.dart';
import 'protected_session_storage.dart';

Future<String?> _sessionAccount() async {
  try {
    final raw = await protectedSessionStorage(
      SupabaseConfig.url,
    )?.accessToken();
    if (raw == null) return null;
    return (jsonDecode(raw) as Map)['user']['id'] as String?;
  } catch (_) {
    return null;
  }
}

class ChatPushNotifications {
  ChatPushNotifications({
    Future<String?> Function()? readAccount,
    Future<Uint8List?> Function(ChatPushPayload)? readAvatar,
  }) : _readAccount = readAccount ?? _sessionAccount,
       _readAvatar = readAvatar ?? _avatar;
  static final instance = ChatPushNotifications();
  final Future<String?> Function() _readAccount;
  final Future<Uint8List?> Function(ChatPushPayload) _readAvatar;
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _idsKey = 'pbh.chat.notification_ids',
      _pausedKey = 'pbh.chat.paused_user';
  final _prefs = SharedPreferencesAsync();
  Future<void>? _initialized;
  Future<void> _initialize() => _initialized ??= () async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_pbh_prominent'),
      ),
      onDidReceiveNotificationResponse: (response) async {
        final user = await _readAccount();
        ChatNavigation.fromLocalPayload(response.payload, user);
        CommunityPostNavigation.fromLocalPayload(response.payload, user);
      },
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'pbh_private_chat',
        'Conversas privadas',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'pbh_private_chat_silent',
        'Conversas privadas (sem som)',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
      ),
    );
  }();
  Future<bool> _allowed(String user, {String? thread}) async =>
      await _readAccount() == user &&
      await _prefs.getBool(InitialNotificationPermission.enabledKey) != false &&
      await _prefs.getString(_pausedKey) != user &&
      (thread == null ||
          await _prefs.getBool('pbh.chat.muted.$user.$thread') != true);
  Future<bool> show(Map<String, dynamic> data) async {
    ChatPushPayload? payload;
    try {
      payload = ChatPushPayload.parse(data);
    } catch (_) {
      return false;
    }
    if (payload == null ||
        !await _allowed(payload.recipientId, thread: payload.threadId))
      return false;
    await _initialize();
    final avatar = await _readAvatar(payload);
    if (!await _allowed(payload.recipientId, thread: payload.threadId))
      return false;
    final silent =
        payload.silent ||
        await _prefs.getBool(
              'pbh.notifications.${payload.recipientId}.sound',
            ) ==
            false;
    final sender = Person(
      name: payload.name,
      key: payload.senderId,
      icon: avatar == null ? null : ByteArrayAndroidIcon(avatar),
    );
    await _plugin.show(
      payload.notificationId,
      payload.name,
      payload.preview,
      NotificationDetails(
        android: AndroidNotificationDetails(
          silent ? 'pbh_private_chat_silent' : 'pbh_private_chat',
          'Conversas privadas',
          importance: Importance.high,
          priority: Priority.high,
          when: payload.sentAt.millisecondsSinceEpoch,
          timeoutAfter: payload.expiresAt
              .difference(DateTime.now())
              .inMilliseconds
              .clamp(1, 604800000),
          icon: 'ic_stat_pbh_prominent',
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
          groupKey: 'pbh.chat.${payload.threadId}',
          onlyAlertOnce: false,
          largeIcon: avatar == null
              ? const DrawableResourceAndroidBitmap('pbh_notification_large')
              : ByteArrayAndroidBitmap(avatar),
          styleInformation: MessagingStyleInformation(
            Person(name: 'Você', key: payload.recipientId),
            groupConversation: false,
            messages: [Message(payload.preview, payload.sentAt, sender)],
          ),
          playSound: !silent,
          enableVibration: !silent,
        ),
      ),
      payload: jsonEncode({
        'recipient_id': payload.recipientId,
        'destination_url': data['destination_url'],
      }),
    );
    if (!await _allowed(payload.recipientId, thread: payload.threadId)) {
      await _plugin.cancel(payload.notificationId);
      return false;
    }
    final ids = await _prefs.getStringList(_idsKey) ?? [];
    ids.remove(payload.notificationId.toString());
    ids.add(payload.notificationId.toString());
    await _prefs.setStringList(
      _idsKey,
      ids.length > 64 ? ids.sublist(ids.length - 64) : ids,
    );
    return true;
  }

  Future<void> pause(String user) async {
    await _prefs.setString(_pausedKey, user);
    await clear();
  }

  Future<void> resume(String user) async {
    if (await _prefs.getString(_pausedKey) == user)
      await _prefs.remove(_pausedKey);
  }

  Future<void> clear() async {
    try {
      for (final notification in await _plugin.getActiveNotifications()) {
        if (notification.id != null &&
            (notification.channelId == 'pbh_private_chat' ||
                notification.channelId == 'pbh_private_chat_silent'))
          await _plugin.cancel(notification.id!);
      }
    } catch (_) {}
    for (final id in await _prefs.getStringList(_idsKey) ?? []) {
      final value = int.tryParse(id);
      if (value != null) {
        try {
          await _plugin.cancel(value);
        } catch (_) {}
      }
    }
    await _prefs.remove(_idsKey);
  }

  static Future<Uint8List?> _avatar(ChatPushPayload payload) async {
    if (payload.founder &&
        (payload.avatar == null ||
            payload.avatar!.isEmpty ||
            payload.avatar ==
                'https://pbh-oficial.vercel.app/assets/assets/images/perfil.png')) {
      try {
        return await _thumbnail(
          (await rootBundle.load(
            'assets/images/perfil.png',
          )).buffer.asUint8List(),
        );
      } catch (_) {
        return null;
      }
    }
    final uri = Uri.tryParse(payload.avatar ?? ''),
        project = Uri.parse(SupabaseConfig.url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.origin != project.origin ||
        !uri.path.startsWith(
          '/storage/v1/object/public/profile-avatars/${payload.senderId}/',
        ) ||
        uri.userInfo.isNotEmpty)
      return null;
    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', uri)..followRedirects = false)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200 || (response.contentLength ?? 0) > 2097152)
        return null;
      final bytes = BytesBuilder();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 3),
      )) {
        bytes.add(chunk);
        if (bytes.length > 2097152) return null;
      }
      return await _thumbnail(bytes.takeBytes());
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<Uint8List?> _thumbnail(Uint8List bytes) async {
    try {
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);
      if (info == null || info.width * info.height > 8000000) return null;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 128,
        targetHeight: 128,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          return (await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          ))?.buffer.asUint8List();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }
}
