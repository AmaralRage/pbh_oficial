@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/widgets/native_platinum_art.dart';
import 'package:pbh_oficial/widgets/supreme_seal_art.dart';

void main() {
  testWidgets(
    'both web journey trophies start one callback with the native reveal',
    (tester) async {
      await tester.runAsync(() async {
        await NativePlatinumArt.preload();
        await NativePlatinumArt.preloadRuby();
      });
      for (final badge in [
        ProfileAchievement.platinum,
        ProfileAchievement.knowledgePlatinum,
      ]) {
        var starts = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SupremeSealArt(
                key: ValueKey(badge.id),
                size: 160,
                achievement: badge,
                celebrate: true,
                onAnimationStarted: () => starts++,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(HtmlElementView), findsNothing);
        expect(find.byType(NativePlatinumArt), findsOneWidget);
        expect(starts, 0);
        await tester.pump(const Duration(milliseconds: 650));
        expect(starts, 1);
        await tester.pump(const Duration(seconds: 7));
        expect(starts, 1);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
