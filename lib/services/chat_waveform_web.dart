import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:math' as math;
import 'package:web/web.dart' as web;

Future<List<double>> extractChatWaveform(
  Uint8List bytes,
  int durationMs,
) async {
  if (bytes.isEmpty ||
      bytes.length > 1048576 ||
      durationMs < 1 ||
      durationMs > 120000)
    return [];
  try {
    final context = web.OfflineAudioContext(1.toJS, 1, 8000);
    final audio = await context
        .decodeAudioData(Uint8List.fromList(bytes).buffer.toJS)
        .toDart;
    if (audio.duration > 121 || audio.numberOfChannels < 1) return [];
    final pcm = audio.getChannelData(0).toDart;
    final rms = List<double>.generate(64, (i) {
      final start = i * pcm.length ~/ 64, end = (i + 1) * pcm.length ~/ 64;
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += pcm[j] * pcm[j];
      }
      return end > start ? math.sqrt(sum / (end - start)) : 0;
    });
    final peak = rms.fold<double>(0, math.max);
    return rms.map((v) => peak > .0001 ? math.sqrt(v / peak) : 0.0).toList();
  } catch (_) {
    return [];
  }
}
