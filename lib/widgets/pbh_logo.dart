import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class PbhLogo extends StatelessWidget {
  final double scale;
  final bool compact;

  const PbhLogo({
    super.key,
    this.scale = 1,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pbhSize = (compact ? 22.0 : 50.0) * scale;
    final officialSize = (compact ? 7.5 : 14.0) * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scaleX: 1.18,
          alignment: Alignment.center,
          child: Text(
            'PBH',
            style: GoogleFonts.orbitron(
              fontSize: pbhSize,
              fontWeight: FontWeight.w500,
              height: 0.9,
              letterSpacing: compact ? 1.8 : 2.4,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(height: compact ? 3 : 10),
        Text(
          'O F I C I A L',
          style: AppTextStyles.statLabel.copyWith(
            fontSize: officialSize,
            letterSpacing: compact ? 3.1 : 8.2,
            color: AppColors.textPrimary.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
