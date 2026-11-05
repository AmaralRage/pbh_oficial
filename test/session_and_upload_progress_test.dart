import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/community_photo.dart';
import 'package:pbh_oficial/services/auth_service.dart';
import 'package:pbh_oficial/services/community_service.dart';

void main() {
  test(
    'other-device logout keeps this session; uploads report only completed attachments',
    () async {
      String? scope;
      var uploadCount = 0;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          Object result = [];
          if (request.url.path.endsWith('/token'))
            result = {
              'access_token': 'test-token',
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'ef500000-0000-4000-8000-000000000002',
                'aud': 'authenticated',
                'email': 'test@example.invalid',
                'created_at': '2026-11-05T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            };
          if (request.url.path.endsWith('/logout'))
            scope = request.url.queryParameters['scope'];
          if (request.url.path.contains(
                '/storage/v1/object/community-photos/',
              ) &&
              request.method == 'POST') {
            uploadCount++;
            result = {'Key': 'ok'};
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
        email: 'test@example.invalid',
        password: 'test',
      );
      await AuthService(client: client).signOutOtherDevices();
      expect(scope, 'others');
      expect(client.auth.currentSession, isNotNull);
      final progress = <String>[];
      final photo = CommunityPhoto(Uint8List.fromList([255, 216, 255, 0]));
      await CommunityService(client: client).createPost(
        'Test',
        photos: [photo, photo],
        onUploadProgress: (done, total) {
          expect(done, uploadCount);
          progress.add('$done/$total');
        },
      );
      expect(progress, ['0/2', '1/2', '2/2']);
      expect(uploadCount, 2);
    },
  );
}
