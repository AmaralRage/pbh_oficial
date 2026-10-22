import 'package:flutter/material.dart';

class HabitSyncNotice extends StatelessWidget {
  const HabitSyncNotice({
    super.key,
    required this.pending,
    required this.cached,
    required this.onRetry,
  });
  final int pending;
  final bool cached;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    if (!cached && pending == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pending > 0
                  ? '$pending marcações salvas neste aparelho, aguardando sincronização.'
                  : 'Exibindo os últimos dados salvos da rotina.',
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Sincronizar')),
        ],
      ),
    );
  }
}
