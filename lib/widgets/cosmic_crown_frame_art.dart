import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Native rendering of moldura_coroa_cosmica_pbh.html, with a clear avatar.
void paintCosmicCrownFrame(
  Canvas c,
  Size size,
  double phase,
  double intensity,
) {
  if (size.isEmpty) return;
  const center = Offset(200, 200);
  final t = phase * math.pi * 2, power = .5 + intensity * .5;
  c.save();
  c.clipRect(Offset.zero & size);
  c.scale(size.width / 400, size.height / 400);
  c.clipPath(
    Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(const Rect.fromLTWH(0, 0, 400, 400))
      ..addOval(Rect.fromCircle(center: center, radius: 103)),
  );
  void glow(Offset p, double r, Color color, double alpha) => c.drawCircle(
    p,
    r,
    Paint()
      ..shader = ui.Gradient.radial(p, r, [
        color.withValues(alpha: alpha * power),
        color.withValues(alpha: 0),
      ]),
  );
  final breath = .5 - .5 * math.cos(t * 3), radius = 111 * (1 + .035 * breath);
  c.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = const Color(
        0xFF7843C7,
      ).withValues(alpha: (.18 - .08 * breath) * power),
  );
  c.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = ui.Gradient.linear(
        const Offset(90, 90),
        const Offset(310, 310),
        const [Color(0xFF7653B9), Color(0xFFE7CCFF), Color(0xFF7653B9)],
        const [0, .5, 1],
      ),
  );
  for (var i = 0; i < 57; i++) {
    c.drawArc(
      Rect.fromCircle(center: center, radius: 118),
      i * math.pi * 2 / 57,
      .017,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0xCC8F65D0),
    );
  }
  for (var i = 0; i < 100; i++) {
    final seed = (i * .61803398875) % 1, life = (phase + i * .137) % 1;
    final p = Offset(seed * 400 + math.sin(t + i) * 2.5, (1 - life) * 400);
    final tint = i % 4 == 0 ? const Color(0xFF87AAFF) : const Color(0xFFB98CFF);
    final alpha =
        (.2 + .65 * (.5 + .5 * math.sin(t * 4 + i))) * math.sin(life * math.pi);
    glow(p, 4 + (i % 3), tint, alpha * .4);
    c.drawCircle(
      p,
      .3 + (i % 5) * .24,
      Paint()..color = tint.withValues(alpha: alpha * power),
    );
  }
  for (var side = 0; side < 2; side++) {
    final tint = side == 0 ? const Color(0xFFBCA1FF) : const Color(0xFF6D91FF);
    c.save();
    c.translate(200, 200);
    c.rotate(side == 0 ? t : -t);
    c.save();
    c.rotate((side == 0 ? -35 : 43) * math.pi / 180);
    final rx = side == 0 ? 170.0 : 164.0, ry = side == 0 ? 68.0 : 74.0;
    c.drawOval(
      Rect.fromLTRB(-rx, -ry, rx, ry),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side == 0 ? 1.5 : 1.3
        ..color = tint.withValues(alpha: .85 * power),
    );
    c.restore();
    final node = side == 0 ? const Offset(-140, -96) : const Offset(118, 110);
    glow(node, 14, tint, .6);
    c.drawCircle(
      node,
      side == 0 ? 5 : 4,
      Paint()
        ..shader = ui.Gradient.radial(
          node,
          5,
          const [Colors.white, Color(0xFFC9A4FF), Color(0xFF7236D9)],
          const [0, .3, 1],
        ),
    );
    c.restore();
  }
  c.save();
  c.translate(0, -7 * (.5 - .5 * math.cos(t * 3)));
  final crown = Path()
    ..moveTo(153, 108)
    ..lineTo(145, 65)
    ..lineTo(169, 81)
    ..lineTo(200, 38)
    ..lineTo(231, 81)
    ..lineTo(255, 65)
    ..lineTo(247, 108)
    ..close();
  glow(const Offset(200, 85), 65, const Color(0xFFA66CFF), .22);
  c.drawPath(crown, Paint()..color = const Color(0xFF39205E));
  final inner = Path()
    ..moveTo(155, 101)
    ..lineTo(149, 71)
    ..lineTo(170, 87)
    ..lineTo(200, 45)
    ..lineTo(230, 87)
    ..lineTo(251, 71)
    ..lineTo(245, 101)
    ..close();
  c.drawPath(inner, Paint()..color = const Color(0x8C9365D4));
  c.drawPath(
    crown,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2
      ..color = const Color(0xFFF0D9FF),
  );
  final base = Path()
    ..moveTo(153, 108)
    ..lineTo(247, 108)
    ..lineTo(247, 119)
    ..quadraticBezierTo(200, 126, 153, 119)
    ..close();
  c.drawPath(base, Paint()..color = const Color(0xFF5C348C));
  c.drawPath(
    base,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFF0D9FF),
  );
  for (final p in [
    const Offset(200, 77),
    const Offset(169, 94),
    const Offset(231, 94),
  ]) {
    final r = p.dx == 200 ? 8.0 : 4.0;
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          r,
          const [Colors.white, Color(0xFFC9A4FF), Color(0xFF7236D9)],
          const [0, .3, 1],
        ),
    );
  }
  c.restore();
  for (var i = 0; i < 2; i++) {
    final p = i == 0 ? const Offset(93, 146) : const Offset(310, 258),
        r = i == 0 ? 9.0 : 7.0;
    final paint = Paint()
      ..strokeWidth = 1.5
      ..color = const Color(0xFFE9D8FF).withValues(
        alpha: (.25 + .75 * (.5 + .5 * math.sin(t * 5 + i * 2))) * power,
      );
    glow(p, 13, const Color(0xFFE9D8FF), .3);
    c.drawLine(p - Offset(r, 0), p + Offset(r, 0), paint);
    c.drawLine(p - Offset(0, r), p + Offset(0, r), paint);
  }
  c.restore();
}
