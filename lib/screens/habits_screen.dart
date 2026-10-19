import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/feedback/tap_feedback.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/habit_model.dart';
import '../services/habit_service.dart';
import '../widgets/animated_entry.dart';
import '../widgets/habit_item_card.dart';
import '../widgets/pbh_app_drawer.dart';
import '../widgets/pbh_app_header.dart';
import '../widgets/pbh_bottom_nav.dart';

class HabitsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  final int currentIndex;
  final bool isAuthenticated;
  final bool isAdmin;
  final int unreadNotifications;
  final int notificationPulseKey;
  final VoidCallback? onLogoPressed;
  final VoidCallback? onAccountAction;
  final VoidCallback? onNotificationsChanged;

  const HabitsScreen({
    super.key,
    this.onNavigate,
    this.currentIndex = 0,
    this.isAuthenticated = false,
    this.isAdmin = false,
    this.unreadNotifications = 0,
    this.notificationPulseKey = 0,
    this.onLogoPressed,
    this.onAccountAction,
    this.onNotificationsChanged,
  });

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _service = HabitService();
  late List<HabitModel> _habits;
  late int _selectedDay;
  List<int> _weekCounts = List.filled(7, 0);
  Set<String> _selectedHabitKeys = HabitService.habitKeys.toSet();
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
      final selectedKeys = await _service.selectedHabitKeys();
      final values = await Future.wait([
        _service.completedOn(_selectedDate),
        _service.weekCounts(DateTime.now(), selectedHabits: selectedKeys),
        _service.streak(habitKeysForStreak: selectedKeys),
      ]);
      if (!mounted) return;
      final completed = values[0] as Set<String>;
      final currentUser = Supabase.instance.client.auth.currentUser;
      final isProjectLeader = currentUser?.email?.toLowerCase() == 'amaralaragao31@gmail.com';
      final today = DateTime.now();
      final projectDays = DateTime.utc(today.year, today.month, today.day).difference(DateTime.utc(2021, 1, 1)).inDays + 1;
      setState(() {
        _selectedHabitKeys = selectedKeys;
        _habits = habitCatalog.where((habit) => selectedKeys.contains(habit.key)).map((habit) => habit.copyWith(completed: completed.contains(habit.key))).toList();
        _weekCounts = values[1] as List<int>;
        _streak = currentUser == null ? 0 : isProjectLeader ? projectDays : values[2] as int;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível carregar sua rotina: $error')));
      }
    }
  }

  Future<void> _chooseHabits() async {
    final selected = Set<String>.of(_selectedHabitKeys);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Monte sua rotina', style: AppTextStyles.titleLarge),
            const SizedBox(height: 6),
            Text('Escolha os compromissos que quer acompanhar. Você pode mudar isso quando precisar.', style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            ...habitCatalog.map((habit) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.orange,
              title: Text(habit.title, style: AppTextStyles.titleMedium.copyWith(fontSize: 15)),
              subtitle: Text(habit.subtitle, style: AppTextStyles.bodySmall),
              value: selected.contains(habit.key),
              onChanged: (value) {
                if (value == false && selected.length == 1) return;
                setSheetState(() { value == true ? selected.add(habit.key) : selected.remove(habit.key); });
              },
            )),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('Salvar rotina'),
            )),
          ]),
        ),
      )),
    );
    if (result == null) return;
    await _service.saveSelectedHabitKeys(result);
    if (mounted) { setState(() => _loading = true); await _load(); }
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
    final completesRoutine = value && !habit.completed && _completedCount + 1 == _habits.length;
    setState(() {
      _habits[index] = habit.copyWith(completed: value);
      _saving.add(habit.key);
    });
    try {
      await _service.setCompleted(habit.key, selected, value);
      await _load();
      if (completesRoutine && mounted) _showRoutineCompleteToast(forToday: selectedStart == todayStart);
    } catch (error) {
      if (mounted) {
        setState(() => _habits[index] = habit.copyWith(completed: !value));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível salvar o hábito: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(habit.key));
    }
  }

  void _showRoutineCompleteToast({required bool forToday}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface,
      elevation: 12,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.orange.withOpacity(.55)),
      ),
      content: TweenAnimationBuilder<double>(
        tween: Tween(begin: .88, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.emoji_events_rounded, color: AppColors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Rotina concluída!', style: AppTextStyles.titleMedium.copyWith(color: AppColors.orange)),
            const SizedBox(height: 2),
            Text(forToday ? 'Disciplina hoje. Liberdade amanhã.' : 'Progresso registrado para este dia.', style: AppTextStyles.bodySmall),
          ])),
          const Icon(Icons.auto_awesome_rounded, color: AppColors.orange, size: 19),
        ]),
      ),
    ));
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
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: PbhAppDrawer(
        currentIndex: widget.currentIndex,
        onNavigate: _handleBottomTap,
        onOpenHabits: () {},
        onAccountAction: widget.onAccountAction ?? () {},
        isAuthenticated: widget.isAuthenticated,
        isOnHabits: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          PbhAppHeader(
            currentSection: 'Rotina de hábitos',
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            onLogoPressed: widget.onLogoPressed ?? () => Navigator.of(context).maybePop(),
            unreadNotifications: widget.unreadNotifications,
            notificationPulseKey: widget.notificationPulseKey,
            onNotificationsChanged: widget.onNotificationsChanged ?? () {},
            showNotifications: widget.isAuthenticated,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
            AnimatedEntry(child: Text('Rotina de Hábitos', style: AppTextStyles.brandHeadline)),
            const SizedBox(height: 16),
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
              Row(mainAxisSize: MainAxisSize.min, children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey('routine-count-$_completedCount'),
                  tween: Tween(begin: .78, end: 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Transform.scale(scale: scale, alignment: Alignment.centerRight, child: child),
                  child: RichText(text: TextSpan(style: AppTextStyles.bodySmall, children: [TextSpan(text: '$_completedCount/${_habits.length}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.orange, fontWeight: FontWeight.w800)), const TextSpan(text: ' concluídos')])),
                ),
                IconButton(tooltip: 'Escolher hábitos da rotina', onPressed: _chooseHabits, icon: const Icon(Icons.tune_rounded, color: AppColors.orange)),
              ])
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
            if (Supabase.instance.client.auth.currentUser != null)
              AnimatedEntry(delayMs: 300, child: _StreakCard(streak: _streak, counts: _weekCounts, habitTotal: _habits.length)),
              ],
            ),
          ),
        ]),
      ),
      bottomNavigationBar: PbhBottomNav(currentIndex: widget.currentIndex, onTap: _handleBottomTap, isAdmin: widget.isAdmin),
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
  const _StreakCard({required this.streak, required this.counts, required this.habitTotal});
  final int streak;
  final List<int> counts;
  final int habitTotal;

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
          final fraction = (habitTotal == 0 ? .08 : (counts[index] / habitTotal).clamp(.08, 1.0)).toDouble();
          final date = monday.add(Duration(days: index));
          const labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
          return Padding(padding: const EdgeInsets.only(left: 8), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [AnimatedContainer(duration: Duration(milliseconds: 300 + index * 45), width: 5, height: 30 * fraction, decoration: BoxDecoration(color: AppColors.orange.withOpacity(.26 + .74 * fraction), borderRadius: BorderRadius.circular(4))), const SizedBox(height: 5), Text(labels[date.weekday - 1], style: AppTextStyles.statLabel.copyWith(fontSize: 9))]));
        }))),
      ]),
    );
  }
}
