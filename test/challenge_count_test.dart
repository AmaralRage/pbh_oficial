import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/challenge_service.dart';

void main() {
  for (final fallback in [false, true]) {
    test(
      'counts include history beyond one response page (fallback=$fallback)',
      () async {
        final offsets = <int>[];
        final client = SupabaseClient(
          'https://test.supabase.co',
          'public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            Object data;
            var status = 200;
            if (request.url.path.endsWith('/token')) {
              data = {
                'access_token': 'test-token',
                'refresh_token': 'refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': 'test-user',
                  'email': 'member@example.com',
                  'aud': 'authenticated',
                  'app_metadata': {},
                  'user_metadata': {},
                  'created_at': '2026-01-01T00:00:00Z',
                },
              };
            } else if (request.url.path.contains('/rpc/')) {
              data = fallback
                  ? {'code': 'PGRST202', 'message': 'missing function'}
                  : [
                      {'challenge_id': 'read', 'completed_days': 1201},
                    ];
              if (fallback) status = 404;
            } else {
              final offset = int.parse(request.url.queryParameters['offset']!);
              offsets.add(offset);
              data = List.generate(
                (1201 - offset).clamp(0, 500),
                (_) => {'challenge_id': 'read'},
              );
              expect(request.url.queryParameters['user_id'], 'eq.test-user');
            }
            return http.Response(
              jsonEncode(data),
              status,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        await client.auth.signInWithPassword(
          email: 'member@example.com',
          password: 'test',
        );
        expect(await ChallengeService(client: client).completionCounts(), {
          'read': 1201,
        });
        expect(offsets, fallback ? [0, 500, 1000] : <int>[]);
      },
    );
  }
}
