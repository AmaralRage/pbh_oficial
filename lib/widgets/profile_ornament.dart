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
    this.intensity = .5,
  });
  final Color color;
  final bool frame;
  final bool founder;
  final String? effect;
  final double intensity;
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
      // localToGlobal uses the whole Flutter view. MediaQuery.size can instead
      // describe the narrower, centered mobile viewport on desktop.
      final view = View.of(context);
      final windowBounds =
          Offset.zero & (view.physicalSize / view.devicePixelRatio);
      final visible =
          box is RenderBox &&
          box.attached &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).overlaps(windowBounds);
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
          widget.intensity.isFinite ? widget.intensity.clamp(0, 1) : .5,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _OrnamentPainter extends CustomPainter {
  // Independent random attributes, generated once. Keeping them stable between
  // frames prevents particles from flickering or jumping when intensity changes.
  static final _weatherParticles = (() {
    final random = math.Random(824731);
    return List.generate(
      128,
      (_) => List.generate(8, (_) => random.nextDouble(), growable: false),
      growable: false,
    );
  })();
  _OrnamentPainter(
    this.motion,
    this.color,
    this.frame,
    this.founder,
    this.effect,
    this.intensity,
  ) : super(repaint: motion);
  final Animation<double> motion;
  final Color color;
  final bool frame;
  final bool founder;
  final String effect;
  final double intensity;
  @override
  void paint(Canvas canvas, Size size) {
    // Whole cycles keep the loop seamless while every effect supports intensity.
    final t = (motion.value * (1 + (intensity * 3).round())) % 1;
    if (effect == 'none') return;
    if (effect == 'halloween' ||
        effect == 'christmas' ||
        effect == 'new_year') {
      _seasonal(canvas, size, t);
      return;
    }
    if (effect == 'rain' || effect == 'snow' || effect == 'fireflies') {
      _weather(canvas, size, t);
      return;
    }
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
        final sparks = (7 + intensity * 14).round();
        for (var i = 0; i < sparks; i++) {
          final phase = (t * 2 + i / sparks) % 1;
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
            ..color = tint.withValues(alpha: .035 + intensity * .12)
            ..strokeCap = StrokeCap.round,
        );
      }
      if (effect == 'aurora') {
        canvas.restore();
        return;
      }
    }
    if (effect == 'embers') {
      final embers = (9 + intensity * 24).round();
      for (var i = 0; i < embers; i++) {
        final phase = (t + i / embers) % 1;
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
    for (var i = 0; i < ((founder ? 8 : 4) + intensity * 14).round(); i++) {
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
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: .025 + intensity * .12),
      );
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

  void _weather(Canvas canvas, Size size, double t) {
    canvas.save();
    final bounds = Offset.zero & size;
    if (frame) {
      // Keep the face clear: particles live only in the outer circular rim.
      final center = size.center(Offset.zero);
      final radius = size.shortestSide / 2;
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(Rect.fromCircle(center: center, radius: radius))
          ..addOval(Rect.fromCircle(center: center, radius: radius - 7)),
      );
    } else {
      canvas.clipRect(bounds);
    }
    final count = ((frame ? 38 : 24) + intensity * (frame ? 90 : 72)).round();
    final speed = 2 + (intensity * 3).round();
    final tint = effect == 'rain'
        ? const Color(0xFF83CFFF)
        : effect == 'snow'
        ? const Color(0xFFE0F4FF)
        : const Color(0xFFBBF878);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final particle = _weatherParticles[i];
      final depth = particle[2];
      final laps = effect == 'rain'
          ? speed + (depth * 5).round()
          : 1 + (depth * speed).round();
      final phase = (t * laps + particle[1]) % 1;
      final drift = math.sin(t * math.pi * 2 + particle[3] * math.pi * 2);
      final wind = math.sin(t * math.pi * 2) * (effect == 'rain' ? 3 : 5);
      final x =
          particle[0] * size.width +
          drift *
              (effect == 'rain' ? 1 + particle[4] * 3 : 4 + particle[4] * 12) +
          wind;
      final y = phase * (size.height + 48) - 24;
      if (effect == 'rain') {
        final length = 4 + particle[5] * 10 + intensity * 4;
        paint
          ..color = tint.withValues(alpha: .18 + depth * .35 + intensity * .12)
          ..strokeWidth = .45 + depth * .85;
        canvas.drawLine(
          Offset(x + length * (.08 + particle[6] * .2), y - length),
          Offset(x, y),
          paint,
        );
      } else if (effect == 'snow') {
        paint.color = tint.withValues(alpha: .25 + particle[7] * .5);
        canvas.drawCircle(Offset(x, y), .55 + depth * 1.6, paint);
      } else {
        final glow = .5 + .5 * math.sin(t * math.pi * 4 + i * 1.7);
        final point = Offset(
          x,
          size.height * ((i * 37 % 103) / 103) + drift * 6,
        );
        paint.color = tint.withValues(alpha: .08 + glow * .12);
        canvas.drawCircle(point, 3 + glow * 2, paint);
        paint.color = tint.withValues(alpha: .2 + glow * .65);
        canvas.drawCircle(point, .8 + glow * .6, paint);
      }
    }
    canvas.restore();
  }

  void _halloween(Canvas canvas, Size size, double t) {
    final r = frame
        ? size.shortestSide * .11
        : math.min(size.height * .18, size.width * .09);
    final bottom = size.height - r * .85 - 2;
    final centers = [
      Offset(r * 1.2, bottom),
      Offset(size.width - r * 1.2, bottom),
    ];
    final angle = t * math.pi * 2;
    // Smoke billows rise from each corner and dissipate before reaching the face.
    for (var side = 0; side < 2; side++) {
      final origin = centers[side];
      final direction = side == 0 ? 1.0 : -1.0;
      final clouds = (5 + intensity * 7).round();
      for (var i = 0; i < clouds; i++) {
        final seed = _weatherParticles[i + side * 20];
        final phase = (t * 2 + seed[1]) % 1;
        final rise = phase * size.height * (frame ? .3 : .7);
        final p =
            origin +
            Offset(
              direction * (phase * r + math.sin(angle + seed[3] * 6) * r * .5),
              -rise,
            );
        final radius = r * (.5 + phase * .85);
        final opacity = math.sin(phase * math.pi) * (.18 + intensity * .25);
        canvas.drawCircle(
          p,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFB67AE8).withValues(alpha: opacity),
                const Color(0xFF493266).withValues(alpha: opacity * .45),
                const Color(0xFF493266).withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: p, radius: radius)),
        );
      }
      final bats = (2 + intensity * 5).round();
      for (var i = 0; i < bats; i++) {
        final seed = _weatherParticles[60 + i + side * 10];
        final phase = (t * 2 + seed[1]) % 1;
        final emergence = ((phase - .12) / .22).clamp(0.0, 1.0);
        final fade = ((1 - phase) / .25).clamp(0.0, 1.0);
        final p = frame
            ? size.center(Offset.zero) +
                  Offset(
                        math.cos(
                          (side == 0 ? math.pi * .8 : math.pi * .2) +
                              direction * phase * 1.6,
                        ),
                        math.sin(
                          (side == 0 ? math.pi * .8 : math.pi * .2) +
                              direction * phase * 1.6,
                        ),
                      ) *
                      (size.shortestSide / 2 - 4)
            : Offset(
                size.width * (.08 + seed[0] * .84) +
                    math.sin(phase * math.pi * 2 + seed[3] * 6) * 12,
                size.height * (.12 + seed[2] * .58) - phase * 12,
              );
        final scale = (frame ? 2.0 : 4.0 + seed[4] * 3) * (.6 + emergence * .4);
        final flap = math.sin(angle * 10 + seed[5] * 6);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.scale(scale);
        final bat = Path()
          ..moveTo(0, -.3)
          ..lineTo(-.3, -.7)
          ..lineTo(-.35, -.15)
          ..quadraticBezierTo(-1.2, -1.1 - flap * .5, -2.2, -.2 - flap * .4)
          ..quadraticBezierTo(-1.5, -.15, -1.4, .5)
          ..quadraticBezierTo(-.8, .1, -.6, .6)
          ..lineTo(0, .9)
          ..lineTo(.6, .6)
          ..quadraticBezierTo(.8, .1, 1.4, .5)
          ..quadraticBezierTo(1.5, -.15, 2.2, -.2 - flap * .4)
          ..quadraticBezierTo(1.2, -1.1 - flap * .5, .35, -.15)
          ..lineTo(.3, -.7)
          ..close();
        canvas.drawPath(
          bat,
          Paint()
            ..color = const Color(
              0xFF251531,
            ).withValues(alpha: emergence * fade),
        );
        canvas.drawPath(
          bat,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .12
            ..color = const Color(
              0xFFD1A0F4,
            ).withValues(alpha: emergence * fade * .8),
        );
        canvas.restore();
      }
    }
    for (var side = 0; side < 2; side++) {
      final p = centers[side];
      final glow = .65 + .35 * math.sin(angle * 2 + side);
      final body = Rect.fromCenter(center: p, width: r * 2.1, height: r * 1.65);
      canvas.drawOval(
        body,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.25, -.35),
            colors: [Color(0xFFFFB34D), Color(0xFFEE711B), Color(0xFF8F300E)],
          ).createShader(body),
      );
      for (final offset in [-.55, 0.0, .55]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: p + Offset(r * offset, 0),
            width: r * .8,
            height: r * 1.55,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = frame ? .6 : 1.2
            ..color = const Color(0xFF8D350D).withValues(alpha: .5),
        );
      }
      canvas.drawLine(
        p + Offset(0, -r * .8),
        p + Offset(r * .18, -r * 1.08),
        Paint()
          ..color = const Color(0xFF91AE51)
          ..strokeWidth = r * .15
          ..strokeCap = StrokeCap.round,
      );
      final face = Path();
      for (final sign in [-1, 1]) {
        face.moveTo(p.dx + sign * r * .2, p.dy - r * .18);
        face.lineTo(p.dx + sign * r * .6, p.dy - r * .28);
        face.lineTo(p.dx + sign * r * .4, p.dy - r * .55);
        face.close();
      }
      face.moveTo(p.dx - r * .6, p.dy + r * .12);
      face.lineTo(p.dx - r * .3, p.dy + r * .2);
      face.lineTo(p.dx - r * .2, p.dy + r * .08);
      face.lineTo(p.dx, p.dy + r * .23);
      face.lineTo(p.dx + r * .2, p.dy + r * .08);
      face.lineTo(p.dx + r * .6, p.dy + r * .12);
      face.quadraticBezierTo(
        p.dx,
        p.dy + r * .92,
        p.dx - r * .6,
        p.dy + r * .12,
      );
      canvas.drawPath(
        face,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFBA3D),
            const Color(0xFFFFF1A1),
            glow,
          )!,
      );
    }
  }

  void _seasonal(Canvas canvas, Size size, double t) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final count = (6 + intensity * 10).round();
    final angle = t * math.pi * 2;
    if (effect == 'halloween') {
      _halloween(canvas, size, t);
    } else if (effect == 'christmas') {
      final wire = Paint()
        ..color = const Color(0xFF85E5A2).withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      if (frame) {
        canvas.drawCircle(center, radius, wire);
      } else {
        canvas.drawPath(
          Path()
            ..moveTo(0, 9)
            ..quadraticBezierTo(size.width / 2, 36, size.width, 9),
          wire,
        );
      }
      const lights = [Color(0xFFFF6D78), Color(0xFFFFD878), Color(0xFF85E5A2)];
      for (var i = 0; i < count; i++) {
        final fraction = (i + .5) / count;
        final a = fraction * math.pi * 2;
        final p = frame
            ? center + Offset(math.cos(a), math.sin(a)) * radius
            : Offset(size.width * fraction, 9 + 54 * fraction * (1 - fraction));
        final glow = .6 + .4 * math.sin(angle * 2 + i);
        canvas.drawCircle(
          p,
          frame ? 3.5 : 5,
          Paint()..color = lights[i % 3].withValues(alpha: glow * .18),
        );
        canvas.drawCircle(
          p,
          frame ? 1.6 : 2.6,
          Paint()..color = lights[i % 3].withValues(alpha: .5 + glow * .5),
        );
        // Snow below the lights, restricted to the outer rim on the photo.
        final phase = (t * 3 + i / count) % 1;
        final snow = frame
            ? center +
                  Offset(math.cos(a + angle), math.sin(a + angle)) *
                      (radius - 1)
            : Offset(
                size.width * ((i * .61803398875) % 1),
                phase * size.height,
              );
        canvas.drawCircle(
          snow,
          frame ? .8 : 1.3,
          Paint()..color = Colors.white.withValues(alpha: .6),
        );
      }
    } else {
      const colors = [Color(0xFFFFD878), Color(0xFF83DFFF), Color(0xFFFFA5E3)];
      final bursts = (3 + intensity * 4).round();
      for (var i = 0; i < bursts; i++) {
        final phase = (t * 3 + i / bursts) % 1;
        final a = i * math.pi * 2 / bursts;
        final origin = frame
            ? center + Offset(math.cos(a), math.sin(a)) * (radius - 1)
            : Offset(
                size.width * (.15 + .7 * ((i * .61803398875) % 1)),
                size.height * (.28 + (i % 3) * .2),
              );
        final reach = (frame ? 3.0 : 24.0) * phase;
        final paint = Paint()
          ..color = colors[i % 3].withValues(
            alpha: math.sin(phase * math.pi) * .9,
          )
          ..strokeWidth = frame ? 1 : 1.5
          ..strokeCap = StrokeCap.round;
        for (var ray = 0; ray < 10; ray++) {
          final direction = ray * math.pi / 5 + i;
          final vector = Offset(math.cos(direction), math.sin(direction));
          canvas.drawLine(
            origin + vector * reach * .45,
            origin +
                vector * reach +
                Offset(0, phase * phase * (frame ? 1 : 6)),
            paint,
          );
        }
      }
    }
    canvas.restore();
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
      oldDelegate.intensity != intensity ||
      oldDelegate.motion != motion;
}
