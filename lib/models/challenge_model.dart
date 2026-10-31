import 'package:flutter/material.dart';

enum ChallengeStatus { active, notStarted, completed }

enum ChallengeLevel { iniciante, intermediario, avancado }

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final int totalDays;
  final int currentDay;
  final ChallengeLevel level;
  final ChallengeStatus status;
  final DateTime? achievedOn;
  final IconData icon;

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.totalDays,
    required this.level,
    required this.status,
    required this.icon,
    this.currentDay = 0,
    this.achievedOn,
  });

  int get remainingDays => (totalDays - currentDay).clamp(0, totalDays);
  int get nextMilestone {
    for (final fraction in [.25, .5, .75, 1.0]) {
      final target = (totalDays * fraction).ceil();
      if (target > currentDay) return target;
    }
    return totalDays;
  }

  String get milestoneLabel => remainingDays == 0
      ? 'Jornada concluída'
      : 'Próximo marco: $nextMilestone de $totalDays registros · faltam ${(nextMilestone - currentDay).clamp(0, totalDays)}';
  String get achievementStatus {
    if (status != ChallengeStatus.completed)
      return 'Faltam $remainingDays de $totalDays dias para conquistar';
    final date = achievedOn;
    if (date == null) return 'Conquistado · data não registrada';
    return 'Conquistado em ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  double get progress =>
      totalDays == 0 ? 0 : (currentDay / totalDays).clamp(0, 1).toDouble();

  String get levelLabel => switch (level) {
    ChallengeLevel.iniciante => 'Iniciante',
    ChallengeLevel.intermediario => 'Intermediário',
    ChallengeLevel.avancado => 'Avançado',
  };
}
