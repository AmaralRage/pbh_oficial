import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Native adaptation of capas_animadas_pbh_edicao_lendaria.html. Architecture is
// cached; the original cover stays underneath the transparent scene and FX.
final _bases = <(String, Size), ui.Picture>{};
final _seeds = (() {
  final r = math.Random(935721);
  return List.generate(
    100,
    (_) => List.generate(7, (_) => r.nextDouble(), growable: false),
    growable: false,
  );
})();

void _line(Canvas c, List<Offset> points, Color color, [double width = 1]) {
  final p = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    p.lineTo(point.dx, point.dy);
  }
  c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color,
  );
}

void _glow(Canvas c, Offset center, double radius, Color color) {
  c.drawCircle(
    center,
    radius,
    Paint()
      ..blendMode = BlendMode.screen
      ..shader = ui.Gradient.radial(center, radius, [
        color,
        color.withValues(alpha: 0),
      ]),
  );
}

ui.Picture _base(String mode, Size size) {
  final key = (mode, size);
  final cached = _bases[key];
  if (cached != null) return cached;
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  final w = size.width, h = size.height;
  void rect(double x, double y, double width, double height, Color color) =>
      c.drawRect(
        Rect.fromLTWH(x * w, y * h, width * w, height * h),
        Paint()..color = color,
      );
  if (mode == 'library') {
    const bookColors = [
      Color(0xBB78604A),
      Color(0xBB463444),
      Color(0xBB6E5547),
      Color(0xBB342E3B),
    ];
    for (final side in [0, 1]) {
      final x = side == 0 ? .015 : .79;
      rect(x, 0, .19, 1, const Color(0x9917121A));
      for (var shelf = 0; shelf < 5; shelf++) {
        final y = .12 + shelf * .2;
        rect(x, y, .19, .015, const Color(0xCC51402D));
        for (var i = 0; i < 16; i++) {
          final seed = _seeds[(shelf * 16 + i) % 100];
          final height = .11 + seed[0] * .055;
          rect(
            x + .006 + i * .0114,
            y - height,
            .006,
            height,
            bookColors[i % 4],
          );
          rect(
            x + .008 + i * .0114,
            y - height + .015,
            .001,
            .05,
            const Color(0x66C9A273),
          );
        }
      }
    }
    final arch = Path()
      ..moveTo(w * .25, h)
      ..lineTo(w * .25, h * .22)
      ..quadraticBezierTo(w * .5, -h * .35, w * .75, h * .22)
      ..lineTo(w * .75, h);
    c.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xAA2B2232),
    );
    c.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x997B5B49),
    );
    rect(.3, .83, .4, .17, const Color(0xAA130E19));
    rect(.3, .83, .4, .025, const Color(0xCC6C4931));
    for (var i = 0; i < 5; i++) {
      rect(.37 + i * .065, .73, .007, .10, const Color(0xCCC5A379));
    }
    final book = Path()
      ..moveTo(w * .43, h * .81)
      ..quadraticBezierTo(w * .49, h * .74, w * .5, h * .8)
      ..quadraticBezierTo(w * .55, h * .74, w * .57, h * .81)
      ..lineTo(w * .5, h * .86)
      ..close();
    c.drawPath(book, Paint()..color = const Color(0xDDC3A477));
  } else if (mode == 'throne') {
    for (var i = 0; i < 7; i++) {
      rect(i / 6, 0, .045, 1, const Color(0x881A1427));
      rect(i / 6 + .018, 0, .004, 1, const Color(0x995E357D));
    }
    final throne = Path()
      ..moveTo(w * .39, h * .9)
      ..lineTo(w * .39, h * .35)
      ..lineTo(w * .46, h * .18)
      ..lineTo(w * .5, h * .3)
      ..lineTo(w * .54, h * .18)
      ..lineTo(w * .61, h * .35)
      ..lineTo(w * .61, h * .9)
      ..close();
    c.drawPath(throne, Paint()..color = const Color(0xBB0B0912));
    c.drawPath(
      throne,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xCC8D55CB),
    );
    rect(.42, .67, .16, .1, const Color(0xCC3E2450));
    rect(.37, .76, .26, .12, const Color(0xCC24152F));
    c.drawOval(
      Rect.fromCenter(
        center: Offset(w * .5, h * .83),
        width: w * .62,
        height: h * .24,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66A779F4),
    );
    final crown = Path()
      ..moveTo(w * .5, h * .12)
      ..lineTo(w * .525, h * .23)
      ..lineTo(w * .5, h * .21)
      ..lineTo(w * .475, h * .23)
      ..close();
    c.drawPath(crown, Paint()..color = const Color(0xAAA275CD));
  } else if (mode == 'cosmos') {
    final mountain = Path()..moveTo(0, h);
    for (var i = 0; i <= 12; i++) {
      mountain.lineTo(i * w / 12, h * (.82 - .2 * math.sin(i * 1.9)));
    }
    mountain
      ..lineTo(w, h)
      ..close();
    c.drawPath(mountain, Paint()..color = const Color(0x99080E1D));
    rect(.46, .58, .12, .27, const Color(0xBB11192D));
    final dome = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(w * .52, h * .54), radius: h * .15),
        math.pi,
        math.pi,
      )
      ..lineTo(w * .67, h * .85)
      ..lineTo(w * .37, h * .85)
      ..close();
    c.drawPath(dome, Paint()..color = const Color(0xBB11192D));
    c.drawPath(
      dome,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0x667EA2CD),
    );
  } else {
    for (var i = 0; i < 8; i++) {
      rect(i / 7, 0, .04, .68, const Color(0x99151218));
      rect(i / 7, 0, .005, .68, const Color(0xAA593D31));
    }
    final ground = Path()..moveTo(0, h);
    for (var i = 0; i <= 16; i++) {
      ground.lineTo(i * w / 16, h * (.81 + math.sin(i * 3) * .06));
    }
    ground
      ..lineTo(w, h)
      ..close();
    c.drawPath(ground, Paint()..color = const Color(0xAA100E13));
    rect(.35, .78, .3, .16, const Color(0xDD171017));
    rect(.37, .77, .26, .035, const Color(0xDD594037));
    final blade = Path()
      ..moveTo(w * .5, h * .16)
      ..lineTo(w * .516, h * .27)
      ..lineTo(w * .51, h * .75)
      ..lineTo(w * .49, h * .75)
      ..lineTo(w * .484, h * .27)
      ..close();
    c.drawPath(
      blade,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w * .484, 0),
          Offset(w * .516, 0),
          const [Color(0xFF768091), Color(0xFFF1F5FF), Color(0xFF68758D)],
          const [0, .5, 1],
        ),
    );
    rect(.455, .38, .09, .02, const Color(0xFF805651));
    rect(.494, .4, .012, .13, const Color(0xFF786151));
    _line(
      c,
      [Offset(w * .5, h * .16), Offset(w * .5, h * .75)],
      const Color(0xBBFBA14B),
      1,
    );
  }
  final picture = recorder.endRecording();
  if (_bases.length >= 8) {
    final oldest = _bases.keys.first;
    _bases.remove(oldest)?.dispose();
  }
  _bases[key] = picture;
  return picture;
}

