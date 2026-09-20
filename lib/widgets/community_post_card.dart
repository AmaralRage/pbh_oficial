import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/community_post_model.dart';

class CommunityPostCard extends StatelessWidget {
  final CommunityPostModel post;

  const CommunityPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PostAvatar(post: post),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
                    Text(
                      post.isJapanese ? post.timeAgo : 'há ${post.timeAgo}',
                      style: AppTextStyles.statLabel,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: AppColors.textTertiary),
            ],
          ),
          if (post.achievementTag != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.orangeDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, size: 13, color: AppColors.orange),
                  const SizedBox(width: 6),
                  Text(
                    post.achievementTag!,
                    style: AppTextStyles.chip.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(post.content, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              _PostAction(icon: Icons.local_fire_department_outlined, label: '${post.likes}'),
              const SizedBox(width: 20),
              _PostAction(icon: Icons.chat_bubble_outline, label: '${post.comments}'),
              const Spacer(),
              const Icon(Icons.share_outlined, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostAvatar extends StatelessWidget {
  final CommunityPostModel post;

  const _PostAvatar({required this.post});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: AppColors.orangeDim, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        post.authorInitials,
        style: AppTextStyles.chip.copyWith(color: AppColors.orange, fontWeight: FontWeight.w800),
      ),
    );

    if (post.avatarAsset == null) return fallback;

    return ClipOval(
      child: Image.asset(
        post.avatarAsset!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PostAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
