import 'package:flutter/material.dart';
import 'profile_surface.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Keep large system text readable rather than squeezing three cards together.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (MediaQuery.textScalerOf(context).scale(14) <= 19 &&
          bounds.maxWidth >= 280) {
        return Row(children: children);
      }
      final cards = children.whereType<StatCard>().toList();
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(children: [cards[i]]),
          ],
        ],
      );
    },
  );
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ProfileSurface(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: context.pbhColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.pbhColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.pbhColors.orange, size: 22),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTextStyles.statNumber),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.statLabel),
          ],
        ),
      ),
    );
  }
}
