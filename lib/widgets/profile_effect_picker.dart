import 'package:flutter/material.dart';
import '../models/profile_style.dart';

class ProfileEffectPicker extends StatefulWidget {
  const ProfileEffectPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.optionsBuilder,
  });
  final List<ProfileStyleOption> options;
  final String selected;
  final Widget Function(List<ProfileStyleOption>) optionsBuilder;
  static String category(String id) => ProfileStyle.platinumEffects.contains(id)
      ? 'Jornadas'
      : ProfileStyle.weatherEffects.contains(id)
      ? 'Natureza'
      : ProfileStyle.seasonalEffects.contains(id)
      ? 'Celebrações'
      : 'Luzes';
  @override
  State<ProfileEffectPicker> createState() => _ProfileEffectPickerState();
}

class _ProfileEffectPickerState extends State<ProfileEffectPicker> {
  String _category = 'Todos';
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final category in [
            'Todos',
            'Jornadas',
            'Natureza',
            'Luzes',
            'Celebrações',
          ])
            ChoiceChip(
              label: Text(category),
              selected: _category == category,
              onSelected: (_) => setState(() => _category = category),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Selecionada: ${widget.options.firstWhere((o) => o.id == widget.selected, orElse: () => widget.options.first).label}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      widget.optionsBuilder(
        widget.options
            .where(
              (o) =>
                  o.id == 'none' ||
                  _category == 'Todos' ||
                  ProfileEffectPicker.category(o.id) == _category,
            )
            .toList(),
      ),
    ],
  );
}
