import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/feedback/tap_feedback.dart';

class PbhBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const PbhBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItemData(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Início'),
    _NavItemData(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: 'Desafios'),
    _NavItemData(icon: Icons.play_circle_outline, activeIcon: Icons.play_circle_fill, label: 'Conteúdo'),
    _NavItemData(icon: Icons.music_note_outlined, activeIcon: Icons.music_note, label: 'Música'),
    _NavItemData(icon: Icons.groups_outlined, activeIcon: Icons.groups, label: 'Comunidade'),
    _NavItemData(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isActive = index == currentIndex;
              return Expanded(
                child: _NavButton(
                  data: item,
                  isActive: isActive,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData({required this.icon, required this.activeIcon, required this.label});
}

class _NavButton extends StatelessWidget {
  final _NavItemData data;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({required this.data, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.orange : AppColors.textTertiary;
    return InkWell(
      enableFeedback: false,
      onTap: () {
        lightTapFeedback();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.12 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Icon(isActive ? data.activeIcon : data.icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: (isActive ? AppTextStyles.navLabelActive : AppTextStyles.navLabel).copyWith(fontSize: 9),
              child: Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
