import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pbh_oficial/widgets/bonfire_art.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'vector bonfire stays on the right and its cover remains available to members',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintBonfireArt(canvas, const Size(650, 230), 1.5, .5);
      final picture = recorder.endRecording();
      final image = await picture.toImage(650, 230);
      try {
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var rightPixels = 0;
        for (var y = 0; y < 230; y++) {
          for (var x = 0; x < 650; x++) {
            final alpha = pixels.getUint8((y * 650 + x) * 4 + 3);
            if (x < 325) {
              expect(
                alpha,
                0,
                reason: 'The bonfire must not cover the left avatar area',
              );
            } else if (alpha > 50) {
              rightPixels++;
            }
          }
        }
        expect(rightPixels, greaterThan(1000));
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory('build').create(recursive: true);
        await File('build/bonfire-vector-preview.png').writeAsBytes(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        );
      } finally {
        image.dispose();
        picture.dispose();
      }
      final style = ProfileStyle.fromMetadata({
        'profile_style': const ProfileStyle(
          cover: 'bonfire',
          coverEffect: 'embers',
        ).toMap(),
      }).validated(founder: false, completed: 0, earned: []);
      expect(style.cover, 'bonfire');
      expect(style.coverEffect, 'embers');
    },
  );
}
