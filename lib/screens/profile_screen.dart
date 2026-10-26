import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/challenge_model.dart';
import '../models/profile_achievement.dart';
import '../models/profile_style.dart';
import '../widgets/profile_identity_card.dart';
import '../widgets/profile_theme_scope.dart';
import '../widgets/personal_goal_card.dart';
import 'appearance_screen.dart';
import '../services/auth_service.dart';
import '../services/profile_achievement_service.dart';
import '../services/challenge_service.dart';
import '../services/community_service.dart';
import '../services/habit_service.dart';
import '../widgets/animated_entry.dart';
import '../widgets/stat_card.dart';
import '../widgets/profile_achievement_seals.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.isAdmin = false,
    this.isAuthenticated = true,
    this.onOpenSignIn,
    this.onEditProfile,
    this.onOpenNotificationSettings,
    this.onOpenPrivacy,
    this.onOpenHelp,
  });

  final bool isAdmin;
  final bool isAuthenticated;
  final VoidCallback? onOpenSignIn;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenNotificationSettings;
  final VoidCallback? onOpenPrivacy;
  final VoidCallback? onOpenHelp;

  @override
  Widget build(BuildContext context) {
    return ProfileThemeScope(
      builder: (context) => SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('Perfil', style: AppTextStyles.brandHeadline),
            const SizedBox(height: 20),
            if (!isAuthenticated) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.pbhColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.pbhColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: context.pbhColors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modo visitante',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Você pode explorar o app sem uma conta.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenSignIn,
                      child: const Text('Entrar'),
                    ),
                  ],
                ),
              ),
            ],
            _ProfileProgress(onEdit: onEditProfile),
            const SizedBox(height: 16),
            PersonalGoalCard(
              isAuthenticated: isAuthenticated,
              onSignIn: onOpenSignIn,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppearanceScreen(),
                ),
              ),
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Aparência do app'),
            ),
            const SizedBox(height: 26),
            if (isAuthenticated)
              AnimatedEntry(
                delayMs: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: context.pbhColors.orange,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Text('Configurações', style: AppTextStyles.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: context.pbhColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.pbhColors.borderSubtle,
                        ),
                      ),
                      child: Column(
                        children: [
                          _SettingsRow(
                            icon: Icons.person_outline,
                            label: 'Editar perfil',
                            subtitle: 'Foto, capa, moldura e selos em destaque',
                            onTap: onEditProfile,
                          ),
                          _SettingsRow(
                            icon: Icons.notifications_none_rounded,
                            label: 'Notificações',
                            subtitle: 'Alertas e som do app',
                            onTap: onOpenNotificationSettings,
                          ),
                          _SettingsRow(
                            icon: Icons.lock_outline_rounded,
                            label: 'Privacidade',
                            subtitle: 'Dados da conta e segurança',
                            onTap: onOpenPrivacy,
                          ),
                          _SettingsRow(
                            icon: Icons.help_outline_rounded,
                            label: 'Ajuda e suporte',
                            subtitle: 'Respostas e opções de contato',
                            isLast: true,
                            onTap: onOpenHelp,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileProgress extends StatefulWidget {
  const _ProfileProgress({this.onEdit});
  final VoidCallback? onEdit;
  @override
  State<_ProfileProgress> createState() => _ProfileProgressState();
}

class _ProfileProgressState extends State<_ProfileProgress> {
  int _streak = 0;
  int _completedChallenges = 0;
  int _totalChallenges = 0;
  Set<String> _manualAwards = {};
  int _followers = 0;
  Set<String> _completedChallengeIds = {};
  bool _loading = true;
  bool _hasProgress = false;
  bool _refreshing = false;
  bool _loadFailed = false;
  bool? _tabActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && _tabActive == false) _load();
    _tabActive = active;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _loadFailed = false;
    });
    try {
      final values = await Future.wait([
        HabitService().streak(),
        ChallengeService().fetchChallenges(),
        CommunityService().followerCount(),
        ProfileAchievementService().manualAwards(),
      ]);
      if (!mounted) return;
      final challenges = values[1] as List<ChallengeModel>;
      final completed = challenges
          .where((challenge) => challenge.status == ChallengeStatus.completed)
          .toList();
      setState(() {
        final isProjectLeader = AuthService.isProjectLeader(
          Supabase.instance.client.auth.currentUser,
        );
        final today = DateTime.now();
        _streak = isProjectLeader
            ? DateTime.utc(
                    today.year,
                    today.month,
                    today.day,
                  ).difference(DateTime.utc(2021, 1, 1)).inDays +
                  1
            : values[0] as int;
        _completedChallenges = completed.length;
        _totalChallenges = challenges.length;
        _manualAwards = values[3] as Set<String>;
        _completedChallengeIds = completed
            .map((challenge) => challenge.id)
            .toSet();
        _followers = values[2] as int;
        _loading = false;
        _hasProgress = true;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProjectLeader = AuthService.isProjectLeader(
      Supabase.instance.client.auth.currentUser,
    );
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    final achievements = ProfileAchievement.earned(
      isAuthenticated: isAuthenticated,
      isProjectLeader: isProjectLeader,
      streak: _streak,
      completedChallenges: _completedChallenges,
      totalChallenges: _totalChallenges,
      followers: _followers,
      completedIds: _completedChallengeIds,
      manualAwards: _manualAwards,
    );
    final metadata =
        Supabase.instance.client.auth.currentUser?.userMetadata ??
        <String, dynamic>{};
    final style = ProfileStyle.fromMetadata(metadata, founder: isProjectLeader)
        .validated(
          founder: isProjectLeader,
          completed: _completedChallenges,
          earned: achievements,
        );
    final name = (metadata['display_name'] as String?)?.trim();
    final identity = ProfileIdentityCard(
      name: isAuthenticated
          ? (name?.isNotEmpty == true
                ? name!
                : isProjectLeader
                ? 'Amaral'
                : 'Sua conta')
          : 'Visitante',
      bio: metadata['bio'] as String? ?? '',
      avatarUrl: metadata['avatar_url'] as String?,
      coverUrl: metadata['cover_url'] as String?,
      founder: isProjectLeader,
      style: style,
      earned: achievements,
      onEdit: widget.onEdit,
    );
    if (_loading)
      return Column(
        children: [
          identity,
          const Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(),
          ),
        ],
      );
    final failureNotice = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            _refreshing
                ? 'Atualizando seu progresso…'
                : _hasProgress
                ? 'Não foi possível atualizar seu progresso. Os últimos dados carregados continuam abaixo.'
                : 'Não foi possível carregar seu progresso. Suas conquistas não foram apagadas.',
            style: AppTextStyles.bodySmall,
          ),
          TextButton.icon(
            onPressed: _refreshing ? null : _load,
            icon: const Icon(Icons.refresh),
            label: Text(_refreshing ? 'Atualizando…' : 'Tentar novamente'),
          ),
        ],
      ),
    );
    if (!_hasProgress) return Column(children: [identity, failureNotice]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        identity,
        const SizedBox(height: 22),
        if (_loadFailed || _refreshing) failureNotice,
        Row(
          children: [
            if (isAuthenticated) ...[
              StatCard(
                icon: Icons.local_fire_department,
                value: '$_streak',
                label: isProjectLeader
                    ? 'Dias do\nprojeto'
                    : 'Dias de\nsequência',
              ),
              const SizedBox(width: 12),
            ],
            StatCard(
              icon: Icons.flag,
              value: '$_completedChallenges',
              label: 'Desafios\nconcluídos',
            ),
            const SizedBox(width: 12),
            StatCard(
              icon: Icons.emoji_events,
              value: '${achievements.length}',
              label: 'Selos\nconquistados',
            ),
          ],
        ),
        const SizedBox(height: 26),
        if (style.highlights(achievements).isNotEmpty) ...[
          Text('Selos em destaque', style: AppTextStyles.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Os marcos que você escolheu para contar sua história.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 14),
          ProfileAchievementSeals(achievements: style.highlights(achievements)),
          const SizedBox(height: 26),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Selos de dedicação',
                style: AppTextStyles.titleMedium,
              ),
            ),
            if (isProjectLeader)
              IconButton(
                tooltip: 'Conceder selo supremo',
                icon: Icon(
                  Icons.add_moderator_outlined,
                  color: context.pbhColors.orange,
                ),
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (_) => const GrantProfileSealDialog(),
                  );
                  if (mounted) _load();
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Sua dedicação deixa marcas. Toque em um selo para conhecer sua história.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 14),
        ProfileAchievementSeals(achievements: achievements),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: isLast
          ? null
          : Border(bottom: BorderSide(color: context.pbhColors.borderSubtle)),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.pbhColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: context.pbhColors.textSecondary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        color: context.pbhColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTextStyles.statLabel.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.pbhColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
