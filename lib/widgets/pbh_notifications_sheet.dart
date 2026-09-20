import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Central temporária de avisos do Projeto Bom Homem.
class PbhNotificationsSheet extends StatefulWidget {
  const PbhNotificationsSheet({super.key});

  @override
  State<PbhNotificationsSheet> createState() => _PbhNotificationsSheetState();
}

class _PbhNotificationsSheetState extends State<PbhNotificationsSheet> {
  bool _allRead = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: AppColors.inactive, borderRadius: BorderRadius.circular(100)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(child: Text('Notificações', style: AppTextStyles.headline.copyWith(fontSize: 22))),
                  TextButton(
                    onPressed: _allRead ? null : () => setState(() => _allRead = true),
                    child: Text(
                      _allRead ? 'Tudo em dia' : 'Marcar como lidas',
                      style: AppTextStyles.chip.copyWith(color: AppColors.orange),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
                children: [
                  _NotificationItem(
                    icon: Icons.local_fire_department_outlined,
                    title: 'Continue sua sequência',
                    message: 'Você já soma 23 dias de consistência. Conclua sua rotina de hoje.',
                    time: 'Agora',
                    unread: !_allRead,
                  ),
                  _NotificationItem(
                    icon: Icons.music_note_outlined,
                    title: 'Playlist oficial disponível',
                    message: 'A trilha Projeto Bom Homem está pronta para acompanhar seu foco.',
                    time: '18 min',
                    unread: !_allRead,
                  ),
                  _NotificationItem(
                    icon: Icons.groups_outlined,
                    title: 'Novo relato na comunidade',
                    message: 'Samuel Robson Fiales compartilhou uma conquista da sua jornada.',
                    time: '42 min',
                    unread: !_allRead,
                  ),
                  _NotificationItem(
                    icon: Icons.emoji_events_outlined,
                    title: 'Desafio em andamento',
                    message: 'O próximo passo do 30 Dias de Disciplina espera por você.',
                    time: 'Hoje',
                    unread: false,
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

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String time;
  final bool unread;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unread ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unread ? AppColors.border : AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 14))),
                    if (unread)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(message, style: AppTextStyles.bodySmall),
                const SizedBox(height: 5),
                Text(time, style: AppTextStyles.statLabel.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
