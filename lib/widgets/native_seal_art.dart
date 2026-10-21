import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/profile_achievement.dart';

class NativeSealArt extends StatefulWidget {
  const NativeSealArt({
    super.key,
    required this.size,
    required this.achievement,
  });
  final double size;
  final ProfileAchievement achievement;
  @override
  State<NativeSealArt> createState() => _NativeSealArtState();
}

class _NativeSealArtState extends State<NativeSealArt>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final badge = widget.achievement;
    final pixels = (widget.size * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(1, 600);
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _motion,
          // Keep the image out of animation rebuilds and rasterize it once.
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                badge.artAsset!,
                cacheWidth: pixels,
                fit: BoxFit.contain,
                semanticLabel: 'Arte: ${badge.title}',
              ),
            ),
          ),
          builder: (context, artwork) {
            final wave = reduced ? 0.0 : math.sin(_motion.value * math.pi * 2);
            return Stack(
              alignment: Alignment.center,
              children: [
                FractionallySizedBox(
                  widthFactor: .8,
                  heightFactor: .8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          badge.color.withValues(
                            alpha: .12 + (wave + 1) * .035,
                          ),
                          badge.color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, wave * 3),
                  child: Transform.scale(
                    scale: .96 + wave * .012,
                    child: artwork,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
