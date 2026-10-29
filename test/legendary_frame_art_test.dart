import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_style.dart';
import 'package:pbh_oficial/widgets/legendary_frame_art.dart';
import 'package:pbh_oficial/widgets/animated_profile_frame_art.dart';
import 'package:pbh_oficial/widgets/event_profile_frame_art.dart';
import 'package:pbh_oficial/widgets/cosmic_crown_frame_art.dart';
import 'package:pbh_oficial/widgets/supreme_crown_frame_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'supreme crown is hidden until granted and preserves the photo',
    () async {
      final option = ProfileStyle.frameEffects.firstWhere(
        (o) => o.id == 'supreme_crown',
      );
      expect(
        option.visible(false, 999, {'platinum', 'knowledge_platinum'}),
        false,
      );
      expect(option.visible(true, 0, {}), true);
      expect(option.visible(false, 0, {'supreme_crown'}), true);
      const selected = ProfileStyle(frameEffect: 'supreme_crown');
      expect(
        selected
            .validated(founder: false, completed: 999, earned: [])
            .frameEffect,
        'orbit',
      );
      expect(
        selected
            .validated(
              founder: false,
              completed: 0,
              earned: [],
              manualAwards: {'supreme_crown'},
            )
            .frameEffect,
        'supreme_crown',
      );
      final art = await loadSupremeCrownArt();
      final rgba = (await art.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      for (var y = 0; y < art.height; y++) {
        for (var x = 0; x < art.width; x++) {
          final index = (y * art.width + x) * 4;
          final alpha = rgba.getUint8(index + 3);
          for (var channel = 0; channel < 3; channel++) {
            expect(
              rgba.getUint8(index + channel),
              lessThanOrEqualTo(alpha),
              reason: 'Premultiplied colors must not leave a dark rectangle',
            );
          }
          if (x == 0 || y == 0 || x == art.width - 1 || y == art.height - 1) {
            expect(alpha, 0, reason: 'Outer image edges must be transparent');
          }
        }
      }
      for (final phase in [0.0, .37, .81]) {
        final recorder = ui.PictureRecorder();
        paintSupremeCrownFrame(
          Canvas(recorder),
          const Size(192, 192),
          phase,
          1,
          art,
        );
        final picture = recorder.endRecording(),
            image = await picture.toImage(192, 192);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var y = 0; y < 192; y++) {
          for (var x = 0; x < 192; x++) {
            if ((x - 96) * (x - 96) + (y - 96) * (y - 96) < 40 * 40) {
              expect(data.getUint8((y * 192 + x) * 4 + 3), 0);
            }
          }
        }
        image.dispose();
        picture.dispose();
      }
    },
  );
  test('cosmic crown preserves the photo throughout its cycle', () async {
    expect(
      ProfileStyle(
        frameEffect: 'crown',
      ).validated(founder: false, completed: 0, earned: []).frameEffect,
      isNot('crown'),
    );
    expect(
      ProfileStyle(
        frameEffect: 'crown',
      ).validated(founder: true, completed: 0, earned: []).frameEffect,
      'crown',
    );
    for (final intensity in [0.0, 1.0]) {
      for (final phase in [0.0, .25, .6, .95]) {
        final recorder = ui.PictureRecorder();
        paintCosmicCrownFrame(
          Canvas(recorder),
          const Size(168, 168),
          phase,
          intensity,
        );
        final picture = recorder.endRecording(),
            image = await picture.toImage(168, 168);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var visible = 0;
        for (var y = 0; y < 168; y++) {
          for (var x = 0; x < 168; x++) {
            final alpha = data.getUint8((y * 168 + x) * 4 + 3);
            if (alpha > 0) visible++;
            if ((x - 84) * (x - 84) + (y - 84) * (y - 84) < 40 * 40) {
              expect(
                alpha,
                0,
                reason: 'Crown must preserve photo phase=$phase',
              );
            }
          }
        }
        expect(visible, greaterThan(500));
        image.dispose();
        picture.dispose();
      }
    }
  });
  test(
    'replacement orbit, pulse, flames and twin rings preserve the actual photo radius',
    () async {
      for (final effect in [
        'orbit',
        'pulse',
        'sparks',
        'double',
        ...ProfileStyle.eventFrameEffects,
      ]) {
        final safe = ProfileStyle(
          frameEffect: effect,
        ).validated(founder: false, completed: 0, earned: []);
        expect(
          safe.frameEffect,
          effect,
          reason: 'Existing access must be preserved',
        );
        final event = ProfileStyle.eventFrameEffects.contains(effect);
        final pixels = effect == 'sparks' || event ? 132 : 120;
        for (final intensity in [0.0, 1.0]) {
          for (final phase in [0.0, .33, .78]) {
            final recorder = ui.PictureRecorder();
            (event ? paintEventProfileFrame : paintAnimatedProfileFrame)(
              Canvas(recorder),
              Size.square(pixels.toDouble()),
              phase,
              intensity,
              effect,
            );
            final picture = recorder.endRecording(),
                image = await picture.toImage(pixels, pixels);
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            var visible = 0;
            for (var y = 0; y < pixels; y++) {
              for (var x = 0; x < pixels; x++) {
                final alpha = data!.getUint8((y * pixels + x) * 4 + 3);
                if (alpha > 0) visible++;
                if ((x - pixels / 2) * (x - pixels / 2) +
                        (y - pixels / 2) * (y - pixels / 2) <
                    40 * 40)
                  expect(
                    alpha,
                    0,
                    reason:
                        '$effect must leave the photo unobstructed at $x,$y phase=$phase intensity=$intensity',
                  );
              }
            }
            expect(visible, greaterThan(300));
            image.dispose();
            picture.dispose();
          }
        }
      }
    },
  );
  test(
    'all four frames retain a transparent photo center throughout their cycles',
    () async {
      for (final effect in ProfileStyle.legendaryFrameEffects) {
        for (final phase in [0.0, .27, .73]) {
          final recorder = ui.PictureRecorder();
          paintLegendaryFrame(
            Canvas(recorder),
            const Size(120, 120),
            phase,
            .8,
            effect,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(120, 120);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          var visible = 0;
          for (var y = 0; y < 120; y++) {
            for (var x = 0; x < 120; x++) {
              final alpha = data!.getUint8((y * 120 + x) * 4 + 3);
              if (alpha > 0) visible++;
              if ((x - 60) * (x - 60) + (y - 60) * (y - 60) < 38 * 38)
                expect(alpha, 0, reason: '$effect must preserve the photo');
            }
          }
          expect(visible, greaterThan(500), reason: effect);
          image.dispose();
          picture.dispose();
        }
      }
    },
  );
}
