import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/navigation/app_transitions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/challenge_model.dart';
import '../models/program_model.dart';
import '../services/challenge_service.dart';
import '../services/habit_service.dart';
import '../widgets/animated_entry.dart';
import '../widgets/featured_challenge_card.dart';
import '../widgets/program_card.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/weekday_selector.dart';
import 'habits_screen.dart';
import 'program_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _habitService = HabitService();
  final _challengeService = ChallengeService();
  int _streak = 0;
  int _todayCompleted = 0;
  int _completedChallenges = 0;
  List<int> _weekCounts = List.filled(7, 0);
  ChallengeModel? _activeChallenge;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _habitService.streak(),
        _habitService.completedOn(DateTime.now()),
        _habitService.weekCounts(DateTime.now()),
        _challengeService.fetchChallenges(),
      ]);
      if (!mounted) return;
      final challenges = values[3] as List<ChallengeModel>;
      ChallengeModel? active;
      for (final challenge in challenges) {
        if (challenge.status == ChallengeStatus.active) {
          active = challenge;
          break;
        }
      }
      setState(() {
        _streak = values[0] as int;
        _todayCompleted = (values[1] as Set<String>).length;
        _weekCounts = values[2] as List<int>;
        _activeChallenge = active;
        _completedChallenges = challenges.where((item) => item.status == ChallengeStatus.completed).length;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final completedWeekDays = {for (var i = 0; i < _weekCounts.length; i++) if (_weekCounts[i] > 0) i};
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata ?? const <String, dynamic>{};
    final displayName = (metadata['display_name'] as String?)?.trim();
    final currentUser = Supabase.instance.client.auth.currentUser;
    final greetingName = displayName?.isNotEmpty == true
        ? displayName!
        : currentUser?.email?.toLowerCase() == 'amaralaragao31@gmail.com'
            ? 'Amaral Aragão'
            : 'guerreiro';
    final greeting = switch (today.hour) { < 12 => 'Bom dia', < 18 => 'Boa tarde', _ => 'Boa noite' };
    final routinePercent = (100 * _todayCompleted / HabitService.habitKeys.length).round();

    return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      AnimatedEntry(delayMs: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$greeting, $greetingName.', style: AppTextStyles.headline), if (currentUser?.email?.toLowerCase() == 'amaralaragao31@gmail.com') ...[const SizedBox(height: 4), Text('Líder do projeto PBH Oficial', style: AppTextStyles.bodySmall.copyWith(color: AppColors.orange))] else ...[const SizedBox(height: 4), Text('Seja intencional em cada escolha.', style: AppTextStyles.bodySmall)]])),
      const SizedBox(height: 24),
      AnimatedEntry(delayMs: 110, child: WeekdaySelector(date: today, completedIndexes: completedWeekDays)),
      const SizedBox(height: 28),
      AnimatedEntry(delayMs: 160, child: SectionHeader(title: 'Seu progresso', actionLabel: 'Ver tudo', onActionTap: () => Navigator.of(context).push(fadeSlideRoute(HabitsScreen(onNavigate: widget.onNavigate))))),
      const SizedBox(height: 14),
      AnimatedEntry(delayMs: 190, child: Row(children: [
        StatCard(icon: Icons.track_changes, value: '$routinePercent%', label: 'Rotina\nde hoje'),
        const SizedBox(width: 12),
        StatCard(icon: Icons.local_fire_department, value: '$_streak', label: 'Dias de\nsequência'),
        const SizedBox(width: 12),
        StatCard(icon: Icons.emoji_events, value: '$_completedChallenges', label: 'Desafios\nconcluídos'),
      ])),
      const SizedBox(height: 28),
      AnimatedEntry(delayMs: 240, child: Text('Em destaque', style: AppTextStyles.titleMedium)),
      const SizedBox(height: 14),
      if (_activeChallenge != null)
        AnimatedEntry(delayMs: 280, child: FeaturedChallengeCard(challenge: _activeChallenge!, onTap: () => widget.onNavigate(1)))
      else
        _NoActiveChallenge(onTap: () => widget.onNavigate(1)),
      const SizedBox(height: 28),
      AnimatedEntry(delayMs: 330, child: SectionHeader(title: 'Conteúdo recomendado', actionLabel: 'Ver todos', onActionTap: () => widget.onNavigate(2))),
      const SizedBox(height: 14),
      ...programCatalog.take(2).toList().asMap().entries.map((entry) => AnimatedEntry(delayMs: 370 + entry.key * 55, child: Padding(padding: const EdgeInsets.only(bottom: 12), child: ProgramCard(program: entry.value, onTap: () => Navigator.of(context).push(fadeSlideRoute(ProgramDetailScreen(program: entry.value))))))),
    ]));
  }
}

class _NoActiveChallenge extends StatelessWidget {
  const _NoActiveChallenge({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: AppColors.surface, borderRadius: BorderRadius.circular(18), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Icon(Icons.flag_outlined, color: AppColors.orange), const SizedBox(width: 12), Expanded(child: Text('Escolha um desafio para começar.', style: AppTextStyles.body)), const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary)]))));
}
