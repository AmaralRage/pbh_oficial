import 'dart:typed_data';
import 'package:flutter/services.dart';

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
    final values = await const MethodChannel('pbh/chat_waveform')
        .invokeListMethod<num>('extract', {
          'bytes': bytes,
          'durationMs': durationMs,
        });
    return values
            ?.take(64)
            .map<double>((v) => v.isFinite ? v.toDouble().clamp(0.0, 1.0) : 0.0)
            .toList() ??
        [];
  } catch (_) {
    return [];
  }
}
