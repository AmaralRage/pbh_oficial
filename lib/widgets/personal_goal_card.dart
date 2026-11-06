import 'package:flutter/material.dart';
import 'profile_surface.dart';
import '../services/personal_goal_service.dart';
import '../core/theme/app_colors.dart';
import '../screens/personal_goal_history_screen.dart';

class PersonalGoalCard extends StatefulWidget {
  const PersonalGoalCard({
    super.key,
    required this.isAuthenticated,
    this.onSignIn,
    this.service,
  });
  final bool isAuthenticated;
  final VoidCallback? onSignIn;
  final PersonalGoalService? service;
  @override
  State<PersonalGoalCard> createState() => _PersonalGoalCardState();
}

class _PersonalGoalCardState extends State<PersonalGoalCard> {
  late final _service = widget.service ?? PersonalGoalService();
  Map<String, dynamic>? _goal;
  List<Map<String, dynamic>> _entries = [];
  String? _error;
  bool _loading = true, _busy = false;
  String _entryDraft = '';
  @override
  void initState() {
    super.initState();
    if (widget.isAuthenticated) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    try {
      final goal = await _service.load();
      final entries = goal == null
          ? <Map<String, dynamic>>[]
          : await _service.entries();
      if (mounted) {
        setState(() {
          _goal = goal;
          _entries = entries;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar seu objetivo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GoalEditor(service: _service, goal: _goal),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _advance() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _GoalEntryEditor(initial: _entryDraft)),
    );
    if (text == null || !mounted) return;
    setState(() => _busy = true);
    _entryDraft = text;
    try {
      await _service.addEntry(_goal!['title'] as String, text);
      _entryDraft = '';
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível registrar. Seu texto foi preservado; toque em registrar um avanço para tentar novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Concluir este objetivo?'),
        content: Text(
          _entryDraft.isEmpty
              ? 'O objetivo e seus avanços ficam guardados no histórico privado. Depois você poderá definir um novo objetivo.'
              : 'Há um avanço ainda não enviado. Ao concluir, esse rascunho será descartado; os registros já salvos continuam no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.complete();
      _entryDraft = '';
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível concluir. Atualize o objetivo e tente novamente.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _history({bool timeline = false}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PersonalGoalHistoryScreen(
        service: _service,
        goalId: timeline ? _goal!['goal_id'] as String : null,
        title: timeline ? 'Linha do tempo' : 'Histórico de objetivos',
        timeline: timeline,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    final active = _goal != null && !_loading && _error == null;
    return ProfileSurface(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.orange.withValues(alpha: .3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colors.orange.withValues(alpha: .08),
              colors.surface,
            ),
            colors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.orangeDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.my_location_rounded,
                  color: colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEU OBJETIVO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: colors.orange,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Um passo de cada vez',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                IconButton(
                  tooltip: 'Editar objetivo e visibilidade',
                  onPressed: _busy ? null : _edit,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (!widget.isAuthenticated) ...[
            const Text(
              'Entre para registrar um objetivo e acompanhar seus avanços.',
            ),
            TextButton(onPressed: widget.onSignIn, child: const Text('Entrar')),
          ] else if (_loading)
            const LinearProgressIndicator()
          else if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Tentar novamente')),
          ] else if (!active) ...[
            Text(
              'Escolha algo que deseja desenvolver e defina um próximo passo possível.',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Definir objetivo'),
            ),
          ] else ...[
            Text(
              _goal!['title'] as String,
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            if ((_goal!['next_step'] as String).trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              ProfileSurface(
                blur: false,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.backgroundElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRÓXIMO PASSO',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: .6,
                              fontWeight: FontWeight.w700,
                              color: colors.orange,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _goal!['next_step'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _goal!['is_public'] == true
                      ? Icons.public_rounded
                      : Icons.lock_outline_rounded,
                  size: 15,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _goal!['is_public'] == true
                        ? 'Objetivo visível no perfil. Seus avanços são privados.'
                        : 'Seu objetivo e seus avanços são privados.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _advance,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded, size: 20),
              label: const Text('Registrar um avanço'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _complete,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 44),
                backgroundColor: Colors.transparent,
              ),
              icon: const Icon(Icons.task_alt, size: 18),
              label: const Text('Concluir objetivo'),
            ),
            if (_entries.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Meus últimos avanços'),
                children: [
                  for (final entry in _entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry['content'] as String),
                      subtitle: Text(
                        goalRecordDate(context, entry['created_at'] as String),
                      ),
                    ),
                ],
              ),
          ],
          if (widget.isAuthenticated && !_loading) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.borderSubtle),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              children: [
                if (active && _goal!['goal_id'] != null)
                  TextButton.icon(
                    onPressed: _busy ? null : () => _history(timeline: true),
                    icon: const Icon(Icons.timeline_rounded, size: 17),
                    label: const Text('Linha do tempo'),
                  ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _history(),
                  icon: const Icon(Icons.history_rounded, size: 17),
                  label: const Text('Histórico'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({required this.service, this.goal});
  final PersonalGoalService service;
  final Map<String, dynamic>? goal;
  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.goal?['title'] as String?,
  );
  late final _step = TextEditingController(
    text: widget.goal?['next_step'] as String?,
  );
  late bool _public = widget.goal?['is_public'] == true;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _step.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.service.save(_title.text, _step.text, _public);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar seu objetivo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Meu objetivo')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _title,
            maxLength: 180,
            decoration: const InputDecoration(
              labelText: 'O que quero desenvolver',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Escreva seu objetivo.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _step,
            maxLength: 300,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Meu próximo passo'),
          ),
          SwitchListTile(
            title: const Text('Compartilhar no perfil público'),
            subtitle: const Text(
              'Mostra apenas o objetivo e o próximo passo, respeitando a privacidade do perfil. Seus avanços continuam privados.',
            ),
            value: _public,
            onChanged: _saving ? null : (v) => setState(() => _public = v),
          ),
          if (_error != null) Text(_error!),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando…' : 'Salvar objetivo'),
          ),
        ],
      ),
    ),
  );
}

class _GoalEntryEditor extends StatefulWidget {
  const _GoalEntryEditor({this.initial = ''});
  final String initial;
  @override
  State<_GoalEntryEditor> createState() => _GoalEntryEditorState();
}

class _GoalEntryEditorState extends State<_GoalEntryEditor> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar um avanço')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Este registro é privado.'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _text,
            maxLength: 1000,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Qual pequeno passo você deu?',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Escreva seu avanço.' : null,
          ),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop(context, _text.text.trim());
              }
            },
            child: const Text('Salvar avanço'),
          ),
        ],
      ),
    ),
  );
}

