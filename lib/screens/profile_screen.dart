import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/animated_entry.dart';
import '../widgets/stat_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static final _streakStartDate = DateTime(2020, 2, 23);

  static const _achievements = [
    (icon: Icons.emoji_events, label: '30 Dias', unlocked: true),
    (icon: Icons.local_fire_department, label: 'Sequência\n20+', unlocked: true),
    (icon: Icons.self_improvement, label: 'Mente\nFocada', unlocked: true),
    (icon: Icons.fitness_center, label: 'Corpo de\nFerro', unlocked: false),
    (icon: Icons.menu_book, label: 'Leitor\nAssíduo', unlocked: false),
    (icon: Icons.groups, label: 'Mentor', unlocked: false),
  ];

  @override
  Widget build(BuildContext context) {
    final streakDays = DateTime.now().difference(_streakStartDate).inDays;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Perfil', style: AppTextStyles.headline),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Configurações em construção.')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedEntry(
            delayMs: 80,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Hero(
                    tag: 'profile-photo',
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.orange, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange.withOpacity(0.28),
                            blurRadius: 24,
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/profile_photo.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lider Amaral', style: AppTextStyles.titleLarge),
                        const SizedBox(height: 4),
                        Text('Membro desde Jan 2026', style: AppTextStyles.bodySmall),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.orangeDim,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('NÍVEL 7 · DISCIPLINADO', style: AppTextStyles.eyebrow),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedEntry(
            delayMs: 140,
            child: Row(
              children: [
                StatCard(icon: Icons.local_fire_department, value: '$streakDays', label: 'Dias de\nsequência'),
                const SizedBox(width: 12),
                const StatCard(icon: Icons.flag, value: '28', label: 'Desafios\nconcluídos'),
                const SizedBox(width: 12),
                const StatCard(icon: Icons.emoji_events, value: '46', label: 'Conquistas'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AnimatedEntry(
            delayMs: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conquistas', style: AppTextStyles.titleMedium),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _achievements.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final a = _achievements[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: a.unlocked ? AppColors.orange.withOpacity(0.4) : AppColors.borderSubtle,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            a.icon,
                            size: 26,
                            color: a.unlocked ? AppColors.orange : AppColors.textTertiary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            a.label,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.statLabel.copyWith(
                              color: a.unlocked ? AppColors.textPrimary : AppColors.textTertiary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AnimatedEntry(
            delayMs: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configurações', style: AppTextStyles.titleMedium),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Column(
                    children: [
                      _SettingsRow(icon: Icons.person_outline, label: 'Editar perfil'),
                      _SettingsRow(icon: Icons.notifications_none, label: 'Notificações'),
                      _SettingsRow(icon: Icons.lock_outline, label: 'Privacidade'),
                      _SettingsRow(icon: Icons.help_outline, label: 'Ajuda e suporte', isLast: true),
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

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLast;

  const _SettingsRow({required this.icon, required this.label, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: InkWell(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label em construção.')),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary))),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
