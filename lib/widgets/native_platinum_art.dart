import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Original trophy artwork in two fixed layers. Flutter owns every clock and
/// transform, including the one-shot reveal, so WebView timing cannot drift.
class NativePlatinumArt extends StatefulWidget {
  const NativePlatinumArt({
    super.key,
    required this.size,
    this.celebrate = false,
    this.onAnimationStarted,
    this.ruby = false,
  });
  final double size;
  final bool ruby;
  final bool celebrate;
  final VoidCallback? onAnimationStarted;
  static Future<List<ui.Image>>? _layers;
  static List<ui.Image>? _decodedLayers;
  static Future<List<ui.Image>>? _rubyLayers;
  static List<ui.Image>? _decodedRuby;
  static Future<List<ui.Image>> preloadRuby() => _rubyLayers ??=
      Future.wait([
        _decode('assets/images/ruby_frame.png'),
        _decode('assets/images/ruby_cup.png'),
      ]).then((layers) {
        _decodedRuby = layers;
        return layers;
      });
  static Future<List<ui.Image>> preload() => _layers ??=
      Future.wait([
        for (final asset in [
          'assets/images/platinum_frame.png',
          'assets/images/platinum_cup.png',
        ])
          _decode(asset),
      ]).then((layers) {
        _decodedLayers = layers;
        return layers;
      });
  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  @override
  State<NativePlatinumArt> createState() => _NativePlatinumArtState();
}

class _NativePlatinumArtState extends State<NativePlatinumArt>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // All ambient periods divide 5040s, keeping the repeat boundary continuous.
  late final _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5040),
  );
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );
  late final _repaint = Listenable.merge([_ambient, _intro]);
  List<ui.Image>? _layers;
  ScrollPosition? _scroll;
  bool _failed = false, _scheduled = false, _reported = false;
  bool _enabled = false, _reduced = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    _intro.addListener(_reportVisibleReveal);
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final cached = widget.ruby
        ? NativePlatinumArt._decodedRuby
        : NativePlatinumArt._decodedLayers;
    if (cached != null) {
      _layers = cached;
      return;
    }
    (widget.ruby
            ? NativePlatinumArt.preloadRuby()
            : NativePlatinumArt.preload())
        .then(
          (layers) {
            if (!mounted) return;
            setState(() => _layers = layers);
            _checkVisibility();
          },
          onError: (Object error) {
            if (mounted) setState(() => _failed = true);
          },
        );
  }

  void _reportVisibleReveal() {
    // The artwork is invisible for the first 12% of its 4.8s reveal.
    // Follow the animation clock so pauses also postpone the sound.
    if (!_reported &&
        widget.celebrate &&
        !_reduced &&
        _intro.value * 5.2 > .12 * 4.8) {
      _reported = true;
      widget.onAnimationStarted?.call();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _enabled =
        !_reduced &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_checkVisibility);
      _scroll = scroll;
      _scroll?.addListener(_checkVisibility);
    }
    if (!_enabled) {
      _ambient.stop();
      _intro.stop();
    }
    _checkVisibility();
  }

  @override
  void didUpdateWidget(covariant NativePlatinumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.celebrate != oldWidget.celebrate) {
      _intro.value = 0;
      _reported = false;
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
      final view = View.of(context);
      final visible =
          box is RenderBox &&
          box.attached &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).overlaps(
            Offset.zero & (view.physicalSize / view.devicePixelRatio),
          );
      if (_layers != null && _enabled && _foreground && visible) {
        if (!_ambient.isAnimating) _ambient.repeat();
        if (widget.celebrate && !_intro.isCompleted && !_intro.isAnimating) {
          _intro.forward();
        }
      } else {
        _ambient.stop();
        _intro.stop();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _ambient.stop();
      _intro.stop();
    }
    _checkVisibility();
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkVisibility);
    WidgetsBinding.instance.removeObserver(this);
    _ambient.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layers = _layers;
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: layers == null && !_failed && widget.celebrate && !_reduced
            ? const ColoredBox(color: Color(0xFF050D1C))
            : _failed || layers == null
            ? Image.asset(
                widget.ruby
                    ? 'assets/images/trofeu_rubi_pbh.png'
                    : 'assets/images/trofeu_platina_pbh.png',
                fit: BoxFit.contain,
              )
            : CustomPaint(
                painter: NativePlatinumPainter(
                  ruby: widget.ruby,
                  frame: layers[0],
                  cup: layers[1],
                  ambient: _ambient,
                  intro: _intro,
                  repaint: _repaint,
                  celebrate: widget.celebrate,
                  reduced: _reduced,
                ),
              ),
      ),
    );
  }
}

