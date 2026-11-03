import 'package:flutter/material.dart';

class MemberBadgeIcon extends StatelessWidget {
  const MemberBadgeIcon({
    super.key,
    required this.badge,
    required this.color,
    required this.size,
  });
  final String? badge;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (badge == 'guardian')
      return SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _GuardianPainter(color)),
      );
    if (badge == 'mentor' || badge == 'ambassador')
      return Icon(
        badge == 'mentor' ? Icons.school_outlined : Icons.public,
        color: color,
        size: size,
      );
    final symbol = switch (badge) {
      'beginner' => '\u2726',
      'consistent' => '\u25c8',
      'veteran' => '\u2605',
      'platinum' => '\u265c',
      'ruby' => '\u2666',
      _ => '\u25c7',
    };
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(fontSize: size, height: 1, color: color),
        ),
      ),
    );
  }
}

// Vector version of the preview's U+26E8 shield-and-cross, independent of fonts.
class _GuardianPainter extends CustomPainter {
  const _GuardianPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 20, size.height / 20);
    final shield = Path()
      ..moveTo(4, 3)
      ..lineTo(16, 3)
      ..lineTo(16, 11)
      ..quadraticBezierTo(16, 15, 10, 18)
      ..quadraticBezierTo(4, 15, 4, 11)
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    final cross = Paint()..color = color;
    canvas.drawRect(const Rect.fromLTWH(9, 5, 2, 9), cross);
    canvas.drawRect(const Rect.fromLTWH(6.5, 7, 7, 2), cross);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GuardianPainter old) => old.color != color;
}
