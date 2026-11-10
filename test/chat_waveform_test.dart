import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/services/chat_waveform.dart';
import 'package:pbh_oficial/widgets/chat_waveform.dart';

Uint8List recording() {
  const rate = 8000;
  final data = ByteData(44 + rate * 2);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, data.lengthInBytes - 8, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, rate * 2, Endian.little);
  for (var i = 0; i < rate; i++) {
    data.setInt16(
      44 + i * 2,
      i < 3200 ? 0 : (math.sin(i * 2 * math.pi * 440 / rate) * 24000).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    test(
      'real decoded waveform distinguishes silence from audible PCM',
      () async {
        final values = await extractChatWaveform(recording(), 1000);
        expect(values, hasLength(64));
        expect(values.take(20).every((v) => v < .01), isTrue);
        expect(values.skip(32).every((v) => v > .8), isTrue);
      },
    );
  } else {
    test(
      'native extraction bounds output and rejects oversized recordings before invoking platform',
      () async {
        const channel = MethodChannel('pbh/chat_waveform');
        var calls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls++;
              return [-1, 2, ...List.filled(70, .5)];
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final values = await extractChatWaveform(recording(), 1000);
        expect(values, hasLength(64));
        expect(values.first, 0);
        expect(values[1], 1);
        expect(await extractChatWaveform(Uint8List(1048577), 1000), isEmpty);
        expect(await extractChatWaveform(recording(), 120001), isEmpty);
        expect(calls, 1);
      },
    );
  }
  testWidgets(
    'waveform follows touch position and exposes accessible progress',
    (tester) async {
      double? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: ChatWaveform(
                samples: const [0, .5, 1, .25],
                progress: .25,
                onSeek: (v) => selected = v,
              ),
            ),
          ),
        ),
      );
      final bounds = tester.getRect(find.byType(ChatWaveform));
      await tester.tapAt(
        Offset(bounds.left + bounds.width * .75, bounds.center.dy),
      );
      expect(selected, closeTo(.75, .02));
      expect(find.bySemanticsLabel('Progresso do áudio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
