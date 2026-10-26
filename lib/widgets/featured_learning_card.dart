import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../services/program_service.dart';
import '../services/minute_clock.dart';
import '../screens/program_lesson_screen.dart';
import 'lesson_media_card.dart';

class FeaturedLearningCard extends StatefulWidget {
  const FeaturedLearningCard({
    super.key,
    required this.program,
    required this.service,
    this.onChanged,
  });
  final ProgramModel program;
  final ProgramService service;
  final Future<void> Function()? onChanged;
  @override
  State<FeaturedLearningCard> createState() => _FeaturedLearningCardState();
}

class _FeaturedLearningCardState extends State<FeaturedLearningCard> {
  bool _opening = false;
  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      final p = widget.program;
      await widget.service.update(p.id, open: true);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => ProgramLessonScreen(
            program: p,
            lesson: p.lessons.firstWhere((l) => l.id == p.featuredLessonId),
            service: widget.service,
          ),
        ),
      );
      await widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o destaque. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MinuteClock.shared,
    builder: (context, _) {
      final p = widget.program;
      if (!p.featuredAt(MinuteClock.shared.now)) return const SizedBox.shrink();
      final lesson = p.lessons.firstWhere((l) => l.id == p.featuredLessonId);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Seleção da semana',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                lesson.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(p.title),
              if (p.featuredNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.featuredNote),
              ],
              if (lesson.media != null) ...[
                const SizedBox(height: 12),
                LessonMediaCard(media: lesson.media!),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _opening ? null : _open,
                child: const Text('Abrir aula em destaque'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
