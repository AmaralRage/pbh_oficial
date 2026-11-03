import 'dart:async';
import 'package:flutter/material.dart';
import '../services/community_service.dart';
import 'community_post_card.dart';

class CommunityActivityButton extends StatefulWidget {
  const CommunityActivityButton({super.key, required this.service});
  final CommunityService service;
  @override
  State<CommunityActivityButton> createState() =>
      _CommunityActivityButtonState();
}

class _CommunityActivityButtonState extends State<CommunityActivityButton>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  Timer? _timer;
  StreamSubscription? _auth;
  String? _account;
  bool _failed = false, _loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _account = widget.service.currentUserId;
    _auth = widget.service.authChanges.listen((_) {
      if (_account == widget.service.currentUserId) return;
      _account = widget.service.currentUserId;
      if (mounted) setState(() => _items = []);
      _load();
    });
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)
        _load();
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final account = widget.service.currentUserId;
    try {
      final items = await widget.service.replyActivity();
      if (mounted && account == widget.service.currentUserId)
        setState(() {
          final ids = <String>{};
          _items = items
              .where((item) => ids.add(item['id'] as String))
              .toList();
          _failed = false;
        });
    } catch (_) {
      if (mounted && account == widget.service.currentUserId)
        setState(() => _failed = true);
    } finally {
      _loading = false;
      if (mounted && account != widget.service.currentUserId) _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _open() async {
    final account = widget.service.currentUserId;
    await _load();
    if (!mounted || account != widget.service.currentUserId) return;
    final items = List<Map<String, dynamic>>.of(_items);
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Respostas aos seus comentários',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (_failed)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Não foi possível carregar. Feche e tente novamente.',
                  ),
                ),
              if (!_failed && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'As respostas aos seus comentários aparecerão aqui.',
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in items)
                      ListTile(
                        tileColor: item['read_at'] == null
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .08)
                            : null,
                        leading: Icon(
                          item['read_at'] == null
                              ? Icons.mark_chat_unread_outlined
                              : Icons.chat_bubble_outline,
                        ),
                        title: Text(
                          'Responderam ao seu comentário',
                          style: TextStyle(
                            fontWeight: item['read_at'] == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          (DateTime.tryParse(
                                    item['created_at'] as String,
                                  )?.toLocal().toString() ??
                                  '')
                              .split('.')
                              .first,
                        ),
                        onTap: () =>
                            Navigator.pop(context, item['id'] as String),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (id == null || !mounted || account != widget.service.currentUserId)
      return;
    try {
      final viewer = widget.service.currentUserId;
      final item = items.firstWhere((n) => n['id'] == id);
      final post = await widget.service.postById(item['post_id'] as String);
      if (post == null) throw StateError('Publicação indisponível.');
      if (!mounted || viewer != widget.service.currentUserId) return;
      await widget.service.readReply(id);
      if (!mounted || viewer != widget.service.currentUserId) return;
      var displayed = post;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => StatefulBuilder(
            builder: (detailContext, refresh) => Scaffold(
              appBar: AppBar(title: const Text('Resposta da comunidade')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CommunityPostCard(
                  post: displayed,
                  isAuthenticated: true,
                  onRequireLogin: () {},
                  onChanged: () async {
                    final updated = await widget.service.postById(post.id);
                    if (!detailContext.mounted) return;
                    if (updated == null ||
                        widget.service.currentUserId != viewer) {
                      Navigator.pop(detailContext);
                      return;
                    }
                    refresh(() => displayed = updated);
                  },
                  openCommentsInitially: true,
                  focusCommentId: item['comment_id'] as String?,
                ),
              ),
            ),
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir a resposta. A publicação pode ter sido removida.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Respostas da comunidade',
    onPressed: _open,
    icon: Badge(
      isLabelVisible: _items.any((n) => n['read_at'] == null),
      label: Text('${_items.where((n) => n['read_at'] == null).length}'),
      child: const Icon(Icons.forum_outlined),
    ),
  );
}
