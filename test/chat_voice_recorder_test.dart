import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:pbh_oficial/widgets/chat_voice_recorder.dart';

class _Recorder extends AudioRecorder {
  _Recorder({this.permitted = true});
  bool permitted;
  int starts = 0, stops = 0, cancels = 0;
  RecordConfig? config;
  @override
  Future<bool> hasPermission({bool request = true}) async => permitted;
  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async =>
      encoder == AudioEncoder.aacLc;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    this.config = config;
    starts++;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return 'fixture';
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async {
            if (call.method != 'create')
              throw StateError('Unexpected recorder method');
            return null;
          },
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          null,
        ),
  );
  testWidgets('denied microphone never starts capture', (tester) async {
    final recorder = _Recorder(permitted: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatVoiceRecorder(
            recorder: recorder,
            pathForRecording: (_, __) async => 'fixture',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(recorder.starts, 0);
    expect(find.textContaining('Permita o microfone'), findsOneWidget);
    expect(find.text('Enviar áudio'), findsNothing);
    recorder.permitted = true;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(recorder.starts, 1);
    expect(find.text('Parar gravação'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'capture stops automatically before two minutes and requires explicit send',
    (tester) async {
      final recorder = _Recorder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatVoiceRecorder(
              recorder: recorder,
              pathForRecording: (_, __) async => 'fixture',
              readRecordingBytes: (_) async => Uint8List.fromList([1, 2, 3]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(recorder.starts, 1);
      expect(recorder.config?.bitRate, 32000);
      expect(recorder.config?.numChannels, 1);
      expect(recorder.stops, 0);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 119500));
      await tester.pumpAndSettle();
      expect(recorder.stops, 1);
      expect(find.text('Ouça antes de enviar'), findsOneWidget);
      expect(find.text('Enviar áudio'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(recorder.cancels, 1);
    },
  );
}
