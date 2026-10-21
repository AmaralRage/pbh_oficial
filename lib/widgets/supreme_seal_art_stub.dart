import 'package:flutter/material.dart';
import '../models/profile_achievement.dart';

class SupremeSealArt extends StatelessWidget {
  const SupremeSealArt({
    super.key,
    required this.size,
    required this.achievement,
  });
  final double size;
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
