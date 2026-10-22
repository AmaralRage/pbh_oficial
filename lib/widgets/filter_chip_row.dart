import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/feedback/tap_feedback.dart';

class FilterChipRow extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return Semantics(
            button: true,
            selected: isSelected,
            label: options[index],
            child: GestureDetector(
              onTap: () {
                lightTapFeedback();
                onSelected(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.pbhColors.orange
                      : context.pbhColors.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? context.pbhColors.orange
                        : context.pbhColors.border,
                    width: 1,
                  ),
                ),
                child: Text(
                  options[index],
                  style: isSelected
                      ? AppTextStyles.chipActive.copyWith(
                          color: context.pbhColors.onAccent,
                        )
                      : AppTextStyles.chip,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