class NativePlatinumPainter extends CustomPainter {
  NativePlatinumPainter({
    required this.frame,
    required this.cup,
    required this.ambient,
    required this.intro,
    required Listenable repaint,
    required this.celebrate,
    required this.reduced,
    this.ruby = false,
  }) : super(repaint: repaint);
  final ui.Image frame, cup;
  final Animation<double> ambient, intro;
  final bool celebrate, reduced;
  final bool ruby;
  Color get light => ruby ? const Color(0xFFFFB2BF) : const Color(0xFFD4F6FF);
  Color get sparkle => ruby ? const Color(0xFFFF7894) : const Color(0xFFB6EAFF);
  static final _particles = (() {
    final random = math.Random(285600);
    return List.generate(
      120,
      (_) => List.generate(6, (_) => random.nextDouble(), growable: false),
      growable: false,
    );
  })();
  static final _inner = Path()
    ..moveTo(300, 72)
    ..lineTo(497, 186)
    ..lineTo(497, 414)
    ..lineTo(300, 528)
    ..lineTo(103, 414)
    ..lineTo(103, 186)
    ..close();
  static const _bounds = Rect.fromLTWH(0, 0, 600, 600);
  double get revealSeconds => reduced || !celebrate ? 5.2 : intro.value * 5.2;
  double _between(double value, double start, double end) =>
      ((value - start) / (end - start)).clamp(0.0, 1.0);
  double _scale(double v) {
    if (v < .12) return .55;
    if (v < .30)
      return ui.lerpDouble(
        .55,
        1.09,
        Curves.easeOutCubic.transform(_between(v, .12, .30)),
      )!;
    if (v < .44) return ui.lerpDouble(1.09, .97, _between(v, .30, .44))!;
    return ui.lerpDouble(.97, 1, _between(v, .44, .60))!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = reduced ? 0.0 : ambient.value * 5040;
    final seconds = revealSeconds;
    final revealing = celebrate && !reduced && seconds < 5.2;
    final progress = seconds / 4.8;
    final opacity = revealing ? _between(progress, .12, .30) : 1.0;
    final compact = size.shortestSide < 80;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 600, size.height / 600);
    canvas.drawRect(
      _bounds,
      Paint()..color = ruby ? const Color(0xFF11040A) : const Color(0xFF050D1C),
    );
    canvas.save();
    if (revealing) {
      canvas.translate(300, 300);
      canvas.scale(_scale(progress));
      canvas.translate(-300, -300);
    }
    paint.color = Colors.white.withValues(alpha: opacity);
    canvas.drawImageRect(
      frame,
      Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
      _bounds,
      paint,
    );
    canvas.save();
    canvas.clipPath(_inner);
    if (!compact) {
      canvas.save();
      canvas.translate(300, 285);
      canvas.rotate(time * math.pi * 2 / 70);
      final beamPaint = Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 260, [
          light.withValues(alpha: .35 * opacity),
          light.withValues(alpha: 0),
        ]);
      for (var i = 0; i < 12; i++) {
        final angle = i * math.pi / 6;
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(260 * math.cos(angle - .1), 260 * math.sin(angle - .1))
            ..lineTo(260 * math.cos(angle + .1), 260 * math.sin(angle + .1))
            ..close(),
          beamPaint,
        );
      }
      canvas.restore();
      for (var i = 0; i < 2; i++) {
        final phase = (time / 3.2 + i * .5) % 1;
        canvas.drawCircle(
          const Offset(300, 285),
          60 * (.45 + phase * 2.85),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = light.withValues(alpha: (1 - phase) * .6 * opacity),
        );
      }
    }
    for (var i = 0; i < (compact ? 8 : 30); i++) {
      final p = _particles[i];
      final phase = (time / (5 + p[4] * 6) + p[5]) % 1;
      canvas.drawCircle(
        Offset(130 + p[0] * 340, 430 + p[1] * 90 - phase * 360),
        1 + p[2] * 2.2,
        Paint()
          ..color = sparkle.withValues(
            alpha: math.sin(phase * math.pi) * .8 * opacity,
          ),
      );
    }
    canvas.restore();
    final float = reduced ? 0.0 : -3.5 + 3.5 * math.cos(time * math.pi * 2 / 5);
    final cupOffset = revealing
        ? ui.lerpDouble(
            70,
            0,
            Curves.easeOutCubic.transform(_between(progress, .16, .46)),
          )!
        : float;
    canvas.save();
    canvas.translate(0, cupOffset);
    final cupOpacity =
        opacity * (revealing ? _between(progress, .16, .31) : 1.0);
    paint.color = Colors.white.withValues(alpha: cupOpacity);
    canvas.drawImageRect(
      cup,
      Rect.fromLTWH(0, 0, cup.width.toDouble(), cup.height.toDouble()),
      _bounds,
      paint,
    );
    canvas.restore();
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = sparkle.withValues(alpha: .5 * opacity);
    final segments = compact ? 36 : 120;
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        const Rect.fromLTWH(13, 13, 574, 574),
        i * math.pi * 2 / segments + time * math.pi * 2 / 90,
        .012,
        false,
        ringPaint,
      );
    }
    canvas.restore();
    if (revealing && seconds > .8) {
      final elapsed = seconds - .8;
      for (var i = 0; i < 3; i++) {
        final radius = elapsed * 130 - i * 46;
        if (radius > 0 && radius < 500)
          canvas.drawCircle(
            const Offset(300, 290),
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 - i * .6
              ..color = sparkle.withValues(
                alpha: (.6 - radius / 550).clamp(0.0, 1.0),
              ),
          );
      }
      for (var i = 0; i < (compact ? 12 : 100); i++) {
        final p = _particles[i];
        final life = 1.2 + p[3] * 1.6;
        if (elapsed >= life) continue;
        final angle = p[0] * math.pi * 2, speed = 70 + p[1] * 210;
        final position = Offset(
          300 + math.cos(angle) * speed * elapsed,
          290 + math.sin(angle) * speed * elapsed + 18 * elapsed * elapsed,
        );
        canvas.drawCircle(
          position,
          .7 + p[2] * 2.5,
          Paint()
            ..color = light.withValues(
              alpha: (1 - elapsed / life) * _between(elapsed, 0, .2),
            ),
        );
      }
    }
    if (revealing) {
      final flash = progress < .22
          ? 0.0
          : progress < .28
          ? .92 * _between(progress, .22, .28)
          : progress < .38
          ? .92 * (1 - _between(progress, .28, .38))
          : 0.0;
      if (flash > 0)
        canvas.drawRect(
          _bounds,
          Paint()
            ..shader = ui.Gradient.radial(const Offset(300, 300), 390, [
              Colors.white.withValues(alpha: flash),
              const Color(0x0072DCFF),
            ]),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NativePlatinumPainter oldDelegate) =>
      oldDelegate.ruby != ruby ||
      oldDelegate.frame != frame ||
      oldDelegate.cup != cup ||
      oldDelegate.celebrate != celebrate ||
      oldDelegate.reduced != reduced ||
      oldDelegate.ambient != ambient ||
      oldDelegate.intro != intro;
}
