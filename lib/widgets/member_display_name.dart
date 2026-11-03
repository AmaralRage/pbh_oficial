import 'member_badge_icon.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// The caller must supply the verified founder flag, never a display-name match.
class MemberDisplayName extends StatelessWidget {
  const MemberDisplayName({
    super.key,
    required this.name,
    required this.founder,
    required this.style,
    this.compact = true,
    this.showBadge = true,
    this.memberBadge,
  });
  final String name;
  final String? memberBadge;
  final bool founder, compact, showBadge;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    if (!showBadge)
      return Text(
        name,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    final label = switch (memberBadge) {
      'guardian' => 'Guardi\u00e3o',
      'mentor' => 'Mentor',
      'beginner' => 'Iniciante',
      'consistent' => 'Constante',
      'veteran' => 'Veterano',
      'ambassador' => 'Embaixador',
      _ => 'Membro',
    };
    final badgeColor = founder
        ? const Color(0xFFFFD27A)
        : memberBadge == 'guardian'
        ? const Color(0xFFDFC2FF)
        : switch (memberBadge) {
            'beginner' => const Color(0xFFE0A779),
            'consistent' => const Color(0xFF69E8CB),
            'veteran' => const Color(0xFFA5C2FF),
            'mentor' => const Color(0xFFA5C2FF),
            'ambassador' => const Color(0xFF69E8CB),
            _ => context.pbhColors.textSecondary,
          };
    final badgeBackground = !founder && memberBadge == 'guardian'
        ? const Color(0xFF321147)
        : badgeColor.withValues(alpha: .1);
    final badgeBorder = !founder && memberBadge == 'guardian'
        ? const Color(0xFF80509F)
        : badgeColor.withValues(alpha: .4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: founder
              ? 'Líder e fundador do Projeto Bom Homem'
              : 'Membro da comunidade PBH',
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  founder ? 'L\u00edder' : label,
                  style: TextStyle(
                    fontSize: compact ? 9 : 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                    letterSpacing: .3,
                  ),
                ),
                if (!founder) ...[
                  const SizedBox(width: 4),
                  MemberBadgeIcon(
                    badge: memberBadge,
                    size: compact ? 12 : 15,
                    color: badgeColor,
                  ),
                ],
                if (founder) ...[
                  const SizedBox(width: 4),
                  SizedBox.square(
                    dimension: compact ? 13 : 17,
                    child: CustomPaint(painter: _KingCrownPainter(badgeColor)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KingCrownPainter extends CustomPainter {
  const _KingCrownPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 20, size.height / 20);
    final paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(3, 15)
        ..lineTo(1, 7)
        ..lineTo(6, 10)
        ..lineTo(10, 4)
        ..lineTo(14, 10)
        ..lineTo(19, 7)
        ..lineTo(17, 15)
        ..close(),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 16, 14, 2),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRect(const Rect.fromLTWH(9.2, 0, 1.6, 5), paint);
    canvas.drawRect(const Rect.fromLTWH(7.5, 1.5, 5, 1.5), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KingCrownPainter old) => old.color != color;
}
