import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/habit_model.dart';

class HabitItemCard extends StatelessWidget {
  final HabitModel habit;
  final ValueChanged<bool> onToggle;

  const HabitItemCard({super.key, required this.habit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(habit.icon, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.title, style: AppTextStyles.titleMedium.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(habit.subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onToggle(!habit.completed),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: habit.completed ? AppColors.orange : Colors.transparent,
                border: Border.all(
                  color: habit.completed ? AppColors.orange : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: habit.completed
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
