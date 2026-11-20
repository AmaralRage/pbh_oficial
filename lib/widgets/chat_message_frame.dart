import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Shared geometry for text, photos and recordings; time stays inside the bubble.
class ChatMessageFrame extends StatelessWidget {
  const ChatMessageFrame({
    super.key,
    required this.mine,
    required this.grouped,
    required this.time,
    required this.read,
    required this.child,
    this.avatar,
    this.founder = false,
    this.photo = false,
    this.text,
    this.fontSize = 14,
  });
  final bool mine, grouped, read, founder, photo;
  final String time;
  final double fontSize;
  final String? text;
  final String? avatar;
  final Widget child;

  Widget _metadata(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            color: context.pbhColors.textSecondary,
          ),
        ),
        if (mine)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.done_all,
              size: 14,
              semanticLabel: read ? 'Mensagem lida' : 'Mensagem enviada',
              color: read
                  ? context.pbhColors.orange
                  : context.pbhColors.textSecondary,
            ),
          ),
      ],
    ),
  );

  Widget _textBubble(BuildContext context) {
    final timeStyle = DefaultTextStyle.of(context).style.copyWith(fontSize: 10);
    final painter = TextPainter(
      text: TextSpan(text: time, style: timeStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final footerWidth = painter.width + (mine ? 18 : 0) + 10;
    final footerHeight = painter.height > 14 ? painter.height : 14.0;
    painter.dispose();
    return Stack(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: text),
              WidgetSpan(
                alignment: PlaceholderAlignment.bottom,
                child: SizedBox(width: footerWidth, height: footerHeight),
              ),
            ],
          ),
          textAlign: TextAlign.start,
        ),
        Positioned(right: 0, bottom: 0, child: _metadata(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.only(bottom: grouped ? 3 : 9),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * .86,
                    ),
                    padding: EdgeInsets.fromLTRB(
                      photo ? 4 : 9,
                      photo ? 4 : 6,
                      photo ? 4 : 9,
                      5,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? Color.alphaBlend(
                              colors.orange.withValues(alpha: .26),
                              colors.surface,
                            )
                          : colors.surfaceElevated,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(mine ? 12 : 3),
                        bottomRight: Radius.circular(mine ? 3 : 12),
                      ),
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: fontSize,
                        height: 1.3,
                      ),
                      child: text != null
                          ? _textBubble(context)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [child, _metadata(context)],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
