import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth_gate.dart';

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
      home: AuthGate(supabaseConfigured: supabaseConfigured),
    );
  }
}
