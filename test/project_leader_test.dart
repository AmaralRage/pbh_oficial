import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/auth_service.dart';

User account(
  String email, {
  bool confirmed = true,
  String? displayName,
  Object? claim,
  bool forged = false,
}) => User(
  id: 'account',
  appMetadata: {if (claim != null) 'pbh_project_leader': claim},
  userMetadata: {
    'display_name': displayName,
    'role': 'admin',
    'pbh_project_leader': forged,
  },
  aud: 'authenticated',
  email: email,
  createdAt: '2026-10-21T00:00:00Z',
  emailConfirmedAt: confirmed ? '2026-10-21T00:00:00Z' : null,
);

void main() {
  test('only the confirmed project leader receives the special award', () {
    expect(
      AuthService.isProjectLeader(
        account('leader@example.invalid', claim: true),
      ),
      isTrue,
    );
    expect(
      AuthService.isProjectLeader(
        account('member@example.invalid', forged: true),
      ),
      isFalse,
    );
    expect(
      AuthService.isProjectLeader(
        account('leader@example.invalid', claim: true, confirmed: false),
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
    expect(
      AuthService.isProjectLeader(
        account('member@example.invalid', claim: 'true'),
      ),
      isFalse,
    );
  });
}
