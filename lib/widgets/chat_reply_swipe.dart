import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../core/theme/app_colors.dart';

class ChatReplySwipe extends StatefulWidget {
  const ChatReplySwipe({
    super.key,
    required this.child,
    this.onReply,
    this.onLongPress,
  });
  final Widget child;
  final VoidCallback? onReply, onLongPress;
  @override
  State<ChatReplySwipe> createState() => _ChatReplySwipeState();
}

class _ChatReplySwipeState extends State<ChatReplySwipe> {
  double _drag = 0;
  void _end() {
    final reply = _drag >= 56;
    setState(() => _drag = 0);
    if (reply) widget.onReply?.call();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: widget.onReply == null
        ? null
        : {
            const CustomSemanticsAction(label: 'Responder à mensagem'):
                widget.onReply!,
          },
    child: GestureDetector(
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: widget.onReply == null
          ? null
          : (details) =>
                setState(() => _drag = (_drag + details.delta.dx).clamp(0, 72)),
      onHorizontalDragEnd: widget.onReply == null ? null : (_) => _end(),
      onHorizontalDragCancel: () => setState(() => _drag = 0),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_drag > 8)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.reply_rounded,
                color: context.pbhColors.orange.withValues(
                  alpha: (_drag / 56).clamp(0, 1),
                ),
              ),
            ),
          Transform.translate(offset: Offset(_drag, 0), child: widget.child),
        ],
      ),
    ),
  );
}
