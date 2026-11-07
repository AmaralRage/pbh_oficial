import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/community_topics.dart';

class CommunityTopicPicker extends StatelessWidget {
  const CommunityTopicPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String>? onChanged;

  static const _icons = <String, IconData>{
    'disciplina': Icons.local_fire_department_outlined,
    'treino': Icons.fitness_center_rounded,
    'leitura': Icons.menu_book_rounded,
    'proposito': Icons.explore_outlined,
    'reflexao': Icons.psychology_outlined,
    'duvidas': Icons.help_outline_rounded,
    'conquistas': Icons.emoji_events_outlined,
    'recomendacoes': Icons.bookmarks_outlined,
  };

  Future<void> _choose(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pbhColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assunto da publicação',
                            style: Theme.of(sheet).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Escolha onde sua história se encaixa.',
                            style: TextStyle(
                              color: sheet.pbhColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar assuntos',
                      onPressed: () => Navigator.pop(sheet),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: communityTopics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final topic = communityTopics.entries.elementAt(index);
                    final active = topic.key == value;
                    final accent = sheet.pbhColors.orange;
                    return Material(
                      color: active
                          ? accent.withValues(alpha: .12)
                          : sheet.pbhColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: active
                              ? accent.withValues(alpha: .65)
                              : sheet.pbhColors.border,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        selected: active,
                        selectedColor: accent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Icon(
                          _icons[topic.key],
                          color: active
                              ? accent
                              : sheet.pbhColors.textSecondary,
                        ),
                        title: Text(
                          topic.value,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: active
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: accent,
                                semanticLabel: 'Selecionado',
                              )
                            : null,
                        onTap: () => Navigator.pop(sheet, topic.key),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onChanged != null,
    child: Material(
      color: context.pbhColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.pbhColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChanged == null ? null : () => _choose(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.pbhColors.orange.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _icons[value] ?? Icons.forum_outlined,
                  color: context.pbhColors.orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assunto',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.pbhColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      communityTopics[value] ?? 'Escolher assunto',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    ),
  );
}
