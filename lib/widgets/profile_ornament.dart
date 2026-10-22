import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Paint-only decoration: the image and profile text never rebuild on a tick.
class ProfileOrnament extends StatefulWidget {
  const ProfileOrnament({
    super.key,
    required this.color,
    this.frame = false,
    this.founder = false,
    this.effect,
  });
  final Color color;
  final bool frame;
  final bool founder;
  final String? effect;
  @override
  State<ProfileOrnament> createState() => _ProfileOrnamentState();
}

class _ProfileOrnamentState extends State<ProfileOrnament>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  ScrollPosition? _scroll;
  bool _enabled = false;
  bool _foreground = true;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        widget.effect != 'none' &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final scroll = Scrollable.maybeOf(context)?.position;
    if (_scroll != scroll) {
      _scroll?.removeListener(_checkVisibility);
      _scroll = scroll;
      _scroll?.addListener(_checkVisibility);
    }
    if (!_enabled) {
      _motion.stop();
      _motion.value = 0;
    }
    _checkVisibility();
  }

  @override
  void didUpdateWidget(covariant ProfileOrnament oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) {
      _motion.stop();
      _motion.value = 0;
      _enabled =
          widget.effect != 'none' &&
          !MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.isCurrentOf(context) ?? true);
      _checkVisibility();
    }
  }

  void _checkVisibility() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      final visible =
          box is RenderBox &&
          box.attached &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).overlaps(
            Offset.zero & MediaQuery.sizeOf(context),
          );
      if (_enabled && _foreground && visible) {
        if (!_motion.isAnimating) _motion.repeat();
      } else {
        _motion.stop();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _motion.stop();
    _checkVisibility();
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkVisibility);
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _OrnamentPainter(
          _motion,
          widget.color,
          widget.frame,
          widget.founder,
          widget.effect ??
              (widget.frame
                  ? 'orbit'
                  : widget.founder
                  ? 'meteors'
                  : 'shimmer'),
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _OrnamentPainter extends CustomPainter {
  _OrnamentPainter(
    this.motion,
    this.color,
    this.frame,
    this.founder,
    this.effect,
  ) : super(repaint: motion);
  final Animation<double> motion;
  final Color color;
  final bool frame;
  final bool founder;
  final String effect;
  @override
  void paint(Canvas canvas, Size size) {
    final t = motion.value;
    if (effect == 'none') return;
    if (frame) {
      final center = size.center(Offset.zero);
      final radius = size.shortestSide / 2 - 1.8;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final angle = t * math.pi * 2;
      if (effect == 'pulse') {
        final pulse = .5 + .5 * math.sin(angle * 2);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 + pulse * 1.5
            ..color = color.withValues(alpha: .25 + pulse * .7),
        );
        canvas.drawCircle(
          center,
          radius - 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8
            ..color = color.withValues(alpha: .15 + pulse * .25),
        );
        return;
      }
      if (effect == 'double' || effect == 'crown') {
        final cosmic = effect == 'crown';
        final accent = cosmic
            ? const Color(0xFFBD83FF)
            : Color.lerp(color, Colors.white, .7)!;
        for (var ring = 0; ring < 2; ring++) {
          final bounds = Rect.fromCircle(
            center: center,
            radius: radius - ring * 3.5,
          );
          canvas.drawArc(
            bounds,
            (ring == 0 ? angle : -angle) + ring * math.pi,
            math.pi * 1.35,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = ring == 0 ? 2.2 : 1.2
              ..strokeCap = StrokeCap.round
              ..shader = SweepGradient(
                transform: GradientRotation(ring == 0 ? angle : -angle),
                colors: [color.withValues(alpha: .1), accent, color],
              ).createShader(bounds),
          );
        }
        if (cosmic) {
          for (var i = 0; i < 6; i++) {
            final a = -angle + i * math.pi / 3;
            final p = center + Offset(math.cos(a), math.sin(a)) * (radius - 1);
            _star(canvas, p, 2.3, accent.withValues(alpha: .8));
          }
        }
        return;
      }
      if (effect == 'sparks') {
        for (var i = 0; i < 14; i++) {
          final phase = (t * 2 + i / 14) % 1;
          final a = i * 2.399 + t * math.pi;
          final p =
              center +
              Offset(math.cos(a), math.sin(a)) * (radius - 3 + phase * 3);
          canvas.drawCircle(
            p,
            .6 + (1 - phase) * 1.2,
            Paint()
              ..color = Color.lerp(
                color,
                Colors.white,
                .5,
              )!.withValues(alpha: math.sin(phase * math.pi) * .85),
          );
        }
        return;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..shader = SweepGradient(
          transform: GradientRotation(angle),
          colors: [
            color.withValues(alpha: .05),
            color.withValues(alpha: .25),
            const Color(0xFFFFF3D9),
            color.withValues(alpha: .05),
          ],
          stops: const [0, .7, .85, 1],
        ).createShader(rect);
      canvas.drawCircle(center, radius, paint);
      final point =
          center +
          Offset(math.cos(angle + 5.3), math.sin(angle + 5.3)) * radius;
      canvas.drawCircle(
        point,
        2.1,
        Paint()..color = Colors.white.withValues(alpha: .65),
      );
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (effect == 'aurora' || effect == 'legacy') {
      for (var band = 0; band < 3; band++) {
        final path = Path();
        for (var step = 0; step <= 20; step++) {
          final x = size.width * step / 20;
          final y =
              size.height *
              (.35 +
                  band * .2 +
                  .15 * math.sin(step * .25 + t * math.pi * 2 + band));
          if (step == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        final tint = effect == 'legacy'
            ? (band.isEven ? const Color(0xFF70E8FF) : const Color(0xFFBD83FF))
            : (band.isEven ? color : const Color(0xFFAF9AFF));
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12 + band * 4
            ..color = tint.withValues(alpha: .065)
            ..strokeCap = StrokeCap.round,
        );
      }
      if (effect == 'aurora') {
        canvas.restore();
        return;
      }
    }
    if (effect == 'embers') {
      for (var i = 0; i < 18; i++) {
        final phase = (t + i / 18) % 1;
        final x =
            size.width * ((i * 73 % 307) / 307) +
            math.sin(phase * math.pi * 2 + i) * 10;
        final y = size.height * (1 - phase);
        canvas.drawCircle(
          Offset(x, y),
          .8 + (i % 3) * .45,
          Paint()
            ..color = color.withValues(alpha: math.sin(phase * math.pi) * .6),
        );
      }
      canvas.restore();
      return;
    }
    // A small fixed constellation; no particles, blur layers or random allocations.
    for (var i = 0; i < (founder ? 14 : 7); i++) {
      final x = ((i * 73 + 19) % 307) / 307 * size.width;
      final y = ((i * 37 + 11) % 103) / 103 * size.height;
      final pulse = .5 + .5 * math.sin(t * math.pi * 2 + i * 1.7);
      canvas.drawCircle(
        Offset(x, y),
        i % 3 == 0 ? 1.15 : .7,
        Paint()
          ..color = Color.lerp(
            color,
            Colors.white,
            .7,
          )!.withValues(alpha: .12 + pulse * .35),
      );
    }
    if (effect == 'meteors' || effect == 'legacy') {
      _meteor(canvas, size, t, .09, .19, .88);
      _meteor(canvas, size, t, .65, .74, .55);
    } else if (effect == 'shimmer') {
      final x = size.width * (t * 1.6 - .3);
      final path = Path()
        ..moveTo(x - 35, 0)
        ..lineTo(x + 20, 0)
        ..lineTo(x - 70, size.height)
        ..lineTo(x - 125, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .045));
    }
    canvas.restore();
  }

  void _star(Canvas canvas, Offset p, double radius, Color tint) {
    final paint = Paint()
      ..color = tint
      ..strokeWidth = .8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p - Offset(radius, 0), p + Offset(radius, 0), paint);
    canvas.drawLine(p - Offset(0, radius), p + Offset(0, radius), paint);
  }

  void _meteor(
    Canvas canvas,
    Size size,
    double t,
    double start,
    double end,
    double origin,
  ) {
    if (t < start || t > end) return;
    final progress = (t - start) / (end - start);
    final opacity = math.sin(progress * math.pi) * .8;
    final head = Offset(
      size.width * origin - progress * 150,
      -12 + progress * (size.height + 45),
    );
    final tail = head + const Offset(34, -45);
    final rect = Rect.fromPoints(tail, head).inflate(1);
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            color.withValues(alpha: 0),
            const Color(0xFFFFF4D5).withValues(alpha: opacity),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      head,
      1.7,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_OrnamentPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.frame != frame ||
      oldDelegate.founder != founder ||
      oldDelegate.effect != effect ||
      oldDelegate.motion != motion;
}
