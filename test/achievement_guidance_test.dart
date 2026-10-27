import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/challenge_model.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';

void main() {
  ChallengeModel challenge(int days, {bool done = false, DateTime? date}) =>
      ChallengeModel(
        id: 'test',
        title: 'Teste',
        description: '',
        totalDays: 7,
        currentDay: days,
        level: ChallengeLevel.iniciante,
        status: done ? ChallengeStatus.completed : ChallengeStatus.active,
        icon: Icons.flag,
        achievedOn: date,
      );
  test('trophies show remaining days and never invent achievement dates', () {
    expect(challenge(3).remainingDays, 4);
    expect(challenge(3).achievementStatus, contains('Faltam 4'));
    expect(
      challenge(7, done: true).achievementStatus,
      contains('data não registrada'),
    );
    expect(
      challenge(7, done: true, date: DateTime(2026, 10, 27)).achievementStatus,
      contains('27/10/2026'),
    );
    expect(challenge(10).remainingDays, 0);
  });
  test('granted seals and challenge completion have distinct requirements', () {
    expect(ProfileAchievement.supremeSeals.first.kindLabel, 'SELO CONCEDIDO');
    expect(
      ProfileAchievement.platinum.requirement,
      contains('todos os desafios'),
    );
    expect(ProfileAchievement.dedication2000.kindLabel, 'SELO DE DEDICAÇÃO');
  });
}
