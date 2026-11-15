import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/chat_message_photo.dart';

void main() {
  for (final dimensions in [
    const Size(400, 1200),
    const Size(1200, 400),
    const Size(600, 600),
  ]) {
    testWidgets('photo preserves $dimensions without a square crop', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final bytes = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          dimensions.width.toInt(),
          dimensions.height.toInt(),
        );
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        return data!.buffer.asUint8List();
      });
      final provider = MemoryImage(bytes!);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ChatMessagePhoto(image: provider),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          provider,
          tester.element(find.byType(ChatMessagePhoto)),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(RawImage));
      expect(size.width / size.height, closeTo(dimensions.aspectRatio, .001));
      expect(size.width, lessThanOrEqualTo(240.001));
      expect(size.height, lessThanOrEqualTo(300.001));
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
      expect(tester.takeException(), isNull);
    });
  }
}
