import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';

List<ProfileAchievement> badges({
  bool authenticated = true,
  bool leader = false,
  int streak = 0,
  int completed = 0,
  int total = 57,
  Set<String> ids = const {},
  Set<String> awards = const {},
}) => ProfileAchievement.earned(
  isAuthenticated: authenticated,
  isProjectLeader: leader,
  streak: streak,
  completedChallenges: completed,
  totalChallenges: total,
  followers: 0,
  completedIds: ids,
  manualAwards: awards,
);

void main() {
  test(
    '2000-day milestone uses amber artwork only after reaching the milestone',
    () {
      final milestone = badges(
        streak: 2000,
      ).firstWhere((badge) => badge.id == 'streak');
      expect(milestone.htmlAsset, 'assets/images/Trofeu_2000_completo.html');
      expect(milestone.artAsset, 'assets/images/trofeu_2000_dias.png');
      expect(milestone.artCaption, '2000 DIAS • DEDICAÇÃO AO PBH');
      expect(
        badges(
          streak: 1999,
        ).any((badge) => badge.htmlAsset == milestone.htmlAsset),
        isFalse,
      );
      expect(
        badges(
          leader: true,
          streak: 2100,
        ).where((badge) => badge.id == 'streak').single,
        ProfileAchievement.dedication2000,
      );
      expect(
        ProfileAchievement.supremeSeals.contains(
          ProfileAchievement.dedication2000,
        ),
        isFalse,
      );
    },
  );
  test('platinum artwork is unlocked only by completing the catalog', () {
    final platinum = badges(
      completed: 57,
    ).firstWhere((badge) => badge.id == 'platinum');
    expect(platinum.htmlAsset, 'assets/images/Trofeu_Platina_PBH.html');
    expect(platinum.artAsset, 'assets/images/trofeu_platina_pbh.png');
    expect(
      badges(leader: true).where((badge) => badge.id == 'platinum'),
      isEmpty,
    );
    expect(
      badges(completed: 56).where((badge) => badge.id == 'platinum'),
      isEmpty,
    );
    expect(
      ProfileAchievement.supremeSeals.where((badge) => badge.id == 'platinum'),
      isEmpty,
    );
  });
  test('porn-free seal is independent and belongs to the project leader', () {
    final seal = badges(
      leader: true,
    ).firstWhere((badge) => badge.id == 'supreme_porn_free');
    expect(seal.title, 'Mente limpa');
    expect(seal.htmlAsset, 'assets/images/Troféu supremo sem pornô.html');
    expect(seal.artAsset, 'assets/images/trofeu_supremo_sem_porno.png');
    expect(
      badges(awards: {'supreme_porn_free'}).single.id,
      'supreme_porn_free',
    );
    expect(
      badges(
        ids: {'digital_fast'},
      ).where((badge) => badge.id == 'supreme_porn_free'),
      isEmpty,
    );
  });
  test(
    'reading seal is owned by leader and manually granted independently',
    () {
      final reading = badges(
        leader: true,
      ).firstWhere((badge) => badge.id == 'supreme_reading');
      expect(reading.title, 'Sabedoria suprema');
      expect(reading.htmlAsset, 'assets/images/Troféu supremo de leitura.html');
      expect(reading.artAsset, 'assets/images/trofeu_supremo_leitura.png');
      expect(badges(awards: {'supreme_reading'}).single.id, 'supreme_reading');
      expect(
        badges(
          ids: {'daily_reading'},
        ).where((badge) => badge.id == 'supreme_reading'),
        isEmpty,
      );
    },
  );
  test('leader owns supreme meditation seal with supplied artwork', () {
    final supreme = badges(
      leader: true,
    ).firstWhere((badge) => badge.id == 'supreme_meditation');
    expect(supreme.id, 'supreme_meditation');
    expect(supreme.artAsset, 'assets/images/trofeu_supremo_meditacao.png');
  });

  test('training seal uses its own artwork and is granted independently', () {
    final leaderBadges = badges(leader: true);
    final training = leaderBadges.firstWhere(
      (badge) => badge.id == 'supreme_training',
    );
    expect(training.title, 'Força suprema');
    expect(training.htmlAsset, 'assets/images/Troféu supremo de treino.html');
    expect(training.artAsset, 'assets/images/trofeu_supremo_treino.png');
    expect(badges(awards: {'supreme_training'}).single.id, 'supreme_training');
    expect(
      badges(
        ids: {'iron_body'},
      ).where((badge) => badge.id == 'supreme_training'),
      isEmpty,
    );
  });

  test(
    'meditation completion alone does not grant the manually awarded seal',
    () {
      expect(
        badges(
          ids: {'daily_meditation'},
        ).where((badge) => badge.id == 'supreme_meditation'),
        isEmpty,
      );
      expect(
        badges(awards: {'supreme_meditation'}).single.id,
        'supreme_meditation',
      );
    },
  );

  test('visitors and users without achievements have no showcase badges', () {
    expect(badges(authenticated: false, leader: true, completed: 57), isEmpty);
    expect(badges(), isEmpty);
  });

  test(
    'only highest milestones are highlighted and platinum requires full catalog',
    () {
      final partial = badges(streak: 110, completed: 30);
      expect(
        partial.where((badge) => badge.id == 'streak').single.title,
        '100 dias de dedicação',
      );
      expect(partial.where((badge) => badge.id == 'challenges').length, 1);
      expect(partial.where((badge) => badge.id == 'platinum'), isEmpty);
      expect(
        badges(completed: 57).where((badge) => badge.id == 'platinum').length,
        1,
      );
      expect(
        badges(completed: 0, total: 0).where((badge) => badge.id == 'platinum'),
        isEmpty,
      );
    },
  );
}
