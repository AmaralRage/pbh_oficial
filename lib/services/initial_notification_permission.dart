import 'package:shared_preferences/shared_preferences.dart';

/// One permission request per installation; declining never causes repeat prompts.
class InitialNotificationPermission {
  InitialNotificationPermission({SharedPreferencesAsync? storage})
    : _storage = storage ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _storage;
  static const enabledKey = 'pbh.push.device.enabled';
  static const askedKey = 'pbh.push.permission.asked';

  Future<void> requestOnce(Future<bool> Function() request) async {
    if (await _storage.getBool(askedKey) == true ||
        await _storage.getBool(enabledKey) == false) {
      return;
    }
    // Save before opening the system dialog, including if the app is closed there.
    await _storage.setBool(askedKey, true);
    final allowed = await request();
    await _storage.setBool(enabledKey, allowed);
  }
}
