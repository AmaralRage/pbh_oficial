import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'pbh_logo.dart';

/// Menu principal aberto pelo icone de tres tracos da tela inicial.
class PbhAppDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenHabits;

  const PbhAppDrawer({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    required this.onOpenHabits,
  });

  static const _mainItems = <_DrawerItemData>[
    _DrawerItemData(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Início', index: 0),
    _DrawerItemData(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: 'Desafios', index: 1),
    _DrawerItemData(icon: Icons.play_circle_outline, activeIcon: Icons.play_circle_fill, label: 'Conteúdo', index: 2),
    _DrawerItemData(icon: Icons.groups_outlined, activeIcon: Icons.groups, label: 'Comunidade', index: 3),
    _DrawerItemData(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil', index: 4),
  ];

  void _selectTab(BuildContext context, int index) {
    Navigator.of(context).pop();
    if (index != currentIndex) onNavigate(index);
  }

  void _openHabits(BuildContext context) {
    Navigator.of(context).pop();
    onOpenHabits();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * .84,
      backgroundColor: AppColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 14, 24),
              child: Row(
                children: [
                  const PbhLogo(compact: true),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Fechar menu',
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('NAVEGAÇÃO', style: AppTextStyles.eyebrow),
            ),
            const SizedBox(height: 10),
            ..._mainItems.map((item) => _DrawerNavigationItem(
                  icon: currentIndex == item.index ? item.activeIcon : item.icon,
                  label: item.label,
                  selected: currentIndex == item.index,
                  onTap: () => _selectTab(context, item.index),
                )),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('SUA JORNADA', style: AppTextStyles.eyebrow),
            ),
            const SizedBox(height: 10),
            _DrawerNavigationItem(
              icon: Icons.checklist_outlined,
              label: 'Rotina de hábitos',
              selected: false,
              onTap: () => _openHabits(context),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: AppColors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('23 dias de consistência', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  const _DrawerItemData({required this.icon, required this.activeIcon, required this.label, required this.index});
}

class _DrawerNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerNavigationItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.orangeDim : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 16),
                Text(label, style: AppTextStyles.titleMedium.copyWith(color: selected ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 15)),
                const Spacer(),
                if (selected) const Icon(Icons.chevron_right, color: AppColors.orange, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
