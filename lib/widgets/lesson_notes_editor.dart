import 'package:flutter/material.dart';
import '../services/lesson_notes_service.dart';

class LessonNotesEditor extends StatefulWidget {
  const LessonNotesEditor({
    super.key,
    required this.programId,
    required this.lessonId,
    this.service,
    this.focusNode,
  });
  final String programId, lessonId;
  final LessonNotesService? service;
  final FocusNode? focusNode;
  @override
  State<LessonNotesEditor> createState() => _LessonNotesEditorState();
}

class _LessonNotesEditorState extends State<LessonNotesEditor> {
  late final _service = widget.service ?? LessonNotesService();
  final _controller = TextEditingController();
  bool _loading = true, _saving = false, _dirty = false, _leaving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final text = await _service.load(widget.programId, widget.lessonId);
      if (mounted) {
        setState(() {
          _controller.text = text;
          _dirty = false;
          _error = null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível abrir suas anotações.');
      }
    }
  }

  Future<bool> _save() async {
    setState(() => _saving = true);
    try {
      await _service.save(widget.programId, widget.lessonId, _controller.text);
      if (mounted) {
        setState(() {
          _dirty = false;
          _error = null;
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível salvar. Suas alterações continuam no campo.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave(bool didPop, Object? result) async {
    if (didPop || _leaving) return;
    _leaving = true;
    final decision = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar sua anotação?'),
        content: const Text('Você tem alterações que ainda não foram salvas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuar escrevendo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Salvar e sair'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final leave =
        decision == 'discard' || (decision == 'save' && await _save());
    if (leave && mounted) {
      setState(() => _dirty = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, result);
    }
    _leaving = false;
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: _leave,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Minhas anotações',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _service.conflict
                  ? 'Há outra versão na sua conta. Seu rascunho foi preservado neste aparelho. Copie o que deseja manter antes de abrir a versão da conta.'
                  : _service.syncPending
                  ? 'Salvas neste aparelho. Sincronização pendente; tente novamente com conexão.'
                  : _service.canSync
                  ? 'Privadas e sincronizadas com sua conta.'
                  : 'Privadas, salvas neste aparelho. Entre na sua conta para sincronizar entre aparelhos.',
            ),
            if (_service.conflict)
              TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Abrir a versão da conta?'),
                            content: const Text(
                              'O texto do campo será substituído. Copie antes qualquer trecho que queira manter.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Abrir'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !mounted) return;
                        setState(() => _saving = true);
                        try {
                          final text = await _service.useRemote(
                            widget.programId,
                            widget.lessonId,
                          );
                          if (mounted)
                            setState(() {
                              _controller.text = text;
                              _dirty = false;
                              _error = null;
                            });
                        } catch (_) {
                          if (mounted)
                            setState(
                              () => _error =
                                  'Não foi possível carregar a versão da conta.',
                            );
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: const Text('Abrir versão da conta'),
              ),
            const SizedBox(height: 12),
            TextField(
              focusNode: widget.focusNode,
              controller: _controller,
              enabled: !_loading && !_saving,
              minLines: 3,
              maxLines: 8,
              maxLength: 6000,
              decoration: const InputDecoration(
                hintText: 'O que esta aula fez você pensar?',
              ),
              onChanged: (_) => setState(() => _dirty = true),
            ),
            if (_error != null) ...[
              Text(_error!),
              if (_loading)
                TextButton(
                  onPressed: _load,
                  child: const Text('Tentar novamente'),
                ),
            ],
            FilledButton(
              onPressed:
                  _loading || _saving || (!_dirty && !_service.syncPending)
                  ? null
                  : _save,
              child: Text(
                _saving
                    ? 'Salvando…'
                    : _service.syncPending && !_dirty
                    ? 'Tentar sincronizar'
                    : _dirty
                    ? 'Salvar anotação'
                    : _controller.text.isEmpty
                    ? 'Escreva para salvar'
                    : 'Anotação salva',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
