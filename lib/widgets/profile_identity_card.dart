import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/profile_achievement.dart';
import '../models/profile_style.dart';
import 'profile_ornament.dart';
import 'profile_cover_media.dart';
import 'profile_achievement_dialog.dart';
import 'supreme_seal_art.dart';
import '../services/platinum_sound.dart';

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
    this.onEditCover,
    this.onEditPhoto,
    this.showDecorations = true,
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
  final bool showDecorations;
  final VoidCallback? onEdit;
  final VoidCallback? onEditCover;
  final VoidCallback? onEditPhoto;
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
    final miniatures = showDecorations
        ? style.profileMiniatures(earned)
        : <ProfileAchievement>[];
    final decoratedFrame = ProfileStyle.decoratedFrameEffects.contains(
      style.frameEffect,
    );
    final frameSpace = !showDecorations
        ? 0.0
        : style.frameEffect == 'supreme_crown'
        ? 48.0
        : style.frameEffect == 'crown'
        ? 36.0
        : style.frameEffect == 'sparks' ||
              ProfileStyle.eventFrameEffects.contains(style.frameEffect)
        ? 18.0
        : ProfileStyle.decoratedFrameEffects.contains(style.frameEffect)
        ? 12.0
        : 0.0;
    final avatarInset = style.frameEffect == 'supreme_crown' ? 48.0 : 20.0;
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
        border: Border.all(
          color: showDecorations
              ? frame.withValues(alpha: .3)
              : context.pbhColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 182 + frameSpace,
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
                        colors: style.cover == 'bonfire'
                            ? const [
                                Color(0xFF090D1B),
                                Color(0xFF161524),
                                Color(0xFF080A13),
                              ]
                            : [
                                cover.withValues(alpha: .7),
                                const Color(0xFF17171C),
                              ],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (coverPhoto != null || coverUrl?.isNotEmpty == true)
                          ProfileCoverMedia(bytes: coverPhoto, url: coverUrl),
                        if (coverPhoto == null &&
                            coverUrl?.isNotEmpty != true &&
                            style.cover != 'bonfire') ...[
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
                        if (showDecorations && style.coverEffect != 'none')
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
                              variant: style.coverVariant,
                              founder: founder,
                            ),
                          ),
                        if (coverPhoto == null &&
                            coverUrl?.isNotEmpty != true &&
                            style.cover != 'bonfire')
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
                  left: avatarInset,
                  bottom: 8 + frameSpace,
                  child: Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.pbhColors.surface,
                      border: Border.all(
                        color: !showDecorations || decoratedFrame
                            ? Colors.transparent
                            : frame,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: ColoredBox(
                        color: context.pbhColors.backgroundElevated,
                        child: image,
                      ),
                    ),
                  ),
                ),
                if (showDecorations && style.frameEffect != 'none')
                  Positioned(
                    left: avatarInset - frameSpace,
                    bottom: 8,
                    width: 96 + frameSpace * 2,
                    height: 96 + frameSpace * 2,
                    child: ProfileOrnament(
                      color: frame,
                      frame: true,
                      founder: founder,
                      effect: style.frameEffect,
                      intensity: style.frameIntensity,
                    ),
                  ),
                if (miniatures.isNotEmpty)
                  Positioned(
                    left: 130,
                    right: 12,
                    bottom: 8,
                    height: 76,
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final tile = (bounds.maxWidth / miniatures.length)
                            .clamp(30.0, 42.0);
                        return Align(
                          alignment: Alignment.bottomRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            runSpacing: 4,
                            children: [
                              for (final badge in miniatures)
                                Tooltip(
                                  message: badge.title,
                                  child: Semantics(
                                    label: badge.title,
                                    button: true,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        PlatinumSound.prepareForUnlock();
                                        showDialog<void>(
                                          context: context,
                                          builder: (ctx) =>
                                              ProfileAchievementDialog(
                                                badge: badge,
                                                celebrate: true,
                                              ),
                                        );
                                      },
                                      child: Container(
                                        width: tile - 4,
                                        height: tile - 4,
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: badge.color.withValues(
                                            alpha: .08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: badge.color.withValues(
                                              alpha: .3,
                                            ),
                                          ),
                                        ),
                                        child:
                                            badge.isJourneyTrophy &&
                                                !MediaQuery.disableAnimationsOf(
                                                  context,
                                                )
                                            ? IgnorePointer(
                                                child: SupremeSealArt(
                                                  size: tile - 10,
                                                  achievement: badge,
                                                ),
                                              )
                                            : badge.artAsset != null
                                            ? Image.asset(
                                                badge.artAsset!,
                                                fit: BoxFit.contain,
                                                cacheWidth: 96,
                                                errorBuilder: (_, __, ___) =>
                                                    Icon(
                                                      badge.icon,
                                                      color: badge.color,
                                                      size: 24,
                                                    ),
                                              )
                                            : Icon(
                                                badge.icon,
                                                color: badge.color,
                                                size: 24,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (onEditCover != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: .8),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onEditCover,
                      icon: const Icon(Icons.wallpaper_rounded, size: 18),
                      label: const Text('Editar capa'),
                    ),
                  ),
                if (onEditPhoto != null)
                  Positioned(
                    left: avatarInset + 66,
                    bottom: 8 + frameSpace,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Editar foto e moldura',
                      onPressed: onEditPhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: AppTextStyles.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onEdit != null)
                      Transform.translate(
                        // Platinum center: 12px inset + half its 38px tile.
                        offset: const Offset(13, 0),
                        child: IconButton(
                          onPressed: onEdit,
                          tooltip: 'Editar perfil',
                          style: IconButton.styleFrom(
                            fixedSize: const Size(48, 48),
                            backgroundColor: Colors.transparent,
                            foregroundColor: context.pbhColors.orange,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
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
                  const SizedBox(height: 8),
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
