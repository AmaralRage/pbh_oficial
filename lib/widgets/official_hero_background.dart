import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class OfficialHeroBackground extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;
  final Alignment imageAlignment;
  final BoxFit fit;
  final double darken;

  const OfficialHeroBackground({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.imageAlignment = Alignment.center,
    this.fit = BoxFit.cover,
    this.darken = 0.24,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/pbh_official_hero.png',
            fit: fit,
            alignment: imageAlignment,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.12 + darken),
                  AppColors.background.withOpacity(0.38 + darken),
                  AppColors.background.withOpacity(0.74 + darken),
                ],
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
