import 'package:shared_preferences/shared_preferences.dart';

/// Local fallback for the introduction explicitly enabled by new sign-ups.
class WelcomePreferences {
  WelcomePreferences({SharedPreferencesAsync? storage})
    : _storage = storage ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _storage;
  String _key(String userId) => 'pbh.welcome.account.$userId.completed';
  Future<bool> shouldShow(String userId, {required bool newlyCreated}) async {
    if (!newlyCreated || userId.isEmpty) return false;
    try {
      return !(await _storage.getBool(_key(userId)) ?? false);
    } catch (_) {
      return true;
    }
  }

  Future<void> complete(String userId) async {
    try {
      await _storage.setBool(_key(userId), true);
    } catch (_) {
      // Failure to remember the introduction must never block access to the app.
    }
  }
}
