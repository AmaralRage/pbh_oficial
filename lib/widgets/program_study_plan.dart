import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../services/program_service.dart';

class ProgramStudyPlan extends StatelessWidget {
  const ProgramStudyPlan({
    super.key,
    required this.program,
    required this.progress,
  });
  final ProgramModel program;
  final ProgramProgress progress;
  @override
  Widget build(BuildContext context) {
    final remaining = program.lessons.where(
      (l) => !progress.completed.contains(l.id),
    );
    final minutes = remaining.fold<int>(0, (sum, l) => sum + l.minutes);
    final next = progress.nextLessonId(program);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sua trilha de estudo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              remaining.isEmpty
                  ? 'Trilha concluída. Revise e pratique no seu ritmo.'
                  : 'Etapas em ordem sugerida. Você pode abrir qualquer aula.',
            ),
            if (remaining.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Próxima aula: ${program.lessons.firstWhere((l) => l.id == next, orElse: () => remaining.first).title}',
              ),
              const SizedBox(height: 6),
              Text(
                '$minutes min estimados de leitura e prática restantes. O tempo dos vídeos e podcasts é adicional.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
