import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ConnectionNotice extends StatelessWidget {
  const ConnectionNotice({
    super.key,
    required this.onRetry,
    this.message =
        'Não foi possível atualizar agora. Confira sua conexão e tente novamente.',
  });
  final VoidCallback onRetry;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: context.pbhColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.pbhColors.borderSubtle),
    ),
    child: Column(
      children: [
        Icon(Icons.cloud_off_outlined, color: context.pbhColors.textSecondary),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}
