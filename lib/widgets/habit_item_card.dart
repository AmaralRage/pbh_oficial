import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/feedback/tap_feedback.dart';
import '../models/habit_model.dart';

class HabitItemCard extends StatelessWidget {
  final HabitModel habit;
  final ValueChanged<bool>? onToggle;

  const HabitItemCard({super.key, required this.habit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: habit.completed,
      enabled: onToggle != null,
      label:
          '${habit.title}, ${habit.completed ? 'concluído' : 'não concluído'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle == null
              ? null
              : () {
                  lightTapFeedback();
                  onToggle?.call(!habit.completed);
                },
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: habit.completed
                  ? context.pbhColors.orange.withOpacity(.075)
                  : context.pbhColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: habit.completed
                    ? context.pbhColors.orange.withOpacity(.48)
                    : context.pbhColors.borderSubtle,
              ),
              boxShadow: habit.completed
                  ? [
                      BoxShadow(
                        color: context.pbhColors.orange.withOpacity(.08),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: habit.completed
                  ? context.pbhColors.orangeDim
                  : context.pbhColors.backgroundElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Icon(
                habit.icon,
                key: ValueKey('${habit.key}-${habit.completed}'),
                color: habit.completed
                    ? context.pbhColors.orange
                    : context.pbhColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  style: AppTextStyles.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(habit.subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          AnimatedScale(
            scale: habit.completed ? 1 : .88,
            duration: const Duration(milliseconds: 320),
            curve: Curves.elasticOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: habit.completed
                    ? context.pbhColors.orange
                    : Colors.transparent,
                border: Border.all(
                  color: habit.completed
                      ? context.pbhColors.orange
                      : context.pbhColors.border,
                  width: 1.5,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: habit.completed
                    ? const Icon(
                        Icons.check_rounded,
                        key: ValueKey('done'),
                        size: 17,
                        color: Colors.white,
                      )
                    : const SizedBox(
                        key: ValueKey('pending'),
                        width: 17,
                        height: 17,
                      ),
              ),
            ),
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
