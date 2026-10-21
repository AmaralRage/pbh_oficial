import 'package:flutter/material.dart';
import '../models/profile_achievement.dart';
import 'native_seal_art.dart';

/// Avoids starting a browser engine when opening a trophy on mobile.
class SupremeSealArt extends StatelessWidget {
  const SupremeSealArt({
    super.key,
    required this.size,
    required this.achievement,
  });
  final double size;
  final ProfileAchievement achievement;
  @override
  Widget build(BuildContext context) =>
      NativeSealArt(size: size, achievement: achievement);
}
