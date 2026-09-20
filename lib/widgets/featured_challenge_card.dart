import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/feedback/tap_feedback.dart';
import '../models/challenge_model.dart';

class FeaturedChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final VoidCallback onTap;

  const FeaturedChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercent = (challenge.progress * 100).round();

    return GestureDetector(
      onTap: () {
        lightTapFeedback();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/discipline_challenge_mountain.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.background.withOpacity(0.92),
                      AppColors.background.withOpacity(0.62),
                      AppColors.background.withOpacity(0.12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DESAFIO ATUAL', style: AppTextStyles.eyebrow.copyWith(fontSize: 10)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 150,
                      child: Text(
                        challenge.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontSize: 19,
                          height: 1.06,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Dia ${challenge.currentDay} de ${challenge.totalDays}',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.chevron_right, size: 17, color: AppColors.textPrimary),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: challenge.progress,
                              minHeight: 4,
                              backgroundColor: AppColors.surfaceElevated,
                              valueColor: const AlwaysStoppedAnimation(AppColors.orange),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$progressPercent%',
                          style: AppTextStyles.chip.copyWith(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
