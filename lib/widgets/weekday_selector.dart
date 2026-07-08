import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class WeekdaySelector extends StatelessWidget {
  /// Índice 0 = Segunda ... 6 = Domingo
  final int todayIndex;
  final Set<int> completedIndexes;

  const WeekdaySelector({
    super.key,
    required this.todayIndex,
    required this.completedIndexes,
  });

  static const _labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isToday = index == todayIndex;
        final isCompleted = completedIndexes.contains(index);

        return Column(
          children: [
            Text(_labels[index], style: AppTextStyles.statLabel),
            const SizedBox(height: 10),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppColors.orange : Colors.transparent,
                border: Border.all(
                  color: isToday
                      ? AppColors.orange
                      : (isCompleted ? Colors.transparent : AppColors.border),
                  width: isToday ? 2 : 1,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        );
      }),
    );
  }
}
