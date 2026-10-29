import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Native SVG adaptation of molduras_animadas_pbh.html. Coordinates share the
/// supplied 240px reference; the central 82px radius is never painted.
void paintLegendaryFrame(
  Canvas c,
  Size size,
  double phase,
  double intensity,
  String effect,
) {
  if (size.isEmpty) return;
  const center = Offset(120, 120);
  final angle = phase * math.pi * 2;
  final power = .65 + intensity * .35;
  c.save();
  c.clipRect(Offset.zero & size);
  c.scale(size.width / 240, size.height / 240);
  c.clipPath(
    Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(const Rect.fromLTWH(0, 0, 240, 240))
      ..addOval(Rect.fromCircle(center: center, radius: 82)),
  );
  void circle(double radius, Color color, double width) => c.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color,
  );
  ui.Shader metal(List<Color> colors, List<double> stops) => ui.Gradient.linear(
    const Offset(40, 40),
    const Offset(200, 200),
    colors,
    stops,
  );
  void ring(ui.Shader shader, double width) => c.drawCircle(
    center,
    90,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = shader,
  );
  void dashRing(
    double radius,
    int count,
    double arc,
    Color color,
    double width,
    double rotation,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < count; i++) {
      c.drawArc(
        rect,
        rotation + i * math.pi * 2 / count,
        arc,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color,
      );
    }
  }

  if (effect == 'knowledge_orbit') {
    circle(91, const Color(0xFF36204C), 17);
    circle(89, const Color(0x44A45AFF), 8);
    circle(89, const Color(0xFFA45AFF), 3);
    dashRing(
      104,
      50,
      .029,
      const Color(0xFFBC7BFF).withValues(alpha: power),
      1.4,
      angle * .5,
    );
    final bounds = Rect.fromCircle(center: center, radius: 97);
    for (var i = 0; i < 24; i++) {
      c.drawArc(
        bounds,
        angle * .5 + i * math.pi / 12,
        i.isEven ? .24 : .021,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFBC7BFF).withValues(alpha: power * .7),
      );
    }
    for (var i = 0; i < 4; i++) {
      c.save();
      c.translate(120, 120);
      c.rotate(i * math.pi / 2);
      c.drawPath(
        Path()
          ..moveTo(0, -109)
          ..lineTo(13, -91)
          ..lineTo(0, -78)
          ..lineTo(-13, -91)
          ..close(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF7D43B6),
      );
      c.restore();
    }
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6,
          p = center + Offset(math.cos(a), math.sin(a)) * 94;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD0A4FF).withValues(
          alpha:
              (.35 + .65 * (.5 + .5 * math.sin(angle * 4 + i * math.pi / 2))) *
              power,
        );
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a + math.pi / 2);
      final rune = Path();
      switch (i % 4) {
        case 0:
          rune
            ..moveTo(0, -5)
            ..lineTo(1.5, -1.5)
            ..lineTo(5, 0)
            ..lineTo(1.5, 1.5)
            ..lineTo(0, 5)
            ..lineTo(-1.5, 1.5)
            ..lineTo(-5, 0)
            ..lineTo(-1.5, -1.5)
            ..close();
        case 1:
          rune
            ..moveTo(0, -5)
            ..lineTo(4, 0)
            ..lineTo(0, 4)
            ..lineTo(-4, 0)
            ..close()
            ..moveTo(-4, 5)
            ..lineTo(0, 2)
            ..lineTo(4, 5);
        case 2:
          rune
            ..moveTo(-4, -4)
            ..lineTo(4, 4)
            ..moveTo(4, -4)
            ..lineTo(-4, 4);
        default:
          rune
            ..moveTo(0, 5)
            ..lineTo(0, -5)
            ..lineTo(4, -1)
            ..moveTo(0, 0)
            ..lineTo(4, 3);
      }
      c.drawPath(rune, paint);
      c.restore();
    }
  } else if (effect == 'journey_crown') {
    final gold = metal(
      const [
        Color(0xFFFFF2B0),
        Color(0xFFAE7231),
        Color(0xFFF9D983),
        Color(0xFF6B401E),
      ],
      const [0, .3, .58, 1],
    );
    circle(90, const Color(0xFF3E2C20), 16);
    ring(gold, 10);
    circle(96, const Color(0xFFEAC479), 1.5);
    final pulse = (.55 + .45 * (.5 + .5 * math.cos(angle * 4))) * power;
    for (var side = 0; side < 2; side++) {
      for (var i = 0; i < 9; i++) {
        final a = (side == 0 ? 145 + i * 12 : 35 - i * 12) * math.pi / 180;
        final p = center + Offset(math.cos(a), math.sin(a)) * 104;
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate((side == 0 ? i * 12 + 55 : -i * 12 - 55) * math.pi / 180);
        c.drawOval(
          const Rect.fromLTWH(-5, -11, 10, 22),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFE4B963).withValues(alpha: pulse),
        );
        c.restore();
      }
    }
    final crown = Path()
      ..moveTo(91, 34)
      ..lineTo(85, 12)
      ..lineTo(106, 23)
      ..lineTo(120, 3)
      ..lineTo(134, 23)
      ..lineTo(155, 12)
      ..lineTo(149, 34)
      ..close();
    c.drawPath(crown, Paint()..shader = gold);
    c.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFFF0AD),
    );
    c.drawLine(
      const Offset(91, 35),
      const Offset(149, 35),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6
        ..color = const Color(0xFFFFE6A0),
    );
    c.drawCircle(
      const Offset(120, 19),
      5,
      Paint()
        ..color = const Color(
          0xFFFFF3B7,
        ).withValues(alpha: (.45 + .55 * math.sin(angle * 4).abs()) * power),
    );
  } else if (effect == 'platinum_iron') {
    circle(92, const Color(0xFF120E12), 20);
    ring(
      metal(
        const [
          Color(0xFF8A8994),
          Color(0xFF292A35),
          Color(0xFF53515A),
          Color(0xFF16151D),
        ],
        const [0, .4, .7, 1],
      ),
      13,
    );
    dashRing(
      96,
      17,
      .094,
      const Color(0xFFE15D32).withValues(alpha: power),
      2,
      0,
    );
    const cracks = [
      [Offset(48, 54), Offset(63, 62), Offset(59, 79), Offset(71, 88)],
      [Offset(180, 48), Offset(173, 64), Offset(188, 73), Offset(179, 89)],
      [Offset(48, 181), Offset(62, 173), Offset(73, 188)],
      [Offset(185, 179), Offset(173, 167), Offset(183, 152)],
    ];
    for (final crack in cracks) {
      final path = Path();
      for (var i = 0; i < crack.length; i++) {
        final delta = crack[i] - center;
        final point = delta.distance < 84
            ? center + delta / delta.distance * 84
            : crack[i];
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(
            0xFFFF7E37,
          ).withValues(alpha: (.55 + .45 * math.sin(angle * 4).abs()) * power),
      );
    }
    for (var i = 0; i < 18; i++) {
      final a = i * 2.4, r = 86.0 + (i % 4) * 4, p = (phase * 4 + i * .077) % 1;
      final point =
          center + Offset(math.cos(a), math.sin(a)) * r + Offset(0, 7 - 25 * p);
      c.drawCircle(
        point,
        (i % 3 == 0 ? 2.4 : 1.3) * (.6 + p * .55),
        Paint()
          ..color =
              (i.isEven ? const Color(0xFFF45B29) : const Color(0xFFFFB35D))
                  .withValues(alpha: math.sin(p * math.pi) * power),
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * 89,
        2.5,
        Paint()..color = const Color(0xFFA3A0A5),
      );
    }
  } else {
    circle(90, const Color(0xFF273C52), 16);
    ring(
      metal(
        const [
          Color(0xFFEFF4FF),
          Color(0xFF667188),
          Color(0xFFE2E5F2),
          Color(0xFF343E58),
          Color(0xFFC6CDDD),
        ],
        const [0, .26, .52, .78, 1],
      ),
      9,
    );
    final pulse = .55 + .45 * (.5 + .5 * math.cos(angle * 3));
    dashRing(
      100,
      18,
      .22,
      const Color(0xFF82D6FF).withValues(alpha: pulse * power),
      2,
      0,
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6,
          p = center + Offset(math.cos(a), math.sin(a)) * 100;
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a + math.pi / 2);
      c.scale(1 + .035 * math.sin(angle * 3));
      final crystal = Path()
        ..moveTo(0, -17)
        ..lineTo(9, 0)
        ..lineTo(0, 14)
        ..lineTo(-9, 0)
        ..close();
      c.drawPath(
        crystal,
        Paint()
          ..color =
              (i.isEven ? const Color(0xFF6A9EC9) : const Color(0xFFBDEFFF))
                  .withValues(alpha: (.65 + .2 * pulse) * power),
      );
      c.drawPath(
        crystal,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFE5F8FF).withValues(alpha: power),
      );
      c.restore();
    }
    c.drawPath(
      Path()
        ..moveTo(120, 12)
        ..lineTo(125, 28)
        ..lineTo(120, 43)
        ..lineTo(115, 28)
        ..close(),
      Paint()
        ..color = const Color(
          0xFFF3FCFF,
        ).withValues(alpha: (.35 + .65 * math.sin(angle * 4).abs()) * power),
    );
  }
  c.restore();
}
