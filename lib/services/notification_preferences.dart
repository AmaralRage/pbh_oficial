import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPreferences {
  NotificationPreferences._();

  static final SharedPreferencesAsync _storage = SharedPreferencesAsync();
  static String get _userKey =>
      Supabase.instance.client.auth.currentUser?.id ?? 'guest';
  static String get _enabledKey => 'pbh.notifications.$_userKey.enabled';
  static String get _soundKey => 'pbh.notifications.$_userKey.sound';

  static Future<bool> get enabled async =>
      await _storage.getBool(_enabledKey) ?? true;
  static Future<bool> get sound async =>
      await _storage.getBool(_soundKey) ?? true;

  static Future<void> setEnabled(bool value) =>
      _storage.setBool(_enabledKey, value);
  static Future<void> setSound(bool value) =>
      _storage.setBool(_soundKey, value);
}
