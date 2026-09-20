import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/feedback/tap_feedback.dart';
import '../models/habit_model.dart';
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
  late List<HabitModel> _habits;
  late int _selectedDay;

  static const _weekDayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  static const _streakBars = [0.42, 0.55, 0.34, 0.95, 0.72, 0.88, 0.54];
  static const _streakLabels = ['S', 'D', 'S', 'T', 'Q', 'Q', 'S'];

  @override
  void initState() {
    super.initState();
    _habits = List.of(mockHabits);
    _selectedDay = DateTime.now().weekday - 1;
  }

  int get _completedCount => _habits.where((h) => h.completed).length;

  List<DateTime> get _currentWeek {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));
    return List<DateTime>.generate(7, (index) => monday.add(Duration(days: index)));
  }

  void _handleBottomTap(int index) {
    if (widget.onNavigate != null) {
      Navigator.of(context).pop();
      widget.onNavigate!(index);
      return;
    }
    if (index == 0) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Rotina de Hábitos', style: AppTextStyles.titleLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opções de rotina em construção.')),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            AnimatedEntry(delayMs: 60, child: _DayStrip()),
            const SizedBox(height: 24),
            AnimatedEntry(
              delayMs: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hoje', style: AppTextStyles.titleMedium),
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodySmall,
                      children: [
                        TextSpan(
                          text: '$_completedCount/${_habits.length}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(text: ' concluídos'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(_habits.length, (index) {
              final habit = _habits[index];
              return AnimatedEntry(
                delayMs: 150 + index * 45,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: HabitItemCard(
                    habit: habit,
                    onToggle: (value) {
                      setState(() {
                        _habits[index] = HabitModel(
                          title: habit.title,
                          subtitle: habit.subtitle,
                          icon: habit.icon,
                          completed: value,
                        );
                      });
                    },
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            AnimatedEntry(delayMs: 400, child: _StreakCard()),
          ],
        ),
      ),
      bottomNavigationBar: PbhBottomNav(
        currentIndex: 0,
        onTap: _handleBottomTap,
      ),
    );
  }

  Widget _DayStrip() {
    final week = _currentWeek;
    return SizedBox(
      height: 68,
      child: Row(
        children: List.generate(week.length, (index) {
          final isSelected = index == _selectedDay;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                lightTapFeedback();
                setState(() => _selectedDay = index);
              },
              child: Column(
                children: [
                  Text(
                    _weekDayLabels[index],
                    style: AppTextStyles.statLabel.copyWith(
                      fontSize: 10,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: isSelected ? 42 : 34,
                    height: isSelected ? 42 : 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.orangeDim : AppColors.backgroundElevated,
                      border: Border.all(
                        color: isSelected ? AppColors.orange : AppColors.borderSubtle,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '${week[index].day}',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 14,
                        color: isSelected ? AppColors.orange : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _StreakCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sequência atual', style: AppTextStyles.statLabel),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: AppColors.orange, size: 22),
                  const SizedBox(width: 7),
                  Text('23', style: AppTextStyles.statNumber.copyWith(fontSize: 26)),
                  const SizedBox(width: 5),
                  Text('dias', style: AppTextStyles.bodySmall),
                ],
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_streakBars.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: 350 + i * 60),
                        width: 5,
                        height: 30 * _streakBars[i],
                        decoration: BoxDecoration(
                          color: AppColors.orange.withOpacity(0.26 + 0.74 * _streakBars[i]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(_streakLabels[i], style: AppTextStyles.statLabel.copyWith(fontSize: 9)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
