import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../models/program_lesson.dart';
import '../models/lesson_media.dart';
import '../models/habit_model.dart';
import '../services/content_admin_service.dart';
import 'program_detail_screen.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key, this.service});
  final ContentAdminService? service;
  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  late final _service = widget.service ?? ContentAdminService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.list();
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'A central de conteúdo está indisponível ou sua conta não tem acesso.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ProgramEditor(row: row, service: _service),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gerenciar conteúdo')),
    floatingActionButton: _error == null && !_loading
        ? FloatingActionButton.extended(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Novo programa'),
          )
        : null,
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
                if (_error == null && _rows.isEmpty)
                  const Text('Crie seu primeiro programa.'),
                for (final row in _rows)
                  Card(
                    child: ListTile(
                      title: Text(row['title'] as String),
                      subtitle: Text(
                        row['published'] == true ? 'Publicado' : 'Rascunho',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(row),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class _ProgramEditor extends StatefulWidget {
  const _ProgramEditor({this.row, required this.service});
  final Map<String, dynamic>? row;
  final ContentAdminService service;
  @override
  State<_ProgramEditor> createState() => _ProgramEditorState();
}

class _ProgramEditorState extends State<_ProgramEditor> {
  final _form = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _title,
      _tagline,
      _description,
      _topic,
      _weeks,
      _outcomes;
  late List<ProgramModule> _modules;
  late ContentLevel _level;
  late bool _published;
  late final TextEditingController _featuredNote;
  bool _featured = false;
  DateTime? _featuredUntil;
  String? _featuredLesson;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final p = widget.row == null ? null : ProgramModel.fromJson(widget.row!);
    _id = p?.id ?? 'program_${DateTime.now().microsecondsSinceEpoch}';
    _title = TextEditingController(text: p?.title);
    _tagline = TextEditingController(text: p?.tagline);
    _description = TextEditingController(text: p?.description);
    _topic = TextEditingController(text: p?.topic);
    _weeks = TextEditingController(text: '${p?.weeks ?? 2}');
    _outcomes = TextEditingController(text: p?.outcomes.join('\n'));
    _modules = [...?p?.curriculum];
    _level = p?.level ?? ContentLevel.iniciante;
    _published = widget.row?['published'] == true;
    _featuredNote = TextEditingController(text: p?.featuredNote ?? '');
    _featured = p?.featuredUntil != null;
    _featuredUntil = p?.featuredUntil;
    _featuredLesson = p?.featuredLessonId;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _tagline,
      _description,
      _topic,
      _weeks,
      _outcomes,
      _featuredNote,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  ProgramModel _model() => ProgramModel(
    id: _id,
    title: _title.text.trim(),
    tagline: _tagline.text.trim(),
    description: _description.text.trim(),
    topic: _topic.text.trim(),
    weeks: int.tryParse(_weeks.text) ?? 0,
    level: _level,
    icon: Icons.menu_book_outlined,
    outcomes: _outcomes.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    curriculum: _modules,
    featuredUntil: _featured ? _featuredUntil : null,
    featuredLessonId: _featured ? _featuredLesson : null,
    featuredNote: _featured ? _featuredNote.text.trim() : '',
  );
  Future<void> _chooseFeaturedEnd() async {
    final now = DateTime.now();
    final initial = _featuredUntil != null && _featuredUntil!.isAfter(now)
        ? _featuredUntil!
        : now.add(const Duration(days: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, now.month, now.day),
    );
    if (date != null && mounted) {
      setState(() {
        _featuredUntil = DateTime(date.year, date.month, date.day, 23, 59, 59);
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final p = _model();
    final error = ContentAdminService.validate(p, published: _published);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.save(p, published: _published);
      if (mounted) {
        setState(() {
          _dirty = false;
          _saving = false;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível salvar. Confira sua conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _module([int? index]) async {
    final old = index == null ? null : _modules[index];
    final controller = TextEditingController(text: old?.title);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(old == null ? 'Novo módulo' : 'Editar módulo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    // O controlador é liberado depois que a rota do diálogo encerra a animação.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() {
      final module = ProgramModule(
        id: old?.id ?? 'm_${DateTime.now().microsecondsSinceEpoch}',
        title: value,
        lessons: old?.lessons ?? [],
      );
      if (index == null) {
        _modules.add(module);
      } else {
        _modules[index] = module;
      }
      _dirty = true;
    });
  }

  Future<void> _lesson(int moduleIndex, [int? lessonIndex]) async {
    final module = _modules[moduleIndex];
    final old = lessonIndex == null ? null : module.lessons[lessonIndex];
    final lesson = await Navigator.of(context).push<ProgramLesson>(
      MaterialPageRoute(builder: (_) => _LessonEditor(lesson: old)),
    );
    if (lesson == null || !mounted) return;
    setState(() {
      final lessons = [...module.lessons];
      if (lessonIndex == null) {
        lessons.add(lesson);
      } else {
        lessons[lessonIndex] = lesson;
      }
      _modules[moduleIndex] = ProgramModule(
        id: module.id,
        title: module.title,
        lessons: lessons,
      );
      _dirty = true;
    });
  }

  Future<void> _remove(int moduleIndex, [int? lessonIndex]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover do programa?'),
        content: const Text(
          'A alteração será aplicada quando você salvar o programa. Evite remover aulas já publicadas para preservar a continuidade dos alunos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      if (lessonIndex == null) {
        _modules.removeAt(moduleIndex);
      } else {
        final m = _modules[moduleIndex];
        final lessons = [...m.lessons]..removeAt(lessonIndex);
        _modules[moduleIndex] = ProgramModule(
          id: m.id,
          title: m.title,
          lessons: lessons,
        );
      }
      _dirty = true;
    });
  }

  void _move(int moduleIndex, int delta, [int? lessonIndex]) {
    setState(() {
      if (lessonIndex == null) {
        final item = _modules.removeAt(moduleIndex);
        _modules.insert(moduleIndex + delta, item);
      } else {
        final m = _modules[moduleIndex];
        final lessons = [...m.lessons];
        final item = lessons.removeAt(lessonIndex);
        lessons.insert(lessonIndex + delta, item);
        _modules[moduleIndex] = ProgramModule(
          id: m.id,
          title: m.title,
          lessons: lessons,
        );
      }
      _dirty = true;
    });
  }

  Future<bool> _leave() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text(
              'Você tem alterações que ainda não foram salvas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuar editando'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int lines = 1,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      minLines: lines,
      maxLines: lines == 1 ? 1 : null,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Preencha este campo.' : null
          : null,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _saving) return;
      if (await _leave() && mounted) {
        setState(() => _dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Editar programa')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _form,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _field(_title, 'Título', required: true),
              _field(_tagline, 'Apresentação curta'),
              _field(_description, 'Descrição', lines: 3),
              _field(_topic, 'Tema', required: true),
              _field(_weeks, 'Ritmo sugerido em semanas'),
              _field(_outcomes, 'Objetivos (um por linha)', lines: 3),
              DropdownButtonFormField<ContentLevel>(
                initialValue: _level,
                decoration: const InputDecoration(labelText: 'Nível'),
                items: ContentLevel.values
                    .map((l) => DropdownMenuItem(value: l, child: Text(l.name)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _level = value!;
                  _dirty = true;
                }),
              ),
              SwitchListTile(
                title: const Text('Publicado'),
                subtitle: const Text(
                  'Rascunhos ficam visíveis apenas para administradores.',
                ),
                value: _published,
                onChanged: (v) => setState(() {
                  _published = v;
                  _dirty = true;
                }),
              ),
              for (var i = 0; i < _modules.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${i + 1}. ${_modules[i].title}'),
                          onTap: () => _module(i),
                        ),
                        Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Subir módulo',
                              onPressed: i > 0 ? () => _move(i, -1) : null,
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'Descer módulo',
                              onPressed: i < _modules.length - 1
                                  ? () => _move(i, 1)
                                  : null,
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              tooltip: 'Remover módulo',
                              onPressed: () => _remove(i),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        for (var j = 0; j < _modules[i].lessons.length; j++)
                          Column(
                            children: [
                              ListTile(
                                title: Text(_modules[i].lessons[j].title),
                                subtitle: const Text(
                                  'Toque para editar a aula',
                                ),
                                onTap: () => _lesson(i, j),
                              ),
                              Wrap(
                                children: [
                                  IconButton(
                                    tooltip: 'Subir aula',
                                    onPressed: j > 0
                                        ? () => _move(i, -1, j)
                                        : null,
                                    icon: const Icon(Icons.arrow_upward),
                                  ),
                                  IconButton(
                                    tooltip: 'Descer aula',
                                    onPressed:
                                        j < _modules[i].lessons.length - 1
                                        ? () => _move(i, 1, j)
                                        : null,
                                    icon: const Icon(Icons.arrow_downward),
                                  ),
                                  IconButton(
                                    tooltip: 'Remover aula',
                                    onPressed: () => _remove(i, j),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        TextButton.icon(
                          onPressed: () => _lesson(i),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar aula'),
                        ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _module(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar módulo'),
              ),
              SwitchListTile(
                title: const Text('Destacar uma aula'),
                subtitle: const Text(
                  'Seleção manual exibida no Início e em Conteúdo até a data escolhida.',
                ),
                value: _featured,
                onChanged: (value) => setState(() {
                  _featured = value;
                  _featuredUntil ??= DateTime.now().add(
                    const Duration(days: 7),
                  );
                  final lessons = _modules.expand((m) => m.lessons).toList();
                  if (_featuredLesson == null && lessons.isNotEmpty) {
                    _featuredLesson = lessons.first.id;
                  }
                  _dirty = true;
                }),
              ),
              if (_featured) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'featured-${_modules.expand((m) => m.lessons).map((l) => l.id).join(',')}',
                  ),
                  initialValue:
                      _modules
                          .expand((m) => m.lessons)
                          .any((l) => l.id == _featuredLesson)
                      ? _featuredLesson
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Aula em destaque',
                  ),
                  items: _modules
                      .expand((m) => m.lessons)
                      .map(
                        (l) => DropdownMenuItem(
                          value: l.id,
                          child: Text(
                            l.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _featuredLesson = value;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _featuredNote,
                  maxLength: 400,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Apresentação do destaque (opcional)',
                  ),
                ),
                TextButton.icon(
                  onPressed: _chooseFeaturedEnd,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    _featuredUntil == null
                        ? 'Escolher data final'
                        : 'Destacar até ${_featuredUntil!.toLocal().day}/${_featuredUntil!.toLocal().month}/${_featuredUntil!.toLocal().year}',
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ProgramDetailScreen(program: _model(), preview: true),
                  ),
                ),
                child: const Text('Visualizar programa'),
              ),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando…' : 'Salvar programa'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LessonEditor extends StatefulWidget {
  const _LessonEditor({this.lesson});
  final ProgramLesson? lesson;
  @override
  State<_LessonEditor> createState() => _LessonEditorState();
}

class _LessonEditorState extends State<_LessonEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _body, _practice, _minutes;
  String? _habit;
  late final TextEditingController _mediaTitle,
      _mediaAuthor,
      _mediaSummary,
      _mediaUrl,
      _mediaThumbnail,
      _mediaAudio;
  bool _mediaEnabled = false;
  LessonMediaKind _mediaKind = LessonMediaKind.video;
  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    _title = TextEditingController(text: l?.title);
    _body = TextEditingController(text: l?.body);
    _practice = TextEditingController(text: l?.practice);
    _minutes = TextEditingController(text: '${l?.minutes ?? 3}');
    _habit = l?.habitKey;
    final media = l?.media;
    _mediaEnabled = media != null;
    _mediaKind = media?.kind ?? LessonMediaKind.video;
    _mediaTitle = TextEditingController(text: media?.title);
    _mediaAuthor = TextEditingController(text: media?.author);
    _mediaSummary = TextEditingController(text: media?.summary);
    _mediaUrl = TextEditingController(text: media?.url);
    _mediaThumbnail = TextEditingController(text: media?.thumbnailUrl);
    _mediaAudio = TextEditingController(text: media?.audioUrl);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _body,
      _practice,
      _minutes,
      _mediaTitle,
      _mediaAuthor,
      _mediaSummary,
      _mediaUrl,
      _mediaThumbnail,
      _mediaAudio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _mediaField(
    TextEditingController controller,
    String label, {
    int lines = 1,
    bool optional = false,
    bool url = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : null,
      keyboardType: url ? TextInputType.url : TextInputType.multiline,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return optional ? null : 'Preencha este campo.';
        return url && !LessonMedia.isWebUrl(text)
            ? 'Informe um link https:// válido.'
            : null;
      },
    ),
  );

  LessonMedia? _media() => !_mediaEnabled
      ? null
      : LessonMedia(
          title: _mediaTitle.text.trim(),
          author: _mediaAuthor.text.trim(),
          summary: _mediaSummary.text.trim(),
          url: _mediaUrl.text.trim(),
          kind: _mediaKind,
          thumbnailUrl: _mediaThumbnail.text.trim().isEmpty
              ? null
              : _mediaThumbnail.text.trim(),
          audioUrl: _mediaAudio.text.trim().isEmpty
              ? null
              : _mediaAudio.text.trim(),
        );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Editar aula')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Título'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Informe um título.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duração de leitura e prática em minutos',
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 180
                  ? 'Informe entre 1 e 180 minutos.'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _body,
            minLines: 8,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Texto da aula'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _practice,
            minLines: 3,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Prática proposta'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _habit ?? '',
            decoration: const InputDecoration(
              labelText: 'Hábito relacionado (opcional)',
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Sem vínculo')),
              ...habitCatalog.map(
                (h) => DropdownMenuItem(value: h.key, child: Text(h.title)),
              ),
            ],
            onChanged: (v) => setState(() => _habit = v == '' ? null : v),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vídeo ou podcast relacionado'),
            value: _mediaEnabled,
            onChanged: (value) => setState(() => _mediaEnabled = value),
          ),
          if (_mediaEnabled) ...[
            DropdownButtonFormField<LessonMediaKind>(
              initialValue: _mediaKind,
              decoration: const InputDecoration(labelText: 'Formato'),
              items: const [
                DropdownMenuItem(
                  value: LessonMediaKind.video,
                  child: Text('Vídeo'),
                ),
                DropdownMenuItem(
                  value: LessonMediaKind.podcast,
                  child: Text('Podcast'),
                ),
              ],
              onChanged: (value) => setState(() => _mediaKind = value!),
            ),
            const SizedBox(height: 16),
            _mediaField(_mediaTitle, 'Título do vídeo ou episódio'),
            _mediaField(_mediaAuthor, 'Autor / Canal'),
            _mediaField(_mediaSummary, 'Resumo da prévia', lines: 3),
            _mediaField(_mediaUrl, 'Link para assistir', url: true),
            _mediaField(
              _mediaThumbnail,
              'Link da capa (opcional)',
              optional: true,
              url: true,
            ),
            _mediaField(
              _mediaAudio,
              'Link para ouvir (opcional)',
              optional: true,
              url: true,
            ),
          ],
          ElevatedButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(
                context,
                ProgramLesson(
                  id:
                      widget.lesson?.id ??
                      'l_${DateTime.now().microsecondsSinceEpoch}',
                  title: _title.text.trim(),
                  body: _body.text.trim(),
                  practice: _practice.text.trim(),
                  minutes: int.parse(_minutes.text),
                  habitKey: _habit,
                  media: _media(),
                ),
              );
            },
            child: const Text('Salvar aula no programa'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Publique o programa depois de revisar o texto e a prática de todas as aulas.',
          ),
        ],
      ),
    ),
  );
}
