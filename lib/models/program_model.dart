import 'package:flutter/material.dart';
import 'program_curriculum.dart';
import 'program_lesson.dart';

enum ContentLevel { iniciante, intermediario, avancado }

class ProgramModel {
  final String id;
  final String title;
  final String tagline;
  final String description;
  final List<ProgramModule> curriculum;
  final String topic;
  int get modules => curriculum.length;
  List<ProgramLesson> get lessons =>
      curriculum.expand((m) => m.lessons).toList();
  final int weeks;
  final ContentLevel level;
  final IconData icon;
  final List<String> outcomes;
  final DateTime? featuredUntil;
  final String? featuredLessonId;
  final String featuredNote;
  bool featuredAt(DateTime now) =>
      featuredUntil != null &&
      featuredUntil!.isAfter(now) &&
      lessons.any((l) => l.id == featuredLessonId);

  const ProgramModel({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.curriculum,
    required this.topic,
    required this.weeks,
    required this.level,
    required this.icon,
    required this.outcomes,
    this.featuredUntil,
    this.featuredLessonId,
    this.featuredNote = '',
  });

  factory ProgramModel.fromJson(Map<String, dynamic> json) => ProgramModel(
    id: json['id'] as String,
    title: json['title'] as String,
    tagline: json['tagline'] as String,
    description: json['description'] as String,
    weeks: (json['weeks'] as num).toInt(),
    topic: json['topic'] as String,
    level: ContentLevel.values.byName(json['level'] as String),
    icon: Icons.menu_book_outlined,
    outcomes: List<String>.from(json['outcomes'] as List),
    featuredUntil: DateTime.tryParse(json['featured_until'] as String? ?? ''),
    featuredLessonId: json['featured_lesson_id'] as String?,
    featuredNote: json['featured_note'] as String? ?? '',
    curriculum: (json['curriculum'] as List)
        .map((e) => ProgramModule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'tagline': tagline,
    'description': description,
    'weeks': weeks,
    'topic': topic,
    'level': level.name,
    'outcomes': outcomes,
    'curriculum': curriculum.map((m) => m.toJson()).toList(),
    if (featuredUntil != null)
      'featured_until': featuredUntil!.toUtc().toIso8601String(),
    if (featuredLessonId != null) 'featured_lesson_id': featuredLessonId,
    if (featuredNote.isNotEmpty) 'featured_note': featuredNote,
  };

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
  ProgramModel(
    id: 'fundamentos_homem_valor',
    title: 'Fundamentos do Homem de Valor',
    tagline: 'Construa sua base: mente, corpo, caráter e propósito.',
    description:
        'Um programa completo para estabelecer as fundações da sua evolução pessoal, unindo disciplina mental, física e de propósito.',
    curriculum: programCurricula['fundamentos_homem_valor']!,
    topic: 'Propósito',
    weeks: 2,
    level: ContentLevel.intermediario,
    icon: Icons.terrain_outlined,
    outcomes: [
      'Clareza de propósito',
      'Autocontrole emocional',
      'Rotina de alto desempenho',
      'Relacionamentos e liderança',
    ],
  ),
  ProgramModel(
    id: 'lideranca_silenciosa',
    title: 'Liderança Silenciosa',
    tagline: 'Influencie pelo exemplo, não pela imposição.',
    description:
        'Desenvolva presença e autoridade natural em qualquer ambiente, sem depender de validação externa.',
    curriculum: programCurricula['lideranca_silenciosa']!,
    topic: 'Liderança',
    weeks: 2,
    level: ContentLevel.avancado,
    icon: Icons.hub_outlined,
    outcomes: [
      'Comunicação assertiva',
      'Presença de liderança',
      'Tomada de decisão sob pressão',
    ],
  ),
  ProgramModel(
    id: 'estoicismo_pratico',
    title: 'Estoicismo Prático',
    tagline: 'Filosofia antiga para problemas modernos.',
    description:
        'Aplique princípios estoicos no dia a dia para lidar com adversidade, foco e serenidade.',
    curriculum: programCurricula['estoicismo_pratico']!,
    topic: 'Emoções',
    weeks: 2,
    level: ContentLevel.iniciante,
    icon: Icons.balance_outlined,
    outcomes: [
      'Gestão de emoções',
      'Foco no que você controla',
      'Resiliência diária',
    ],
  ),
  ProgramModel(
    id: 'corpo_combate',
    title: 'Corpo de Combate',
    tagline: 'Força física como base da disciplina mental.',
    description:
        'Organize uma rotina de movimento e descanso com foco em consistência e respeito aos seus limites.',
    curriculum: programCurricula['corpo_combate']!,
    topic: 'Corpo',
    weeks: 2,
    level: ContentLevel.intermediario,
    icon: Icons.fitness_center_outlined,
    outcomes: [
      'Planejamento da rotina',
      'Consistência nas atividades',
      'Equilíbrio e descanso',
    ],
  ),
  ProgramModel(
    id: 'niilismo_sentido',
    title: 'Niilismo: riscos e reconstrução de sentido',
    tagline:
        'Questione o sentido sem abandonar o cuidado e a responsabilidade.',
    description:
        'Entenda o niilismo e os riscos de transformar a ideia de que nada importa em apatia ou indiferença. Reflita sobre valores, consequências e compromissos possíveis no cotidiano.',
    curriculum: programCurricula['niilismo_sentido']!,
    topic: 'Filosofia',
    weeks: 2,
    level: ContentLevel.iniciante,
    icon: Icons.explore_outlined,
    outcomes: [
      'Compreender o niilismo existencial',
      'Examinar os riscos da apatia e da indiferença',
      'Questionar valores com responsabilidade',
      'Construir compromissos que façam sentido',
    ],
  ),
];
