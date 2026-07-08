import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/launch_screen.dart';

void main() {
  runApp(const PbhOficialApp());
}

class PbhOficialApp extends StatelessWidget {
  const PbhOficialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PBH Oficial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const LaunchScreen(),
    );
  }
}
