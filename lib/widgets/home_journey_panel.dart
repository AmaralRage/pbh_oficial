import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../models/weekly_review.dart';
import '../services/program_service.dart';
import '../services/weekly_review_service.dart';
import '../screens/program_lesson_screen.dart';
import 'featured_learning_card.dart';

class HomeJourneyPanel extends StatefulWidget {
  const HomeJourneyPanel({
    super.key,
    required this.pendingHabits,
    required this.activeChallenge,
    required this.onHabits,
    required this.onChallenges,
    required this.onContent,
    this.programService,
    this.reviewService,
  });
  final int pendingHabits;
  final bool activeChallenge;
  final VoidCallback onHabits, onChallenges, onContent;
  final ProgramService? programService;
  final WeeklyReviewService? reviewService;
  @override
  State<HomeJourneyPanel> createState() => _HomeJourneyPanelState();
}

class _HomeJourneyPanelState extends State<HomeJourneyPanel> {
  late final _programs = widget.programService ?? ProgramService();
  ProgramModel? _ongoing;
  ProgramModel? _featured;
  ProgramProgress? _state;
  WeeklyReview? _review;
  bool _loading = true;
  bool _opening = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      List<ProgramModel> catalog = [];
      Map<String, ProgramProgress>? progress;
      try {
        catalog = await _programs.availableCatalog();
        progress = await _programs.loadAll(catalog);
      } catch (_) {
        /* Resumo dos hábitos continua disponível. */
      }
      final ongoing =
          catalog
              .where(
                (p) =>
                    (progress?[p.id]?.started ?? false) &&
                    !(progress?[p.id]?.isComplete(p) ?? false) &&
                    p.lessons.isNotEmpty,
              )
              .toList()
            ..sort(
              (a, b) => (progress?[b.id]?.openedAt ?? '').compareTo(
                progress?[a.id]?.openedAt ?? '',
              ),
            );
      final review = await (widget.reviewService ?? WeeklyReviewService()).load(
        progress?.values,
      );
      if (!mounted) return;
      setState(() {
        _review = review;
        _ongoing = ongoing.isEmpty ? null : ongoing.first;
        _featured = ProgramService.featured(catalog);
        _state = _ongoing == null ? null : progress?[_ongoing!.id];
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível atualizar seu resumo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _next() async {
    if (_opening) return;
    final p = _ongoing;
    if (p == null) {
      if (widget.pendingHabits > 0) {
        widget.onHabits();
      } else if (widget.activeChallenge) {
        widget.onChallenges();
      } else {
        widget.onContent();
      }
      return;
    }
    setState(() => _opening = true);
    try {
      final state = await _programs.update(p.id, open: true);
      final next = state.nextLessonId(p);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProgramLessonScreen(
            program: p,
            lesson: p.lessons.firstWhere(
              (l) => l.id == next,
              orElse: () => p.lessons.first,
            ),
            service: _programs,
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível abrir a próxima aula.');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _comparison(int? current, int? previous) {
    if (current == null || previous == null) return 'Indisponível no momento';
    final difference = current - previous;
    return difference == 0
        ? 'Mesmo total no período anterior'
        : '${difference > 0 ? '+' : ''}$difference em relação ao período anterior';
  }

  Widget _metric(String title, int? value, int? previous) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${value ?? '—'} • $title',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          _comparison(value, previous),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      );
    }
    final p = _ongoing, review = _review;
    final next = p == null ? null : _state?.nextLessonId(p);
    final label = p != null
        ? 'Continuar: ${p.lessons.firstWhere((l) => l.id == next, orElse: () => p.lessons.first).title}'
        : widget.pendingHabits > 0
        ? 'Registrar os hábitos de hoje'
        : widget.activeChallenge
        ? 'Avançar no desafio ativo'
        : 'Explorar uma nova aula';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_featured != null)
          FeaturedLearningCard(
            program: _featured!,
            service: _programs,
            onChanged: _load,
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Seu próximo passo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (p != null) Text(p.title),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _opening ? null : _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(label),
                ),
              ],
            ),
          ),
        ),
        if (review != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seu resumo semanal',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${review.start.day}/${review.start.month} até ${review.today.day}/${review.today.month}',
                  ),
                  _metric(
                    'hábitos registrados',
                    review.habits,
                    review.previousHabits,
                  ),
                  _metric(
                    'aulas concluídas',
                    review.lessons,
                    review.previousLessons,
                  ),
                  _metric(
                    'registros diários em desafios',
                    review.challengeDays,
                    review.previousChallengeDays,
                  ),
                  const Text(
                    'Comparação com os mesmos dias da semana anterior. Conclusões antigas de aulas sem data não entram no resumo.',
                  ),
                ],
              ),
            ),
          ),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error Tentar novamente')),
        const SizedBox(height: 16),
      ],
    );
  }
}
