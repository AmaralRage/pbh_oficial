import 'package:audioplayers/audioplayers.dart';
import 'platinum_chime.dart';

final _player = AudioPlayer();
void preparePlatinumSound() {}
Future<void> playPlatinumSound(Future<bool> enabled) async {
  try {
    if (!await enabled) return;
    await _player.play(BytesSource(platinumChimeWav(), mimeType: 'audio/wav'));
  } catch (_) {
    /* Audio failure never prevents opening trophy details. */
  }
}
