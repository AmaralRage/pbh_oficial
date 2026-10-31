import 'package:flutter/material.dart';
import '../models/profile_style.dart';

/// Groups only visible options; hidden grants never produce a placeholder.
class ProfileOptionGroups extends StatelessWidget {
  const ProfileOptionGroups({
    super.key,
    required this.options,
    required this.founder,
    required this.completed,
    required this.earned,
    required this.builder,
  });
  final List<ProfileStyleOption> options;
  final bool founder;
  final int completed;
  final Set<String> earned;
  final Widget Function(List<ProfileStyleOption>) builder;
  static String group(ProfileStyleOption option) =>
      option.founderOnly || option.hiddenUnlessAvailable
      ? 'Exclusivas'
      : option.badge != null ||
            option.requiredBadges.isNotEmpty ||
            option.minimum > 0
      ? 'Recompensas de jornadas'
      : 'Opções disponíveis';
  @override
  Widget build(BuildContext context) {
    final visible = options.where((o) => o.visible(founder, completed, earned));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final label in [
          'Opções disponíveis',
          'Recompensas de jornadas',
          'Exclusivas',
        ])
          if (visible.any((o) => group(o) == label)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            builder(visible.where((o) => group(o) == label).toList()),
          ],
      ],
    );
  }
}
