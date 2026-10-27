import 'dart:math' as math;
import 'package:flutter/material.dart';

final _outerFlame = Path()
  ..moveTo(58, 257)
  ..cubicTo(27, 214, 73, 188, 66, 140)
  ..cubicTo(97, 170, 87, 194, 106, 201)
  ..cubicTo(104, 157, 129, 132, 130, 83)
  ..cubicTo(167, 133, 142, 167, 161, 200)
  ..cubicTo(177, 176, 177, 155, 173, 134)
  ..cubicTo(221, 185, 216, 237, 182, 261)
  ..close();
final _middleFlame = Path()
  ..moveTo(81, 257)
  ..cubicTo(61, 224, 94, 198, 91, 169)
  ..cubicTo(117, 195, 105, 208, 119, 217)
  ..cubicTo(132, 186, 127, 152, 144, 129)
  ..cubicTo(169, 173, 154, 193, 170, 220)
  ..cubicTo(181, 206, 182, 192, 183, 181)
  ..cubicTo(203, 213, 194, 242, 178, 259)
  ..close();
final _innerFlame = Path()
  ..moveTo(98, 258)
  ..cubicTo(80, 229, 109, 211, 112, 187)
  ..cubicTo(127, 207, 122, 216, 129, 224)
  ..cubicTo(140, 201, 140, 186, 148, 175)
  ..cubicTo(165, 209, 152, 220, 168, 238)
  ..lineTo(156, 260)
  ..close();
final _hotFlame = Path()
  ..moveTo(117, 258)
  ..cubicTo(108, 239, 124, 225, 131, 210)
  ..cubicTo(138, 225, 135, 230, 144, 237)
  ..cubicTo(152, 227, 152, 220, 154, 216)
  ..cubicTo(164, 234, 157, 248, 150, 259)
  ..close();

Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

