import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/profile_achievement.dart';

/// Static, bounded thumbnails. Never embeds HTML or starts animation tickers.
class ProfileAchievementPicker extends StatelessWidget {
  const ProfileAchievementPicker({
    super.key,
    required this.earned,
    required this.selected,
    required this.onChanged,
    this.fixedTrophies = false,
  });
  final List<ProfileAchievement> earned;
  final List<String> selected;
  final ValueChanged<List<String>>? onChanged;
  final bool fixedTrophies;
  Widget _art(ProfileAchievement badge, {double size = 48}) => SizedBox.square(
    dimension: size,
    child: badge.artAsset == null
        ? Icon(badge.icon, color: badge.color, size: size * .65)
        : Image.asset(
            badge.artAsset!,
            cacheWidth: 128,
            cacheHeight: 128,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) => Icon(badge.icon, color: badge.color),
          ),
  );
  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    final byId = {for (final badge in earned) badge.id: badge};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.backgroundElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pr\u00e9via da sele\u00e7\u00e3o',
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (fixedTrophies)
                    for (final b in earned.where((b) => b.isJourneyTrophy))
                      Tooltip(message: b.title, child: _art(b, size: 36)),
                  for (final id in selected)
                    if (byId[id] != null)
                      Tooltip(message: byId[id]!.title, child: _art(byId[id]!, size: 36)),
                ],
              ),
              if (selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    fixedTrophies
                        ? 'Sem miniaturas extras.'
                        : 'Nenhum selo em destaque.',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (earned.where((b) => !b.isJourneyTrophy).isEmpty)
          const Text('Conquiste selos para escolher aqui.')
        else
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: earned.where((b) => !b.isJourneyTrophy).length,
              itemBuilder: (_, index) {
                final badge = earned
                    .where((b) => !b.isJourneyTrophy)
                    .elementAt(index);
                final chosen = selected.contains(badge.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 136,
                    child: Material(
                      color: chosen
                          ? Color.alphaBlend(colors.orangeDim, colors.surface)
                          : colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: chosen ? colors.orange : colors.borderSubtle,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onChanged == null
                            ? null
                            : () {
                                final next = List<String>.of(selected);
                                if (chosen) {
                                  next.remove(badge.id);
                                } else if (next.length < 3) {
                                  next.add(badge.id);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Escolha at\u00e9 3 selos. Remova um para trocar.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                onChanged!(next);
                              },
                        child: Semantics(
                          selected: chosen,
                          button: true,
                          label: badge.title,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Icon(
                                    chosen
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: chosen
                                        ? colors.orange
                                        : colors.textTertiary,
                                  ),
                                ),
                                _art(badge, size: 56),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      badge.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
