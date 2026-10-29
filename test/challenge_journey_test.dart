import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/challenge_journey.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';

void main() {
  test(
    'knowledge ruby has its own artwork while retaining earned identity',
    () {
      expect(
        ProfileAchievement.knowledgePlatinum.artAsset,
        'assets/images/trofeu_rubi_pbh.png',
      );
      expect(
        ProfileAchievement.knowledgePlatinum.htmlAsset,
        'assets/images/Trofeu_Rubi_PBH.html',
      );
      expect(
        ProfileAchievement.knowledgePlatinum.id,
        isNot(ProfileAchievement.platinum.id),
      );
    },
  );
  Set<String> badges(Set<String> completed) => ProfileAchievement.earned(
    isAuthenticated: true,
    isProjectLeader: false,
    streak: 0,
    completedChallenges: completed.length,
    totalChallenges: 62,
    followers: 0,
    completedIds: completed,
  ).map((b) => b.id).toSet();
  test(
    'journey membership is fixed and collections never share challenges',
    () {
      expect(ChallengeJourney.original.challengeIds.length, 57);
      expect(ChallengeJourney.knowledge.challengeIds.length, 5);
      expect(
        ChallengeJourney.original.challengeIds.intersection(
          ChallengeJourney.knowledge.challengeIds,
        ),
        isEmpty,
      );
      expect(ChallengeJourney.original.unlocked({}), isFalse);
    },
  );
  test(
    'original platinum survives expansion and knowledge has its own platinum',
    () {
      final original = ChallengeJourney.original.challengeIds;
      final knowledge = ChallengeJourney.knowledge.challengeIds;
      expect(badges(original), contains('platinum'));
      expect(badges(original), isNot(contains('knowledge_platinum')));
      expect(badges(knowledge), contains('knowledge_platinum'));
      expect(badges(knowledge), isNot(contains('platinum')));
      expect(
        badges({...original, ...knowledge}),
        containsAll(['platinum', 'knowledge_platinum']),
      );
      expect(
        badges(knowledge.difference({knowledge.last})),
        isNot(contains('knowledge_platinum')),
      );
      expect(
        badges({
          ...original.difference({original.last}),
          ...knowledge,
        }),
        isNot(contains('platinum')),
      );
    },
  );
}
