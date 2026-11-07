import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatMessageSearch extends StatefulWidget {
  const ChatMessageSearch({
    super.key,
    required this.service,
    required this.threadId,
  });
  final ChatService service;
  final String threadId;
  @override
  State<ChatMessageSearch> createState() => _ChatMessageSearchState();
}

class _ChatMessageSearchState extends State<ChatMessageSearch> {
  final _text = TextEditingController();
  final _results = <ChatMessage>[];
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false, _failed = false, _more = false;
  String? _account;
  @override
  void initState() {
    super.initState();
    _account = widget.service.userId;
  }

  Future<void> _search({bool older = false}) async {
    final query = _text.text.trim();
    final generation = ++_generation;
    if (query.length < 2) {
      setState(() {
        _results.clear();
        _loading = false;
        _failed = false;
        _more = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
      if (!older) _results.clear();
    });
    try {
      final rows = await widget.service.searchMessages(
        widget.threadId,
        query,
        before: older ? _results.lastOrNull : null,
      );
      if (!mounted ||
          generation != _generation ||
          _account != widget.service.userId)
        return;
      setState(() {
        _results.addAll(rows);
        _more = rows.length == 30;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buscar na conversa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Mensagens disponíveis nos últimos 7 dias.'),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Digite pelo menos 2 caracteres',
                counterText: '',
              ),
              onChanged: (_) {
                _generation++;
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _search(),
                );
              },
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_failed)
              TextButton(
                onPressed: () => _search(),
                child: const Text('Não foi possível buscar. Tentar novamente'),
              ),
            Expanded(
              child: _account != widget.service.userId
                  ? const Center(child: Text('Sua conta mudou.'))
                  : ListView(
                      children: [
                        if (!_loading &&
                            !_failed &&
                            _text.text.trim().length >= 2 &&
                            _results.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Nenhuma mensagem encontrada.'),
                          ),
                        for (final message in _results)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            title: Text(
                              message.body,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${message.senderId == _account ? 'Você' : 'Membro'} · ${message.createdAt.day}/${message.createdAt.month} às ${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                            ),
                            trailing: const Icon(Icons.reply_rounded),
                            onTap: () => Navigator.pop(context, message),
                          ),
                        if (_more)
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => _search(older: true),
                            child: const Text('Mais resultados'),
                          ),
                      ],
                    ),
            ),
            const Text(
              'Toque em um resultado para responder à mensagem.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
