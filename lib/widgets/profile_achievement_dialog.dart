import 'package:flutter/material.dart';
import '../models/profile_achievement.dart';
import 'supreme_seal_art.dart';
import 'deferred_seal_art.dart';
import '../services/platinum_sound.dart';

class ProfileAchievementDialog extends StatelessWidget {
  const ProfileAchievementDialog({
    super.key,
    required this.badge,
    this.celebrate = false,
  });
  final ProfileAchievement badge;
  final bool celebrate;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: badge.color.withValues(alpha: .35)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(const Color(0xFF16161B), badge.color, .12)!,
              const Color(0xFF101014),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        badge.kindLabel,
                        style: TextStyle(
                          color: badge.color,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar conquista',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 184,
                  height: 184,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        badge.color.withValues(alpha: .26),
                        badge.color.withValues(alpha: .04),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: badge.color.withValues(alpha: .18),
                    ),
                  ),
                  child: ClipOval(
                    child:
                        badge.htmlAsset ==
                                ProfileAchievement.platinum.htmlAsset &&
                            !MediaQuery.disableAnimationsOf(context)
                        ? IgnorePointer(
                            child: DeferredSealArt(
                              preview: Image.asset(
                                badge.artAsset!,
                                fit: BoxFit.contain,
                              ),
                              builder: () => SupremeSealArt(
                                size: 160,
                                achievement: badge,
                                celebrate: celebrate,
                                onAnimationStarted: () =>
                                    PlatinumSound.playFor(badge),
                              ),
                            ),
                          )
                        : badge.artAsset == null
                        ? Icon(badge.icon, color: badge.color, size: 88)
                        : Image.asset(
                            badge.artAsset!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                Icon(badge.icon, color: badge.color, size: 88),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  badge.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFCDD0DA),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded, size: 16, color: badge.color),
                    const SizedBox(width: 6),
                    const Text(
                      'Conquista desbloqueada',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: badge.color,
                      foregroundColor: const Color(0xFF101014),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
