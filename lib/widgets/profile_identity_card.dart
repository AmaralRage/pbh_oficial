import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/profile_achievement.dart';
import '../models/profile_style.dart';
import 'profile_ornament.dart';

/// Bounded images with isolated decorative animations.
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.name,
    required this.bio,
    required this.style,
    required this.earned,
    this.avatarUrl,
    this.photo,
    this.coverUrl,
    this.coverPhoto,
    this.founder = false,
    this.onEdit,
  });
  final String name;
  final String bio;
  final ProfileStyle style;
  final List<ProfileAchievement> earned;
  final String? avatarUrl;
  final Uint8List? photo;
  final String? coverUrl;
  final Uint8List? coverPhoto;
  final bool founder;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final frame = ProfileStyle.frames
        .firstWhere(
          (o) => o.id == style.frame,
          orElse: () => ProfileStyle.frames.first,
        )
        .color;
    final cover = ProfileStyle.covers
        .firstWhere(
          (o) => o.id == style.cover,
          orElse: () => ProfileStyle.covers.first,
        )
        .color;
    Widget fallback() => founder
        ? Image.asset(
            'assets/images/perfil.png',
            fit: BoxFit.cover,
            cacheWidth: 256,
            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 44),
          )
        : Icon(
            Icons.person_outline_rounded,
            size: 44,
            color: context.pbhColors.textSecondary,
          );
    final image = photo != null
        ? Image.memory(photo!, fit: BoxFit.cover, cacheWidth: 256)
        : avatarUrl?.isNotEmpty == true
        ? Image.network(
            avatarUrl!,
            fit: BoxFit.cover,
            cacheWidth: 256,
            errorBuilder: (_, __, ___) => fallback(),
          )
        : fallback();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.pbhColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: frame.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 174,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 132,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cover.withValues(alpha: .7),
                          const Color(0xFF17171C),
                        ],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (coverPhoto != null)
                          Image.memory(
                            coverPhoto!,
                            fit: BoxFit.cover,
                            cacheWidth: 1024,
                          )
                        else if (coverUrl?.isNotEmpty == true)
                          Image.network(
                            coverUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: 1024,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        if (coverPhoto == null &&
                            coverUrl?.isNotEmpty != true) ...[
                          Positioned(
                            right: -22,
                            top: -65,
                            child: Icon(
                              Icons.hexagon_outlined,
                              size: 230,
                              color: Colors.white.withValues(alpha: .06),
                            ),
                          ),
                        ],
                        if (style.coverEffect != 'none')
                          Positioned.fill(
                            child: ProfileOrnament(
                              color: ProfileStyle.coverEffects
                                  .firstWhere(
                                    (o) => o.id == style.coverEffect,
                                    orElse: () => ProfileStyle.coverEffects[1],
                                  )
                                  .color,
                              effect: style.coverEffect,
                              intensity: style.coverIntensity,
                              founder: founder,
                            ),
                          ),
                        if (coverPhoto == null && coverUrl?.isNotEmpty != true)
                          Positioned(
                            right: 24,
                            top: 26,
                            child: Text(
                              style.cover == 'founder'
                                  ? 'LEGADO\nPBH'
                                  : 'PROJETO\nBOM HOMEM',
                              style: AppTextStyles.eyebrow
                                  .copyWith(
                                    color: context.pbhColors.orangeLight,
                                  )
                                  .copyWith(
                                    color: Colors.white.withValues(alpha: .55),
                                    letterSpacing: 3,
                                    height: 1.6,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 0,
                  child: Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.pbhColors.surface,
                      border: Border.all(color: frame, width: 3),
                    ),
                    child: ClipOval(
                      child: ColoredBox(
                        color: context.pbhColors.backgroundElevated,
                        child: image,
                      ),
                    ),
                  ),
                ),
                if (style.frameEffect != 'none')
                  Positioned(
                    left: 20,
                    bottom: 0,
                    width: 96,
                    height: 96,
                    child: ProfileOrnament(
                      color: frame,
                      frame: true,
                      founder: founder,
                      effect: style.frameEffect,
                      intensity: style.frameIntensity,
                    ),
                  ),
                if (onEdit != null)
                  Positioned(
                    right: 12,
                    bottom: 0,
                    child: IconButton(
                      onPressed: onEdit,
                      tooltip: 'Editar perfil',
                      color: context.pbhColors.orange,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      style.title == 'founder'
                          ? Icons.workspace_premium_rounded
                          : Icons.local_offer_outlined,
                      color: frame,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        style.titleLabel(earned),
                        style: AppTextStyles.bodySmall.copyWith(color: frame),
                      ),
                    ),
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(bio, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
