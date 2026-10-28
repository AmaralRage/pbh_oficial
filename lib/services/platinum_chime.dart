import 'dart:math' as math;
import 'dart:typed_data';

// Same frequencies, stagger and exponential envelope as the supplied HTML.
const platinumChimeFrequencies = [523.25, 783.99, 1046.5, 1567.98];
Uint8List? _cachedChime;
Uint8List platinumChimeWav() => _cachedChime ??= _encodeChime();

Uint8List _encodeChime() {
  const rate = 22050;
  final samples = ((1.3 + .115 * 3) * rate).ceil();
  final data = ByteData(44 + samples * 2);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    final time = i / rate;
    var amplitude = 0.0;
    for (var note = 0; note < platinumChimeFrequencies.length; note++) {
      final elapsed = time - note * .115;
      if (elapsed < 0 || elapsed >= 1.3) continue;
      final gain = elapsed < .035
          ? .0001 * math.pow(.095 / .0001, elapsed / .035)
          : elapsed < 1.25
          ? .095 * math.pow(.0001 / .095, (elapsed - .035) / 1.215)
          : .0001 * (1.3 - elapsed) / .05;
      amplitude +=
          math.sin(2 * math.pi * platinumChimeFrequencies[note] * elapsed) *
          gain;
    }
    data.setInt16(
      44 + i * 2,
      (amplitude.clamp(-1, 1) * 32767).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}
