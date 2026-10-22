import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/feedback/tap_feedback.dart';
import 'pbh_logo.dart';
import 'pbh_notifications_sheet.dart';

/// Cabeçalho permanente das seções principais do aplicativo.
class PbhAppHeader extends StatelessWidget {
  final String currentSection;
  final VoidCallback onMenuPressed;
  final VoidCallback onLogoPressed;
  final int unreadNotifications;
  final int notificationPulseKey;
  final VoidCallback onNotificationsChanged;
  final bool showNotifications;

  const PbhAppHeader({
    super.key,
    required this.currentSection,
    required this.onMenuPressed,
    required this.onLogoPressed,
    this.unreadNotifications = 0,
    this.notificationPulseKey = 0,
    required this.onNotificationsChanged,
    this.showNotifications = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.pbhColors.background,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Abrir menu',
                  icon: Icon(Icons.menu, color: context.pbhColors.textPrimary),
                  onPressed: onMenuPressed,
                ),
                Expanded(
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'Voltar para a tela inicial',
                      child: GestureDetector(
                        onTap: () {
                          lightTapFeedback();
                          onLogoPressed();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: PbhLogo(compact: true),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showNotifications)
                  IconButton(
                    tooltip: 'Notificações',
                    icon: _AnimatedNotificationBell(
                      pulseKey: notificationPulseKey,
                      unreadCount: unreadNotifications,
                    ),
                    onPressed: () async {
                      await showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => PbhNotificationsSheet(
                          onChanged: onNotificationsChanged,
                        ),
                      );
                      onNotificationsChanged();
                    },
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
          const SizedBox(height: 9),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Row(
              key: ValueKey(currentSection),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: context.pbhColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  currentSection.toUpperCase(),
                  style: AppTextStyles.eyebrow
                      .copyWith(color: context.pbhColors.orangeLight)
                      .copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNotificationBell extends StatefulWidget {
  const _AnimatedNotificationBell({
    required this.pulseKey,
    required this.unreadCount,
  });

  final int pulseKey;
  final int unreadCount;

  @override
  State<_AnimatedNotificationBell> createState() =>
      _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState extends State<_AnimatedNotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );

  @override
  void didUpdateWidget(covariant _AnimatedNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulseKey != oldWidget.pulseKey) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final shake =
                    math.sin(_controller.value * math.pi * 8) *
                    (1 - _controller.value) *
                    .22;
                final scale = 1 + math.sin(_controller.value * math.pi) * .22;
                return Transform.rotate(
                  angle: shake,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Icon(
                widget.unreadCount > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
                color: context.pbhColors.textPrimary,
                size: 23,
              ),
            ),
          ),
          if (widget.unreadCount > 0)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: context.pbhColors.orange,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.pbhColors.background,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  widget.unreadCount > 9 ? '9+' : '${widget.unreadCount}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
