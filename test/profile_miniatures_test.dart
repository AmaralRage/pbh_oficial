import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/models/profile_style.dart';
import 'package:pbh_oficial/widgets/profile_identity_card.dart';
import 'package:pbh_oficial/widgets/native_platinum_art.dart';

void main() {
  final earned = [
    ProfileAchievement.platinum,
    ProfileAchievement.knowledgePlatinum,
    ...ProfileAchievement.supremeSeals,
  ];
  test(
    'fixed journey trophies coexist with up to three earned selected achievements',
    () {
      const selected = ProfileStyle(
        featured: [
          'supreme_reading',
          'fake',
          'supreme_training',
          'supreme_meditation',
          'supreme_porn_free',
        ],
      );
      final safe = selected.validated(
        founder: false,
        completed: 0,
        earned: earned,
      );
      expect(safe.profileMiniatures(earned).map((e) => e.id), [
        'platinum',
        'knowledge_platinum',
        'supreme_reading',
        'supreme_training',
        'supreme_meditation',
      ]);
      expect(
        const ProfileStyle(
          featured: [],
        ).profileMiniatures(earned).map((e) => e.id),
        ['platinum', 'knowledge_platinum'],
      );
      expect(const ProfileStyle().profileMiniatures([]), isEmpty);
    },
  );
  testWidgets(
    'all five miniatures fit a narrow profile and open ruby details',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await NativePlatinumArt.preload();
        await NativePlatinumArt.preloadRuby();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileIdentityCard(
              name: 'Membro',
              bio: 'Minha jornada',
              style: const ProfileStyle(
                frameEffect: 'none',
                coverEffect: 'none',
                featured: [
                  'supreme_reading',
                  'supreme_training',
                  'supreme_meditation',
                ],
              ),
              earned: earned,
            ),
          ),
        ),
      );
      await tester.pump();
      for (final label in [
        'Platina PBH',
        'Rubi do Conhecimento',
        'Sabedoria suprema',
        'Força suprema',
        'Ascensão suprema',
      ]) {
        expect(find.byTooltip(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Rubi do Conhecimento'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Rubi do Conhecimento'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
