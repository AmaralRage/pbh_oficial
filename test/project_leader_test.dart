import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/auth_service.dart';

User account(String email, {bool confirmed = true, String? displayName}) =>
    User(
      id: 'account',
      appMetadata: const {},
      userMetadata: {'display_name': displayName, 'role': 'admin'},
      aud: 'authenticated',
      email: email,
      createdAt: '2026-10-21T00:00:00Z',
      emailConfirmedAt: confirmed ? '2026-10-21T00:00:00Z' : null,
    );

void main() {
  test('only the confirmed project leader receives the special award', () {
    expect(
      AuthService.isProjectLeader(account(AuthService.adminEmail)),
      isTrue,
    );
    expect(
      AuthService.isProjectLeader(account('AMARALARAGAO31@gmail.com')),
      isTrue,
    );
    expect(
      AuthService.isProjectLeader(
        account(AuthService.adminEmail, confirmed: false),
      ),
      isFalse,
    );
    expect(
      AuthService.isProjectLeader(
        account('another-admin@example.com', displayName: 'Amaral'),
      ),
      isFalse,
    );
    expect(AuthService.isProjectLeader(null), isFalse);
  });
}
