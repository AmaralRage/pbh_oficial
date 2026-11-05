import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/auth_service.dart';
import 'package:pbh_oficial/services/private_support_service.dart';

void main() {
  test(
    'legacy session receives server identity without changing its account',
    () async {
      var refreshes = 0;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final refreshing =
              request.url.queryParameters['grant_type'] == 'refresh_token';
          if (refreshing) refreshes++;
          return http.Response(
            jsonEncode({
              'access_token': 'test-token',
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'same-account',
                'email': 'private@example.invalid',
                'aud': 'authenticated',
                'created_at': '2026-10-21T00:00:00Z',
                'email_confirmed_at': '2026-10-21T00:00:00Z',
                'app_metadata': {if (refreshing) 'pbh_project_leader': true},
                'user_metadata': {'display_name': 'Same name'},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'private@example.invalid',
        password: 'test',
      );
      expect(AuthService.isProjectLeader(client.auth.currentUser), isFalse);
      await AuthService.refreshLegacyIdentity(client);
      expect(client.auth.currentUser!.id, 'same-account');
      expect(
        client.auth.currentUser!.userMetadata!['display_name'],
        'Same name',
      );
      expect(AuthService.isProjectLeader(client.auth.currentUser), isTrue);
      await AuthService.refreshLegacyIdentity(client);
      expect(refreshes, 1);
    },
  );

  test(
    'support sends only request content, with no founder or member email',
    () async {
      Map<String, dynamic>? sent;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/rest/v1/rpc/submit_private_support_request',
          );
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '"request-id"',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await PrivateSupportService(
        client: client,
      ).submit(kind: 'help', message: '  Help me  ');
      expect(sent, {'p_kind': 'help', 'p_message': 'Help me'});
    },
  );

  test(
    'support failure is propagated instead of reporting a false delivery',
    () async {
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            '{"code":"PGRST202","message":"missing migration"}',
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        PrivateSupportService(
          client: client,
        ).submit(kind: 'account_deletion', message: 'Delete my account'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
