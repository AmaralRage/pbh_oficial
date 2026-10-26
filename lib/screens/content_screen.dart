import 'package:flutter/material.dart';
import '../core/navigation/app_transitions.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_colors.dart';
import '../models/program_model.dart';
import '../services/program_service.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/program_card.dart';
import '../widgets/featured_learning_card.dart';
import 'program_detail_screen.dart';
import 'program_lesson_screen.dart';
import 'admin_content_screen.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key, this.isAdmin = false, this.service});
  final bool isAdmin;
  final ProgramService? service;
  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  late final _service = widget.service ?? ProgramService();
  List<ProgramModel> _programs = [];
  Map<String, ProgramProgress> _progress = {};
  Set<String> _interests = {};
  int _filterIndex = 0;
  String? _topic;
  String _query = '';
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool? _tabActive;
  static const _filters = [
    'Todos',
    'Iniciante',
    'Intermediário',
    'Avançado',
    'Salvos',
    'Concluídos',
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && _tabActive == false) _load();
    _tabActive = active;
  }

  Future<void> _load() async {
    try {
      final programs = await _service.availableCatalog();
      final progress = await _service.loadAll(programs);
      final interests = await _service.topics();
      if (mounted) {
        setState(() {
          _programs = programs;
          _progress = progress;
          _interests = interests;
          _error = null;
          if (_topic != null && !programs.any((p) => p.topic == _topic)) {
            _topic = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível carregar o conteúdo. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(ProgramModel p, {bool resume = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (resume) {
        final state = await _service.update(p.id, open: true);
        final next = state.nextLessonId(p);
        if (!mounted) return;
        await Navigator.of(context).push(
          fadeSlideRoute(
            ProgramLessonScreen(
              program: p,
              lesson: p.lessons.firstWhere(
                (l) => l.id == next,
                orElse: () => p.lessons.first,
              ),
              service: _service,
            ),
          ),
        );
      } else {
        await Navigator.of(context).push(
          fadeSlideRoute(ProgramDetailScreen(program: p, service: _service)),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível abrir o programa. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleInterest(String topic) async {
    if (_busy) return;
    setState(() => _busy = true);
    final next = {..._interests};
    next.contains(topic) ? next.remove(topic) : next.add(topic);
    try {
      await _service.saveTopics(next);
      if (mounted) setState(() => _interests = next);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar seus interesses.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = _programs.map((p) => p.topic).toSet().toList()..sort();
    final ordered = ProgramService.recommend(_programs, _progress, _interests);
    final ongoing =
        _programs
            .where(
              (p) =>
                  (_progress[p.id]?.started ?? false) &&
                  !(_progress[p.id]?.isComplete(p) ?? false) &&
                  p.lessons.isNotEmpty,
            )
            .toList()
          ..sort(
            (a, b) => (_progress[b.id]?.openedAt ?? '').compareTo(
              _progress[a.id]?.openedAt ?? '',
            ),
          );
    final level = switch (_filterIndex) {
      1 => ContentLevel.iniciante,
      2 => ContentLevel.intermediario,
      3 => ContentLevel.avancado,
      _ => null,
    };
    final query = _query.trim().toLowerCase();
    final list = ordered
        .where(
          (p) =>
              (level == null || p.level == level) &&
              (_filterIndex != 4 || (_progress[p.id]?.saved ?? false)) &&
              (_filterIndex != 5 ||
                  (_progress[p.id]?.isComplete(p) ?? false)) &&
              (_topic == null || p.topic == _topic) &&
              (query.isEmpty ||
                  '${p.title} ${p.tagline} ${p.description} ${p.topic} ${p.lessons.map((l) => l.title).join(' ')}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Conteúdo', style: AppTextStyles.brandHeadline),
                ),
                if (widget.isAdmin)
                  IconButton(
                    tooltip: 'Gerenciar conteúdo',
                    icon: const Icon(Icons.edit_note),
                    onPressed: () async {
                      await Navigator.of(
                        context,
                      ).push(fadeSlideRoute(const AdminContentScreen()));
                      await _load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Aprenda, pratique e acompanhe sua evolução.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 20),
            if (ProgramService.featured(_programs) != null)
              FeaturedLearningCard(
                program: ProgramService.featured(_programs)!,
                service: _service,
                onChanged: _load,
              ),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Buscar por programa, tema ou aula',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ],
            if (_service.syncPending)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Exibindo o progresso deste aparelho. Puxe para atualizar e tentar sincronizar.',
                ),
              ),
            if (_service.catalogOffline)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Catálogo disponível neste aparelho. Puxe para buscar atualizações.',
                ),
              ),
            if (ongoing.isNotEmpty) ...[
              Text('Continue de onde parou', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              for (final p in ongoing)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: AppTextStyles.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          '${_progress[p.id]!.completedCount(p)} de ${p.lessons.length} aulas concluídas',
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value:
                              _progress[p.id]!.completedCount(p) /
                              p.lessons.length,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Próxima: ${p.lessons.firstWhere((l) => l.id == _progress[p.id]!.nextLessonId(p)).title}',
                          style: AppTextStyles.bodySmall,
                        ),
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _open(p, resume: true),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Continuar aula'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
            if (topics.isNotEmpty) ...[
              Text('Seus interesses', style: AppTextStyles.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Escolha os temas para ordenar as recomendações.',
                style: AppTextStyles.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: topics
                    .map(
                      (t) => FilterChip(
                        label: Text(t),
                        labelStyle: TextStyle(
                          color: _interests.contains(t)
                              ? context.pbhColors.onAccent
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        selected: _interests.contains(t),
                        onSelected: _busy ? null : (_) => _toggleInterest(t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
            Text('Explore os programas', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            FilterChipRow(
              options: _filters,
              selectedIndex: _filterIndex,
              onSelected: (i) => setState(() => _filterIndex = i),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todos os temas'),
                  labelStyle: TextStyle(
                    color: _topic == null
                        ? context.pbhColors.onAccent
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  selected: _topic == null,
                  onSelected: (_) => setState(() => _topic = null),
                ),
                for (final topic in topics)
                  ChoiceChip(
                    label: Text(topic),
                    labelStyle: TextStyle(
                      color: _topic == topic
                          ? context.pbhColors.onAccent
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    selected: _topic == topic,
                    onSelected: (_) => setState(() => _topic = topic),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${list.length} programas encontrados',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 12),
            if (!_loading && list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum programa encontrado. Tente outro termo ou filtro.',
                ),
              ),
            for (final p in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProgramCard(program: p, onTap: () => _open(p)),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 12),
                      child: Text(
                        '${p.topic} • ${_progress[p.id]?.completedCount(p) ?? 0}/${p.lessons.length} aulas'
                        '${(_progress[p.id]?.saved ?? false) ? ' • Salvo' : ''}'
                        '${(_progress[p.id]?.isComplete(p) ?? false) ? ' • Concluído' : ''}',
                        style: AppTextStyles.bodySmall,
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
