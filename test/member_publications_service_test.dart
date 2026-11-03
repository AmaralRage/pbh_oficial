import 'dart:convert';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/widgets/community_photo_gallery.dart';

void main() {
  test(
    'member publications use bounded server privacy RPC and original media paths',
    () async {
      final calls = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          calls.add(request);
          final Object body;
          if (request.url.path.contains('/rpc/member_publications')) {
            body = [
              {
                'id': 'post',
                'user_id': 'member',
                'author_name': 'Member',
                'content': 'Hello',
                'created_at': '2026-11-03T12:00:00Z',
                'image_paths': ['member/post/0.jpg'],
                'image_framings': [
                  [0, .2, 1, .5],
                ],
              },
            ];
          } else {
            body = [
              {
                'path': 'member/post/0.jpg',
                'signedURL':
                    '/object/sign/community-photos/member/post/0.jpg?token=test',
                'error': null,
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
      final posts = await CommunityService(
        client: client,
      ).memberPosts('member', offset: 20);
      expect(jsonDecode(calls.first.body), {
        'p_user': 'member',
        'p_offset': 20,
      });
      expect(posts.single.imagePaths, ['member/post/0.jpg']);
      expect(posts.single.imageFramings, [
        [0, .2, 1, .5],
      ]);
      expect(posts.single.imageUrls.single, contains('0.jpg'));
      await client.dispose();
    },
  );
  test(
    'feed decoding is bounded while full-screen images retain original resolution',
    () {
      final preview =
          CommunityPhotoGallery.photo(
                'https://example.invalid/photo.jpg',
                cacheWidth: 1200,
              )
              as Image;
      final full =
          CommunityPhotoGallery.photo('https://example.invalid/photo.jpg')
              as Image;
      expect(preview.image, isA<ResizeImage>());
      expect((preview.image as ResizeImage).width, 1200);
      expect(full.image, isA<NetworkImage>());
    },
  );
}
