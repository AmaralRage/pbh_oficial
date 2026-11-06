import 'dart:async';
import 'package:flutter/material.dart';
import '../services/private_support_service.dart';
import '../widgets/loading_cards.dart';
import '../widgets/connection_notice.dart';

class SupportHistoryScreen extends StatefulWidget {
  const SupportHistoryScreen({super.key});
  @override
  State<SupportHistoryScreen> createState() => _SupportHistoryScreenState();
}

class _SupportHistoryScreenState extends State<SupportHistoryScreen> {
  final _service = PrivateSupportService();
  late final _account = _service.currentUserId;
  StreamSubscription? _auth;
  final _items = <Map<String, dynamic>>[];
  bool _loading = false, _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    _auth = _service.authChanges.listen((_) {
      if (mounted && _account != _service.currentUserId) {
        setState(() => _items.clear());
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.requests(reset ? 0 : _items.length);
      if (mounted && _account == _service.currentUserId)
        setState(() {
          if (reset) _items.clear();
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
        if (_error != null) ConnectionNotice(onRetry: () => _load(reset: true)),
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
        if (_loading)
          const LoadingCards(
            count: 2,
            showMedia: false,
            label: 'Carregando pedidos',
          ),
        if (!_loading && _more && _error == null)
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
  final _service = PrivateSupportService();
  late final _account = _service.currentUserId;
  final _replies = <Map<String, dynamic>>[];
  StreamSubscription? _auth;
  bool _loading = false, _more = true;
  String? _error;
  int _version = 0;
  @override
  void initState() {
    super.initState();
    _load();
    _auth = _service.authChanges.listen((_) {
      if (mounted && _account != _service.currentUserId) {
        setState(() => _replies.clear());
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.replies(
        widget.request['id'] as String,
        offset: reset ? 0 : _replies.length,
      );
      if (!mounted || _account != _service.currentUserId || version != _version)
        return;
      setState(() {
        if (reset) _replies.clear();
        _replies.addAll(rows);
        _more = rows.length == 30;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _account != _service.currentUserId) return;
        try {
          await _service.markRepliesRead(
            rows.map((r) => r['id'] as String).toList(),
          );
        } catch (_) {}
      });
    } catch (_) {
      if (mounted && version == _version)
        setState(
          () => _error =
              'Não foi possível carregar as respostas. Confira a conexão e tente novamente.',
        );
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Seu atendimento'),
      actions: [
        IconButton(
          onPressed: _loading ? null : () => _load(reset: true),
          tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
          if (_replies.isEmpty && !_loading && _error == null)
            const Text('Aguardando a resposta da equipe.'),
          for (final reply in _replies)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(reply['message'] as String),
              ),
            ),
          if (_loading)
            const LoadingCards(
              count: 2,
              showMedia: false,
              label: 'Carregando respostas',
            ),
          if (_error != null)
            ConnectionNotice(onRetry: () => _load(reset: _replies.isEmpty)),
          if (!_loading && _more && _error == null)
            TextButton(
              onPressed: () => _load(),
              child: Text(
                _error != null ? 'Tentar novamente' : 'Carregar respostas',
              ),
            ),
        ],
      ),
    ),
  );
}
