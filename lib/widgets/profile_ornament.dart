import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Paint-only decoration: the image and profile text never rebuild on a tick.
class ProfileOrnament extends StatefulWidget {
  const ProfileOrnament({
    super.key,
    required this.color,
    this.frame = false,
    this.founder = false,
  });
  final Color color;
  final bool frame;
  final bool founder;
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
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _OrnamentPainter extends CustomPainter {
  _OrnamentPainter(this.motion, this.color, this.frame, this.founder)
    : super(repaint: motion);
  final Animation<double> motion;
  final Color color;
  final bool frame;
  final bool founder;
  @override
  void paint(Canvas canvas, Size size) {
    final t = motion.value;
    if (frame) {
      final center = size.center(Offset.zero);
      final radius = size.shortestSide / 2 - 1.8;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final angle = t * math.pi * 2;
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
    if (founder) {
      _meteor(canvas, size, t, .09, .19, .88);
      _meteor(canvas, size, t, .65, .74, .55);
    } else {
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
      oldDelegate.motion != motion;
}
