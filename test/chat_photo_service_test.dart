import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/chat_models.dart';
import 'package:pbh_oficial/services/chat_service.dart';

void main() {
  test(
    'private photo checks current visibility before and after authenticated download',
    () async {
      var visible = true,
          revokeDuringDownload = false,
          downloads = 0,
          checks = 0;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public',
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
                  'created_at': '2026-11-09T00:00:00Z',
                  'app_metadata': {},
                  'user_metadata': {},
                },
              }),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          if (r.url.path.endsWith('/chat_messages')) {
            checks++;
            return http.Response(
              jsonEncode(
                visible ? {'image_path': 'member/thread/photo.jpg'} : null,
              ),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          if (r.url.path.contains('/storage/v1/object/')) {
            downloads++;
            expect(r.headers['authorization'], 'Bearer fixture');
            if (revokeDuringDownload) visible = false;
            return http.Response.bytes(
              [0xff, 0xd8, 0xff, 0xe0],
              200,
              request: r,
            );
          }
          throw StateError('Unexpected request');
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'fixture',
      );
      ChatMessage photo({bool expired = false}) => ChatMessage(
        id: 'photo',
        senderId: 'other',
        body: '',
        imagePath: 'member/thread/photo.jpg',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(days: expired ? -1 : 1)),
      );
      final service = ChatService(client: client);
      expect(await service.photo('thread', photo()), [0xff, 0xd8, 0xff, 0xe0]);
      expect(downloads, 1);
      expect(checks, 2);
      visible = false;
      await expectLater(service.photo('thread', photo()), throwsStateError);
      expect(downloads, 1);
      visible = true;
      await expectLater(
        service.photo('thread', photo(expired: true)),
        throwsStateError,
      );
      expect(downloads, 1);
      revokeDuringDownload = true;
      await expectLater(service.photo('thread', photo()), throwsStateError);
      expect(downloads, 2);
    },
  );
}
