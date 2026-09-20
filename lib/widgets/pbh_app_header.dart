import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'pbh_logo.dart';

/// Cabeçalho permanente das seções principais do aplicativo.
/// O indicador abaixo da marca mostra a área selecionada sem substituir a
/// identidade visual fixa do topo.
class PbhAppHeader extends StatelessWidget {
  final String currentSection;
  final VoidCallback onMenuPressed;

  const PbhAppHeader({
    super.key,
    required this.currentSection,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Abrir menu',
                  icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                  onPressed: onMenuPressed,
                ),
                const Expanded(child: Center(child: PbhLogo(compact: true))),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notificações',
                      icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Você está em dia por aqui.')),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Row(
              key: ValueKey(currentSection),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  currentSection.toUpperCase(),
                  style: AppTextStyles.eyebrow.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
