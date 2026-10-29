import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/challenge_journey.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/models/profile_style.dart';
import 'package:pbh_oficial/widgets/profile_effect_picker.dart';

void main() {
  final cases = [
    (<String>{}, <String>[]),
    (
      ChallengeJourney.original.challengeIds,
      ['platinum_orbit', 'platinum_iron', 'platinum_ascent', 'platinum_throne'],
    ),
    (
      ChallengeJourney.knowledge.challengeIds,
      ['knowledge_orbit', 'knowledge_constellation'],
    ),
    (
      {
        ...ChallengeJourney.original.challengeIds,
        ...ChallengeJourney.knowledge.challengeIds,
      },
      ProfileStyle.platinumEffects.toList(),
    ),
  ];
  test(
    'each platinum unlocks its own effects and the pair unlocks the combined set',
    () {
      for (final scenario in cases) {
        final earned = ProfileAchievement.earned(
          isAuthenticated: true,
          isProjectLeader: false,
          streak: 0,
          completedChallenges: scenario.$1.length,
          totalChallenges: 62,
          followers: 0,
          completedIds: scenario.$1,
        );
        for (final option in [
          ...ProfileStyle.frameEffects,
          ...ProfileStyle.coverEffects,
        ].where((o) => ProfileStyle.platinumEffects.contains(o.id))) {
          expect(
            option.available(
              false,
              scenario.$1.length,
              earned.map((e) => e.id).toSet(),
            ),
            scenario.$2.contains(option.id),
            reason: option.id,
          );
        }
        for (final pair in const [
          ('platinum_orbit', 'platinum_ascent'),
          ('knowledge_orbit', 'knowledge_constellation'),
          ('journey_crown', 'journey_legacy'),
        ]) {
          final draft = ProfileStyle(
            frameEffect: pair.$1,
            coverEffect: pair.$2,
            frameIntensity: .8,
            coverIntensity: .3,
          );
          final safe =
              ProfileStyle.fromMetadata({
                'profile_style': draft.toMap(),
              }).validated(
                founder: false,
                completed: scenario.$1.length,
                earned: earned,
              );
          expect(
            safe.frameEffect,
            scenario.$2.contains(pair.$1) ? pair.$1 : 'orbit',
          );
          expect(
            safe.coverEffect,
            scenario.$2.contains(pair.$2) ? pair.$2 : 'shimmer',
          );
          expect(safe.coverIntensity, .3);
          expect(ProfileStyle.hasIntensity(pair.$1), isTrue);
        }
      }
    },
  );
  testWidgets(
    'platinum category shows exclusive effects and keeps none available',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileEffectPicker(
              options: ProfileStyle.coverEffects,
              selected: 'shimmer',
              optionsBuilder: (options) =>
                  Wrap(children: [for (final o in options) Text(o.label)]),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Platinas'));
      await tester.pump();
      expect(find.text('Forja da Disciplina'), findsOneWidget);
      expect(find.text('Biblioteca dos Sábios'), findsOneWidget);
      expect(find.text('Observatório Eterno'), findsOneWidget);
      expect(find.text('Sem animação'), findsOneWidget);
      expect(find.text('Chuva'), findsNothing);
    },
  );
}
