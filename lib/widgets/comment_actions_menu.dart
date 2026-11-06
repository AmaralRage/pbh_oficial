import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CommentActionsMenu extends StatelessWidget {
  const CommentActionsMenu({
    super.key,
    required this.isOwn,
    required this.enabled,
    required this.onSelected,
  });

  final bool isOwn, enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    final danger = Theme.of(context).colorScheme.error;
    PopupMenuItem<String> action(
      String value,
      String label,
      IconData icon, {
      bool destructive = false,
    }) {
      final accent = destructive ? danger : colors.orange;
      return PopupMenuItem<String>(
        value: value,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: destructive ? danger : colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Opções do comentário',
      enabled: enabled,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      menuPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: .4),
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.borderSubtle),
      ),
      popUpAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 180),
        reverseDuration: Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      ),
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: colors.textTertiary,
      ),
      itemBuilder: (_) => [
        action('reply', 'Responder', Icons.reply_rounded),
        if (isOwn) ...[
          action('edit', 'Editar', Icons.edit_outlined),
          const PopupMenuDivider(height: 12),
          action(
            'delete',
            'Excluir',
            Icons.delete_outline_rounded,
            destructive: true,
          ),
        ],
      ],
      onSelected: onSelected,
    );
  }
}
