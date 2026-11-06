import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Static placeholders avoid adding decorative animation work on mobile.
class LoadingCards extends StatelessWidget {
  const LoadingCards({
    super.key,
    this.count = 3,
    this.showMedia = true,
    this.label = 'Carregando publicações',
  });
  final int count;
  final bool showMedia;
  final String label;
  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    Widget line(double width) => Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: width,
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: colors.textTertiary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: colors.textTertiary.withValues(
                            alpha: .12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: line(.5)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    line(.92),
                    const SizedBox(height: 10),
                    line(.7),
                    if (showMedia) ...[
                      const SizedBox(height: 18),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: colors.textTertiary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
