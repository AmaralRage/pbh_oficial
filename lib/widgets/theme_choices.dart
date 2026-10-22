import 'package:flutter/material.dart';
import '../core/theme/pbh_palette.dart';

class ThemeChoices extends StatelessWidget {
  const ThemeChoices({
    super.key,
    required this.selected,
    required this.onSelected,
    this.founder = false,
    this.allowFollowApp = false,
  });
  final String selected;
  final ValueChanged<String>? onSelected;
  final bool founder;
  final bool allowFollowApp;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (allowFollowApp)
        RadioListTile<String>(
          value: 'app',
          groupValue: selected,
          onChanged: onSelected == null ? null : (id) => onSelected!(id!),
          title: const Text('Acompanhar tema do app'),
        ),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final palette in PbhPalette.catalog.where(
              (p) => founder || !p.founderOnly,
            ))
              SizedBox(
                width: constraints.maxWidth < 280
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2,
                child: Semantics(
                  selected: selected == palette.id,
                  button: true,
                  label: palette.name,
                  child: Material(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: onSelected == null
                          ? null
                          : () => onSelected!(palette.id),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected == palette.id
                                ? palette.orangeLight
                                : palette.border,
                            width: selected == palette.id ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 62,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  colors: [
                                    palette.base,
                                    Color.lerp(
                                      palette.base,
                                      palette.accent,
                                      .4,
                                    )!,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 25,
                                      height: 25,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: palette.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            height: 5,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            height: 5,
                                            color: Colors.white24,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    palette.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (selected == palette.id)
                                  Icon(
                                    Icons.check_circle,
                                    color: palette.orangeLight,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
