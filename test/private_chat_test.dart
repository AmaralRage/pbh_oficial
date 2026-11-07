import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/chat_models.dart';
import 'package:pbh_oficial/services/chat_image_preparation.dart';
import 'package:pbh_oficial/services/chat_local_store.dart';
import 'package:pbh_oficial/services/chat_navigation.dart';
import 'package:pbh_oficial/services/chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const thread = 'cc070000-0000-4000-8000-000000000001';
  const id = 'cc070000-0000-4000-8000-000000000011';
  test(
    'chat uses verified profile identity for founder and uploaded avatars',
    () async {
      var avatar = 'https://fixture.invalid/avatar.jpg';
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          dynamic result;
          if (request.url.path.endsWith('/token')) {
            result = {
              'access_token': 'test',
              'refresh_token': 'test',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'member',
                'aud': 'authenticated',
                'created_at': '2026-11-07T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            };
          } else if (request.url.path.endsWith('/chat_inbox')) {
            result = [
              {
                'thread_id': thread,
                'peer_id': id,
                'name': 'Líder',
                'avatar_url': null,
                'last_at': '2026-11-07T00:00:00Z',
                'activity_at': '2026-11-07T00:00:00Z',
                'peer_read_at': '2026-11-07T00:00:00Z',
              },
            ];
          } else if (request.url.path.endsWith('/search_community_members')) {
            result = [
              {'user_id': id, 'name': 'Líder', 'avatar_url': null},
            ];
          } else if (request.url.path.endsWith(
            '/community_member_identities',
          )) {
            expect((jsonDecode(request.body) as Map)['p_ids'], [id]);
            result = [
              {
                'user_id': id,
                'avatar_url': avatar.isEmpty ? null : avatar,
                'founder': true,
              },
            ];
          } else {
            throw StateError('Unexpected endpoint');
          }
          return http.Response(
            jsonEncode(result),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'fixture',
      );
      final service = ChatService(client: client);
      final row = (await service.inbox()).single;
      expect(row.avatar, avatar);
      expect(row.founder, isTrue);
      avatar = '';
      final defaultRow = (await service.inbox()).single;
      expect(defaultRow.avatar, isNull);
      expect(defaultRow.founder, isTrue);
      expect((await service.search('Líder')).single['founder'], isTrue);
    },
  );
  test(
    'notification opens only the intended account and official chat URL',
    () {
      ChatNavigation.pending.value = null;
      final data = {
        'recipient_id': 'member',
        'destination_url': 'https://pbh-oficial.vercel.app/?chat=$thread',
      };
      ChatNavigation.fromNotification(data, 'other');
      expect(ChatNavigation.pending.value, isNull);
      ChatNavigation.fromNotification({
        ...data,
        'destination_url': 'https://evil.invalid/?chat=$thread',
      }, 'member');
      expect(ChatNavigation.pending.value, isNull);
      ChatNavigation.fromLocalPayload(jsonEncode(data), 'member');
      expect(ChatNavigation.pending.value, thread);
      ChatNavigation.pending.value = null;
    },
  );
  test(
    'lost send acknowledgement is confirmed without a second message',
    () async {
      var saved = false, calls = 0;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          dynamic result;
          if (request.url.path.endsWith('/token'))
            result = {
              'access_token': 'test',
              'refresh_token': 'test',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'member',
                'aud': 'authenticated',
                'created_at': '2026-11-07T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            };
          if (request.url.path.endsWith('/chat_messages'))
            result = saved
                ? {
                    'id': id,
                    'sender_id': 'member',
                    'body': 'Olá',
                    'reply_to': null,
                  }
                : null;
          if (request.url.path.endsWith('/chat_send')) {
            calls++;
            saved = true;
            throw http.ClientException('acknowledgement lost');
          }
          return http.Response(
            jsonEncode(result),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'fixture',
      );
      const draft = ChatDraft(id: id, text: 'Olá');
      await expectLater(
        ChatService(client: client).send(thread, draft),
        throwsA(isA<http.ClientException>()),
      );
      await ChatService(client: client).send(thread, draft);
      expect(calls, 1);
      await expectLater(
        ChatService(
          client: client,
        ).send(thread, const ChatDraft(id: id, text: 'Alterado')),
        throwsStateError,
      );
    },
  );
  test(
    'photo preparation bounds stored size and dimensions, rejects invalid input',
    () {
      final image = img.Image(width: 1600, height: 2400);
      final result = compressChatImage(
        Uint8List.fromList(img.encodePng(image)),
      );
      final decoded = img.decodeJpg(result)!;
      expect(result.length, lessThanOrEqualTo(512 * 1024));
      expect(decoded.height, lessThanOrEqualTo(1280));
      expect(decoded.width, lessThanOrEqualTo(1280));
      expect(() => compressChatImage(Uint8List(0)), throwsArgumentError);
      expect(
        () => compressChatImage(Uint8List(15 * 1024 * 1024 + 1)),
        throwsArgumentError,
      );
    },
  );
  test(
    'draft and wallpaper persist separately by account and conversation',
    () async {
      final directory = await Directory.systemTemp.createTemp('pbh-chat-test-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      });
      final store = ChatLocalStore();
      const draft = ChatDraft(id: id, text: 'Rascunho');
      await store.save('a', thread, draft);
      expect((await ChatLocalStore().load('a', thread))?.id, id);
      expect(await store.load('b', thread), isNull);
      expect(await store.load('a', 'other'), isNull);
      await store.saveWallpaper(
        'a',
        thread,
        'custom',
        Uint8List.fromList([1, 2, 3]),
        dim: .8,
      );
      await store.save('a', thread, const ChatDraft(id: id, text: ''));
      expect(await store.load('a', thread), isNull);
      expect((await store.wallpaper('a', thread))['preset'], 'custom');
      expect((await store.wallpaper('a', thread))['dim'], .8);
      expect(await store.wallpaper('b', thread), isEmpty);
      final voice = ChatVoice(
        bytes: Uint8List.fromList([1, 2, 3]),
        format: 'webm',
        durationMs: 120000,
      );
      await store.save('a', thread, ChatDraft(id: id, text: '', voice: voice));
      final restored = await ChatLocalStore().load('a', thread);
      expect(restored?.id, id);
      expect(restored?.voice?.durationMs, 120000);
      expect(restored?.voice?.bytes, [1, 2, 3]);
      expect(await store.load('b', thread), isNull);
      await store.save(
        'a',
        thread,
        ChatDraft(
          id: id,
          text: '',
          voice: ChatVoice(
            bytes: Uint8List.fromList([1]),
            format: 'webm',
            durationMs: 120001,
          ),
        ),
      );
      expect(await store.load('a', thread), isNull);
    },
  );
}
