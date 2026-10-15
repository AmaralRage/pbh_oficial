import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const adminEmail = 'amaralaragao31@gmail.com';

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Future<void> createAccount(String email, String password) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: Uri.base.origin,
    );
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
      redirectTo: Uri.base.origin,
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

  Future<void> signOut() => _client.auth.signOut();
}
