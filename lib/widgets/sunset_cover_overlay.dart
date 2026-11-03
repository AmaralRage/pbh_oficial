import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Transparent adaptation of the supplied sunset: no opaque sky or landscape.
void paintSunsetCoverOverlay(
  Canvas canvas,
  Size size,
  double phase,
  double intensity,
) {
  final t = phase * math.pi * 2;
  final strength = .35 + intensity * .65;
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.scale(size.width / 1200, size.height / 400);
  const bounds = Rect.fromLTWH(0, 0, 1200, 400);
  final sun = Offset(610, 235 + math.sin(t) * 4);
  final glow = Paint()
    ..shader = RadialGradient(
      colors: [
        Color.fromRGBO(255, 202, 136, .2 * strength),
        const Color(0x00FF9E63),
      ],
    ).createShader(Rect.fromCircle(center: sun, radius: 250));
  canvas.drawRect(bounds, glow);
  canvas.drawCircle(
    sun,
    45,
    Paint()..color = Color.fromRGBO(255, 219, 161, .28 * strength),
  );
  for (var i = 0; i < 10; i++) {
    final x = ((i * 167 + phase * 1550) % 1550) - 160;
    final y = 40 + (i * 47 % 150).toDouble();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: 140 + (i % 4) * 35,
        height: 12 + (i % 3) * 5,
      ),
      Paint()..color = Color.fromRGBO(211, 153, 181, .08 * strength),
    );
  }
  // Moving reflection lines, leaving the original picture visible underneath.
  for (var i = 0; i < 65; i++) {
    final y = 282 + i * 1.8, depth = (y - 280) / 120;
    final x = 610 + math.sin(i * 14.3 + t) * depth * 100;
    final width = 6 + depth * 45 + math.sin(i * 6.4).abs() * 30;
    canvas.drawLine(
      Offset(x - width / 2, y),
      Offset(x + width / 2, y),
      Paint()
        ..color = Color.fromRGBO(255, 201, 151, (.22 - depth * .1) * strength)
        ..strokeWidth = .65 + depth,
    );
  }
  final birdPaint = Paint()
    ..color = Color.fromRGBO(235, 210, 238, .6 * strength)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 7; i++) {
    final x = ((i * 213 + phase * 1550) % 1550) - 120;
    final y = 65 + (i * 23 % 120) + math.sin(t + i) * 5;
    final wing = math.sin(t * 5 + i) * 5;
    canvas.drawPath(
      Path()
        ..moveTo(x - 11, y - 3 - wing * .4)
        ..quadraticBezierTo(x - 4, y - 9 - wing, x, y)
        ..quadraticBezierTo(x + 4, y - 9 - wing, x + 11, y - 3 - wing * .4),
      birdPaint,
    );
  }
  for (var i = 0; i < (15 + intensity * 25).round(); i++) {
    final x = (i * 139 % 1200) + math.sin(t + i) * 12,
        y = (i * 71 % 360) + math.cos(t + i) * 6;
    canvas.drawCircle(
      Offset(x, y),
      .8 + (i % 3) * .4,
      Paint()
        ..color = Color.fromRGBO(
          255,
          230,
          180,
          (.1 + .13 * (.5 + .5 * math.sin(t + i))) * strength,
        ),
    );
  }
  canvas.restore();
}
