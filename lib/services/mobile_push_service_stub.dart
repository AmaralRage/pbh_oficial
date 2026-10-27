import 'package:supabase_flutter/supabase_flutter.dart';

class MobilePushService {
  static bool get isSupported => false;
  static bool get isConfigured => false;
  static Future<bool> get deviceEnabled async => true;
  static Future<void> bind(SupabaseClient client) async {}
  static Future<void> subscribe() async =>
      throw UnsupportedError('Push nativo indisponível nesta plataforma.');
  static Future<void> unregister() async {}
  static Future<void> disable() async {}
  static Future<void> setSound(bool enabled) async {}
}
