import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/navigation/app_transitions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/program_model.dart';
import '../models/program_lesson.dart';
import '../services/program_service.dart';
import 'program_lesson_screen.dart';
import '../widgets/program_study_plan.dart';

class ProgramDetailScreen extends StatefulWidget {
  const ProgramDetailScreen({
    super.key,
    required this.program,
    this.service,
    this.preview = false,
  });
  final ProgramModel program;
  final ProgramService? service;
  final bool preview;
  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  late final _service = widget.service ?? ProgramService();
  ProgramProgress _progress = const ProgramProgress();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.preview) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final state = await _service.loadAll([widget.program]);
      if (mounted) {
        setState(() {
          _progress = state[widget.program.id]!;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar o progresso.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final result = await _service.update(
        widget.program.id,
        saved: !_progress.saved,
      );
      if (mounted) {
        setState(() {
          _progress = result;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível salvar o programa. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(ProgramLesson lesson) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = widget.preview
          ? const ProgramProgress()
          : await _service.update(widget.program.id, open: true);
      if (!mounted) return;
      setState(() => _progress = result);
      await Navigator.of(context).push(
        fadeSlideRoute(
          ProgramLessonScreen(
            program: widget.program,
            lesson: lesson,
            service: _service,
            preview: widget.preview,
          ),
        ),
      );
      if (!widget.preview) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível abrir a aula. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final count = _progress.completedCount(program);
    final lessons = program.lessons;
    final next = _progress.nextLessonId(program);
    return Scaffold(
      backgroundColor: context.pbhColors.background,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _busy || _loading || widget.preview ? null : _save,
            tooltip: _progress.saved ? 'Remover dos salvos' : 'Salvar programa',
            icon: Icon(
              _progress.saved ? Icons.bookmark : Icons.bookmark_border,
            ),
          ),
          IconButton(
            onPressed: () =>
                Share.share('${program.title}\n${program.tagline}'),
            tooltip: 'Compartilhar programa',
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${program.topic} • ${program.levelLabel}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(program.title, style: AppTextStyles.brandHeadline),
            const SizedBox(height: 12),
            Text(program.description, style: AppTextStyles.body),
            const SizedBox(height: 14),
            Text(
              '${program.modules} módulos • ${lessons.length} aulas • ritmo sugerido: ${program.weeks} semanas',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),
            Text(
              'O que você vai desenvolver',
              style: AppTextStyles.titleMedium,
            ),
            for (final outcome in program.outcomes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.check_circle_outline,
                  color: context.pbhColors.orange,
                ),
                title: Text(outcome, style: AppTextStyles.body),
              ),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text(
                _progress.isComplete(program)
                    ? 'Programa concluído! Você pode revisar as aulas.'
                    : '$count de ${lessons.length} aulas concluídas',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: lessons.isEmpty ? 0 : count / lessons.length,
              ),
              if (!widget.preview && _service.syncPending)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Progresso salvo neste aparelho. A sincronização será tentada novamente ao abrir o programa.',
                  ),
                ),
              const SizedBox(height: 20),
              if (lessons.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _open(
                          lessons.firstWhere(
                            (l) => l.id == next,
                            orElse: () => lessons.first,
                          ),
                        ),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    _progress.isComplete(program)
                        ? 'Revisar programa'
                        : _progress.started
                        ? 'Continuar programa'
                        : 'Iniciar programa',
                  ),
                ),
            ],
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ],
            const SizedBox(height: 24),
            if (!_loading)
              ProgramStudyPlan(program: program, progress: _progress),
            const SizedBox(height: 12),
            Text('Módulos e aulas', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            for (final (index, module)
                in (_loading ? <ProgramModule>[] : program.curriculum).indexed)
              Card(
                child: ExpansionTile(
                  key: PageStorageKey('${program.id}/${module.id}'),
                  initiallyExpanded:
                      _progress.isComplete(program) ||
                      module.lessons.any((l) => l.id == next),
                  title: Text('Etapa ${index + 1} · ${module.title}'),
                  subtitle: Text(
                    '${module.lessons.where((l) => _progress.completed.contains(l.id)).length}/${module.lessons.length} aulas',
                  ),
                  children: [
                    for (final lesson in module.lessons)
                      ListTile(
                        selected:
                            lesson.id == next && !_progress.isComplete(program),
                        leading: Icon(
                          _progress.completed.contains(lesson.id)
                              ? Icons.check_circle
                              : Icons.menu_book_outlined,
                          color: context.pbhColors.orange,
                        ),
                        title: Text(lesson.title),
                        subtitle: Text(
                          '${lesson.media == null ? 'Leitura e prática' : 'Vídeo/podcast + leitura e prática'} • ${lesson.minutes} min de leitura e prática',
                        ),
                        onTap: _busy || _loading ? null : () => _open(lesson),
                      ),
                    if (module.lessons.isNotEmpty &&
                        module.lessons.last.practice.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prática ao finalizar a etapa',
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              module.lessons.last.practice,
                              style: AppTextStyles.bodySmall,
                            ),
                            TextButton.icon(
                              onPressed: _busy || _loading
                                  ? null
                                  : () => _open(module.lessons.last),
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Abrir aula e praticar'),
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
