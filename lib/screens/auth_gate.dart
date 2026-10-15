import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/navigation/app_transitions.dart';
import '../main_navigation.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.supabaseConfigured});

  final bool supabaseConfigured;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthService? _authService;
  String? _adminUid;
  Future<bool>? _adminFuture;
  bool _passwordRecovery = false;

  void _openSignIn() {
    Navigator.of(context).push(
      fadeSlideRoute<void>(
        AuthScreen(onClose: () => Navigator.of(context).pop()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.supabaseConfigured) return const SupabaseSetupScreen();
    final authService = _authService ??= AuthService();

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final event = snapshot.data?.event;
        if (event == AuthChangeEvent.passwordRecovery) {
          _passwordRecovery = true;
        } else if (event == AuthChangeEvent.signedOut) {
          _passwordRecovery = false;
          _adminUid = null;
          _adminFuture = null;
        }
        if (_passwordRecovery) return const PasswordRecoveryScreen();

        final session = snapshot.data?.session ?? authService.currentSession;
        if (session == null) {
          return MainNavigation(
            isAuthenticated: false,
            onOpenSignIn: _openSignIn,
          );
        }

        final user = session.user;
        if (_adminUid != user.id || _adminFuture == null) {
          _adminUid = user.id;
          _adminFuture = authService.isAdmin().catchError((_) => false);
        }
        return FutureBuilder<bool>(
          future: _adminFuture,
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScreen();
            }
            return MainNavigation(
              isAdmin: adminSnapshot.data ?? false,
              isAuthenticated: true,
            );
          },
        );
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
