import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/private_support_service.dart';
import 'support_history_screen.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});
  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final _client = Supabase.instance.client;
  final _items = <Map<String, dynamic>>[];
  bool _loading = false, _more = true;
  bool _showResolved = false;
  String? _error;
  final _resolving = <String>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _more = true;
      }
    });
    try {
      final rows = await _client
          .from('private_support_requests')
          .select('id,user_id,kind,message,created_at,resolved')
          .eq('resolved', _showResolved)
          .order('created_at')
          .order('id')
          .range(_items.length, _items.length + 29);
      if (mounted)
        setState(() {
          _items.addAll(rows);
          _more = rows.length == 30;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível carregar as solicitações.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(String id) async {
    if (_resolving.contains(id) || _loading) return;
    setState(() => _resolving.add(id));
    try {
      final rows = await _client
          .from('private_support_requests')
          .update({'resolved': true})
          .eq('id', id)
          .select('id');
      if (rows.isEmpty) throw StateError('Permission denied');
      if (mounted)
        setState(() => _items.removeWhere((item) => item['id'] == id));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível concluir a solicitação.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _resolving.remove(id));
    }
  }

  Future<void> _reply(String id) => showDialog<void>(
    context: context,
    builder: (_) => _SupportReplyDialog(requestId: id),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Atendimento privado'),
      actions: [
        IconButton(
          onPressed: _loading || _resolving.isNotEmpty
              ? null
              : () => _load(reset: true),
          tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile.adaptive(
          title: const Text('Mostrar atendidos'),
          value: _showResolved,
          onChanged: _loading || _resolving.isNotEmpty
              ? null
              : (value) {
                  setState(() => _showResolved = value);
                  _load(reset: true);
                },
        ),
        const Text(
          'Pedidos de exclusão devem ser processados pela equipe. Marcar como atendido não apaga a conta.',
        ),
        const SizedBox(height: 16),
        if (_error != null) Text(_error!),
        if (_items.isEmpty && !_loading && _error == null)
          Text(
            _showResolved
                ? 'Nenhuma solicitação atendida.'
                : 'Nenhuma solicitação pendente.',
          ),
        for (final item in _items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['kind'] == 'account_deletion'
                        ? 'Exclusão de conta'
                        : 'Ajuda',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText('Conta: ${item['user_id']}'),
                  SelectableText('Protocolo: ${item['id']}'),
                  const SizedBox(height: 12),
                  SelectableText(item['message'] as String),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _resolving.contains(item['id'])
                            ? null
                            : () => _reply(item['id'] as String),
                        child: const Text('Responder'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SupportRequestScreen(request: item),
                          ),
                        ),
                        child: const Text('Ver respostas'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed:
                        item['resolved'] == true ||
                            _resolving.contains(item['id']) ||
                            _loading
                        ? null
                        : () => _resolve(item['id'] as String),
                    child: const Text('Marcar como atendido'),
                  ),
                ],
              ),
            ),
          ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading && (_more || _error != null))
          TextButton(
            onPressed: _resolving.isEmpty ? _load : null,
            child: const Text('Carregar solicitações'),
          ),
      ],
    ),
  );
}

class _SupportReplyDialog extends StatefulWidget {
  const _SupportReplyDialog({required this.requestId});
  final String requestId;
  @override
  State<_SupportReplyDialog> createState() => _SupportReplyDialogState();
}

class _SupportReplyDialogState extends State<_SupportReplyDialog> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _text.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PrivateSupportService().reply(widget.requestId, _text.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Não foi possível enviar. Sua resposta continua aqui.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Responder ao membro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _text,
              enabled: !_busy,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Resposta privada'),
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _busy ? null : _send,
          child: Text(_busy ? 'Enviando...' : 'Enviar'),
        ),
      ],
    ),
  );
}
