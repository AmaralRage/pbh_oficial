import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ProfileOptionTile extends StatelessWidget {
  const ProfileOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.preview,
    this.onTap,
    this.requirement,
  });
  final String label;
  final bool selected;
  final Widget preview;
  final VoidCallback? onTap;
  final String? requirement;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onTap != null,
    label: requirement == null ? label : '$label. $requirement',
    child: Tooltip(
      message: requirement ?? label,
      child: SizedBox(
        width: 104,
        child: Material(
          color: context.pbhColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected
                  ? context.pbhColors.orange
                  : context.pbhColors.borderSubtle,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        child: TickerMode(enabled: false, child: preview),
                      ),
                      if (selected)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Icon(
                            Icons.check_circle,
                            size: 19,
                            color: context.pbhColors.orange,
                          ),
                        ),
                      if (requirement != null)
                        const Center(
                          child: Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.pbhColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
