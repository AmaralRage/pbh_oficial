import 'package:flutter/material.dart';

/// Frozen membership keeps each platinum independent of later collections.
class ChallengeJourney {
  const ChallengeJourney({
    required this.id,
    required this.title,
    required this.description,
    required this.challengeIds,
    required this.icon,
    required this.color,
  });
  final String id, title, description;
  final Set<String> challengeIds;
  final IconData icon;
  final Color color;
  String get coverAsset => id == 'knowledge'
      ? 'assets/images/capaJornada.png'
      : 'assets/images/capaJogo.png';
  Alignment get coverAlignment =>
      id == 'knowledge' ? const Alignment(0, .25) : const Alignment(0, -.55);
  bool unlocked(Set<String> completed) =>
      challengeIds.isNotEmpty && completed.containsAll(challengeIds);
  int completedCount(Set<String> completed) =>
      challengeIds.intersection(completed).length;
  static const original = ChallengeJourney(
    id: 'original',
    title: 'Jornada Original PBH',
    description:
        'Os 57 desafios que iniciaram a sua coleção. Sua platina continua independente das novas jornadas.',
    icon: Icons.flag_outlined,
    color: Color(0xFFFF6A24),
    challengeIds: {
      'discipline_30',
      'wake_5',
      'digital_fast',
      'iron_body',
      'daily_reading',
      '7day_focus',
      'phone_free_morning',
      'walk_daily',
      'water_habit',
      'gratitude_journal',
      'bedtime_routine',
      '20min_reading',
      'no_sugar_week',
      'cold_shower',
      'early_riser',
      'daily_meditation',
      'tidy_space',
      'no_social_morning',
      'pushup_progress',
      'run_beginner',
      'core_strength',
      'mobility_daily',
      'no_alcohol',
      'budget_month',
      'learn_language',
      'write_daily',
      'one_task',
      'no_complaints',
      'kindness_daily',
      'call_family',
      'cook_at_home',
      'protein_breakfast',
      'stretch_breaks',
      'weekly_planning',
      'focus_blocks',
      'no_impulse_buy',
      'donate_weekly',
      'service_month',
      'lead_by_example',
      'public_speaking',
      'conflict_reflection',
      'digital_sunset',
      'weekend_outdoors',
      'cycling_month',
      'swimming_routine',
      'bodyweight_month',
      'no_takeout',
      'content_fast',
      'morning_pages',
      'purpose_review',
      'financial_learning',
      'gratitude_letters',
      'consistent_prayer',
      'volunteer_month',
      'creative_practice',
      'no_snooze',
      'five_minute_rule',
    },
  );
  static const knowledge = ChallengeJourney(
    id: 'knowledge',
    title: 'Jornada do Conhecimento',
    description:
        'Leia, registre, estude, explique e aplique. Cinco desafios para transformar curiosidade em prática.',
    icon: Icons.auto_stories_rounded,
    color: Color(0xFF86C9FF),
    challengeIds: {
      'knowledge_read',
      'knowledge_notes',
      'knowledge_focus',
      'knowledge_explain',
      'knowledge_apply',
    },
  );
  static const all = [original, knowledge];
}