void paintBonfireArt(Canvas canvas, Size size, double angle, double intensity) {
  final boxWidth = (size.width * .27).clamp(145.0, 245.0);
  final scale = math.min(boxWidth / 240, size.height * .94 / 300);
  canvas.save();
  canvas.translate(
    size.width * .975 - boxWidth / 2 - 120 * scale,
    size.height - 300 * scale,
  );
  canvas.scale(scale);
  final pulse = .72 + .18 * math.sin(angle * 4);
  final halo = Rect.fromCenter(
    center: const Offset(122, 251),
    width: 232,
    height: 96,
  );
  canvas.drawOval(
    halo,
    Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFCE6A).withValues(alpha: .65 * pulse),
          const Color(0xFFFF5D0D).withValues(alpha: .33 * pulse),
          const Color(0x00E23C06),
        ],
        stops: const [0, .35, 1],
      ).createShader(halo),
  );
  final glow = Rect.fromCenter(
    center: const Offset(122, 220),
    width: 154,
    height: 200,
  );
  canvas.drawOval(
    glow,
    Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6C13).withValues(alpha: .24 * pulse),
          const Color(0x00FF6C13),
        ],
      ).createShader(glow),
  );
  final stones = [
    _polygon(const [
      Offset(15, 273),
      Offset(39, 250),
      Offset(61, 259),
      Offset(75, 283),
      Offset(37, 292),
    ]),
    _polygon(const [
      Offset(166, 267),
      Offset(195, 243),
      Offset(223, 255),
      Offset(237, 285),
      Offset(193, 292),
    ]),
    _polygon(const [
      Offset(64, 274),
      Offset(87, 255),
      Offset(110, 264),
      Offset(123, 290),
      Offset(75, 293),
    ]),
    _polygon(const [
      Offset(126, 272),
      Offset(151, 254),
      Offset(177, 268),
      Offset(187, 293),
      Offset(136, 291),
    ]),
  ];
  for (final stone in stones) {
    canvas.drawPath(stone, Paint()..color = const Color(0xFF29252A));
    canvas.drawPath(
      stone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF100F13),
    );
  }
  for (final wood in [
    _polygon(const [
      Offset(39, 259),
      Offset(180, 232),
      Offset(189, 248),
      Offset(52, 275),
    ]),
    _polygon(const [
      Offset(192, 267),
      Offset(62, 229),
      Offset(51, 244),
      Offset(180, 283),
    ]),
  ]) {
    canvas.drawPath(wood, Paint()..color = const Color(0xFF5E3B2C));
    canvas.drawPath(
      wood,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF1B1212),
    );
  }
  final grain = Paint()
    ..color = const Color(0xFFBD7040).withValues(alpha: .8)
    ..strokeWidth = 2;
  canvas.drawLine(const Offset(52, 257), const Offset(173, 234), grain);
  canvas.drawLine(const Offset(67, 234), const Offset(182, 269), grain);
  void flame(Path path, Paint paint, int cycles, double phase) {
    final wave = math.sin(angle * cycles + phase);
    canvas.save();
    canvas.translate(120, 258);
    canvas.skew(wave * .075, 0);
    canvas.scale(1 + wave * .045, 1 - wave * (.025 + intensity * .045));
    canvas.translate(-120, -258);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  const flameBounds = Rect.fromLTWH(28, 83, 195, 180);
  flame(
    _outerFlame,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment(-.4, -1),
        colors: [
          Color(0xFFA91D0B),
          Color(0xFFFF4E09),
          Color(0xFFFF991F),
          Color(0x40FFDF72),
        ],
        stops: [0, .4, .78, 1],
      ).createShader(flameBounds),
    7,
    0,
  );
  flame(
    _middleFlame,
    Paint()..color = const Color(0xFFFF8C1B).withValues(alpha: .91),
    10,
    2,
  );
  flame(
    _innerFlame,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topCenter,
        colors: [Color(0xFFFFF5BD), Color(0xFFFFB72F), Color(0x1AFF6011)],
        stops: [0, .55, 1],
      ).createShader(flameBounds),
    14,
    1,
  );
  flame(
    _hotFlame,
    Paint()..color = const Color(0xFFFFF2B5).withValues(alpha: .9),
    14,
    1,
  );
  // The sword is a fixed foreground element, as in the supplied SVG.
  canvas.save();
  canvas.translate(123, 175);
  canvas.rotate(-9 * math.pi / 180);
  canvas.translate(-123, -175);
  // Keep the tip planted in the fire while halving the entire sword.
  canvas.translate(123, 255);
  canvas.scale(.5);
  canvas.translate(-123, -255);
  final blade = _polygon(const [
    Offset(116, 64),
    Offset(131, 64),
    Offset(128, 234),
    Offset(123, 255),
    Offset(118, 234),
  ]);
  canvas.drawPath(
    blade,
    Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF1C1E28),
          Color(0xFF8E9BA8),
          Color(0xFFF3E4C7),
          Color(0xFF777E88),
          Color(0xFF161821),
        ],
        stops: [0, .24, .48, .57, 1],
      ).createShader(const Rect.fromLTWH(116, 64, 15, 191)),
  );
  canvas.drawPath(
    blade,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF171923),
  );
  canvas.drawLine(
    const Offset(123, 69),
    const Offset(123, 239),
    Paint()
      ..color = const Color(0xADFFF0D3)
      ..strokeWidth = 1.7,
  );
  final guard = Path()
    ..moveTo(88, 66)
    ..quadraticBezierTo(123, 78, 158, 66)
    ..lineTo(155, 79)
    ..quadraticBezierTo(122, 96, 91, 79)
    ..close();
  canvas.drawPath(guard, Paint()..color = const Color(0xFF48414A));
  canvas.drawPath(
    guard,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF15151B),
  );
  for (final tip in [
    _polygon(const [
      Offset(89, 67),
      Offset(77, 58),
      Offset(83, 51),
      Offset(99, 65),
    ]),
    _polygon(const [
      Offset(149, 65),
      Offset(165, 51),
      Offset(171, 58),
      Offset(158, 67),
    ]),
  ]) {
    canvas.drawPath(tip, Paint()..color = const Color(0xFF69616A));
  }
  final handle = Path()
    ..moveTo(116, 64)
    ..lineTo(116, 22)
    ..quadraticBezierTo(123, 7, 130, 22)
    ..lineTo(130, 64)
    ..close();
  canvas.drawPath(handle, Paint()..color = const Color(0xFF342E36));
  canvas.drawPath(
    handle,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF14151A),
  );
  for (final y in [29.0, 39.0, 49.0]) {
    canvas.drawLine(
      Offset(115, y),
      Offset(131, y),
      Paint()
        ..color = const Color(0xFFA8875D)
        ..strokeWidth = 2.5,
    );
  }
  canvas.drawCircle(
    const Offset(123, 71),
    7,
    Paint()..color = const Color(0xFFB78B4E),
  );
  canvas.drawCircle(
    const Offset(123, 71),
    3,
    Paint()..color = const Color(0xFFF6D18B),
  );
  canvas.restore();
  for (final (i, p) in const [
    Offset(57, 150),
    Offset(182, 120),
    Offset(96, 94),
    Offset(206, 188),
    Offset(44, 211),
  ].indexed) {
    canvas.drawCircle(
      p + Offset(0, -5 * (1 + math.sin(angle * 8 + i))),
      1.7 + (i % 2) * .7,
      Paint()
        ..color = const Color(
          0xFFFFCE75,
        ).withValues(alpha: .15 + .85 * (.5 + .5 * math.sin(angle * 8 + i))),
    );
  }
  canvas.restore();
}
