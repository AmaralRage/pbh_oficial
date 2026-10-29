import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Adaptation of molduras_pbh_eventos_sem_chuva.html, around a clear photo.
void paintEventProfileFrame(
  Canvas c,
  Size size,
  double phase,
  double intensity,
  String effect,
) {
  if (size.isEmpty) return;
  const center = Offset(150, 150);
  final angle = phase * math.pi * 2, power = .5 + intensity * .5;
  final halloween = effect == 'halloween', christmas = effect == 'christmas';
  final rain = effect == 'rain';
  final colors = rain
      ? const [
          Color(0xFFE8FCFF),
          Color(0xFF4E9BB7),
          Color(0xFFC5F5FF),
          Color(0xFF1C4B79),
          Color(0xFFA9ECFF),
        ]
      : halloween
      ? const [
          Color(0xFFFFCE70),
          Color(0xFF9C391B),
          Color(0xFFF58B28),
          Color(0xFF4A184B),
          Color(0xFFC874FA),
        ]
      : christmas
      ? const [Color(0xFFE63948), Color(0xFFFFDA86), Color(0xFF1DD6A0)]
      : const [Color(0xFFFFE7A2), Colors.white, Color(0xFFD5A0FF)];
  c.save();
  c.clipRect(Offset.zero & size);
  c.scale(size.width / 300, size.height / 300);
  c.clipPath(
    Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(const Rect.fromLTWH(0, 0, 300, 300))
      ..addOval(Rect.fromCircle(center: center, radius: 96)),
  );
  Offset polar(double a, double r) =>
      center + Offset(math.cos(a), math.sin(a)) * r;
  void glow(Offset p, double r, Color tint, double alpha) => c.drawCircle(
    p,
    r,
    Paint()
      ..shader = ui.Gradient.radial(p, r, [
        tint.withValues(alpha: alpha * power),
        tint.withValues(alpha: 0),
      ]),
  );
  void ring(double r, double width, Color tint) => c.drawCircle(
    center,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = tint,
  );
  final radius = halloween
      ? 102.0
      : rain
      ? 101.0
      : 99.0;
  ring(radius, 22, colors.first.withValues(alpha: .12 * power));
  ring(
    radius,
    14,
    halloween ? const Color(0xFF180D18) : const Color(0xFF102332),
  );
  c.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..shader = ui.Gradient.linear(
        const Offset(45, 45),
        const Offset(255, 255),
        colors,
        List.generate(colors.length, (i) => i / (colors.length - 1)),
      ),
  );
  ring(97, 1.3, colors.last.withValues(alpha: .7));
  final breath = .5 + .5 * math.sin(angle * 3);
  ring(
    116 + breath * 3,
    1,
    colors.first.withValues(alpha: (.15 + breath * .2) * power),
  );
  for (var i = 0; i < 48; i++) {
    final a = i * math.pi / 24 + angle;
    c.drawArc(
      Rect.fromCircle(center: center, radius: 111),
      a,
      halloween ? (i % 4 == 0 ? .1 : .025) : .025,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = colors.last.withValues(alpha: .7 * power),
    );
  }
  void star(Offset p, double r, Color tint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4,
          q = p + Offset(math.cos(a), math.sin(a)) * (i.isEven ? r : r * .25);
      if (i == 0) {
        path.moveTo(q.dx, q.dy);
      } else {
        path.lineTo(q.dx, q.dy);
      }
    }
    c.drawPath(path..close(), Paint()..color = tint);
  }

  if (rain) {
    for (var j = 0; j < 4; j++) {
      final p = polar(angle * 2 + j * math.pi / 2, 102);
      glow(p, 16, colors.first, .5);
      c.drawCircle(p, 3 + breath, Paint()..color = const Color(0xFFC6F8FF));
    }
    for (final p in [
      const Offset(150, 34),
      const Offset(49, 176),
      const Offset(251, 129),
    ]) {
      final drop = Path()
        ..moveTo(p.dx, p.dy - 10)
        ..cubicTo(p.dx - 17, p.dy + 9, p.dx + 17, p.dy + 9, p.dx, p.dy - 10);
      c.drawPath(drop, Paint()..color = colors.first);
    }
    // A brief rim flash; no rain particles and no flash over the photo.
    final flash = math.pow(math.max(0, math.cos(angle * 2)), 50).toDouble();
    ring(104, 5, Colors.white.withValues(alpha: flash * .6 * power));
  } else if (halloween) {
    final crown = Path()
      ..moveTo(112, 52)
      ..lineTo(108, 35)
      ..lineTo(128, 45)
      ..lineTo(139, 27)
      ..lineTo(148, 46)
      ..lineTo(161, 29)
      ..lineTo(173, 48)
      ..lineTo(192, 40)
      ..lineTo(185, 59)
      ..lineTo(174, 67)
      ..lineTo(124, 67)
      ..close();
    c.drawPath(crown, Paint()..color = const Color(0xFF211122));
    c.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFEF873F),
    );
    for (var j = 0; j < 5; j++) {
      glow(polar(angle + j * 1.7, 120), 34, const Color(0xFFA441C5), .16);
    }
  } else {
    for (final y in [35.0, 265.0]) {
      final p = Offset(150, y);
      glow(p, 17, colors.first, .35);
      if (christmas) {
        for (var i = 0; i < 4; i++) {
          final d =
              Offset(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4)) * 11;
          c.drawLine(
            p - d,
            p + d,
            Paint()
              ..strokeWidth = 2
              ..color = const Color(0xFFE8FAFF),
          );
        }
      } else {
        star(p, 14, const Color(0xFFFFF2B6));
      }
    }
    if (christmas) {
      for (var i = 0; i < 16; i++) {
        final p = polar(i * math.pi / 8, 105), tint = colors[i % 3];
        glow(p, 10, tint, .4 + breath * .25);
        c.drawCircle(p, 3, Paint()..color = tint);
      }
    }
  }
  // Stable, independent phases avoid particle jumps when intensity changes.
  if (!rain) {
    final count = (30 + intensity * 35).round();
    for (var i = 0; i < count; i++) {
      final seed = (i * .61803398875) % 1;
      final life = (phase * (2 + i % 3) + seed) % 1;
      final fade = math.sin(life * math.pi), a = i * 2.39996;
      final tint = colors[i % colors.length];
      Offset p;
      if (christmas) {
        p = Offset(seed * 300 + 5 * math.sin(angle * 2 + i), -10 + life * 320);
        c.drawCircle(
          p,
          1 + (i % 3) * .7,
          Paint()
            ..color = const Color(0xFFE8FAFF).withValues(alpha: fade * power),
        );
      } else if (halloween) {
        p =
            polar(a, 108 + (i % 6) * 5) +
            Offset(math.sin(angle + i) * 5, 10 - life * 30);
        if (i % 4 == 0) {
          final wing = math.sin(angle * 12 + i) * 5;
          c.save();
          c.translate(p.dx, p.dy);
          final bat = Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(-6, -7 - wing, -13, -2)
            ..lineTo(-9, 4)
            ..lineTo(-4, 2)
            ..lineTo(0, 5)
            ..lineTo(4, 2)
            ..lineTo(9, 4)
            ..lineTo(13, -2)
            ..quadraticBezierTo(6, -7 - wing, 0, 0)
            ..close();
          c.drawPath(
            bat,
            Paint()..color = const Color(0xFF190B23).withValues(alpha: fade),
          );
          c.drawPath(
            bat,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8
              ..color = const Color(0xFFBB73DD).withValues(alpha: fade),
          );
          c.restore();
        } else {
          glow(p, 8, tint, fade * .3);
          c.drawOval(
            Rect.fromCenter(center: p, width: 3, height: i.isEven ? 9 : 5),
            Paint()..color = tint.withValues(alpha: fade * power),
          );
        }
      } else {
        final origin = polar((i ~/ 12) * 2.4, 110);
        p = origin + Offset(math.cos(a), math.sin(a)) * life * 33;
        glow(p, 6, tint, fade * .25);
        c.drawRect(
          Rect.fromCenter(center: p, width: 2, height: 3),
          Paint()..color = tint.withValues(alpha: fade * power),
        );
      }
    }
  }
  c.restore();
}
