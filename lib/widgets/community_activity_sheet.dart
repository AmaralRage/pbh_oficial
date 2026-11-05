import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/community_service.dart';

class CommunityActivitySheet extends StatefulWidget {
  const CommunityActivitySheet({
    super.key,
    required this.service,
    required this.initialItems,
    required this.unreadCount,
    required this.onPreferences,
  });
  final CommunityService service;
  final List<Map<String, dynamic>> initialItems;
  final int unreadCount;
  final VoidCallback onPreferences;
  @override
  State<CommunityActivitySheet> createState() => _CommunityActivitySheetState();
}

class _CommunityActivitySheetState extends State<CommunityActivitySheet> {
  late final _account = widget.service.currentUserId;
  late final _items = List<Map<String, dynamic>>.of(widget.initialItems);
  late int _offset = _items.length, _unread = widget.unreadCount;
  late bool _more = _items.length == 30;
  bool _loading = false, _marking = false;
  String? _error;
  StreamSubscription? _auth;
  @override
  void initState() {
    super.initState();
    _auth = widget.service.authChanges.listen((_) {
      if (!mounted || _account == widget.service.currentUserId) return;
      setState(() {
        _items.clear();
        _unread = 0;
      });
      Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || _marking) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.service.activityPage(
        offset: reset ? 0 : _offset,
      );
      final unread = await widget.service.activityUnreadCount();
      if (!mounted || _account != widget.service.currentUserId) return;
      setState(() {
        if (reset) {
          _items.clear();
          _offset = 0;
        }
        final ids = _items.map((n) => n['id']).toSet();
        _items.addAll(rows.where((n) => ids.add(n['id'])));
        _offset += rows.length;
        _more = rows.length == 30;
        _unread = unread;
      });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível atualizar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    if (_marking || _loading || _items.isEmpty) return;
    final dates =
        _items
            .map((n) => DateTime.tryParse(n['created_at'] as String? ?? ''))
            .whereType<DateTime>()
            .toList()
          ..sort();
    if (dates.isEmpty) return;
    final through = dates.last;
    setState(() {
      _marking = true;
      _error = null;
    });
    try {
      await widget.service.markActivityRead(through);
      final unread = await widget.service.activityUnreadCount();
      if (!mounted || _account != widget.service.currentUserId) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = {
            ..._items[i],
            'read_at':
                _items[i]['read_at'] ??
                DateTime.now().toUtc().toIso8601String(),
          };
        }
        _unread = unread;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Não foi possível marcar os avisos. Tente novamente.',
        );
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Atividade da comunidade',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Preferências de atividade',
                  onPressed: widget.onPreferences,
                  icon: const Icon(Icons.tune),
                ),
                IconButton(
                  tooltip: 'Fechar atividade',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _unread == 0
                    ? 'Você está em dia'
                    : '$_unread ${_unread == 1 ? 'atividade não lida' : 'atividades não lidas'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed:
                    _unread == 0 || _marking || _loading || _items.isEmpty
                    ? null
                    : _markAll,
                icon: const Icon(Icons.done_all),
                label: Text(_marking ? 'Marcando…' : 'Marcar todas como lidas'),
              ),
            ),
          ),
          if (_loading || _marking) const LinearProgressIndicator(),
          const Divider(height: 1),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length + 1,
                itemBuilder: (context, index) {
                  if (index == _items.length)
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: _items.isEmpty
                            ? const Text(
                                'As interações da comunidade aparecerão aqui.',
                              )
                            : _more
                            ? TextButton(
                                onPressed: _loading || _marking
                                    ? null
                                    : () => _load(),
                                child: const Text('Carregar mais atividades'),
                              )
                            : const Text('Você chegou ao fim da atividade.'),
                      ),
                    );
                  final item = _items[index];
                  return _ActivityTile(
                    key: ValueKey(item['id']),
                    item: item,
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({super.key, required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  String _time() {
    final date = DateTime.tryParse(item['created_at'] as String? ?? '');
    if (date == null) return '';
    final age = DateTime.now().difference(date);
    if (age.inMinutes < 1) return 'agora';
    if (age.inHours < 1) return 'há ${age.inMinutes} min';
    if (age.inDays < 1) return 'há ${age.inHours} h';
    return 'há ${age.inDays} ${age.inDays == 1 ? 'dia' : 'dias'}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = item['read_at'] == null;
    final name = item['actor_name'] as String? ?? 'Membro';
    final avatar = item['actor_avatar_url'] as String?;
    final action = switch (item['kind']) {
      'post_like' => 'curtiu sua publicação',
      'post_comment' => 'comentou na sua publicação',
      'mention' => 'mencionou você',
      _ => 'respondeu ao seu comentário',
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      tileColor: unread ? context.pbhColors.orangeDim : null,
      onTap: onTap,
      leading: ClipOval(
        child: SizedBox.square(
          dimension: 40,
          child: avatar?.isNotEmpty == true
              ? Image.network(
                  avatar!,
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person_outline),
                )
              : ColoredBox(
                  color: context.pbhColors.backgroundElevated,
                  child: const Icon(Icons.person_outline),
                ),
        ),
      ),
      title: Text(
        '$name $action',
        style: TextStyle(
          fontSize: 14,
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((item['preview'] as String? ?? '').isNotEmpty)
              Text(
                item['preview'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 5),
            Text(
              '${unread ? 'Não lida · ' : ''}${_time()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
