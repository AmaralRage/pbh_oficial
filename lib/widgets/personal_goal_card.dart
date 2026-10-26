import 'package:flutter/material.dart';
import '../services/personal_goal_service.dart';

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

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Meu objetivo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
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
          ] else if (_goal == null) ...[
            const Text(
              'Escolha algo que deseja desenvolver e defina um próximo passo possível.',
            ),
            FilledButton(
              onPressed: _edit,
              child: const Text('Definir objetivo'),
            ),
          ] else ...[
            Text(
              _goal!['title'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if ((_goal!['next_step'] as String).isNotEmpty)
              Text('Próximo passo: ${_goal!['next_step']}'),
            const SizedBox(height: 8),
            Text(
              _goal!['is_public'] == true
                  ? 'Objetivo compartilhado no seu perfil público'
                  : 'Objetivo privado',
            ),
            const Text('Os registros de avanço são sempre privados.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _advance,
              child: const Text('Registrar um avanço'),
            ),
            TextButton(
              onPressed: _busy ? null : _edit,
              child: const Text('Editar objetivo e visibilidade'),
            ),
            if (_entries.isNotEmpty)
              ExpansionTile(
                title: const Text('Meus últimos avanços'),
                children: [
                  for (final entry in _entries)
                    ListTile(
                      title: Text(entry['content'] as String),
                      subtitle: Text(entry['goal_title'] as String),
                    ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
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
  });
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Objetivo pessoal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(_goal!['title'] as String),
            if (_goal!['is_public'] != true)
              const Text('Visível somente para você.'),
            if ((_goal!['next_step'] as String).isNotEmpty)
              Text('Próximo passo: ${_goal!['next_step']}'),
          ],
        ),
      ),
    );
  }
}
