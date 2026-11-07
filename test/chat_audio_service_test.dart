import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/chat_models.dart';
import 'package:pbh_oficial/services/chat_service.dart';

const _thread = 'cc070000-0000-4000-8000-000000000001',
    _id = 'cc070000-0000-4000-8000-000000000011';
const _path = 'member/$_thread/$_id.webm';
Future<SupabaseClient> _client(
  Future<http.Response> Function(http.Request) handler,
) async {
  final client = SupabaseClient(
    'https://test.supabase.co',
    'public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((r) async {
      if (r.url.path.endsWith('/token'))
        return http.Response(
          jsonEncode({
            'access_token': 'fixture',
            'refresh_token': 'fixture',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'member',
              'aud': 'authenticated',
              'created_at': '2026-11-07T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          }),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      return handler(r);
    }),
  );
  await client.auth.signInWithPassword(
    email: 'fixture@example.invalid',
    password: 'fixture',
  );
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'lost voice acknowledgement does not upload, validate or insert twice',
    () async {
      var uploaded = false,
          saved = false,
          uploads = 0,
          validations = 0,
          sends = 0;
      final client = await _client((r) async {
        dynamic data;
        var status = 200;
        if (r.url.path.endsWith('/chat_messages'))
          data = saved
              ? {
                  'id': _id,
                  'sender_id': 'member',
                  'body': '',
                  'reply_to': null,
                  'audio_path': _path,
                  'audio_format': 'webm',
                }
              : null;
        else if (r.url.path.endsWith('/chat_prepare_audio'))
          data = _path;
        else if (r.method == 'HEAD') {
          status = uploaded ? 200 : 404;
          data = uploaded
              ? {}
              : {
                  'statusCode': '404',
                  'error': 'Not found',
                  'message': 'Not found',
                };
        } else if (r.url.path.contains('/storage/v1/object/')) {
          uploads++;
          uploaded = true;
          data = {'Key': 'chat-audio/$_path'};
        } else if (r.url.path.endsWith('/validate-chat-audio')) {
          validations++;
          expect(jsonDecode(r.body), {'path': _path});
          expect(r.headers['authorization'], 'Bearer fixture');
          data = {'duration_ms': 1000};
        } else if (r.url.path.endsWith('/chat_send_audio')) {
          sends++;
          saved = true;
          throw http.ClientException('acknowledgement lost');
        } else {
          throw StateError('Unexpected request ${r.url.path}');
        }
        return http.Response(
          jsonEncode(data),
          status,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.dispose);
      final draft = ChatDraft(
        id: _id,
        text: '',
        voice: ChatVoice(
          bytes: Uint8List.fromList([1, 2, 3]),
          format: 'webm',
          durationMs: 1000,
        ),
      );
      await expectLater(
        ChatService(client: client).send(_thread, draft),
        throwsA(isA<http.ClientException>()),
      );
      await ChatService(client: client).send(_thread, draft);
      expect(uploads, 1);
      expect(validations, 1);
      expect(sends, 1);
    },
  );
  test(
    'voice cache avoids duplicate downloads and still checks current access',
    () async {
      var visible = true, downloads = 0, checks = 0;
      final client = await _client((r) async {
        if (r.url.path.endsWith('/chat_messages')) {
          checks++;
          return http.Response(
            jsonEncode(visible ? {'audio_path': _path} : null),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.url.path.contains('/storage/v1/object/')) {
          downloads++;
          return http.Response.bytes(
            [1, 2, 3],
            200,
            request: r,
            headers: {'content-type': 'audio/webm'},
          );
        }
        throw StateError('Unexpected request');
      });
      addTearDown(client.dispose);
      final service = ChatService(client: client),
          message = ChatMessage(
            id: _id,
            senderId: 'other',
            body: '',
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(days: 7)),
            audioPath: _path,
            audioFormat: 'webm',
            audioDurationMs: 1000,
          );
      expect(await service.audio(_thread, message), [1, 2, 3]);
      expect(await service.audio(_thread, message), [1, 2, 3]);
      expect(downloads, 1);
      expect(checks, 2);
      visible = false;
      await expectLater(service.audio(_thread, message), throwsStateError);
      expect(downloads, 1);
      expect(checks, 3);
    },
  );
}
