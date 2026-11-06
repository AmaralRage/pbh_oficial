import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/services/community_post_navigation.dart';

void main() {
  test(
    'retrying a failed broadcast never inserts the saved post twice',
    () async {
      var inserts = 0, queued = 0;
      const id = 'bc500000-0000-4000-8000-000000000003';
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          Object? response = [];
          var status = 200;
          if (request.url.path.endsWith('/token'))
            response = {
              'access_token': 'test-token',
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'leader',
                'email': 'private@example.invalid',
                'aud': 'authenticated',
                'created_at': '2026-11-05T00:00:00Z',
                'email_confirmed_at': '2026-11-05T00:00:00Z',
                'app_metadata': {'pbh_project_leader': true},
                'user_metadata': {},
              },
            };
          if (request.url.path.endsWith('/community_posts')) {
            if (request.method == 'POST') {
              inserts++;
              response = null;
            } else {
              response = inserts > 0
                  ? [
                      {'id': id},
                    ]
                  : [];
            }
          }
          if (request.url.path.endsWith('/queue_community_post_broadcast')) {
            queued++;
            expect(jsonDecode(request.body), {'p_post': id});
            if (queued == 1) {
              status = 503;
              response = {'code': 'temporary', 'message': 'try again'};
            } else {
              response = 'notice';
            }
          }
          return http.Response(
            jsonEncode(response),
            status,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'private@example.invalid',
        password: 'test',
      );
      final service = CommunityService(client: client);
      expect(service.canNotifyMembers, true);
      await expectLater(
        service.createPost('Test', draftId: id, notifyMembers: true),
        throwsA(isA<CommunityBroadcastPending>()),
      );
      await service.createPost('Test', draftId: id, notifyMembers: true);
      expect(inserts, 1);
      expect(queued, 2);
    },
  );
  test(
    'notification links are restricted to PBH and to the current recipient',
    () {
      const id = 'bc500000-0000-4000-8000-000000000003';
      CommunityPostNavigation.pending.value = null;
      CommunityPostNavigation.fromNotification({
        'recipient_id': 'other',
        'destination_url': 'https://pbh-oficial.vercel.app/?community_post=$id',
      }, 'member');
      expect(CommunityPostNavigation.pending.value, isNull);
      CommunityPostNavigation.fromNotification({
        'recipient_id': 'member',
        'destination_url': 'https://pbh-oficial.vercel.app/?community_post=$id',
      }, 'member');
      expect(CommunityPostNavigation.pending.value, id);
      expect(
        communityPostFromNotificationUrl(
          'https://other.invalid/?community_post=$id',
        ),
        isNull,
      );
      expect(
        communityPostFromNotificationUrl(
          'https://pbh-oficial.vercel.app/?community_post=invalid',
        ),
        isNull,
      );
      CommunityPostNavigation.pending.value = null;
    },
  );
}
