import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/navigation/app_transitions.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth_gate.dart';
import 'screens/launch_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
  runApp(PbhOficialApp(supabaseConfigured: SupabaseConfig.isConfigured));
}

class PbhOficialApp extends StatelessWidget {
  final bool supabaseConfigured;

  const PbhOficialApp({super.key, required this.supabaseConfigured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PBH Oficial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: InitialLaunchGate(supabaseConfigured: supabaseConfigured),
    );
  }
}

/// Shows the welcome screen once, then restores the normal authenticated app.
class InitialLaunchGate extends StatefulWidget {
  const InitialLaunchGate({super.key, required this.supabaseConfigured});

  final bool supabaseConfigured;

  @override
  State<InitialLaunchGate> createState() => _InitialLaunchGateState();
}

class _InitialLaunchGateState extends State<InitialLaunchGate> {
  static const _welcomeSeenKey = 'pbh.welcome.seen';
  final _storage = SharedPreferencesAsync();
  late final Future<bool> _welcomeSeen = _storage.getBool(_welcomeSeenKey).then((value) => value ?? false);

  Future<void> _continueFromWelcome() async {
    try {
      await _storage.setBool(_welcomeSeenKey, true);
    } catch (_) {
      // Keep the welcome usable if local preferences are unavailable.
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      fadeSlideRoute(AuthGate(supabaseConfigured: widget.supabaseConfigured)),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _welcomeSeen,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const _AppStartingScreen();
          if (!(snapshot.data ?? false)) {
            return LaunchScreen(
              onStart: _continueFromWelcome,
            );
          }
          return AuthGate(supabaseConfigured: widget.supabaseConfigured);
        },
      );
}

class _AppStartingScreen extends StatelessWidget {
  const _AppStartingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
}
