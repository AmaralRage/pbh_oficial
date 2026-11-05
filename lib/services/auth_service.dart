import 'package:supabase_flutter/supabase_flutter.dart';
import 'mobile_push_service.dart';

class AuthService {
  AuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // app_metadata is controlled by Auth's server, never by profile edits.
  static bool isProjectLeader(User? user) =>
      user?.emailConfirmedAt != null &&
      user?.appMetadata['pbh_project_leader'] == true;

  static Future<void> refreshLegacyIdentity(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null || user.appMetadata.containsKey('pbh_project_leader'))
      return;
    // Existing sessions predate the server claim. Refresh before applying
    // founder appearance; do not discard a valid session on network failure.
    try {
      await client.auth.refreshSession().timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  final SupabaseClient _client;
  // Native apps have no HTTP origin; let Supabase use its configured Site URL.
  String? get _emailRedirect =>
      const {'http', 'https'}.contains(Uri.base.scheme)
      ? Uri.base.origin
      : null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Future<void> createAccount(String email, String password) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'pbh_welcome_pending': true},
      emailRedirectTo: _emailRedirect,
    );
  }

  Future<void> completeWelcome(String userId) async {
    if (_client.auth.currentUser?.id != userId) return;
    await _client.auth
        .updateUser(UserAttributes(data: {'pbh_welcome_pending': false}))
        .timeout(const Duration(seconds: 10));
  }

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _emailRedirect,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<bool> isAdmin() async {
    final user = currentUser;
    if (user == null) return false;
    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return profile?['role'] == 'admin';
  }

  Future<void> signOut() async {
    await MobilePushService.unregister();
    await _client.auth.signOut();
  }

  Future<void> signOutOtherDevices() async {
    if (currentUser == null) throw StateError('Entre na sua conta.');
    await _client.auth.signOut(scope: SignOutScope.others);
  }
}
