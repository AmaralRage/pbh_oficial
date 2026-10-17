import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/launch_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
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
