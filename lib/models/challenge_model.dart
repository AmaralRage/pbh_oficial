import 'package:flutter/material.dart';

enum ChallengeStatus { active, notStarted, completed }

enum ChallengeLevel { iniciante, intermediario, avancado }

class ChallengeModel {
  final String title;
  final String description;
  final int totalDays;
  final int currentDay; // relevante apenas quando status == active
  final ChallengeLevel level;
  final int participants;
  final ChallengeStatus status;
  final IconData icon;

  const ChallengeModel({
    required this.title,
    required this.description,
    required this.totalDays,
    required this.level,
    required this.participants,
    required this.status,
    required this.icon,
    this.currentDay = 0,
  });

  double get progress => totalDays == 0 ? 0 : currentDay / totalDays;

  String get levelLabel {
    switch (level) {
      case ChallengeLevel.iniciante:
        return 'Iniciante';
      case ChallengeLevel.intermediario:
        return 'Intermediário';
      case ChallengeLevel.avancado:
        return 'Avançado';
    }
  }
}

/// Dados de exemplo — substituir pela integração real (API / backend).
final List<ChallengeModel> mockChallenges = [
  const ChallengeModel(
    title: '30 Dias de Disciplina',
    description: 'Construa rotina, foco e consistência em 30 dias.',
    totalDays: 30,
    currentDay: 17,
    level: ChallengeLevel.intermediario,
    participants: 4821,
    status: ChallengeStatus.active,
    icon: Icons.flag_outlined,
  ),
  const ChallengeModel(
    title: 'Despertar 5h',
    description: 'Domine suas manhãs e ganhe vantagem sobre o dia.',
    totalDays: 21,
    level: ChallengeLevel.avancado,
    participants: 2310,
    status: ChallengeStatus.notStarted,
    icon: Icons.wb_twilight_outlined,
  ),
  const ChallengeModel(
    title: 'Jejum Mental Digital',
    description: 'Reduza ruído e recupere o controle da sua atenção.',
    totalDays: 14,
    level: ChallengeLevel.iniciante,
    participants: 6104,
    status: ChallengeStatus.notStarted,
    icon: Icons.smartphone_outlined,
  ),
  const ChallengeModel(
    title: 'Corpo de Ferro',
    description: 'Treinos progressivos para força e resistência.',
    totalDays: 60,
    level: ChallengeLevel.avancado,
    participants: 1876,
    status: ChallengeStatus.notStarted,
    icon: Icons.fitness_center_outlined,
  ),
  const ChallengeModel(
    title: 'Leitura Diária',
    description: 'Vinte minutos de leitura para expandir sua mente.',
    totalDays: 30,
    currentDay: 30,
    level: ChallengeLevel.iniciante,
    participants: 3452,
    status: ChallengeStatus.completed,
    icon: Icons.menu_book_outlined,
  ),
];
