import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<ui.Image>? _art;
Future<ui.Image> loadSupremeCrownArt() => _art ??= (() async {
  final bytes = await rootBundle.load('assets/images/supreme_crown_frame.png');
  final codec = await ui.instantiateImageCodec(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
  try {
    final source = (await codec.getNextFrame()).image;
    final rgba = (await source.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final pixels = rgba.buffer.asUint8List(
      rgba.offsetInBytes,
      rgba.lengthInBytes,
    );
    // The supplied PNG has an opaque near-black backdrop. Turn only that
    // backdrop into transparency once, retaining the brighter metal and gems.
    for (var i = 0; i < pixels.length; i += 4) {
      final brightness = math.max(
        pixels[i],
        math.max(pixels[i + 1], pixels[i + 2]),
      );
      final pixel = i ~/ 4, x = pixel % source.width, y = pixel ~/ source.width;
      final edge = math.min(
        math.min(x, source.width - 1 - x),
        math.min(y, source.height - 1 - y),
      );
      final coverage =
          ((brightness - 35) / 40).clamp(0.0, 1.0) *
          (edge / 24).clamp(0.0, 1.0);
      // decodeImageFromPixels expects premultiplied RGBA. Changing only alpha
      // leaves the original dark RGB behind, producing a rectangular haze.
      for (var channel = 0; channel < 4; channel++) {
        pixels[i + channel] = (pixels[i + channel] * coverage).round();
      }
    }
    final ready = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      source.width,
      source.height,
      ui.PixelFormat.rgba8888,
      ready.complete,
    );
    final result = await ready.future;
    source.dispose();
    return result;
  } finally {
    codec.dispose();
  }
})();

void paintSupremeCrownFrame(
  Canvas c,
  Size size,
  double phase,
  double intensity,
  ui.Image? image,
) {
  if (size.isEmpty) return;
  final t = phase * math.pi * 2, power = .4 + intensity * .6;
  const center = Offset(512, 480);
  c.save();
  c.clipRect(Offset.zero & size);
  c.scale(size.width / 1024, size.height / 1024);
  c.translate(0, 32);
  c.clipPath(
    Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(const Rect.fromLTWH(0, -32, 1024, 1024))
      ..addOval(Rect.fromCircle(center: center, radius: 224)),
  );
  if (image != null) {
    c.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      const Rect.fromLTWH(0, 0, 1024, 964),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
  Offset polar(double a, double r) =>
      center + Offset(math.cos(a) * r, math.sin(a) * r * .91);
  void flare(Offset p, double r, Color tint, double alpha) {
    c.drawCircle(
      p,
      r,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(
          p,
          r,
          [
            Colors.white.withValues(alpha: alpha * power),
            tint.withValues(alpha: alpha * power * .6),
            tint.withValues(alpha: 0),
          ],
          const [0, .13, 1],
        ),
    );
    final paint = Paint()
      ..strokeWidth = 1.4
      ..color = tint.withValues(alpha: alpha * power);
    c.drawLine(p - Offset(r * .7, 0), p + Offset(r * .7, 0), paint);
    c.drawLine(p - Offset(0, r * .7), p + Offset(0, r * .7), paint);
  }

  for (var i = 0; i < (100 + intensity * 170).round(); i++) {
    final a = i * 2.39996 + t * (i.isEven ? 1 : -1), r = 285.0 + (i * 53 % 180);
    final p = polar(a, r),
        tint = i % 3 == 0 ? const Color(0xFFFFDB93) : const Color(0xFFD19CFF);
    final alpha = (.2 + .55 * (.5 + .5 * math.sin(t * 4 + i))) * power;
    c.drawCircle(
      p,
      .7 + (i % 5) * .45,
      Paint()..color = tint.withValues(alpha: alpha),
    );
  }
  for (var k = 0; k < 3; k++) {
    c.save();
    c.translate(512, 480);
    c.rotate(t * (k.isEven ? 1 : -1) + k * 2.094);
    c.scale(1, .91);
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 350.0 + k * 16),
      0,
      1.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = (k == 1 ? const Color(0xFFFFCC85) : const Color(0xFFCB73FF))
            .withValues(alpha: .55 * power),
    );
    c.restore();
  }
  for (var k = 0; k < 9; k++) {
    final a = t * (k.isEven ? 2 : -2) + k * math.pi * 2 / 9,
        r = 290 + 45 * math.sin(k * 2.4),
        p = polar(a, r),
        tail = polar(a - .25, r);
    final tint = k % 3 == 0 ? const Color(0xFFFFE8A5) : const Color(0xFFF0CAFF);
    c.drawPath(
      Path()
        ..moveTo(tail.dx, tail.dy)
        ..quadraticBezierTo(p.dx - 16, p.dy - 16, p.dx, p.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = ui.Gradient.linear(tail, p, [
          tint.withValues(alpha: 0),
          tint.withValues(alpha: power),
        ]),
    );
    flare(p, 15, tint, .55);
  }
  for (var k = 0; k < 5; k++) {
    final a = t + k * math.pi * 2 / 5,
        b = a + .35 + .14 * math.sin(t * 4 + k),
        p = polar(a, 382),
        q = polar(b, 382);
    final path = Path()..moveTo(p.dx, p.dy);
    for (var j = 1; j <= 7; j++) {
      final f = j / 7, d = j.isEven ? -9.0 : 9.0;
      path.lineTo(p.dx + (q.dx - p.dx) * f + d, p.dy + (q.dy - p.dy) * f - d);
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFD69AFF).withValues(
          alpha: (.23 + .24 * (.5 + .5 * math.sin(t * 8 + k))) * power,
        ),
    );
  }
  for (var k = 0; k < 3; k++) {
    final cycle = (phase * 5 + k / 3) % 1,
        p = k == 0
            ? const Offset(511, 170)
            : k == 1
            ? const Offset(511, 845)
            : polar(t, 350);
    c.drawCircle(
      p,
      cycle * 120,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(
          0xFFE4ADFF,
        ).withValues(alpha: (1 - cycle) * .65 * power),
    );
  }
  flare(
    const Offset(511, 171),
    47 + 9 * math.sin(t * 5),
    const Color(0xFFDA77FF),
    .85,
  );
  flare(
    const Offset(511, 845),
    35 + 7 * math.sin(t * 4),
    const Color(0xFFCA6CFF),
    .7,
  );
  c.restore();
}
