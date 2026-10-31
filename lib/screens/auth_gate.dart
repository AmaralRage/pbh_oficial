import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/navigation/app_transitions.dart';
import '../main_navigation.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'welcome_screen.dart';
import '../services/welcome_preferences.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.supabaseConfigured,
    this.initialIndex = 0,
    this.openHabitsInitially = false,
  });
  final int initialIndex;
  final bool openHabitsInitially;

  final bool supabaseConfigured;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthService? _authService;
  String? _adminUid;
  Future<List<bool>>? _adminFuture;
  final _welcomed = <String>{};
  WelcomeFocus? _welcomeFocus;
  bool _passwordRecovery = false;
  bool _initialHabitsConsumed = false;
  bool _takeInitialHabits() {
    if (_initialHabitsConsumed) return false;
    _initialHabitsConsumed = true;
    return _welcomeFocus == WelcomeFocus.habits || widget.openHabitsInitially;
  }

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
          _welcomeFocus = null;
          _initialHabitsConsumed = false;
        }
        if (_passwordRecovery) return const PasswordRecoveryScreen();

        final session = snapshot.data?.session ?? authService.currentSession;
        if (session == null) {
          return MainNavigation(
            initialIndex: widget.initialIndex,
            openHabitsInitially: _takeInitialHabits(),
            isAuthenticated: false,
            onOpenSignIn: _openSignIn,
          );
        }

        final user = session.user;
        if (_adminUid != user.id || _adminFuture == null) {
          _adminUid = user.id;
          _welcomeFocus = null;
          _initialHabitsConsumed = false;
          _adminFuture = Future.wait([
            authService.isAdmin().catchError((_) => false),
            WelcomePreferences()
                .shouldShow(
                  user.id,
                  newlyCreated:
                      user.userMetadata?['pbh_welcome_pending'] == true,
                )
                .then((show) {
                  if (!show &&
                      user.userMetadata?['pbh_welcome_pending'] == true) {
                    // Retry an earlier completion that could only be saved locally.
                    unawaited(
                      authService
                          .completeWelcome(user.id)
                          .catchError((Object _) {}),
                    );
                  }
                  return show;
                }),
          ]);
        }
        return FutureBuilder<List<bool>>(
          future: _adminFuture,
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScreen();
            }
            if ((adminSnapshot.data?[1] ?? false) &&
                !_welcomed.contains(user.id)) {
              return WelcomeScreen(
                key: ValueKey(user.id),
                onFinish: (focus) async {
                  await WelcomePreferences().complete(user.id);
                  try {
                    await authService.completeWelcome(user.id);
                  } catch (_) {
                    // The per-account local flag prevents repeats if sync fails.
                  }
                  if (!mounted || authService.currentUser?.id != user.id)
                    return;
                  setState(() {
                    _welcomed.add(user.id);
                    _welcomeFocus = focus;
                    _initialHabitsConsumed = false;
                  });
                },
              );
            }
            return MainNavigation(
              initialIndex: _welcomeFocus == WelcomeFocus.learning
                  ? 2
                  : _welcomeFocus == WelcomeFocus.challenges
                  ? 1
                  : widget.initialIndex,
              openHabitsInitially: _takeInitialHabits(),
              isAdmin: adminSnapshot.data?[0] ?? false,
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
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
