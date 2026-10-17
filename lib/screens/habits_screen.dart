import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/feedback/tap_feedback.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/habit_model.dart';
import '../services/habit_service.dart';
import '../widgets/animated_entry.dart';
import '../widgets/habit_item_card.dart';
import '../widgets/pbh_bottom_nav.dart';

class HabitsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const HabitsScreen({super.key, this.onNavigate});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _service = HabitService();
  late List<HabitModel> _habits;
  late int _selectedDay;
  List<int> _weekCounts = List.filled(7, 0);
  int _streak = 0;
  bool _loading = true;
  final Set<String> _saving = {};

  List<DateTime> get _currentWeek {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));
    return List<DateTime>.generate(7, (index) => monday.add(Duration(days: index)));
  }

  DateTime get _selectedDate => _currentWeek[_selectedDay];
  int get _completedCount => _habits.where((habit) => habit.completed).length;

  @override
  void initState() {
    super.initState();
    _habits = List.of(habitCatalog);
    _selectedDay = DateTime.now().weekday - 1;
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _service.completedOn(_selectedDate),
        _service.weekCounts(DateTime.now()),
        _service.streak(),
      ]);
      if (!mounted) return;
      final completed = values[0] as Set<String>;
      setState(() {
        _habits = habitCatalog.map((habit) => habit.copyWith(completed: completed.contains(habit.key))).toList();
        _weekCounts = values[1] as List<int>;
        _streak = values[2] as int;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível carregar sua rotina: $error')));
      }
    }
  }

  Future<void> _toggleHabit(int index, bool value) async {
    final habit = _habits[index];
    final today = DateTime.now();
    final selected = _selectedDate;
    final selectedStart = DateTime(selected.year, selected.month, selected.day);
    final todayStart = DateTime(today.year, today.month, today.day);
    if (selectedStart.isAfter(todayStart)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você não pode registrar um dia futuro.')));
      return;
    }
    setState(() {
      _habits[index] = habit.copyWith(completed: value);
      _saving.add(habit.key);
    });
    try {
      await _service.setCompleted(habit.key, selected, value);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _habits[index] = habit.copyWith(completed: !value));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível salvar o hábito: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(habit.key));
    }
  }

  Future<void> _shareWeeklySummary() async {
    final completed = _weekCounts.fold<int>(0, (total, count) => total + count);
    final activeDays = _weekCounts.where((count) => count > 0).length;
    await Share.share(
      'Meu resumo da semana no PBH: $completed hábitos concluídos em $activeDays dias. '
      'Um compromisso de cada vez.',
      subject: 'Meu resumo semanal PBH',
    );
  }

  void _handleBottomTap(int index) {
    if (widget.onNavigate != null) {
      Navigator.of(context).pop();
      widget.onNavigate!(index);
    } else if (index == 0) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final week = _currentWeek;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.of(context).pop()),
        title: Text('Rotina de Hábitos', style: AppTextStyles.titleLarge),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            AnimatedEntry(child: SizedBox(
              height: 68,
              child: Row(children: List.generate(week.length, (index) {
                final day = week[index];
                final selected = index == _selectedDay;
                final future = DateTime(day.year, day.month, day.day).isAfter(DateTime.now());
                return Expanded(child: GestureDetector(
                  onTap: future ? null : () { lightTapFeedback(); setState(() { _selectedDay = index; _loading = true; }); _load(); },
                  child: Opacity(opacity: future ? .4 : 1, child: Column(children: [
                    Text(const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][index], style: AppTextStyles.statLabel.copyWith(fontSize: 10, color: selected ? AppColors.textPrimary : AppColors.textSecondary)),
                    const SizedBox(height: 7),
                    AnimatedContainer(duration: const Duration(milliseconds: 220), width: selected ? 42 : 34, height: selected ? 42 : 34, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppColors.orangeDim : AppColors.backgroundElevated, border: Border.all(color: selected ? AppColors.orange : AppColors.borderSubtle, width: selected ? 2 : 1)), child: Text('${day.day}', style: AppTextStyles.titleMedium.copyWith(fontSize: 14, color: selected ? AppColors.orange : AppColors.textPrimary))),
                  ])),
                ));
              })),
            )),
            const SizedBox(height: 24),
            AnimatedEntry(delayMs: 60, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_selectedDay == DateTime.now().weekday - 1 ? 'Hoje' : '${_selectedDate.day}/${_selectedDate.month}', style: AppTextStyles.titleMedium),
              RichText(text: TextSpan(style: AppTextStyles.bodySmall, children: [TextSpan(text: '$_completedCount/${_habits.length}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.orange, fontWeight: FontWeight.w800)), const TextSpan(text: ' concluídos')]))
            ])),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()))
            else
              ...List.generate(_habits.length, (index) {
                final habit = _habits[index];
                return AnimatedEntry(delayMs: 90 + index * 35, child: Padding(padding: const EdgeInsets.only(bottom: 8), child: HabitItemCard(habit: habit, onToggle: _saving.contains(habit.key) ? null : (value) => _toggleHabit(index, value))));
              }),
            const SizedBox(height: 20),
            AnimatedEntry(delayMs: 270, child: _WeeklySummaryCard(counts: _weekCounts, onShare: _shareWeeklySummary)),
            const SizedBox(height: 12),
            AnimatedEntry(delayMs: 300, child: _StreakCard(streak: _streak, counts: _weekCounts)),
          ],
        ),
      ),
      bottomNavigationBar: PbhBottomNav(currentIndex: 0, onTap: _handleBottomTap),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({required this.counts, required this.onShare});
  final List<int> counts;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final completed = counts.fold<int>(0, (total, count) => total + count);
    final activeDays = counts.where((count) => count > 0).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderSubtle)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.insights_rounded, color: AppColors.orange)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Resumo da semana', style: AppTextStyles.titleMedium.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text('$completed hábitos em $activeDays ${activeDays == 1 ? 'dia' : 'dias'}', style: AppTextStyles.bodySmall),
        ])),
        IconButton(tooltip: 'Compartilhar resumo semanal', onPressed: onShare, icon: const Icon(Icons.share_outlined, color: AppColors.orange)),
      ]),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.counts});
  final int streak;
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface.withOpacity(.72), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderSubtle)),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sequência atual', style: AppTextStyles.statLabel), const SizedBox(height: 10), Row(children: [const Icon(Icons.local_fire_department, color: AppColors.orange, size: 22), const SizedBox(width: 7), Text('$streak', style: AppTextStyles.statNumber.copyWith(fontSize: 26)), const SizedBox(width: 5), Text(streak == 1 ? 'dia' : 'dias', style: AppTextStyles.bodySmall)])]),
        const Spacer(),
        SizedBox(height: 52, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (index) {
          final fraction = (counts[index] / habitCatalog.length).clamp(.08, 1.0);
          final date = monday.add(Duration(days: index));
          const labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
          return Padding(padding: const EdgeInsets.only(left: 8), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [AnimatedContainer(duration: Duration(milliseconds: 300 + index * 45), width: 5, height: 30 * fraction, decoration: BoxDecoration(color: AppColors.orange.withOpacity(.26 + .74 * fraction), borderRadius: BorderRadius.circular(4))), const SizedBox(height: 5), Text(labels[date.weekday - 1], style: AppTextStyles.statLabel.copyWith(fontSize: 9))]));
        }))),
      ]),
    );
  }
}
