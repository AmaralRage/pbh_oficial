import 'package:flutter/material.dart';
import '../core/navigation/app_transitions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/challenge_model.dart';
import '../models/program_model.dart';
import '../widgets/animated_entry.dart';
import '../widgets/featured_challenge_card.dart';
import '../widgets/program_card.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/weekday_selector.dart';
import 'habits_screen.dart';
import 'program_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final completedWeekDays = Set<int>.from(
      List<int>.generate(today.weekday - 1, (index) => index),
    );
    final activeChallenge = mockChallenges.firstWhere(
      (c) => c.status == ChallengeStatus.active,
      orElse: () => mockChallenges.first,
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AnimatedEntry(
            delayMs: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bom dia, guerreiro.', style: AppTextStyles.headline),
                const SizedBox(height: 4),
                Text('Seja intencional em cada escolha.', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AnimatedEntry(
            delayMs: 110,
            child: WeekdaySelector(date: today, completedIndexes: completedWeekDays),
          ),
          const SizedBox(height: 28),
          AnimatedEntry(
            delayMs: 160,
            child: SectionHeader(
              title: 'Seu progresso',
              actionLabel: 'Ver tudo',
              onActionTap: () {
                Navigator.of(context).push(
                  fadeSlideRoute(HabitsScreen(onNavigate: onNavigate)),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          const AnimatedEntry(
            delayMs: 190,
            child: Row(
              children: [
                StatCard(icon: Icons.track_changes, value: '81%', label: 'Rotina\nsemanal'),
                SizedBox(width: 12),
                StatCard(icon: Icons.local_fire_department, value: '23', label: 'Dias de\nconsistência'),
                SizedBox(width: 12),
                StatCard(icon: Icons.emoji_events, value: '7', label: 'Missões\nconcluídas'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AnimatedEntry(
            delayMs: 240,
            child: Text('Em destaque', style: AppTextStyles.titleMedium),
          ),
          const SizedBox(height: 14),
          AnimatedEntry(
            delayMs: 280,
            child: FeaturedChallengeCard(
              challenge: activeChallenge,
              onTap: () => onNavigate(1),
            ),
          ),
          const SizedBox(height: 28),
          AnimatedEntry(
            delayMs: 330,
            child: SectionHeader(
              title: 'Conteúdo recomendado',
              actionLabel: 'Ver todos',
              onActionTap: () => onNavigate(2),
            ),
          ),
          const SizedBox(height: 14),
          ...mockPrograms.take(2).toList().asMap().entries.map(
                (entry) => AnimatedEntry(
                  delayMs: 370 + entry.key * 55,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ProgramCard(
                      program: entry.value,
                      onTap: () {
                        Navigator.of(context).push(
                          fadeSlideRoute(ProgramDetailScreen(program: entry.value)),
                        );
                      },
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
