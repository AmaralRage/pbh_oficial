import 'package:flutter/material.dart';

enum ContentLevel { iniciante, intermediario, avancado }

class ProgramModel {
  final String id;
  final String title;
  final String tagline;
  final String description;
  final int modules;
  final int weeks;
  final ContentLevel level;
  final IconData icon;
  final List<String> outcomes;

  const ProgramModel({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.modules,
    required this.weeks,
    required this.level,
    required this.icon,
    required this.outcomes,
  });

  String get levelLabel {
    switch (level) {
      case ContentLevel.iniciante:
        return 'Nível Iniciante';
      case ContentLevel.intermediario:
        return 'Nível Intermediário';
      case ContentLevel.avancado:
        return 'Nível Avançado';
    }
  }
}

final List<ProgramModel> programCatalog = [
  const ProgramModel(
    id: 'fundamentos_homem_valor',
    title: 'Fundamentos do Homem de Valor',
    tagline: 'Construa sua base: mente, corpo, caráter e propósito.',
    description:
        'Um programa completo para estabelecer as fundações da sua evolução pessoal, unindo disciplina mental, física e de propósito.',
    modules: 12,
    weeks: 6,
    level: ContentLevel.intermediario,
    icon: Icons.terrain_outlined,
    outcomes: [
      'Clareza de propósito',
      'Autocontrole emocional',
      'Rotina de alto desempenho',
      'Relacionamentos e liderança',
    ],
  ),
  const ProgramModel(
    id: 'lideranca_silenciosa',
    title: 'Liderança Silenciosa',
    tagline: 'Influencie pelo exemplo, não pela imposição.',
    description:
        'Desenvolva presença e autoridade natural em qualquer ambiente, sem depender de validação externa.',
    modules: 8,
    weeks: 4,
    level: ContentLevel.avancado,
    icon: Icons.hub_outlined,
    outcomes: [
      'Comunicação assertiva',
      'Presença de liderança',
      'Tomada de decisão sob pressão',
    ],
  ),
  const ProgramModel(
    id: 'estoicismo_pratico',
    title: 'Estoicismo Prático',
    tagline: 'Filosofia antiga para problemas modernos.',
    description:
        'Aplique princípios estoicos no dia a dia para lidar com adversidade, foco e serenidade.',
    modules: 10,
    weeks: 5,
    level: ContentLevel.iniciante,
    icon: Icons.balance_outlined,
    outcomes: [
      'Gestão de emoções',
      'Foco no que você controla',
      'Resiliência diária',
    ],
  ),
  const ProgramModel(
    id: 'corpo_combate',
    title: 'Corpo de Combate',
    tagline: 'Força física como base da disciplina mental.',
    description:
        'Um programa de treino progressivo, sem academia obrigatória, focado em consistência.',
    modules: 16,
    weeks: 8,
    level: ContentLevel.intermediario,
    icon: Icons.fitness_center_outlined,
    outcomes: [
      'Força e resistência',
      'Consistência de treino',
      'Disciplina alimentar',
    ],
  ),
];
