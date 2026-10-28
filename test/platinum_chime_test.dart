import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/services/platinum_chime.dart';

void main() {
  test(
    'original platinum chord produces valid PCM with four audible notes and a quiet ending',
    () {
      final wav = platinumChimeWav();
      final data = ByteData.sublistView(wav);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint16(34, Endian.little), 16);
      expect(data.getUint32(40, Endian.little), wav.length - 44);
      final rate = data.getUint32(24, Endian.little);
      final samples = (wav.length - 44) ~/ 2;
      expect(samples / rate, closeTo(1.645, .001));
      double energy(double frequency) {
        var real = 0.0, imaginary = 0.0;
        for (var i = 0; i < samples; i++) {
          final value = data.getInt16(44 + i * 2, Endian.little) / 32768;
          final phase = 2 * math.pi * frequency * i / rate;
          real += value * math.cos(phase);
          imaginary += value * math.sin(phase);
        }
        return real * real + imaginary * imaginary;
      }

      for (final note in platinumChimeFrequencies) {
        expect(energy(note), greaterThan(energy(333) * 100));
      }
      expect(
        data.getInt16(44 + (samples - 1) * 2, Endian.little).abs(),
        lessThan(4),
      );
    },
  );
}
