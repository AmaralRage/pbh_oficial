import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/models/community_photo.dart';

const owner = 'ad300000-0000-4000-8000-000000000001';
const postId = 'ad300000-0000-4000-8000-000000000004';
final photo = CommunityPhoto(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
);
Map<String, dynamic> token() => {
  'access_token': 'test-token',
  'refresh_token': 'test-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': owner,
    'aud': 'authenticated',
    'email': 'test@example.invalid',
    'created_at': '2026-10-30T12:00:00Z',
    'app_metadata': {},
    'user_metadata': {},
  },
};

void main() {
  test(
    'feed refresh reuses valid image URLs and explicit reload renews them',
    () async {
      var signatures = 0;
      final path = '$owner/$postId/0.png';
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          Object body;
          if (request.url.path.contains('/object/sign/')) {
            signatures++;
            body = [
              {
                'path': path,
                'signedURL':
                    '/object/sign/community-photos/$path?token=$signatures',
                'error': null,
              },
            ];
          } else {
            body = [
              {
                'id': postId,
                'user_id': owner,
                'author_name': 'Author',
                'content': 'Post',
                'created_at': '2026-11-02T12:00:00Z',
                'image_paths': [path],
              },
            ];
          }
          return http.Response(
            jsonEncode(body),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      try {
        final service = CommunityService(client: client);
        final first = (await service.fetchPosts()).single.imageUrls.single;
        expect(first, isNotEmpty);
        final refreshed = (await service.fetchPosts()).single.imageUrls.single;
        expect(refreshed, first);
        expect(signatures, 1);
        CommunityService(client: client).invalidatePhotoUrls([path]);
        final renewed = (await service.fetchPosts()).single.imageUrls.single;
        expect(renewed, isNot(first));
        expect(signatures, 2);
      } finally {
        await client.dispose();
      }
    },
  );

  for (final failUpload in [false, true]) {
    test(
      'upload owns its paths and reconciles a lost publish response (failUpload=$failUpload)',
      () async {
        var committed = false, posts = 0, uploads = 0, deletesAfterCommit = 0;
        List<dynamic>? reserved;
        final client = SupabaseClient(
          'https://test.supabase.co',
          'public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            Object? body = <Object>[];
            var status = 200;
            final path = request.url.path;
            if (path.endsWith('/token')) {
              body = token();
            } else if (path.endsWith('/prepare_community_photos')) {
              reserved = (jsonDecode(request.body) as Map)['p_paths'] as List;
              body = null;
            } else if (path.endsWith('/community_posts')) {
              if (request.method == 'POST') {
                posts++;
                final payload = jsonDecode(request.body) as Map;
                expect(payload['image_paths'], ['$owner/$postId/0.png']);
                expect(payload['user_id'], owner);
                committed = true;
                status = 500;
                body = {'code': 'XX000', 'message': 'lost response'};
              } else {
                expect(request.url.queryParameters['user_id'], 'eq.$owner');
                body = committed
                    ? [
                        {'id': postId},
                      ]
                    : [];
              }
            } else if (path.contains('/storage/v1/object/community-photos')) {
              if (request.method == 'DELETE') {
                if (committed) deletesAfterCommit++;
              } else {
                uploads++;
                expect(path.endsWith('/$owner/$postId/0.png'), true);
                if (failUpload) {
                  status = 400;
                  body = {
                    'statusCode': '400',
                    'message': 'upload failed',
                    'error': 'Bad Request',
                  };
                } else {
                  body = {'Key': 'community-photos/$owner/$postId/0.png'};
                }
              }
            }
            return http.Response(
              jsonEncode(body),
              status,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        try {
          await client.auth.signInWithPassword(
            email: 'test@example.invalid',
            password: 'password',
          );
          final service = CommunityService(client: client);
          final sending = service.createPost(
            'Meu relato',
            photos: [photo],
            draftId: postId,
          );
          if (failUpload) {
            await expectLater(sending, throwsA(anything));
            expect(posts, 0);
          } else {
            await sending;
            await service.createPost(
              'Meu relato',
              photos: [photo],
              draftId: postId,
            );
            expect(posts, 1);
          }
          expect(reserved, ['$owner/$postId/0.png']);
          expect(uploads, 1);
          expect(deletesAfterCommit, 0);
        } finally {
          await client.dispose();
        }
      },
    );
  }
  test('failed photo signing preserves a readable text post', () async {
    final client = SupabaseClient(
      'https://test.supabase.co',
      'public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final feed = request.url.path.endsWith('/community_feed');
        final body = feed
            ? [
                {
                  'id': postId,
                  'user_id': owner,
                  'created_at': '2026-10-30T12:00:00Z',
                  'content': 'Relato preservado',
                  'image_paths': ['$owner/$postId/0.png'],
                },
              ]
            : {'statusCode': '403', 'message': 'denied', 'error': 'Forbidden'};
        return http.Response(
          jsonEncode(body),
          feed ? 200 : 403,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    try {
      final posts = await CommunityService(client: client).fetchPosts();
      expect(posts.single.content, 'Relato preservado');
      expect(posts.single.imageUrls, ['']);
    } finally {
      await client.dispose();
    }
  });
}
