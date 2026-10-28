import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'bonfire_art.dart';

/// Paint-only decoration: the image and profile text never rebuild on a tick.
class ProfileOrnament extends StatefulWidget {
  const ProfileOrnament({
    super.key,
    required this.color,
    this.frame = false,
    this.founder = false,
    this.effect,
    this.intensity = .5,
    this.variant = 'royal',
  });
  final Color color;
  final bool frame;
  final bool founder;
  final String? effect;
  final double intensity;
  final String variant;
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
    if (oldWidget.effect != widget.effect ||
        oldWidget.variant != widget.variant) {
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
          widget.variant,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _OrnamentPainter extends CustomPainter {
  static final _stormDrops = (() {
    final random = math.Random(571903);
    return List.generate(
      330,
      (_) => List.generate(8, (_) => random.nextDouble(), growable: false),
      growable: false,
    );
  })();
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
    this.variant,
  ) : super(repaint: motion);
  final Animation<double> motion;
  final Color color;
  final bool frame;
  final bool founder;
  final String effect;
  final double intensity;
  final String variant;
  @override
  void paint(Canvas canvas, Size size) {
    // Whole cycles keep the loop seamless while every effect supports intensity.
    final t = (motion.value * (1 + (intensity * 3).round())) % 1;
    if (effect == 'none') return;
    if (!frame && effect == 'aurora') {
      _auroraBorealis(canvas, size, motion.value);
      return;
    }
    if (!frame && effect == 'meteors') {
      _meteorShower(canvas, size, motion.value);
      return;
    }
    if (!frame && effect == 'embers') {
      _soulEmbers(canvas, size, motion.value);
      return;
    }
    if (!frame && effect == 'legacy') {
      _nebula(canvas, size, t);
      return;
    }
    if (!frame && (effect == 'christmas' || effect == 'halloween')) {
      _themedCover(canvas, size, t);
      return;
    }
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

  // Adapted from the supplied aurora_boreal_pbh.html canvas. No background
  // image or opaque sky is painted: the user's cover remains the base layer.
  void _auroraBorealis(Canvas canvas, Size size, double phase) {
    const palette = [Color(0xFF34F7BD), Color(0xFF29D9E8), Color(0xFFB24CFF)];
    final angle = phase * math.pi * 2;
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()..blendMode = BlendMode.screen;
    for (var band = 0; band < 4; band++) {
      final base = w * (.12 + band * .24);
      final spread = w * (.11 + band * .015);
      final alpha = (.09 + intensity * .13) * (1 - band * .1);
      for (var strip = 0; strip < 52; strip++) {
        final u = strip / 51;
        final x =
            base +
            (u - .5) * spread * 2 +
            math.sin(angle + u * 5 + band) * w * .055;
        final top = h * (.04 + .08 * math.sin(u * 3 + band + angle));
        final bottom = h * (.66 + .12 * math.sin(u * 4 + band + angle));
        final width = math.max(1.5, w * .008);
        final opacity = alpha * (.55 + .45 * math.sin(u * math.pi));
        final first = palette[(band + strip % 3) % 3];
        final second = palette[(band + 1) % 3];
        paint.shader = ui.Gradient.linear(
          Offset(x, top),
          Offset(x, bottom),
          [
            first.withValues(alpha: 0),
            first.withValues(alpha: opacity),
            second.withValues(alpha: opacity),
            second.withValues(alpha: 0),
          ],
          const [0, .2, .63, 1],
        );
        final path = Path()..moveTo(x, top);
        for (var step = 0; step <= 15; step++) {
          final v = step / 15;
          path.lineTo(
            x + math.sin(v * 5 + angle * 2 + band + u * 3) * w * .065,
            top + (bottom - top) * v,
          );
        }
        for (var step = 15; step >= 0; step--) {
          final v = step / 15;
          path.lineTo(
            x + width + math.sin(v * 5 + angle * 2 + band + u * 3) * w * .065,
            top + (bottom - top) * v,
          );
        }
        canvas.drawPath(path..close(), paint);
      }
    }
    paint.shader = null;
    for (var i = 0; i < 115; i++) {
      final star = _weatherParticles[i];
      final twinkle = (.45 + .55 * math.sin(angle * 3 + star[3] * 7)).clamp(
        0.0,
        1.0,
      );
      paint.color = const Color(0xFFDFFAFF).withValues(alpha: twinkle * .8);
      canvas.drawCircle(
        Offset(star[0] * w, star[1] * h * .83),
        .3 + star[2] * 1.1,
        paint,
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
    if (effect == 'rain') {
      _storm(canvas, size, motion.value);
      return;
    }
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
    final tint = effect == 'snow'
        ? const Color(0xFFE0F4FF)
        : const Color(0xFFBBF878);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final particle = _weatherParticles[i];
      final depth = particle[2];
      final laps = 1 + (depth * speed).round();
      final phase = (t * laps + particle[1]) % 1;
      final drift = math.sin(t * math.pi * 2 + particle[3] * math.pi * 2);
      final wind = math.sin(t * math.pi * 2) * 5;
      final x =
          particle[0] * size.width + drift * (4 + particle[4] * 12) + wind;
      final y = phase * (size.height + 48) - 24;
      if (effect == 'snow') {
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

  void _meteorShower(Canvas canvas, Size size, double t) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final angle = t * math.pi * 2;
    final stars = (size.width * size.height / 550).floor().clamp(
      12,
      _stormDrops.length,
    );
    for (var i = 0; i < stars; i++) {
      final p = _stormDrops[i];
      final alpha =
          (.2 + p[2] * .55) *
          (.75 + .25 * math.sin(angle * (1 + (p[3] * 3).round()) + p[4] * 7));
      canvas.drawCircle(
        Offset(p[0] * size.width, p[1] * size.height),
        .3 + p[5] * 1.1,
        Paint()..color = const Color(0xFFDFEDFF).withValues(alpha: alpha),
      );
    }
    // Persistent seeded events keep the loop smooth, with independent lifetimes
    // and cyan/violet trails rather than two identical fixed shooting stars.
    final count = (10 + intensity * 26).round();
    final seconds = t * 12;
    for (var i = 0; i < count; i++) {
      final p = _stormDrops[150 + i];
      final start = (i + p[0] * .65) * 12 / count;
      final age = (seconds - start + 12) % 12;
      final lifetime = .45 + p[1] * .45;
      if (age >= lifetime) continue;
      final alpha = math
          .min(1.0, math.min(age / .12, (lifetime - age) / .2))
          .clamp(0.0, 1.0);
      final speed = 260 + p[2] * 300;
      final velocity = Offset(-speed * .85, speed * .48);
      final head =
          Offset(
            p[3] * (size.width + 140) - 60,
            -35 + p[4] * size.height * .6,
          ) +
          velocity * age;
      final length = 55 + p[5] * 110;
      final tail = head - velocity / velocity.distance * length;
      final thick = .8 + p[6] * 1.5;
      final hue = p[7] < .35 ? 195.0 : 245.0;
      final tint = HSLColor.fromAHSL(1, hue, 1, .8).toColor();
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thick * 5
          ..shader = ui.Gradient.linear(
            tail,
            head,
            [tint.withValues(alpha: 0), tint.withValues(alpha: alpha * .14)],
            const [0, 1],
          ),
      );
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thick * 2
          ..shader = ui.Gradient.linear(
            tail,
            head,
            [
              tint.withValues(alpha: 0),
              tint.withValues(alpha: alpha * .45),
              Colors.white.withValues(alpha: alpha),
            ],
            const [0, .7, 1],
          ),
      );
      _nebulaGlow(canvas, head, thick * 5, tint, alpha * .25);
      canvas.drawCircle(
        head,
        thick * 1.3,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
    canvas.restore();
  }

  void _soulEmbers(Canvas canvas, Size size, double t) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final angle = t * math.pi * 2;
    final count = (70 + intensity * 160).round();
    final scale = math.max(.65, size.width / 850);
    for (var i = 0; i < count; i++) {
      final p = _stormDrops[i];
      final phase = (p[1] + t * (3 + (p[2] * 5 + intensity * 2).round())) % 1;
      final startX = p[7] < .55
          ? size.width * (.73 + p[0] * .18)
          : -20 + p[0] * (size.width + 40);
      final vx = (p[3] - .5) * .68;
      final vy = -(.55 + p[2] * 1.15);
      final age = phase * (80 + p[5] * 130);
      final x =
          startX +
          vx * age * scale +
          math.sin(age * .034 + p[4] * 6.28) * 12 * scale;
      final y =
          size.height * (.78 + p[5] * .30) +
          vy * age * scale -
          age * age * .001 * scale;
      final opacity = math.max(
        0.0,
        math.min(1.0, math.min(phase * 9, (1 - phase) * 1.4)),
      );
      final r = (.65 + p[6] * 2.45) * scale;
      final hue = p[4] > .65
          ? 43.0
          : p[4] > .22
          ? 25.0
          : 10.0;
      Color tint(double lightness, double alpha) =>
          HSLColor.fromAHSL(alpha, hue, 1, lightness).toColor();
      final point = Offset(x, y);
      canvas.drawCircle(
        point,
        r * 7,
        Paint()
          ..shader = RadialGradient(
            colors: [
              tint(.70, opacity * .8),
              tint(.52, opacity * .35),
              tint(.40, 0),
            ],
            stops: const [0, .2, 1],
          ).createShader(Rect.fromCircle(center: point, radius: r * 7)),
      );
      final trail = 5 + p[0] * 17;
      canvas.drawLine(
        point,
        point + Offset(-vx * trail * .45, -vy * trail * .7),
        Paint()
          ..strokeWidth = r * .8
          ..strokeCap = StrokeCap.round
          ..color = tint(.67, opacity * .35),
      );
      canvas.drawCircle(
        point,
        r * .65,
        Paint()
          ..color = HSLColor.fromAHSL(
            opacity,
            hue + 10,
            1,
            p[4] > .65 ? .85 : .65,
          ).toColor(),
      );
    }
    paintBonfireArt(canvas, size, angle, intensity);
    canvas.restore();
  }

  void _storm(Canvas canvas, Size size, double t) {
    canvas.save();
    if (frame) {
      final center = size.center(Offset.zero);
      final radius = size.shortestSide / 2;
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(Rect.fromCircle(center: center, radius: radius))
          ..addOval(Rect.fromCircle(center: center, radius: radius - 7)),
      );
    } else {
      canvas.clipRect(Offset.zero & size);
    }
    final scale = (size.height / 280).clamp(.3, 1.5);
    for (var i = 0; i < 12; i++) {
      final p = _stormDrops[i];
      final radius = (65 + p[2] * 115) * scale;
      final span = size.width + radius * 2;
      final center = Offset(
        (p[0] * span + t * span) % span - radius,
        -20 * scale + p[1] * (size.height * .38 + 20 * scale),
      );
      _nebulaGlow(
        canvas,
        center,
        radius,
        const Color(0xFF97B1D1),
        .018 + p[4] * .052,
      );
    }
    final count = (size.width * .43 * (.4 + intensity * 1.2)).round().clamp(
      24,
      _stormDrops.length,
    );
    final paint = Paint()
      ..strokeWidth = 1.15 * scale
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final p = _stormDrops[i];
      final laps =
          ((340 + p[2] * 430) *
                  scale *
                  12 /
                  (size.height + 60 * scale) *
                  (.65 + intensity * .7))
              .round()
              .clamp(1, 100);
      final y =
          ((p[1] + t * laps) % 1) * (size.height + 60 * scale) - 30 * scale;
      final span = size.width + 60 * scale;
      final x = ((p[0] - t) % 1) * span - 30 * scale;
      final length = (9 + p[3] * 15) * scale;
      paint.color = const Color(0xFFAACFF8).withValues(alpha: .12 + p[4] * .48);
      canvas.drawLine(Offset(x, y), Offset(x - 4 * scale, y + length), paint);
    }
    // Irregular, brief strikes; their frequency is independent of the rain speed.
    // At paused time zero no flash is drawn, including reduced-motion mode.
    final strikes = 3 + (intensity * 3).round();
    final seconds = t * 12;
    for (var strike = 0; strike < strikes; strike++) {
      final seed = _stormDrops[200 + strike];
      final start = (strike + .25 + seed[0] * .35) * 12 / strikes;
      final age = seconds - start;
      if (age < 0 || age > .28) continue;
      final life = 1 - age / .28;
      final alpha = math.min(1.0, life * 1.8);
      final endY = size.height * (.55 + seed[1] * .39);
      final segments = (endY / (24 * scale)).ceil().clamp(4, 28);
      var point = Offset(size.width * (.12 + seed[2] * .76), -8 * scale);
      final main = Path()..moveTo(point.dx, point.dy);
      final branches = Path();
      for (var k = 0; k < segments; k++) {
        final p = _stormDrops[(strike * 31 + k + 40) % _stormDrops.length];
        point = Offset(
          point.dx + (p[0] - .5) * 64 * scale,
          -8 * scale + (endY + 8 * scale) * (k + 1) / segments,
        );
        main.lineTo(point.dx, point.dy);
        if (k > 1 && k < segments - 1 && p[4] < .23) {
          var branch = point;
          branches.moveTo(branch.dx, branch.dy);
          for (var j = 0; j < 2 + (p[5] * 3).round(); j++) {
            final b =
                _stormDrops[(strike * 43 + k * 5 + j + 100) %
                    _stormDrops.length];
            branch += Offset(
              (b[0] - .5) * 68 * scale,
              (12 + b[1] * 15) * scale,
            );
            branches.lineTo(branch.dx, branch.dy);
          }
        }
      }
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        main,
        glow
          ..strokeWidth = 18 * scale
          ..color = const Color(0xFF64B0FF).withValues(alpha: alpha * .06),
      );
      canvas.drawPath(
        main,
        glow
          ..strokeWidth = 10 * scale
          ..color = const Color(0xFF64B0FF).withValues(alpha: alpha * .22),
      );
      canvas.drawPath(
        main,
        glow
          ..strokeWidth = 3 * scale
          ..color = const Color(0xFF80C6FF).withValues(alpha: alpha * .9),
      );
      canvas.drawPath(
        main,
        glow
          ..strokeWidth = 1.2 * scale
          ..color = Colors.white.withValues(alpha: alpha),
      );
      canvas.drawPath(
        branches,
        glow
          ..strokeWidth = 1.1 * scale
          ..color = const Color(0xFFABD8FF).withValues(alpha: alpha * .7),
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(
            0xFFBDDAFF,
          ).withValues(alpha: (.35 + seed[3] * .4) * life * .23),
      );
    }
    canvas.restore();
  }

  void _nebulaGlow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  // Transparent adaptation of the supplied founder artwork, without its sample
  // city background, avatar or any additional profile decorations.
  void _nebula(Canvas canvas, Size size, double t) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final angle = t * math.pi * 2;
    final strength = .65 + intensity * .7;
    final scale = (size.height / 230).clamp(.5, 1.5);
    if (variant == 'astral') {
      for (var j = 0; j < 7; j++) {
        final x0 =
            size.width * (.09 + j * .145) +
            math.sin(angle + j * 1.7) * size.width * .035;
        final path = Path();
        for (var k = 0; k <= 32; k++) {
          final y = size.height * k / 32;
          final x =
              x0 +
              math.sin(k * .32 + angle + j) * size.width * .026 +
              math.sin(k * .12 - angle + j) * size.width * .015;
          if (k == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        final tint = j.isOdd
            ? const Color(0xFF12F0DF)
            : const Color(0xFF3091FF);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * .10
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                tint.withValues(alpha: 0),
                tint.withValues(alpha: .18 * strength),
                tint.withValues(alpha: .08 * strength),
                tint.withValues(alpha: 0),
              ],
              stops: const [0, .28, .68, 1],
            ).createShader(Offset.zero & size),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color =
                (j.isOdd ? const Color(0xFF8BFFE6) : const Color(0xFF82C9FF))
                    .withValues(alpha: .32 * strength),
        );
      }
      for (var arc = 0; arc < 3; arc++) {
        final path = Path();
        for (var k = 0; k <= 22; k++) {
          final q = k / 22;
          final x =
              size.width * (.16 + arc * .30) +
              math.sin(q * 8 + angle + arc) * size.width * .065 +
              math.sin(k * 3.9 + arc * 11) * size.width * .007;
          final y = size.height * (.08 + q * .82);
          if (k == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = arc == 1 ? 1.6 : 1
            ..color =
                (arc == 1 ? const Color(0xFFE2FFFF) : const Color(0xFF37FBE7))
                    .withValues(
                      alpha:
                          (.35 + .20 * math.pow(math.sin(angle + arc), 2)) *
                          strength,
                    ),
        );
      }
      _nebulaGlow(
        canvas,
        Offset(size.width * (.5 + math.sin(angle) * .08), size.height * .48),
        size.width * .19,
        const Color(0xFF0AFBD7),
        .085 * strength,
      );
      final count = (60 + intensity * 100).round().clamp(
        0,
        _weatherParticles.length,
      );
      for (var i = 0; i < count; i++) {
        final p = _weatherParticles[i];
        final x =
            (p[0] * size.width + math.sin(angle + i) * 8 + size.width) %
            size.width;
        final y = ((p[1] - t * (1 + (p[2] * 3).round())) % 1) * size.height;
        final tint = i % 4 == 0
            ? const Color(0xFFE9FFFF)
            : i % 3 == 0
            ? const Color(0xFF35F9BA)
            : const Color(0xFF49BFFF);
        canvas.drawCircle(
          Offset(x, y),
          (.5 + p[4] * 1.2) * scale,
          Paint()
            ..color = tint.withValues(
              alpha: .22 + .55 * (.5 + .5 * math.sin(angle + i)),
            ),
        );
      }
    } else {
      final palette = variant == 'eclipse'
          ? const [
              Color(0xFFFF9B45),
              Color(0xFFE34CBA),
              Color(0xFF793BFF),
              Color(0xFFFFE3A1),
            ]
          : const [
              Color(0xFFB779FF),
              Color(0xFF664DFF),
              Color(0xFF47E5FF),
              Color(0xFFFF6FD9),
            ];
      for (var j = 0; j < 5; j++) {
        final center = Offset(
          size.width * (.13 + j * .19 + math.sin(angle + j * 1.8) * .07),
          size.height * (.27 + .12 * math.sin(j * 2.3 + angle)),
        );
        _nebulaGlow(
          canvas,
          center,
          math.max(size.width, size.height) * (.18 + .04 * math.sin(j + angle)),
          palette[j % 4],
          .065 * strength,
        );
      }
      for (var layer = 0; layer < 3; layer++) {
        final path = Path();
        final phase = angle + layer * 2.2;
        for (var i = 0; i <= 64; i++) {
          final x = size.width * i / 64;
          final y =
              size.height * (.32 + layer * .17) +
              math.sin(x / size.width * 11 + phase) *
                  size.height *
                  (.09 + layer * .015) +
              math.sin(x / size.width * 22 - phase) * size.height * .026;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (16 + layer * 5) * scale
            ..color = palette[layer].withValues(alpha: .12 * strength),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25
            ..color = palette[layer].withValues(alpha: .32 * strength),
        );
      }
      final count = (45 + intensity * 80).round().clamp(
        0,
        _weatherParticles.length,
      );
      for (var i = 0; i < count; i++) {
        final p = _weatherParticles[i];
        final phase = p[3] * math.pi * 2;
        final point = Offset(
          (p[0] * size.width +
                  math.sin(angle + phase) * 9 * (.3 + p[2]) +
                  size.width) %
              size.width,
          (p[1] * size.height - math.cos(angle + phase) * 4 + size.height) %
              size.height,
        );
        final twinkle =
            .5 + .5 * math.sin(angle * (1 + (p[2] * 2).round()) + phase);
        final tint = i % 5 == 0 ? palette[2] : Colors.white;
        canvas.drawCircle(
          point,
          (.4 + p[4] * 1.2) * (.6 + twinkle * .4) * scale,
          Paint()..color = tint.withValues(alpha: .12 + .55 * twinkle),
        );
        if (i % 17 == 0 && twinkle > .85) {
          _star(canvas, point, 4 * scale, palette[i % 4].withValues(alpha: .6));
        }
      }
      _nebulaGlow(
        canvas,
        Offset(size.width * (.72 + .02 * math.sin(angle)), size.height * .28),
        size.width * .17,
        palette[2],
        .06 * strength,
      );
    }
    canvas.restore();
  }

