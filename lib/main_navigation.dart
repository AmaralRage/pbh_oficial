import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'screens/challenges_screen.dart';
import 'screens/community_screen.dart';
import 'screens/content_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'core/navigation/app_transitions.dart';
import 'widgets/pbh_app_drawer.dart';
import 'widgets/pbh_app_header.dart';
import 'widgets/pbh_bottom_nav.dart';

/// Widget raiz que controla a navegação principal do app (bottom nav).
/// Cada aba mantém seu próprio estado ao trocar de tela (IndexedStack).
class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const _sectionNames = ['Início', 'Desafios', 'Conteúdo', 'Comunidade', 'Perfil'];
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _goTo),
      const ChallengesScreen(),
      const ContentScreen(),
      const CommunityScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: PbhAppDrawer(
        currentIndex: _currentIndex,
        onNavigate: _goTo,
        onOpenHabits: _openHabits,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PbhAppHeader(
              currentSection: _sectionNames[_currentIndex],
              onMenuPressed: _openMenu,
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
          ],
        ),
      ),
      bottomNavigationBar: PbhBottomNav(
        currentIndex: _currentIndex,
        onTap: _goTo,
      ),
    );
  }
}
