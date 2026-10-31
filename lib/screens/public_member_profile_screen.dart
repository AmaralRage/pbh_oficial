import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/public_member_profile.dart';
import '../services/public_member_profile_service.dart';
import '../widgets/profile_identity_card.dart';
import '../widgets/profile_achievement_seals.dart';
import '../widgets/profile_theme_scope.dart';
import '../widgets/profile_background.dart';
import '../widgets/stat_card.dart';
import '../widgets/personal_goal_card.dart';
import '../services/personal_goal_service.dart';

class PublicMemberProfileScreen extends StatefulWidget {
  const PublicMemberProfileScreen({super.key, required this.userId});
  final String userId;
  @override
  State<PublicMemberProfileScreen> createState() =>
      _PublicMemberProfileScreenState();
}

class _PublicMemberProfileScreenState extends State<PublicMemberProfileScreen>
    with WidgetsBindingObserver {
  final _service = PublicMemberProfileService();
  StreamSubscription<AuthState>? _auth;
  PublicMemberProfile? _profile;
  bool _loading = true;
  bool _failed = false;
  bool _showAll = false;
  int _version = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = _service.client.auth.onAuthStateChange.listen((_) {
      if (mounted) _load();
    });
    _load();
  }

  Future<void> _load() async {
    final version = ++_version;
    setState(() {
      _loading = true;
      _failed = false;
      _profile = null;
      _showAll = false;
    });
    try {
      final profile = await _service.fetch(widget.userId);
      if (!mounted || version != _version) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (mounted && version == _version)
        setState(() {
          _loading = false;
          _failed = true;
        });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? false))
      _load();
  }

  @override
  void dispose() {
    _auth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null)
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil do membro')),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _failed ? Icons.cloud_off_outlined : Icons.lock_outline,
                        size: 42,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _failed
                            ? 'Não foi possível carregar este perfil.'
                            : 'Este perfil não está disponível para visualização.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    final highlights = profile.style.highlights(profile.earned);
    return ProfileThemeScope(
      themeId: profile.style.profileTheme,
      founder: profile.founder,
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            profile.isOwn ? 'Seu perfil público' : 'Perfil do membro',
          ),
        ),
        body: ProfileBackground(
          style: profile.style,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              children: [
                ProfileIdentityCard(
                  name: profile.name,
                  bio: profile.bio,
                  style: profile.style,
                  earned: profile.earned,
                  avatarUrl: profile.avatarUrl,
                  coverUrl: profile.coverUrl,
                  founder: profile.founder,
                ),
                const SizedBox(height: 22),
                PublicGoalCard(
                  key: ValueKey('goal-${profile.id}-$_version'),
                  userId: profile.id,
                  service: PersonalGoalService(client: _service.client),
                ),
                if (!profile.hasProgress)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.pbhColors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Este membro prefere manter seu progresso e suas conquistas privados.',
                    ),
                  ),
                if (profile.isOwn && !profile.progressShared)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      'Somente você vê os números e selos abaixo. Ative “Compartilhar progresso e conquistas” em Privacidade para mostrá-los aos outros membros.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                if (profile.hasProgress) ...[
                  Row(
                    children: [
                      StatCard(
                        icon: Icons.flag_outlined,
                        value: '${profile.completed}',
                        label: 'Desafios\nconcluídos',
                      ),
                      const SizedBox(width: 12),
                      StatCard(
                        icon: Icons.groups_outlined,
                        value: '${profile.followers}',
                        label: 'Pessoas que\nacompanham',
                      ),
                      const SizedBox(width: 12),
                      StatCard(
                        icon: Icons.emoji_events_outlined,
                        value: '${profile.earned.length}',
                        label: 'Selos\nconquistados',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Selos em destaque', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 14),
                  if (highlights.isEmpty)
                    Text(
                      'Nenhum selo em destaque por enquanto.',
                      style: AppTextStyles.bodySmall,
                    )
                  else
                    ProfileAchievementSeals(achievements: highlights),
                  const SizedBox(height: 20),
                  if (profile.earned.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Todas as conquistas'),
                      onExpansionChanged: (open) =>
                          setState(() => _showAll = open),
                      children: [
                        if (_showAll)
                          ProfileAchievementSeals(achievements: profile.earned),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
