import 'package:flutter/material.dart';
import 'dart:async';
import 'services/private_support_service.dart';
import 'services/community_post_navigation.dart';
import 'screens/community_publication_screen.dart';
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
import 'widgets/retained_tab_view.dart';

/// Widget raiz que controla a navegação principal do app (bottom nav).
/// Cada aba mantém seu próprio estado ao trocar de tela (IndexedStack).
class MainNavigation extends StatefulWidget {
  final int initialIndex;
  final bool openHabitsInitially;
  final bool isAdmin;
  final bool isAuthenticated;
  final VoidCallback? onOpenSignIn;

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
    this.openHabitsInitially = false,
    this.isAdmin = false,
    this.isAuthenticated = false,
    this.onOpenSignIn,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  Timer? _supportTimer;
  bool _countLoading = false;
  bool _openingPost = false;
  void _handlePostLink() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openPendingPost();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openPendingPost() async {
    if (_openingPost || !mounted) return;
    final id = CommunityPostNavigation.pending.value;
    if (id == null) return;
    CommunityPostNavigation.pending.value = null;
    _openingPost = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CommunityPublicationScreen(postId: id),
        ),
      );
    } finally {
      _openingPost = false;
      if (mounted && CommunityPostNavigation.pending.value != null)
        _openPendingPost();
    }
  }

  static const _sectionNames = [
    'Início',
    'Desafios',
    'Conteúdo',
    'Música',
    'Comunidade',
    'Perfil',
  ];
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;
  int _unreadNotifications = 0;
  int _notificationPulseKey = 0;
  int _habitMigrationGeneration = 0;
  bool _notificationAlertsEnabled = true;
  bool _notificationSoundEnabled = true;
  RealtimeChannel? _announcementChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CommunityPostNavigation.pending.addListener(_handlePostLink);
    final link = Uri.base.queryParameters['community_post'];
    if (link != null && validCommunityPostId(link))
      CommunityPostNavigation.pending.value = link;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openPendingPost();
    });
    _currentIndex = widget.initialIndex;
    if (widget.openHabitsInitially) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openHabits();
      });
    }
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
          content: const Text(
            'Não foi possível transferir seus hábitos de visitante. Eles continuam salvos neste dispositivo.',
          ),
          action: SnackBarAction(
            label: 'Tentar',
            onPressed: _migrateGuestHabitHistory,
          ),
        ),
      );
    }
  }

  void _connectNotifications() {
    _supportTimer?.cancel();
    _supportTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)
        _refreshUnreadNotifications();
    });
    _loadNotificationPreferences();
    _refreshUnreadNotifications();
    _announcementChannel = Supabase.instance.client
        .channel(
          'announcements-${Supabase.instance.client.auth.currentUser?.id ?? 'user'}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            final sender = payload.newRecord['created_by'] as String?;
            final currentUser = Supabase.instance.client.auth.currentUser?.id;
            if (sender != null &&
                sender != currentUser &&
                mounted &&
                _notificationAlertsEnabled) {
              setState(() {
                _unreadNotifications++;
                _notificationPulseKey++;
              });
              if (_notificationSoundEnabled &&
                  payload.newRecord['sound_enabled'] != false) {
                NotificationSound.play();
              }
            } else {
              _refreshUnreadNotifications();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'announcements',
          callback: (_) => _refreshUnreadNotifications(),
        )
        .subscribe();
  }

  void _disconnectNotifications() {
    _supportTimer?.cancel();
    final channel = _announcementChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    _announcementChannel = null;
    _unreadNotifications = 0;
  }

  @override
  void dispose() {
    CommunityPostNavigation.pending.removeListener(_handlePostLink);
    _supportTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final channel = _announcementChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }

  Future<void> _refreshUnreadNotifications() async {
    if (!widget.isAuthenticated || _countLoading) return;
    final account = Supabase.instance.client.auth.currentUser?.id;
    _countLoading = true;
    try {
      if (!_notificationAlertsEnabled) {
        if (mounted) setState(() => _unreadNotifications = 0);
        return;
      }
      final counts = await Future.wait([
        AnnouncementService().unreadCount().catchError((_) => 0),
        PrivateSupportService().unreadCount().catchError((_) => 0),
      ]);
      if (mounted && account == Supabase.instance.client.auth.currentUser?.id)
        setState(() => _unreadNotifications = counts[0] + counts[1]);
    } catch (_) {
      if (mounted && account == Supabase.instance.client.auth.currentUser?.id)
        setState(() => _unreadNotifications = 0);
    } finally {
      _countLoading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshUnreadNotifications();
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

  Future<void> _openSettingsScreen(
    Widget screen, {
    bool refreshNotifications = false,
  }) async {
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
      _currentIndex = index;
    });
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _openHabits() {
    Navigator.of(context).push(fadeSlideRoute(_buildHabitsScreen()));
  }

  HabitsScreen _buildHabitsScreen() => HabitsScreen(
    onNavigate: _goTo,
    currentIndex: _currentIndex,
    isAuthenticated: widget.isAuthenticated,
    isAdmin: widget.isAdmin,
    unreadNotifications: _unreadNotifications,
    notificationPulseKey: _notificationPulseKey,
    onLogoPressed: _returnToLaunch,
    onAccountAction: _accountAction,
    onNotificationsChanged: _refreshUnreadNotifications,
    onRequireLogin: widget.onOpenSignIn,
  );

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
      HomeScreen(
        key: ValueKey('home-$accountKey-$_habitMigrationGeneration'),
        onNavigate: _goTo,
        onOpenHabits: _openHabits,
      ),
      ChallengesScreen(
        key: ValueKey('challenges-$accountKey'),
        isAuthenticated: widget.isAuthenticated,
        onRequireLogin: () => widget.onOpenSignIn?.call(),
      ),
      ContentScreen(
        key: ValueKey('content-$accountKey'),
        isAdmin: widget.isAdmin,
      ),
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
        onEditProfile: widget.isAuthenticated
            ? () => _openSettingsScreen(const EditProfileScreen())
            : null,
        onOpenNotificationSettings: widget.isAuthenticated
            ? () => _openSettingsScreen(
                const NotificationSettingsScreen(),
                refreshNotifications: true,
              )
            : null,
        onOpenPrivacy: widget.isAuthenticated
            ? () => _openSettingsScreen(const PrivacySettingsScreen())
            : null,
        onOpenHelp: () => _openSettingsScreen(const HelpSupportScreen()),
      ),
    ];
    if (widget.isAdmin) screens.add(const AdminAnnouncementsScreen());

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.pbhColors.background,
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
              child: RetainedTabView(
                key: ValueKey(accountKey),
                index: _currentIndex,
                children: screens,
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
