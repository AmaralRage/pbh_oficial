import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/screens/profile_image_cropper.dart';

void main() {
  testWidgets('cropper exports only the image viewport as a bounded PNG', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    Uint8List? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<Uint8List>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileImageCropper(
                      bytes: bytes,
                      aspectRatio: 2,
                      title: 'Ajustar imagem',
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar recorte'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.length, lessThanOrEqualTo(5 * 1024 * 1024));
    final codec = await tester.runAsync(
      () => ui.instantiateImageCodec(result!),
    );
    final frame = await tester.runAsync(() => codec!.getNextFrame());
    expect(frame!.image.width / frame.image.height, closeTo(2, .02));
    frame.image.dispose();
    codec!.dispose();
  });
  testWidgets('framing returns a normalized viewport without replacing source bytes', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    List<double>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<List<double>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileImageCropper(
                      bytes: bytes,
                      aspectRatio: 2,
                      title: 'Ajustar imagem',
                      returnFraming: true,
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar recorte'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!, hasLength(4));
    expect(result![0], closeTo(0, .01));
    expect(result![1], closeTo(0, .01));
    expect(result![2], closeTo(1, .01));
    expect(result![3], closeTo(.5, .01));
    expect(bytes.length, greaterThan(0));
  });

}
