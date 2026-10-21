import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/launch_screen.dart';
import 'screens/app_startup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PbhOficialApp());
}

Future<void> initializeApp() async {
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
    } catch (_) {
      // Clean up a partially initialized client before another attempt.
      // The persisted session is kept on the device.
      if (Supabase.instance.isInitialized) {
        await Supabase.instance.dispose();
      }
      rethrow;
    }
  }
}

class PbhOficialApp extends StatelessWidget {
  const PbhOficialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PBH Oficial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppStartupScreen(
        initialize: initializeApp,
        child: LaunchScreen(),
      ),
    );
  }
}
