import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class ProfileTitleChoice {
  const ProfileTitleChoice(this.id, this.label, this.description, this.icon);
  final String id, label, description;
  final IconData icon;
}

class ProfileTitlePicker extends StatelessWidget {
  const ProfileTitlePicker({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String value;
  final List<ProfileTitleChoice> options;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) {
    final selected =
        options.where((o) => o.id == value).firstOrNull ?? options.first;
    final colors = context.pbhColors;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onChanged == null
          ? null
          : () async {
              final chosen = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: colors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => _TitleSheet(value: value, options: options),
              );
              if (context.mounted && chosen != null) onChanged?.call(chosen);
            },
      child: Row(
        children: [
          _TitleIcon(icon: selected.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seu t\u00edtulo no perfil',
                  style: TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
                const SizedBox(height: 4),
                Text(
                  selected.label,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.unfold_more_rounded, color: colors.textSecondary),
        ],
      ),
    );
  }
}

class _TitleIcon extends StatelessWidget {
  const _TitleIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: context.pbhColors.orangeDim,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: context.pbhColors.orange, size: 22),
  );
}

class _TitleSheet extends StatefulWidget {
  const _TitleSheet({required this.value, required this.options});
  final String value;
  final List<ProfileTitleChoice> options;
  @override
  State<_TitleSheet> createState() => _TitleSheetState();
}

class _TitleSheetState extends State<_TitleSheet> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    final filtered = widget.options
        .where((o) => o.label.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Escolha seu t\u00edtulo',
                      style: AppTextStyles.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sua identidade e as conquistas que voc\u00ea desbloqueou.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (text) => setState(() => query = text),
                decoration: const InputDecoration(
                  hintText: 'Buscar t\u00edtulo',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Nenhum t\u00edtulo encontrado.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = filtered[index],
                            selected = item.id == widget.value;
                        return Material(
                          color: selected
                              ? Color.alphaBlend(
                                  colors.orangeDim,
                                  colors.surface,
                                )
                              : colors.backgroundElevated,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: selected
                                  ? colors.orange
                                  : colors.borderSubtle,
                            ),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onTap: () => Navigator.pop(context, item.id),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            leading: _TitleIcon(icon: item.icon),
                            title: Text(
                              item.label,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 14,
                                color: colors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              selected
                                  ? 'Em uso no seu perfil'
                                  : item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              color: selected
                                  ? colors.orange
                                  : colors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
