import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/launch_screen.dart';
import 'screens/app_startup_screen.dart';
import 'services/appearance_service.dart';
import 'services/mobile_push_service.dart';
import 'widgets/mobile_app_viewport.dart';

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
      await AppearanceService.instance.bind(Supabase.instance.client);
      await MobilePushService.bind(Supabase.instance.client);
    } catch (_) {
      // Clean up a partially initialized client before another attempt.
      // The persisted session is kept on the device.
      if (Supabase.instance.isInitialized) {
        await Supabase.instance.dispose();
      }
      rethrow;
    }
  }
  if (!SupabaseConfig.isConfigured) await AppearanceService.instance.bind(null);
}

class PbhOficialApp extends StatelessWidget {
  const PbhOficialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppearanceService.instance,
      builder: (context, _) => MaterialApp(
        title: 'PBH Oficial',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forPalette(AppearanceService.instance.palette),
        builder: (context, child) => MobileAppViewport(
          reduceEffects: AppearanceService.instance.reducedEffects,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const AppStartupScreen(
          initialize: initializeApp,
          child: LaunchScreen(),
        ),
      ),
    );
  }
}
