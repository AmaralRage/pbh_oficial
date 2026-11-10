import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../core/theme/app_colors.dart';

class ChatSendFailure extends StatelessWidget {
  const ChatSendFailure({
    super.key,
    required this.draft,
    required this.onRetry,
  });
  final ChatDraft draft;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 300),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.pbhColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.pbhColors.orange.withValues(alpha: .5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draft.photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                draft.photo!,
                height: 100,
                fit: BoxFit.contain,
                semanticLabel: 'Foto com envio pendente',
              ),
            ),
          if (draft.voice != null) const Text('Mensagem de áudio'),
          if (draft.text.isNotEmpty)
            Text(draft.text, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          const Text('Envio não confirmado', style: TextStyle(fontSize: 12)),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ],
      ),
    ),
  );
}