void paintLegendaryCover(
  Canvas c,
  Size size,
  double phase,
  double intensity,
  String effect,
) {
  final mode = switch (effect) {
    'knowledge_constellation' => 'library',
    'platinum_throne' => 'throne',
    'journey_legacy' => 'cosmos',
    _ => 'forge',
  };
  final w = size.width, h = size.height, a = phase * math.pi * 2;
  final palette = switch (mode) {
    'library' => const [
      Color(0xFFFFD78B),
      Color(0xFFDBB4FF),
      Color(0xFFFFF4D1),
    ],
    'throne' => const [Color(0xFFB76BFF), Color(0xFFF8B6FF), Color(0xFF6936FF)],
    'cosmos' => const [Color(0xFFB2D8FF), Color(0xFFF5D9FF), Color(0xFF8E8DFF)],
    _ => const [Color(0xFFFF9B35), Color(0xFFFFE3A2), Color(0xFFFF5925)],
  };
  c.save();
  c.clipRect(Offset.zero & size);
  _glow(
    c,
    Offset(w * .5, h * .6),
    h * .8,
    palette[0].withValues(alpha: .12 + intensity * .08),
  );
  c.drawPicture(_base(mode, size));
  if (mode == 'library') {
    for (var i = 0; i < 7; i++) {
      final x = w * (.3 + i * .065) + math.sin(a + i) * w * .018;
      final y = h * (.3 + math.cos(a + i) * .1);
      c.save();
      c.translate(x, y);
      c.rotate(math.sin(a + i) * .3);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-7, -4, 14, 8),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xAAD4B58C),
      );
      _line(c, const [Offset(-6, 0), Offset(6, 0)], const Color(0xFF62485C));
      c.restore();
      final r = 2 + intensity;
      c.drawPath(
        Path()
          ..moveTo(x, y - 10 - r)
          ..lineTo(x + r * .5, y - 10)
          ..lineTo(x, y - 10 + r)
          ..lineTo(x - r * .5, y - 10)
          ..close(),
        Paint()..color = palette[1].withValues(alpha: .4 + intensity * .25),
      );
    }
    for (var i = 0; i < 5; i++) {
      final point = Offset(w * (.37 + i * .065) + 1, h * .72);
      _glow(
        c,
        point,
        18 + intensity * 10 + math.sin(a * 2 + i) * 3,
        const Color(0x66FFCA7B),
      );
      c.drawOval(
        Rect.fromCenter(
          center: point,
          width: 2.3,
          height: 5 + math.sin(a * 3 + i),
        ),
        Paint()..color = const Color(0xFFFFDF95),
      );
    }
  } else if (mode == 'throne') {
    for (var i = 0; i < 5; i++) {
      final x = w * (i.isEven ? .18 : .82) + math.sin(a + i) * 8;
      final y = h * .78;
      _glow(
        c,
        Offset(x, y),
        20 + intensity * 16 + math.sin(a * 2 + i) * 4,
        const Color(0x888B39FF),
      );
      c.drawPath(
        Path()
          ..moveTo(x, y + 8)
          ..quadraticBezierTo(
            x - 10,
            y - 15,
            x + math.sin(a * 2 + i) * 10,
            y - 27 - math.sin(a * 3 + i) * 8,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xBBB779FF),
      );
    }
    for (var i = 0; i < 4; i++) {
      final y = h * (.2 + i * .17);
      c.drawPath(
        Path()
          ..moveTo(w * .31, y)
          ..quadraticBezierTo(
            w * .5 + math.sin(a + i) * 15,
            y + 10,
            w * .69,
            y,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x77BB8DFF),
      );
    }
  } else if (mode == 'cosmos') {
    for (var i = 0; i < 65; i++) {
      final s = _seeds[i];
      c.drawCircle(
        Offset(s[0] * w, s[1] * h),
        i % 9 == 0 ? 1.4 : .65,
        Paint()
          ..color = palette[i % 3].withValues(
            alpha: .3 + .35 * math.sin(a + s[2] * 6).abs(),
          ),
      );
    }
    c.save();
    c.translate(w * .52, h * .54);
    c.rotate(a);
    for (var i = 0; i < 3; i++) {
      final r = h * (.3 + i * .075);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 3.2, height: r * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x999DB8FF),
      );
    }
    for (var i = 0; i < 12; i++) {
      final v = i * math.pi / 6;
      c.drawCircle(
        Offset(math.cos(v) * h * .55, math.sin(v) * h * .55),
        1.4,
        Paint()..color = const Color(0xBBD8CBFF),
      );
    }
    c.restore();
    for (var i = 0; i < 3; i++) {
      final s = _seeds[i + 80];
      final p = (phase * 2 + s[0]) % 1;
      if (p > .18) continue;
      final x = w * (.3 + s[1] * .6) - p * w * 2;
      final y = h * s[2] * .35 + p * h * 2;
      _line(
        c,
        [Offset(x, y), Offset(x + 45, y - 22)],
        palette[0].withValues(alpha: math.sin(p / .18 * math.pi)),
        1.3,
      );
      _glow(
        c,
        Offset(x, y),
        7,
        palette[0].withValues(alpha: .5 * math.sin(p / .18 * math.pi)),
      );
    }
  } else {
    _glow(
      c,
      Offset(w * .5, h * .7),
      h * (.35 + intensity * .1),
      const Color(0x88FF7825),
    );
    for (var i = 0; i < 6; i++) {
      final x = w * .5 + (i - 2.5) * w * .017;
      final y = h * .7;
      c.drawPath(
        Path()
          ..moveTo(x, y + 10)
          ..quadraticBezierTo(
            x + math.sin(a * 4 + i) * 8,
            y - 15,
            x + math.sin(a * 3 + i) * 5,
            y - h * .16 - math.sin(a * 2 + i) * 6,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xBBFF8B35),
      );
    }
  }
  final count = (25 + intensity * 45).round();
  for (var i = 0; i < count; i++) {
    final s = _seeds[i];
    final p = (phase + s[0]) % 1;
    final x =
        (mode == 'forge' && i.isEven ? w * (.4 + s[1] * .2) : s[1] * w) +
        math.sin(a + s[3] * 6) * 6;
    final y = mode == 'forge'
        ? h * (1 - p)
        : h * (.2 + s[2] * .6) + math.sin(a + s[3] * 6) * 8;
    final opacity = math.sin(p * math.pi) * (.45 + intensity * .4);
    final point = Offset(x, y);
    final r = .5 + s[4] * 1.6;
    if (i % 4 == 0)
      _glow(c, point, r * 4, palette[i % 3].withValues(alpha: opacity * .25));
    c.drawCircle(
      point,
      r,
      Paint()..color = palette[i % 3].withValues(alpha: opacity),
    );
  }
  c.restore();
}
