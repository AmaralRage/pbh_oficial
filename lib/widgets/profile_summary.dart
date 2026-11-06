import 'package:flutter/material.dart';
import '../core/theme/app_text_styles.dart';
import '../models/profile_achievement.dart';
import 'profile_achievement_seals.dart';
import 'stat_card.dart';

class ProfileSummaryStats extends StatelessWidget {
  const ProfileSummaryStats({
    super.key,
    required this.streak,
    required this.completed,
    required this.seals,
    required this.founder,
    this.showStreak = true,
  });
  final int streak, completed, seals;
  final bool founder, showStreak;
  @override
  Widget build(BuildContext context) => ProfileStats(
    children: [
      if (showStreak) ...[
        StatCard(
          icon: Icons.local_fire_department,
          value: '$streak',
          label: founder ? 'Dias do\nprojeto' : 'Dias de\nsequência',
        ),
        const SizedBox(width: 12),
      ],
      StatCard(
        icon: Icons.flag,
        value: '$completed',
        label: 'Desafios\nconcluídos',
      ),
      const SizedBox(width: 12),
      StatCard(
        icon: Icons.emoji_events,
        value: '$seals',
        label: 'Selos\nconquistados',
      ),
    ],
  );
}

class ProfileSealSections extends StatelessWidget {
  const ProfileSealSections({
    super.key,
    required this.highlights,
    required this.earned,
    this.action,
  });
  final List<ProfileAchievement> highlights, earned;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (highlights.isNotEmpty) ...[
        Text('Selos em destaque', style: AppTextStyles.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Os marcos que você escolheu para contar sua história.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 14),
        ProfileAchievementSeals(achievements: highlights),
        const SizedBox(height: 26),
      ],
      Row(
        children: [
          Expanded(
            child: Text('Selos de dedicação', style: AppTextStyles.titleMedium),
          ),
          if (action != null) action!,
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Sua dedicação deixa marcas. Toque em um selo para conhecer sua história.',
        style: AppTextStyles.bodySmall,
      ),
      const SizedBox(height: 14),
      ProfileAchievementSeals(achievements: earned),
    ],
  );
}
