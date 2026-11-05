import 'package:flutter/material.dart';
import '../services/private_support_service.dart';

class SupportHistoryScreen extends StatefulWidget {
  const SupportHistoryScreen({super.key});
  @override
  State<SupportHistoryScreen> createState() => _SupportHistoryScreenState();
}

class _SupportHistoryScreenState extends State<SupportHistoryScreen> {
  final _service = PrivateSupportService();
  final _items = <Map<String, dynamic>>[];
  bool _loading = false, _more = true;
  String? _error;
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
      if (reset) _items.clear();
    });
    try {
      final rows = await _service.requests(_items.length);
      if (mounted)
        setState(() {
          _items.addAll(rows);
          _more = rows.length == 30;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível carregar seus pedidos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Meus pedidos de suporte'),
      actions: [
        IconButton(
          onPressed: _loading ? null : () => _load(reset: true),
          tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_error != null) Text(_error!),
        if (_items.isEmpty && !_loading && _error == null)
          const Text('Você ainda não enviou pedidos.'),
        for (final item in _items)
          Card(
            child: InkWell(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['kind'] == 'account_deletion'
                                ? 'Exclusão de conta'
                                : 'Ajuda',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['resolved'] == true ? 'Atendido' : 'Em atendimento',
                    ),
                    const SizedBox(height: 8),
                    Text('Protocolo: ${item['id']}'),
                  ],
                ),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SupportRequestScreen(request: item),
                ),
              ),
            ),
          ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading && (_more || _error != null))
          TextButton(onPressed: _load, child: const Text('Carregar pedidos')),
      ],
    ),
  );
}

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({super.key, required this.request});
  final Map<String, dynamic> request;
  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  late Future<List<Map<String, dynamic>>> _replies;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _replies = PrivateSupportService().replies(widget.request['id'] as String);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Seu atendimento'),
      actions: [
        IconButton(
          onPressed: () => setState(_refresh),
          tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SelectableText('Protocolo: ${widget.request['id']}'),
        const SizedBox(height: 16),
        SelectableText(widget.request['message'] as String),
        const SizedBox(height: 24),
        Text(
          'Respostas da equipe',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _replies,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Text(
                'Não foi possível carregar as respostas. Toque em atualizar.',
              );
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty)
              return const Text('Aguardando a resposta da equipe.');
            return Column(
              children: [
                for (final reply in snapshot.data!)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(reply['message'] as String),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
