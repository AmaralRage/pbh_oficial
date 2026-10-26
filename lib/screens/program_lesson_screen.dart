import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/habit_model.dart';
import '../models/program_model.dart';
import '../models/program_lesson.dart';
import '../services/habit_service.dart';
import '../services/habit_reminder_service.dart';
import '../services/program_service.dart';
import '../widgets/lesson_media_card.dart';
import '../widgets/lesson_notes_editor.dart';

class ProgramLessonScreen extends StatefulWidget {
  const ProgramLessonScreen({
    super.key,
    required this.program,
    required this.lesson,
    required this.service,
    this.preview = false,
  });
  final ProgramModel program;
  final ProgramLesson lesson;
  final ProgramService service;
  final bool preview;
  @override
  State<ProgramLessonScreen> createState() => _ProgramLessonScreenState();
}

class _ProgramLessonScreenState extends State<ProgramLessonScreen> {
  bool _saving = false;
  bool _addingHabit = false;
  bool _completed = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (!widget.preview) _load();
  }

  Future<void> _load() async {
    try {
      final state = await widget.service.read(widget.program.id);
      if (mounted) {
        setState(() => _completed = state.completed.contains(widget.lesson.id));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível carregar o progresso. Tente novamente.',
        );
      }
    }
  }

  Future<void> _complete() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!widget.preview) {
        await widget.service.update(
          widget.program.id,
          completedLesson: widget.lesson.id,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addHabit() async {
    setState(() => _addingHabit = true);
    try {
      widget.service.ensureCurrentAccount();
      final service = HabitService();
      final selected = await service.selectedHabitKeys();
      widget.service.ensureCurrentAccount();
      final alreadyAdded = selected.contains(widget.lesson.habitKey);
      selected.add(widget.lesson.habitKey!);
      await service.saveSelectedHabitKeys(selected);
      widget.service.ensureCurrentAccount();
      String message = alreadyAdded
          ? 'Este hábito já está na sua rotina.'
          : 'Hábito adicionado à sua rotina.';
      try {
        final reminders = HabitReminderService();
        await reminders.syncSelectedHabits(selected);
        if (!kIsWeb) {
          final settings = await reminders.load();
          if (settings.enabled) {
            final completed = await service.completedOn(DateTime.now());
            await reminders.synchronizeLocalSchedule(
              enabled: true,
              time: settings.time,
              selectedHabitKeys: selected,
              pendingHabitKeys: selected.difference(completed),
            );
          }
        }
      } catch (_) {
        message += ' Confira os lembretes na tela de rotina.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível atualizar sua rotina. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _addingHabit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final habits = habitCatalog.where((h) => h.key == lesson.habitKey);
    return Scaffold(
      appBar: AppBar(title: const Text('Aula')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(widget.program.title, style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            Text(lesson.title, style: AppTextStyles.brandHeadline),
            const SizedBox(height: 10),
            Text(
              'Leitura e prática • cerca de ${lesson.minutes} min',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),
            if (lesson.media != null) ...[
              LessonMediaCard(media: lesson.media!),
              const SizedBox(height: 24),
            ],
            SelectableText(
              lesson.body,
              style: AppTextStyles.body.copyWith(height: 1.7),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.pbhColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coloque em prática', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 12),
                  Text(lesson.practice, style: AppTextStyles.body),
                  if (habits.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _addingHabit || widget.preview
                          ? null
                          : _addHabit,
                      icon: const Icon(Icons.add_task),
                      label: Text('Adicionar à rotina: ${habits.first.title}'),
                    ),
                    Text(
                      'A conclusão desta aula não marca o hábito como feito.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[Text(_error!), const SizedBox(height: 12)],
            if (!widget.preview) ...[
              LessonNotesEditor(
                programId: widget.program.id,
                lessonId: lesson.id,
                service: widget.service.notesService(),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              onPressed: _saving ? null : _complete,
              icon: Icon(_completed ? Icons.check_circle : Icons.done),
              label: Text(
                widget.preview
                    ? 'Voltar à prévia'
                    : _saving
                    ? 'Salvando…'
                    : _completed
                    ? 'Aula concluída • Voltar'
                    : 'Concluir aula',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
