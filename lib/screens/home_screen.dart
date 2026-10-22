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
import '../widgets/habit_sync_notice.dart';
import '../widgets/weekday_selector.dart';
import 'habits_screen.dart';
import 'program_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate, this.onOpenHabits});
  final ValueChanged<int> onNavigate;
  final VoidCallback? onOpenHabits;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _habitService = HabitService();
  final _challengeService = ChallengeService();
  int _streak = 0;
  int _todayCompleted = 0;
  int _selectedHabitCount = HabitService.habitKeys.length;
  int _completedChallenges = 0;
  List<int> _weekCounts = List.filled(7, 0);
  ChallengeModel? _activeChallenge;
  bool _loading = true;
  int _pendingChanges = 0;
  bool _hasChallenges = false;
  String? _loadError;
  int _loadVersion = 0;
  bool? _tabActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && _tabActive == false) _load();
    _tabActive = active;
  }

  int get _projectDays {
    final today = DateTime.now();
    return DateTime.utc(
          today.year,
          today.month,
          today.day,
        ).difference(DateTime.utc(2021, 1, 1)).inDays +
        1;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final loadVersion = ++_loadVersion;
    if (mounted)
      setState(() {
        _loading = true;
        _loadError = null;
      });
    try {
      _habitService.resetReadStatus();
      await _habitService.syncPending();
      final selectedHabits = await _habitService.selectedHabitKeys();
      final values = await Future.wait([
        _habitService.streak(habitKeysForStreak: selectedHabits),
        _habitService.completedOn(DateTime.now()),
        _habitService.weekCounts(
          DateTime.now(),
          selectedHabits: selectedHabits,
        ),
        _challengeService.fetchChallenges().then<Object>(
          (value) => value,
          onError: (Object error) => error,
        ),
      ]);
      final pending = await _habitService.pendingChanges();
      if (!mounted || loadVersion != _loadVersion) return;
      final challenges = values[3] is List<ChallengeModel>
          ? values[3] as List<ChallengeModel>
          : null;
      ChallengeModel? active;
      for (final challenge in challenges ?? <ChallengeModel>[]) {
        if (challenge.status == ChallengeStatus.active) {
          active = challenge;
          break;
        }
      }
      setState(() {
        _streak = values[0] as int;
        _todayCompleted = (values[1] as Set<String>)
            .intersection(selectedHabits)
            .length;
        _weekCounts = values[2] as List<int>;
        if (challenges != null) {
          _loadError = null;
          _activeChallenge = active;
          _completedChallenges = challenges
              .where((item) => item.status == ChallengeStatus.completed)
              .length;
          _hasChallenges = true;
        } else {
          _loadError =
              'A rotina foi carregada, mas não foi possível atualizar os desafios.';
        }
        _pendingChanges = pending;
        _selectedHabitCount = selectedHabits.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || loadVersion != _loadVersion) return;
      setState(() {
        _loading = false;
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final completedWeekDays = <int>{
      for (var i = 0; i < _weekCounts.length; i++)
        if (_weekCounts[i] > 0) i,
    };
    final elapsedWeekDays = <int>{for (var i = 0; i < today.weekday; i++) i};
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isProjectLeader =
        currentUser?.email?.toLowerCase() == 'amaralaragao31@gmail.com';
    final metadata = currentUser?.userMetadata ?? const <String, dynamic>{};
    final displayName = (metadata['display_name'] as String?)?.trim();
    final greetingName = isProjectLeader
        ? 'Amaral'
        : (displayName?.isNotEmpty == true ? displayName! : 'guerreiro');
    final greeting = switch (today.hour) {
      < 12 => 'Bom dia',
      < 18 => 'Boa tarde',
      _ => 'Boa noite',
    };
    final routinePercent = _selectedHabitCount == 0
        ? 0
        : (100 * _todayCompleted / _selectedHabitCount)
              .round()
              .clamp(0, 100)
              .toInt();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AnimatedEntry(
              delayMs: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $greetingName.',
                    style: AppTextStyles.brandHeadline,
                  ),
                  if (isProjectLeader) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Líder do projeto PBH Oficial',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.orange,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'Seja intencional em cada escolha.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _HomeLoadError(message: _loadError!, onRetry: _load),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            const SizedBox(height: 24),
            HabitSyncNotice(
              pending: _pendingChanges,
              cached: _habitService.isUsingCachedData,
              onRetry: _load,
            ),
            AnimatedEntry(
              delayMs: 110,
              child: WeekdaySelector(
                date: today,
                completedIndexes: completedWeekDays,
                elapsedIndexes: elapsedWeekDays,
              ),
            ),
            const SizedBox(height: 28),
            AnimatedEntry(
              delayMs: 160,
              child: SectionHeader(
                title: 'Seu progresso',
                actionLabel: 'Ver tudo',
                onActionTap:
                    widget.onOpenHabits ??
                    () => Navigator.of(context).push(
                      fadeSlideRoute(
                        HabitsScreen(onNavigate: widget.onNavigate),
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedEntry(
              delayMs: 190,
              child: Row(
                children: [
                  StatCard(
                    icon: Icons.track_changes,
                    value: '$routinePercent%',
                    label: 'Rotina\nde hoje',
                  ),
                  if (currentUser != null) ...[
                    const SizedBox(width: 12),
                    StatCard(
                      icon: Icons.local_fire_department,
                      value: '${isProjectLeader ? _projectDays : _streak}',
                      label: isProjectLeader
                          ? 'Dias do\nprojeto'
                          : 'Dias de\nsequência',
                    ),
                  ],
                  const SizedBox(width: 12),
                  StatCard(
                    icon: Icons.emoji_events,
                    value: _hasChallenges ? '$_completedChallenges' : '—',
                    label: 'Desafios\nconcluídos',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AnimatedEntry(
              delayMs: 240,
              child: Text('Em destaque', style: AppTextStyles.titleMedium),
            ),
            const SizedBox(height: 14),
            if (_activeChallenge != null)
              AnimatedEntry(
                delayMs: 280,
                child: FeaturedChallengeCard(
                  challenge: _activeChallenge!,
                  onTap: () => widget.onNavigate(1),
                ),
              )
            else
              _NoActiveChallenge(onTap: () => widget.onNavigate(1)),
            const SizedBox(height: 28),
            AnimatedEntry(
              delayMs: 330,
              child: SectionHeader(
                title: 'Conteúdo recomendado',
                actionLabel: 'Ver todos',
                onActionTap: () => widget.onNavigate(2),
              ),
            ),
            const SizedBox(height: 14),
            ...programCatalog
                .take(2)
                .toList()
                .asMap()
                .entries
                .map(
                  (entry) => AnimatedEntry(
                    delayMs: 370 + entry.key * 55,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProgramCard(
                        program: entry.value,
                        onTap: () => Navigator.of(context).push(
                          fadeSlideRoute(
                            ProgramDetailScreen(program: entry.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _HomeLoadError extends StatelessWidget {
  const _HomeLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Não foi possível atualizar seu progresso. $message',
            style: AppTextStyles.bodySmall,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Tentar')),
      ],
    ),
  );
}

class _NoActiveChallenge extends StatelessWidget {
  const _NoActiveChallenge({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Escolha um desafio para começar.',
                style: AppTextStyles.body,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    ),
  );
}
