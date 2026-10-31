import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/auth_service.dart';

void main() {
  test(
    'new registration marks welcome pending without requiring a session',
    () async {
      Map<String, dynamic>? payload;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/v1/signup');
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 'ad300000-0000-4000-8000-000000000001',
              'aud': 'authenticated',
              'email': 'new@example.invalid',
              'created_at': '2026-10-30T12:00:00Z',
              'user_metadata': {'pbh_welcome_pending': true},
              'app_metadata': {},
              'identities': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      try {
        await AuthService(
          client: client,
        ).createAccount('new@example.invalid', 'a-valid-test-password');
        expect(payload?['data'], {'pbh_welcome_pending': true});
        expect(client.auth.currentSession, isNull);
      } finally {
        await client.dispose();
      }
    },
  );
}