class PublicGoalCard extends StatefulWidget {
  const PublicGoalCard({
    super.key,
    required this.userId,
    required this.service,
    this.isOwn = false,
  });
  final bool isOwn;
  final String userId;
  final PersonalGoalService service;
  @override
  State<PublicGoalCard> createState() => _PublicGoalCardState();
}

class _PublicGoalCardState extends State<PublicGoalCard> {
  Map<String, dynamic>? _goal;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final goal = await widget.service.publicGoal(widget.userId);
      if (mounted) {
        setState(() {
          _goal = goal;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return TextButton(
        onPressed: _load,
        child: const Text(
          'Não foi possível carregar o objetivo. Tentar novamente',
        ),
      );
    }
    if (_goal == null) return const SizedBox.shrink();
    final colors = context.pbhColors;
    final nextStep = (_goal!['next_step'] as String).trim();
    return ProfileSurface(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.orange.withValues(alpha: .3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colors.orange.withValues(alpha: .08),
              colors.surface,
            ),
            colors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.orangeDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.my_location_rounded,
                  size: 22,
                  color: colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isOwn ? 'MEU OBJETIVO' : 'OBJETIVO PESSOAL',
                      style: TextStyle(
                        color: colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Um passo de cada vez',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_goal!['is_public'] != true)
                Tooltip(
                  message: 'Visível somente para você.',
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: colors.orange,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _goal!['title'] as String,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (nextStep.isNotEmpty) ...[
            const SizedBox(height: 16),
            ProfileSurface(
              blur: false,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.backgroundElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRÓXIMO PASSO',
                          style: TextStyle(
                            color: colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nextStep,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
