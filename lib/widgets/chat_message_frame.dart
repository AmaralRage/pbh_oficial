import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Shared geometry for text, photos and recordings; time stays outside the bubble.
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
  });
  final bool mine, grouped, read, founder, photo;
  final String time;
  final String? avatar;
  final Widget child;
  Widget _avatar() => ClipOval(
    child: SizedBox(
      width: 30,
      height: 30,
      child: avatar?.isNotEmpty == true
          ? Image.network(
              avatar!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person_outline, size: 20),
            )
          : founder
          ? Image.asset('assets/images/perfil.png', fit: BoxFit.cover)
          : const Icon(Icons.person_outline, size: 20),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.only(bottom: grouped ? 5 : 18),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 21),
                child: grouped ? const SizedBox(width: 30) : _avatar(),
              ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * .8,
                    ),
                    padding: EdgeInsets.all(photo ? 5 : 13),
                    decoration: BoxDecoration(
                      color: mine
                          ? Color.alphaBlend(
                              colors.orange.withValues(alpha: .32),
                              colors.surface,
                            )
                          : colors.surfaceElevated,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(17),
                        topRight: const Radius.circular(17),
                        bottomLeft: Radius.circular(mine ? 17 : 5),
                        bottomRight: Radius.circular(mine ? 5 : 17),
                      ),
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        height: 1.35,
                      ),
                      child: child,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5, left: 2, right: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                        if (mine)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.done_all,
                              semanticLabel: read
                                  ? 'Mensagem lida'
                                  : 'Mensagem enviada',
                              size: 14,
                              color: read
                                  ? colors.orange
                                  : colors.textSecondary,
                            ),
                          ),
                      ],
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