  // Canvas-only adaptation of the supplied cover demo. The real cover image
  // remains below this transparent, clipped decoration; no sample background.
  void _themedCover(Canvas canvas, Size size, double t) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final angle = t * math.pi * 2;
    final scale = (size.height / 230).clamp(.5, 1.5);
    if (effect == 'christmas') {
      const lights = [
        Color(0xFFFF555E),
        Color(0xFFF7E56C),
        Color(0xFF6CFFAD),
        Color(0xFF88CCFF),
      ];
      for (var i = 0; i < 11; i++) {
        final x = (i + .5) * size.width / 11;
        final y = (14 + math.sin(i * .9) * 8) * scale;
        canvas.drawLine(
          Offset(i * size.width / 11, 0),
          Offset(x, y),
          Paint()
            ..color = const Color(0xFF5D6B79)
            ..strokeWidth = 1,
        );
        final alpha = .65 + .35 * math.sin(angle * 2 + i);
        final color = lights[i % lights.length];
        final point = Offset(x, y);
        final glowRadius = 12 * scale;
        canvas.drawCircle(
          point,
          glowRadius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: alpha * .45),
                color.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: point, radius: glowRadius)),
        );
        canvas.drawCircle(
          point,
          4.5 * scale,
          Paint()..color = color.withValues(alpha: alpha),
        );
      }
      _christmasTree(canvas, size, angle);
      final count = (40 + intensity * 90).round().clamp(
        0,
        _weatherParticles.length,
      );
      for (var i = 0; i < count; i++) {
        final p = _weatherParticles[i];
        final phase = (p[1] + t * (1 + (p[2] * 2).round())) % 1;
        final x =
            p[0] * size.width + math.sin(angle * 3 + p[3] * 7) * 7 * scale;
        final y = phase * (size.height + 30) - 15;
        canvas.drawCircle(
          Offset(x, y),
          (1.1 + p[4] * 2.7) * scale,
          Paint()..color = const Color(0xFFF2F9FF).withValues(alpha: .65),
        );
      }
    } else {
      final fogBounds = Rect.fromLTRB(
        0,
        size.height * .55,
        size.width,
        size.height,
      );
      canvas.drawRect(
        fogBounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00764D9A), Color(0x4DB58EE3)],
          ).createShader(fogBounds),
      );
      canvas.drawCircle(
        Offset(size.width * .85, size.height * .23),
        25 * scale,
        Paint()..color = const Color(0xFFF4A64C).withValues(alpha: .5),
      );
      final count = (16 + intensity * 32).round();
      for (var i = 0; i < count; i++) {
        final p = _weatherParticles[i];
        final radius = (4 + p[4] * 8) * scale;
        final span = size.width + radius * 6;
        final x =
            ((p[0] + t * (1 + (p[2] * 2).round())) % 1) * span - radius * 3;
        if (p[7] >= .7) {
          final point = Offset(
            x,
            size.height * .85 + math.sin(angle + p[3] * 7) * 10 * scale,
          );
          final bounds = Rect.fromCenter(
            center: point,
            width: radius * 10,
            height: radius * 4,
          );
          canvas.drawOval(
            bounds,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  const Color(0xFF9B7EB3).withValues(alpha: .12),
                  const Color(0xFF9B7EB3).withValues(alpha: 0),
                ],
              ).createShader(bounds),
          );
          continue;
        }
        final y =
            size.height * (.12 + p[1] * .65) +
            math.sin(angle * 4 + p[3] * 7) * 3 * scale;
        final wing = math.sin(angle * 12 + p[3] * 7) * radius * .5;
        canvas.save();
        canvas.translate(x, y);
        final bat = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-radius, -radius - wing, -radius * 2, 0)
          ..quadraticBezierTo(-radius, -radius * .1, 0, radius * .25)
          ..quadraticBezierTo(radius, -radius * .1, radius * 2, 0)
          ..quadraticBezierTo(radius, -radius - wing, 0, 0)
          ..close();
        canvas.drawPath(bat, Paint()..color = const Color(0xFF120D24));
        canvas.restore();
      }
    }
    canvas.restore();
  }

  void _christmasTree(Canvas canvas, Size size, double angle) {
    final scale = math.min(1.0, math.min(size.width / 540, size.height / 230));
    canvas.save();
    canvas.translate(size.width - 52 * scale, size.height - 12 * scale);
    canvas.scale(scale);
    canvas.drawRect(
      const Rect.fromLTWH(-5, -26, 10, 25),
      Paint()..color = const Color(0xFF54351D),
    );
    const greens = [Color(0xFF075C3E), Color(0xFF08754B), Color(0xFF0B6843)];
    for (var k = 0; k < 3; k++) {
      final y = -119.0 + k * 31;
      final half = 29.0 + k * 12;
      final branch = Path()
        ..moveTo(0, y)
        ..lineTo(-half, y + 61)
        ..quadraticBezierTo(0, y + 53, half, y + 61)
        ..close();
      canvas.drawPath(branch, Paint()..color = greens[k]);
    }
    const ornaments = [
      Color(0xFFFFDC6D),
      Color(0xFFFF617E),
      Color(0xFF78D9FF),
      Color(0xFFF5F4FF),
    ];
    for (var i = 0; i < 19; i++) {
      final y = -99.0 + (i % 5) * 17 + (i ~/ 5) * 3;
      final spread = (y + 122) * .35;
      final point = Offset(math.sin(i * 2.4) * spread, y);
      final color = ornaments[i % 4];
      final alpha = .55 + .45 * math.sin(angle * 3 + i * 1.7);
      canvas.drawCircle(
        point,
        9,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha * .4),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: point, radius: 9)),
      );
      canvas.drawCircle(
        point,
        2.5,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
    const starCenter = Offset(0, -125);
    canvas.drawCircle(
      starCenter,
      20,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFDC67).withValues(alpha: .3),
            const Color(0x00FFDC67),
          ],
        ).createShader(Rect.fromCircle(center: starCenter, radius: 20)),
    );
    final star = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final r = i.isOdd ? 2.2 : 11.0;
      final p = starCenter + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(star..close(), Paint()..color = const Color(0xFFFFDF77));
    const gifts = [
      (-35.0, -16.0, 25.0, 20.0, Color(0xFFE74B68), Color(0xFFFFE1A0)),
      (-8.0, -12.0, 22.0, 16.0, Color(0xFF557EF0), Color(0xFFF4CF74)),
      (20.0, -20.0, 27.0, 24.0, Color(0xFFB66AF0), Color(0xFFFFE5A3)),
    ];
    for (final (x, y, w, h, color, ribbon) in gifts) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = color);
      final paint = Paint()..color = ribbon;
      canvas.drawRect(Rect.fromLTWH(x + w * .43, y, w * .14, h), paint);
      canvas.drawRect(Rect.fromLTWH(x, y + h * .4, w, 3), paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final tilt in [-.4, .4]) {
        canvas.save();
        canvas.translate(x + w * .5, y - 3);
        canvas.rotate(tilt);
        canvas.drawOval(const Rect.fromLTWH(-6, -3, 12, 6), paint);
        canvas.restore();
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
      oldDelegate.variant != variant ||
      oldDelegate.motion != motion;
}
