import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Native adaptation of the four frames actually displayed by
/// molduras_pbh_quatro_novas_chamas.html (specs.slice(4)).
void paintAnimatedProfileFrame(
  Canvas c,
  Size size,
  double phase,
  double intensity,
  String effect,
) {
  if (size.isEmpty) return;
  final fire = effect == 'sparks';
  final viewport = fire ? 300.0 : 240.0;
  const center = Offset(120, 120);
  final angle = phase * math.pi * 2;
  final power = .55 + intensity * .45;
  c.save();
  c.clipRect(Offset.zero & size);
  c.scale(size.width / viewport, size.height / viewport);
  if (fire) c.translate(30, 30);
  // The normal photo radius is 41px: both viewport sizes leave it untouched.
  c.clipPath(
    Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(
        Rect.fromLTWH(fire ? -30 : 0, fire ? -30 : 0, viewport, viewport),
      )
      ..addOval(Rect.fromCircle(center: center, radius: fire ? 96 : 84)),
  );
  void ring(double radius, Color color, double width) => c.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color,
  );
  void glow(Offset p, double radius, Color color) => c.drawCircle(
    p,
    radius,
    Paint()
      ..blendMode = BlendMode.screen
      ..shader = ui.Gradient.radial(p, radius, [
        color,
        color.withValues(alpha: 0),
      ]),
  );
  void arc(
    double radius,
    double start,
    double sweep,
    Color tint,
    double width,
  ) => c.drawArc(
    Rect.fromCircle(center: center, radius: radius),
    start,
    sweep,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = tint,
  );
  if (effect == 'orbit') {
    ring(91, const Color(0xFF172039), 14);
    ring(90, const Color(0xBF8B9CFB), 2);
    ring(98, const Color(0x885D75C8), 1);
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      c.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * 91,
        1.3,
        Paint()..color = const Color(0xCCB9D8FF),
      );
    }
    c.save();
    c.translate(120, 120);
    c.rotate(angle * 2);
    c.translate(-120, -120);
    arc(101, -math.pi / 2 - .46, .46, const Color(0x55A5C7FF), 9);
    arc(
      101,
      -math.pi / 2 - .46,
      .46,
      const Color(0xFFA5C7FF).withValues(alpha: power),
      3,
    );
    glow(const Offset(120, 19), 15, const Color(0x88A9DCFF));
    c.drawCircle(
      const Offset(120, 19),
      6,
      Paint()..color = const Color(0xFFD7EFFF),
    );
    c.drawCircle(const Offset(120, 19), 2, Paint()..color = Colors.white);
    c.restore();
    c.save();
    c.translate(120, 120);
    c.rotate(-angle);
    c.translate(-120, -120);
    arc(
      106,
      math.pi / 2,
      .23,
      const Color(0xFF8D63FF).withValues(alpha: power),
      2,
    );
    glow(const Offset(120, 226), 12, const Color(0x77A9BAFF));
    c.drawCircle(
      const Offset(120, 226),
      4.5,
      Paint()..color = const Color(0xFFCBB2FF),
    );
    c.restore();
  } else if (effect == 'pulse') {
    final breath = .5 - .5 * math.cos(angle * 3);
    ring(90, const Color(0xFF332B4D), 15);
    ring(89, const Color(0xB3BCA5FF), 5);
    for (var i = 0; i < 2; i++) {
      final pulse = i == 0 ? breath : 1 - breath;
      final radius = (i == 0 ? 99.0 : 106.0) * (.96 + pulse * .095);
      final tint = i == 0 ? const Color(0xFFC6B5FF) : const Color(0xFFA4D6FF);
      ring(
        radius,
        tint.withValues(alpha: (.25 + pulse * .7) * power * .22),
        i == 0 ? 10 : 6,
      );
      ring(
        radius,
        tint.withValues(alpha: (.25 + pulse * .7) * power),
        i == 0 ? 3 : 2,
      );
    }
    final alpha = (.35 + breath * .5) * power;
    ring(86, const Color(0xFFEEE5FF).withValues(alpha: alpha), 1.3);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      c.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * 89,
        3,
        Paint()..color = const Color(0xFFF2E9FF).withValues(alpha: alpha),
      );
    }
  } else if (effect == 'double') {
    ring(89, const Color(0xFF24293F), 13);
    ring(88, const Color(0xFFA9B4DC), 3);
    ring(95, const Color(0x4DD9C9FF), 1);
    for (var side = 0; side < 2; side++) {
      final tint = side == 0
          ? const Color(0xFFA0CAFF)
          : const Color(0xFFAD8DFF);
      c.save();
      c.translate(120, 120);
      c.rotate(side == 0 ? angle : -angle);
      final rx = side == 0 ? 107.0 : 86.0, ry = side == 0 ? 86.0 : 107.0;
      final rect = Rect.fromLTRB(-rx, -ry, rx, ry);
      c.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = tint.withValues(alpha: power * .16),
      );
      c.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = tint.withValues(alpha: power),
      );
      for (var i = 0; i < 40; i++) {
        final a = i * math.pi * 2 / 40, b = a + .04;
        c.drawLine(
          Offset(rx * math.cos(a), ry * math.sin(a)),
          Offset(rx * math.cos(b), ry * math.sin(b)),
          Paint()
            ..strokeWidth = 1
            ..color =
                (side == 0 ? const Color(0xFFEEF8FF) : const Color(0xFFF0D9FF))
                    .withValues(alpha: power),
        );
      }
      final node = side == 0 ? const Offset(107, 0) : const Offset(0, -107);
      glow(node, 12, tint.withValues(alpha: .45 * power));
      c.drawCircle(
        node,
        5,
        Paint()
          ..color = side == 0
              ? const Color(0xFFE4FAFF)
              : const Color(0xFFD6C2FF),
      );
      c.restore();
    }
  } else {
    ring(91, const Color(0xFF22131B), 17);
    ring(91, const Color(0xA6B83E1B), 8);
    ring(97, const Color(0x66FF9B3D), 9);
    ring(97, const Color(0xFFFF9B3D).withValues(alpha: power), 3);
    final aura = .65 + .35 * math.sin(angle * 6).abs();
    ring(99, const Color(0xFFF24A16).withValues(alpha: .18 * aura * power), 16);
    for (var i = 0; i < 46; i++) {
      final a = i * 2.39996, r = 94.0 + (i % 4) * 2;
      final point = center + Offset(math.cos(a), math.sin(a)) * r;
      final height = 10.0 + (i % 7) * 3;
      final wave = .5 + .5 * math.sin(angle * (6 + i % 3) + i * .86);
      final sy = (.65 + wave * .5) * (.65 + intensity * .5),
          sx = .7 + wave * .38;
      c.save();
      c.translate(point.dx, point.dy);
      c.rotate(a + math.pi / 2);
      c.translate(0, 4);
      c.scale(sx, sy);
      c.translate(0, -4);
      final tongue = Path()
        ..moveTo(-4, 3)
        ..quadraticBezierTo(-8, -7, -2, -height)
        ..quadraticBezierTo(2, -height * .64, 5, -height - 7)
        ..quadraticBezierTo(10, -4, 4, 4)
        ..close();
      final tint = const [
        Color(0xFFFFCA55),
        Color(0xFFFF6B23),
        Color(0xFFED3521),
      ][i % 3];
      c.drawPath(
        tongue,
        Paint()..color = tint.withValues(alpha: (.45 + wave * .5) * power),
      );
      final inner = Path()
        ..moveTo(-1, 2)
        ..quadraticBezierTo(-3, -6, 1, -height * .65)
        ..quadraticBezierTo(5, -4, 2, 3)
        ..close();
      c.drawPath(
        inner,
        Paint()
          ..color = const Color(
            0xFFFFE29A,
          ).withValues(alpha: (.5 + wave * .35) * power),
      );
      c.restore();
    }
    for (var i = 0; i < 24; i++) {
      final a = i * 2.39996,
          r = 101.0 + (i % 5) * 4,
          p = (phase * (4 + i % 3) + i * .071) % 1;
      final point =
          center +
          Offset(math.cos(a), math.sin(a)) * r +
          Offset(6 * p, 5 - 30 * p);
      c.drawCircle(
        point,
        (1 + (i % 3) * .6) * (.45 + .6 * math.sin(p * math.pi)),
        Paint()
          ..color =
              (i.isEven ? const Color(0xFFFF5E2E) : const Color(0xFFFFC45A))
                  .withValues(alpha: math.sin(p * math.pi) * power),
      );
    }
  }
  c.restore();
}
