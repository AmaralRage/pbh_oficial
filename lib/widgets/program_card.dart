import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/program_model.dart';

/// Card horizontal de programa — usado na Home ("Conteúdo recomendado")
/// e na listagem completa da tela Conteúdo.
class ProgramCard extends StatelessWidget {
  final ProgramModel program;
  final VoidCallback onTap;

  const ProgramCard({super.key, required this.program, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasProgress = program.progress > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(program.icon, color: AppColors.orange, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(program.title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    program.tagline,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniTag(icon: Icons.view_module_outlined, label: '${program.modules} módulos'),
                      _MiniTag(icon: Icons.calendar_today_outlined, label: '${program.weeks} semanas'),
                    ],
                  ),
                  if (hasProgress) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: program.progress,
                        minHeight: 6,
                        backgroundColor: AppColors.backgroundElevated,
                        valueColor: const AlwaysStoppedAnimation(AppColors.orange),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.chip.copyWith(fontSize: 11)),
      ],
    );
  }
}
