import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pbh_oficial/screens/chat_photo_preview_screen.dart';

void main() {
  testWidgets(
    'photo preview keeps caption and send accessible above keyboard on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 8, height: 16)),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: ChatPhotoPreviewScreen(bytes: bytes),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        List.filled(16, 'Uma legenda para minha foto.').join(' '),
      );
      await tester.pump();
      expect(find.text('0/2000'), findsNothing);
      expect(
        tester.getBottomRight(find.byTooltip('Enviar foto')).dy,
        lessThanOrEqualTo(480),
      );
      expect(
        tester.getSize(find.byTooltip('Enviar foto')).width,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'photo preview preserves caption on cancel and returns only explicit confirmation',
    (tester) async {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 8, height: 8)),
      );
      String? confirmed;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  confirmed = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPhotoPreviewScreen(
                        bytes: bytes,
                        caption: 'Legenda original',
                      ),
                    ),
                  );
                },
                child: const Text('Escolher foto'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Escolher foto'));
      await tester.pumpAndSettle();
      expect(find.text('Legenda original'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Legenda revisada');
      await tester.tap(find.byTooltip('Cancelar envio'));
      await tester.pumpAndSettle();
      expect(confirmed, isNull);
      await tester.tap(find.text('Escolher foto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Legenda revisada');
      await tester.tap(find.byTooltip('Enviar foto'));
      await tester.pumpAndSettle();
      expect(confirmed, 'Legenda revisada');
      expect(tester.takeException(), isNull);
    },
  );
}
