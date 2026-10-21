import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/challenge_model.dart';
import '../models/profile_achievement.dart';
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
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final name = (metadata['display_name'] as String?)?.trim();
    final bio = (metadata['bio'] as String?)?.trim();
    final displayName = isAdmin ? 'Amaral' : (name?.isNotEmpty == true ? name! : 'Sua conta');

    return SafeArea(
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: AppColors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Modo visitante', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 4),
                        Text('Você pode explorar o app sem uma conta.', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  TextButton(onPressed: onOpenSignIn, child: const Text('Entrar')),
                ],
              ),
            ),
          ],
          AnimatedEntry(
            delayMs: 60,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.orange, width: 2),
                      boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(.2), blurRadius: 20)],
                    ),
                    child: ClipOval(
                      child: isAuthenticated
                          ? Image.asset(
                              'assets/images/profile_photo.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (_, __, ___) => const _DefaultProfileAvatar(),
                            )
                          : const _DefaultProfileAvatar(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AppTextStyles.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (bio?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(bio!, style: AppTextStyles.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        if (!isAuthenticated) ...[
                          const SizedBox(height: 4),
                          Text('Visitante', style: AppTextStyles.bodySmall),
                        ] else if (isAdmin) ...[
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.workspace_premium_rounded, color: AppColors.orange, size: 13),
                                const SizedBox(width: 5),
                                Text('LÍDER DO PROJETO', style: AppTextStyles.eyebrow.copyWith(fontSize: 9, letterSpacing: .7)),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text('Membro da comunidade', style: AppTextStyles.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _ProfileProgress(),
          const SizedBox(height: 26),
          if (isAuthenticated) AnimatedEntry(
            delayMs: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.orange, size: 19),
                    const SizedBox(width: 8),
                    Text('Configurações', style: AppTextStyles.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.person_outline,
                        label: 'Editar perfil',
                        subtitle: 'Nome e descrição da sua conta',
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
    );
  }
}

class _ProfileProgress extends StatefulWidget {
  const _ProfileProgress();
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        HabitService().streak(),
        ChallengeService().fetchChallenges(),
        CommunityService().followerCount(),
        ProfileAchievementService().manualAwards(),
      ]);
      if (!mounted) return;
      final challenges = values[1] as List<ChallengeModel>;
      final completed = challenges.where((challenge) => challenge.status == ChallengeStatus.completed).toList();
      setState(() {
        final isProjectLeader = Supabase.instance.client.auth.currentUser?.email?.toLowerCase() == 'amaralaragao31@gmail.com';
        final today = DateTime.now();
        _streak = isProjectLeader
            ? DateTime.utc(today.year, today.month, today.day).difference(DateTime.utc(2021, 1, 1)).inDays + 1
            : values[0] as int;
        _completedChallenges = completed.length;
        _totalChallenges = challenges.length;
        _manualAwards = values[3] as Set<String>;
        _completedChallengeIds = completed.map((challenge) => challenge.id).toSet();
        _followers = values[2] as int;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProjectLeader = AuthService.isProjectLeader(Supabase.instance.client.auth.currentUser);
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    final achievements = ProfileAchievement.earned(
      isAuthenticated: isAuthenticated, isProjectLeader: isProjectLeader,
      streak: _streak, completedChallenges: _completedChallenges,
      totalChallenges: _totalChallenges, followers: _followers,
      completedIds: _completedChallengeIds, manualAwards: _manualAwards,
    );
    if (_loading) return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (isAuthenticated) ...[
          StatCard(icon: Icons.local_fire_department, value: '$_streak', label: isProjectLeader ? 'Dias do\nprojeto' : 'Dias de\nsequência'),
          const SizedBox(width: 12),
        ],
        StatCard(icon: Icons.flag, value: '$_completedChallenges', label: 'Desafios\nconcluídos'),
        const SizedBox(width: 12),
        StatCard(icon: Icons.emoji_events, value: '${achievements.length}', label: 'Selos\nconquistados'),
      ]),
      const SizedBox(height: 26),
      Row(children: [
        Expanded(child: Text('Selos de dedicação', style: AppTextStyles.titleMedium)),
        if (isProjectLeader) IconButton(
          tooltip: 'Conceder selo supremo',
          icon: const Icon(Icons.add_moderator_outlined, color: AppColors.orange),
          onPressed: () async {
            await showDialog<void>(context: context, builder: (_) => const GrantProfileSealDialog());
            if (mounted) _load();
          },
        ),
      ]),
      const SizedBox(height: 4),
      Text('Sua dedicação deixa marcas. Toque em um selo para conhecer sua história.', style: AppTextStyles.bodySmall),
      const SizedBox(height: 14),
      ProfileAchievementSeals(achievements: achievements),
    ]);
  }
}

class _DefaultProfileAvatar extends StatelessWidget {
  const _DefaultProfileAvatar();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Icon(
          Icons.person_outline_rounded,
          color: AppColors.textTertiary,
          size: 38,
        ),
      );
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
          border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
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
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 19, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
                        const SizedBox(height: 3),
                        Text(subtitle, style: AppTextStyles.statLabel.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
                ],
              ),
            ),
          ),
        ),
      );
}
