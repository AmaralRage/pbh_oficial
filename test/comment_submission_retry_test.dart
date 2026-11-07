import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/services/comment_submission_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'lost comment acknowledgement retries the same UUID after service recreation',
    () async {
      final ids = <String>{};
      var calls = 0;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({
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
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/submit_community_comment')) {
            ids.add((jsonDecode(request.body) as Map)['p_id'] as String);
            if (++calls == 1) {
              throw http.ClientException('response lost after insert');
            }
          }
          return http.Response(
            'null',
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
      await expectLater(
        CommunityService(client: client).addComment('post', 'My comment'),
        throwsA(isA<http.ClientException>()),
      );
      await CommunityService(client: client).addComment('post', 'My comment');
      expect(ids.length, 1);
      await CommunityService(
        client: client,
      ).confirmCommentDraftCleared('post', 'My comment');
      await CommunityService(client: client).addComment('post', 'My comment');
      expect(
        ids.length,
        2,
        reason: 'a new deliberate comment must receive its own UUID',
      );
    },
  );
  test(
    'pending comment attempts stay separate by member, post and reply target',
    () async {
      final store = CommentSubmissionStore();
      final first = await store.requestId(
        'a',
        'post',
        'text',
        null,
        false,
        CommunityService.newPostId,
      );
      expect(
        await CommentSubmissionStore().requestId(
          'a',
          'post',
          'text',
          null,
          false,
          CommunityService.newPostId,
        ),
        first,
      );
      expect(
        await store.requestId(
          'b',
          'post',
          'text',
          null,
          false,
          CommunityService.newPostId,
        ),
        isNot(first),
      );
      expect(
        await store.requestId(
          'a',
          'other',
          'text',
          null,
          false,
          CommunityService.newPostId,
        ),
        isNot(first),
      );
      expect(
        await store.requestId(
          'a',
          'post',
          'text',
          'reply',
          false,
          CommunityService.newPostId,
        ),
        isNot(first),
      );
    },
  );
}
