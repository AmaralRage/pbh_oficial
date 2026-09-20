import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class WeekdaySelector extends StatelessWidget {
  /// Data usada para destacar o dia atual. O índice 0 é segunda-feira.
  final DateTime date;
  final Set<int> completedIndexes;

  const WeekdaySelector({
    super.key,
    required this.date,
    required this.completedIndexes,
  });

  static const _labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  static const _fullLabels = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];

  int get _todayIndex => date.weekday - 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hoje · ${_fullLabels[_todayIndex]}', style: AppTextStyles.bodySmall),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
        final isToday = index == _todayIndex;
        final isCompleted = completedIndexes.contains(index);

        return Column(
          children: [
            Text(
              _labels[index],
              style: AppTextStyles.statLabel.copyWith(
                color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
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
        ),
      ],
    );
  }
}
