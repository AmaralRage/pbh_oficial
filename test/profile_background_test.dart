import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_style.dart';
import 'package:pbh_oficial/widgets/profile_background.dart';

void main() {
  test(
    'background survives saving, copying and reward validation independently of the cover',
    () {
      const path = 'ad300000-0000-4000-8000-000000000001/123456.png';
      const original = ProfileStyle(
        background: 'custom',
        backgroundPath: path,
        backgroundDim: .65,
        cover: 'night',
      );
      final restored = ProfileStyle.fromMetadata({
        'profile_style': original.toMap(),
      }).validated(founder: false, completed: 0, earned: []);
      expect(restored.background, 'custom');
      expect(restored.backgroundPath, path);
      expect(restored.backgroundDim, .65);
      expect(restored.copyWith(frameEffect: 'none').backgroundPath, path);
      expect(restored.cover, 'night');
      expect(restored.copyWith(backgroundPath: '').backgroundPath, '');
      final bad = ProfileStyle.fromMetadata({
        'profile_style': {
          'background': 'script',
          'background_path': '../private/file.html',
          'background_dim': 99,
        },
      });
      expect(bad.background, 'none');
      expect(bad.backgroundPath, '');
      expect(bad.backgroundDim, .85);
      expect(ProfileStyle.safeBackgroundDim(double.nan), .35);
      expect(ProfileStyle.fromMetadata({}).background, 'none');
    },
  );
  testWidgets(
    'background stays behind readable cards while the profile scrolls on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final kind in ['none', 'ember', 'library', 'astral']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileBackground(
                style: ProfileStyle(background: kind),
                child: ListView(
                  children: [
                    for (var i = 0; i < 12; i++)
                      Card(child: SizedBox(height: 90, child: Text('Card $i'))),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Card 0'), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
