import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class OfficialHeroBackground extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;
  final Alignment imageAlignment;
  final BoxFit fit;
  final double darken;
  final bool animate;

  const OfficialHeroBackground({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.imageAlignment = Alignment.center,
    this.fit = BoxFit.cover,
    this.darken = 0.24,
    this.animate = false,
  });

  @override
  State<OfficialHeroBackground> createState() => _OfficialHeroBackgroundState();
}

class _OfficialHeroBackgroundState extends State<OfficialHeroBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _motion.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant OfficialHeroBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _motion.repeat(reverse: true);
    } else if (!widget.animate && oldWidget.animate) {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.animate && !reduceMotion)
            AnimatedBuilder(
              animation: _motion,
              builder: (context, child) {
                final amount = Curves.easeInOutSine.transform(_motion.value);
                return Transform.translate(
                  offset: Offset((amount - .5) * 44, (.5 - amount) * 30),
                  child: Transform.scale(
                    scale: 1.07 + amount * .08,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/images/pbh_official_hero.png',
                fit: widget.fit,
                alignment: widget.imageAlignment,
              ),
            )
          else
            Image.asset(
              'assets/images/pbh_official_hero.png',
              fit: widget.fit,
              alignment: widget.imageAlignment,
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.12 + widget.darken),
                  context.pbhColors.background.withOpacity(
                    0.38 + widget.darken,
                  ),
                  context.pbhColors.background.withOpacity(
                    0.74 + widget.darken,
                  ),
                ],
              ),
            ),
          ),
          if (widget.animate && !reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) => CustomPaint(
                    painter: _GalaxyParticlePainter(
                      progress: _motion.value,
                      accent: context.pbhColors.orange,
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: widget.padding, child: widget.child),
        ],
      ),
    );
  }
}

class _GalaxyParticlePainter extends CustomPainter {
  const _GalaxyParticlePainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final time = progress * math.pi * 2;
    _paintGlow(canvas, size, Offset(.2 + math.sin(time) * .08, .28), .45);
    _paintGlow(canvas, size, Offset(.82 + math.cos(time * .8) * .07, .72), .32);

    for (var index = 0; index < 54; index++) {
      final phase = index * .83;
      final x = ((index * 73) % 997) / 997;
      final y = ((index * 193 + 47) % 991) / 991;
      final driftX = math.sin(time + phase) * .024;
      final driftY = math.cos(time * .8 + phase) * .035;
      final twinkle = .28 + .72 * ((math.sin(time * 1.7 + phase) + 1) / 2);
      final point = Offset(
        (x + driftX).clamp(.01, .99).toDouble() * size.width,
        (y + driftY).clamp(.01, .99).toDouble() * size.height,
      );
      final isOrange = index % 9 == 0;
      final color = isOrange ? accent : Colors.white;
      final radius = index % 11 == 0 ? 1.8 : .8;
      final paint = Paint()
        ..color = color.withOpacity(twinkle * (isOrange ? .72 : .48));
      canvas.drawCircle(point, radius * (.7 + twinkle * .55), paint);

      if (index % 13 == 0) {
        final glint = Paint()..color = color.withOpacity(twinkle * .32);
        canvas.drawLine(point.translate(-3, 0), point.translate(3, 0), glint);
        canvas.drawLine(point.translate(0, -3), point.translate(0, 3), glint);
      }
    }
  }

  void _paintGlow(Canvas canvas, Size size, Offset anchor, double strength) {
    final x =
        (anchor.dx + math.sin(progress * math.pi * 2 + anchor.dy) * .035) *
        size.width;
    final y =
        (anchor.dy + math.cos(progress * math.pi * 2 + anchor.dx) * .045) *
        size.height;
    final center = Offset(x, y);
    final radius = size.shortestSide * .17;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withOpacity(strength * .14),
          accent.withOpacity(strength * .035),
          Colors.transparent,
        ],
        stops: const [0, .38, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GalaxyParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
