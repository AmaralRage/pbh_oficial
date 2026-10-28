import '../models/profile_achievement.dart';
import 'notification_preferences.dart';
import 'platinum_sound_native.dart'
    if (dart.library.js_interop) 'platinum_sound_web.dart'
    as playback;

class PlatinumSound {
  static void prepareForUnlock() => playback.preparePlatinumSound();
  static void playFor(ProfileAchievement badge) {
    if (badge.htmlAsset != ProfileAchievement.platinum.htmlAsset) return;
    playback.playPlatinumSound(NotificationPreferences.sound);
  }
}
