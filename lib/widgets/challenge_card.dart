import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/feedback/tap_feedback.dart';
import '../models/challenge_model.dart';

class ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final VoidCallback onTap;

  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        lightTapFeedback();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBadge(icon: challenge.icon, status: challenge.status),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(challenge.title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    challenge.description,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Tag(label: challenge.levelLabel),
                      _Tag(label: '${challenge.totalDays} dias'),
                      _Tag(
                        label: '${_formatCount(challenge.participants)} participantes',
                        icon: Icons.groups_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TrailingIndicator(challenge: challenge),
          ],
        ),
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return '$value';
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final ChallengeStatus status;

  const _IconBadge({required this.icon, required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == ChallengeStatus.completed;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.orangeDim : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted ? AppColors.orange.withOpacity(0.5) : AppColors.border,
        ),
      ),
      child: Icon(
        icon,
        color: isCompleted ? AppColors.orange : AppColors.textSecondary,
        size: 24,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _Tag({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.textTertiary),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppTextStyles.chip.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _TrailingIndicator extends StatelessWidget {
  final ChallengeModel challenge;

  const _TrailingIndicator({required this.challenge});

  @override
  Widget build(BuildContext context) {
    switch (challenge.status) {
      case ChallengeStatus.completed:
        return const Icon(Icons.check_circle, color: AppColors.orange, size: 22);
      case ChallengeStatus.active:
        return const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 22);
      case ChallengeStatus.notStarted:
        return Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.orange,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 18),
        );
    }
  }
}
