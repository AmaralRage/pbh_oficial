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
  final IconData icon;

  const ChallengeModel({required this.id, required this.title, required this.description, required this.totalDays, required this.level, required this.status, required this.icon, this.currentDay = 0});

  double get progress => totalDays == 0 ? 0 : (currentDay / totalDays).clamp(0, 1).toDouble();

  String get levelLabel => switch (level) {
        ChallengeLevel.iniciante => 'Iniciante',
        ChallengeLevel.intermediario => 'Intermediário',
        ChallengeLevel.avancado => 'Avançado',
      };
}
