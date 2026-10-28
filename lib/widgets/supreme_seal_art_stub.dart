import 'package:flutter/material.dart';
import '../models/profile_achievement.dart';

class SupremeSealArt extends StatelessWidget {
  static Future<void> warmUp() async {}
  const SupremeSealArt({
    super.key,
    required this.size,
    required this.achievement,
    this.celebrate = false,
    this.onAnimationStarted,
  });
  final double size;
  final bool celebrate;
  final VoidCallback? onAnimationStarted;
  final ProfileAchievement achievement;
  @override
  Widget build(BuildContext context) => Image.asset(
    achievement.artAsset!,
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'Arte: ${achievement.title}',
  );
}
