import '../models/profile_achievement.dart';
import 'notification_preferences.dart';
import 'platinum_sound_native.dart'
    if (dart.library.js_interop) 'platinum_sound_web.dart'
    as playback;

class PlatinumSound {
  static Future<bool>? _preparedPreference;
  static void prepareForUnlock() {
    // Read storage during the click/dialog transition, not when the reveal starts.
    _preparedPreference = NotificationPreferences.sound.catchError(
      (Object _) => false,
    );
    playback.preparePlatinumSound();
  }

  static void playFor(ProfileAchievement badge) {
    if (!badge.isJourneyTrophy) return;
    final preference = _preparedPreference ?? NotificationPreferences.sound;
    _preparedPreference = null;
    playback.playPlatinumSound(preference);
  }
}
