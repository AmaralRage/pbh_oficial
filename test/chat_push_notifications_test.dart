import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:pbh_oficial/services/chat_push_notifications_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = 'cc070000-0000-4000-8000-000000000001',
      sender = 'cc070000-0000-4000-8000-000000000002',
      thread = 'cc070000-0000-4000-8000-000000000003',
      message = 'cc070000-0000-4000-8000-000000000004';
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  Map<String, dynamic> data() => {
    'chat_id': thread,
    'message_id': message,
    'recipient_id': user,
    'sender_id': sender,
    'sender_name': 'Arthur Morgan',
    'preview': 'Olá, irmão!',
    'destination_url': 'https://pbh-oficial.vercel.app/?chat=$thread',
    'sent_at': DateTime.now().toUtc().toIso8601String(),
    'expires_at': DateTime.now()
        .add(const Duration(days: 7))
        .toUtc()
        .toIso8601String(),
  };
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize') return true;
          if (call.method == 'getActiveNotifications')
            return [
              {'id': 42, 'channelId': 'pbh_private_chat'},
              {'id': 43, 'channelId': 'pbh_announcements'},
            ];
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'native conversation uses sender photo, name, preview and chat destination',
    () async {
      final service = ChatPushNotifications(
        readAccount: () async => user,
        readAvatar: (_) async => Uint8List.fromList([1, 2, 3]),
      );
      expect(await service.show(data()), isTrue);
      final args =
          calls.singleWhere((c) => c.method == 'show').arguments as Map;
      expect(args['title'], 'Arthur Morgan');
      expect(args['body'], 'Olá, irmão!');
      final android = args['platformSpecifics'] as Map,
          style = android['styleInformation'] as Map;
      final entry = (style['messages'] as List).single as Map,
          person = entry['person'] as Map;
      expect(style['groupConversation'], false);
      expect(person['name'], 'Arthur Morgan');
      expect(person['key'], sender);
      expect(person['icon'], [1, 2, 3]);
      expect(entry['text'], 'Olá, irmão!');
      expect(android['largeIcon'], [1, 2, 3]);
      expect(jsonDecode(args['payload'] as String), {
        'recipient_id': user,
        'destination_url': 'https://pbh-oficial.vercel.app/?chat=$thread',
      });
    },
  );
  test('another account or an expired preview cannot be displayed', () async {
    var avatars = 0;
    final service = ChatPushNotifications(
      readAccount: () async => sender,
      readAvatar: (_) async {
        avatars++;
        return null;
      },
    );
    expect(await service.show(data()), isFalse);
    expect(avatars, 0);
    expect(calls.where((c) => c.method == 'show'), isEmpty);
    final expired = data()
      ..['expires_at'] = DateTime.now()
          .subtract(const Duration(seconds: 1))
          .toIso8601String();
    expect(await service.show(expired), isFalse);
  });
  test(
    'account switch during avatar fetch suppresses the private preview',
    () async {
      var account = user;
      final service = ChatPushNotifications(
        readAccount: () async => account,
        readAvatar: (_) async {
          account = sender;
          return Uint8List.fromList([1]);
        },
      );
      expect(await service.show(data()), isFalse);
      expect(calls.where((c) => c.method == 'show'), isEmpty);
    },
  );
  test(
    'logging out removes only chat alerts and pauses delivery until resumed',
    () async {
      final service = ChatPushNotifications(
        readAccount: () async => user,
        readAvatar: (_) async => null,
      );
      expect(await service.show(data()), isTrue);
      await service.pause(user);
      final canceled = calls
          .where((c) => c.method == 'cancel')
          .map((c) => (c.arguments as Map)['id'])
          .toList();
      expect(canceled, contains(42));
      expect(canceled, isNot(contains(43)));
      expect(await service.show(data()), isFalse);
      await service.resume(user);
      expect(await service.show(data()), isTrue);
    },
  );
}
