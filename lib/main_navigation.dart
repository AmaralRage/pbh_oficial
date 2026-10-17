import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_colors.dart';
import 'screens/challenges_screen.dart';
import 'screens/community_screen.dart';
import 'screens/content_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/home_screen.dart';
import 'screens/launch_screen.dart';
import 'screens/music_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_announcements_screen.dart';
import 'services/announcement_service.dart';
import 'services/habit_service.dart';
import 'services/notification_sound.dart';
import 'screens/settings_screens.dart';
import 'core/navigation/app_transitions.dart';
import 'widgets/pbh_app_drawer.dart';
import 'widgets/pbh_app_header.dart';
import 'widgets/pbh_bottom_nav.dart';
import 'widgets/spotify_playback_dock.dart';

/// Widget raiz que controla a navegação principal do app (bottom nav).
/// Cada aba mantém seu próprio estado ao trocar de tela (IndexedStack).
class MainNavigation extends StatefulWidget {
  final int initialIndex;
  final bool isAdmin;
  final bool isAuthenticated;
  final VoidCallback? onOpenSignIn;

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
    this.isAdmin = false,
    this.isAuthenticated = false,
    this.onOpenSignIn,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const _sectionNames = ['Início', 'Desafios', 'Conteúdo', 'Música', 'Comunidade', 'Perfil'];
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;
  int _previousIndex = 0;
  int _unreadNotifications = 0;
  int _notificationPulseKey = 0;
  int _habitMigrationGeneration = 0;
  bool _notificationAlertsEnabled = true;
  bool _notificationSoundEnabled = true;
  RealtimeChannel? _announcementChannel;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (widget.isAuthenticated) {
      _connectNotifications();
      _migrateGuestHabitHistory();
    }
  }

  @override
  void didUpdateWidget(covariant MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isAuthenticated && widget.isAuthenticated) {
      _connectNotifications();
      _migrateGuestHabitHistory();
    } else if (oldWidget.isAuthenticated && !widget.isAuthenticated) {
      _disconnectNotifications();
    }
  }

  Future<void> _migrateGuestHabitHistory() async {
    try {
      await HabitService().migrateGuestHistory();
      if (mounted) setState(() => _habitMigrationGeneration++);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível transferir seus hábitos de visitante. Eles continuam salvos neste dispositivo.'),
          action: SnackBarAction(label: 'Tentar', onPressed: _migrateGuestHabitHistory),
        ),
      );
    }
  }

  void _connectNotifications() {
    _loadNotificationPreferences();
    _refreshUnreadNotifications();
    _announcementChannel = Supabase.instance.client
        .channel('announcements-${Supabase.instance.client.auth.currentUser?.id ?? 'user'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            final sender = payload.newRecord['created_by'] as String?;
            final currentUser = Supabase.instance.client.auth.currentUser?.id;
            if (sender != null && sender != currentUser && mounted && _notificationAlertsEnabled) {
              setState(() {
                _unreadNotifications++;
                _notificationPulseKey++;
              });
              if (_notificationSoundEnabled && payload.newRecord['sound_enabled'] != false) {
                NotificationSound.play();
              }
            } else {
              _refreshUnreadNotifications();
            }
          },
        )
        .subscribe();
  }

  void _disconnectNotifications() {
    final channel = _announcementChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    _announcementChannel = null;
    _unreadNotifications = 0;
  }

  @override
  void dispose() {
    final channel = _announcementChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }

  Future<void> _refreshUnreadNotifications() async {
    if (!widget.isAuthenticated) return;
    try {
      if (!_notificationAlertsEnabled) {
        if (mounted) setState(() => _unreadNotifications = 0);
        return;
      }
      final count = await AnnouncementService().unreadCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {
      if (mounted) setState(() => _unreadNotifications = 0);
    }
  }

  Future<void> _loadNotificationPreferences() async {
    final values = await Future.wait([
      NotificationPreferences.enabled,
      NotificationPreferences.sound,
    ]);
    if (!mounted) return;
    setState(() {
      _notificationAlertsEnabled = values[0];
      _notificationSoundEnabled = values[1];
    });
    _refreshUnreadNotifications();
  }

  Future<void> _openSettingsScreen(Widget screen, {bool refreshNotifications = false}) async {
    await Navigator.of(context).push<void>(fadeSlideRoute<void>(screen));
    if (!mounted) return;
    if (refreshNotifications) {
      await _loadNotificationPreferences();
    } else {
      setState(() {});
    }
  }

  void _goTo(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _openHabits() {
    Navigator.of(context).push(
      fadeSlideRoute(HabitsScreen(onNavigate: _goTo)),
    );
  }

  void _returnToLaunch() {
    Navigator.of(context).pushAndRemoveUntil(
      fadeSlideRoute(const LaunchScreen()),
      (route) => false,
    );
  }

  Future<void> _accountAction() async {
    if (widget.isAuthenticated) {
      await Supabase.instance.client.auth.signOut();
    } else {
      widget.onOpenSignIn?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionNames = [..._sectionNames, if (widget.isAdmin) 'Admin'];
    final accountKey = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final screens = <Widget>[
      HomeScreen(key: ValueKey('home-$accountKey-$_habitMigrationGeneration'), onNavigate: _goTo),
      ChallengesScreen(
        key: ValueKey('challenges-$accountKey'),
        isAuthenticated: widget.isAuthenticated,
        onRequireLogin: () => widget.onOpenSignIn?.call(),
      ),
      const ContentScreen(),
      const MusicScreen(),
      CommunityScreen(
        key: ValueKey('community-$accountKey'),
        isAuthenticated: widget.isAuthenticated,
        onRequireLogin: () => widget.onOpenSignIn?.call(),
      ),
      ProfileScreen(
        key: ValueKey('profile-$accountKey'),
        isAdmin: widget.isAdmin,
        isAuthenticated: widget.isAuthenticated,
        onOpenSignIn: widget.onOpenSignIn,
        onEditProfile: widget.isAuthenticated ? () => _openSettingsScreen(const EditProfileScreen()) : null,
        onOpenNotificationSettings: widget.isAuthenticated
            ? () => _openSettingsScreen(const NotificationSettingsScreen(), refreshNotifications: true)
            : null,
        onOpenPrivacy: widget.isAuthenticated ? () => _openSettingsScreen(const PrivacySettingsScreen()) : null,
        onOpenHelp: () => _openSettingsScreen(const HelpSupportScreen()),
      ),
    ];
    if (widget.isAdmin) screens.add(const AdminAnnouncementsScreen());

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: PbhAppDrawer(
        currentIndex: _currentIndex,
        onNavigate: _goTo,
        onOpenHabits: _openHabits,
        onAccountAction: _accountAction,
        isAuthenticated: widget.isAuthenticated,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PbhAppHeader(
              currentSection: sectionNames[_currentIndex],
              onMenuPressed: _openMenu,
              onLogoPressed: _returnToLaunch,
              unreadNotifications: _unreadNotifications,
              notificationPulseKey: _notificationPulseKey,
              onNotificationsChanged: _refreshUnreadNotifications,
              showNotifications: widget.isAuthenticated,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                reverseDuration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  final isForward = _currentIndex >= _previousIndex;
                  final offset = Tween<Offset>(
                    begin: Offset(isForward ? 0.08 : -0.08, 0),
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_currentIndex),
                  child: screens[_currentIndex],
                ),
              ),
            ),
            const SpotifyPlaybackDock(),
          ],
        ),
      ),
      bottomNavigationBar: PbhBottomNav(
        currentIndex: _currentIndex,
        onTap: _goTo,
        isAdmin: widget.isAdmin,
      ),
    );
  }
}
