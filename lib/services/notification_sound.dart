import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

class NotificationSound {
  NotificationSound._();

  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play() async {
    try {
      await _player.play(BytesSource(_tone()));
    } catch (_) {
      // A browser may block audio until the user interacts with the page.
    }
  }

  static Uint8List _tone() {
    const sampleRate = 22050;
    final firstToneSamples = (sampleRate * .12).round();
    final silenceSamples = (sampleRate * .045).round();
    final secondToneSamples = (sampleRate * .19).round();
    final sampleCount = firstToneSamples + silenceSamples + secondToneSamples;
    final dataLength = sampleCount * 2;
    final bytes = ByteData(44 + dataLength);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
      double sample = 0;
      if (i < firstToneSamples) {
        sample = _sine(i, firstToneSamples, 880);
      } else if (i >= firstToneSamples + silenceSamples) {
        sample = _sine(i - firstToneSamples - silenceSamples, secondToneSamples, 1174);
      }
      bytes.setInt16(44 + i * 2, (sample * 10500).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  static double _sine(int index, int length, double frequency) {
    final fade = math.min(1.0, math.min(index / 300, (length - index) / 300));
    return math.sin(2 * math.pi * frequency * index / 22050) * fade;
  }
}
