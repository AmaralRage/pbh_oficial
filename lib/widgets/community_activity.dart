import 'community_activity_sheet.dart';
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
  bool _failed = false;
  int _unreadCount = 0;
  Future<void>? _pending;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _account = widget.service.currentUserId;
    _auth = widget.service.authChanges.listen((_) {
      if (_account == widget.service.currentUserId) return;
      _account = widget.service.currentUserId;
      if (mounted)
        setState(() {
          _items = [];
          _unreadCount = 0;
        });
      _load();
    });
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)
        _load();
    });
  }

  Future<void> _load() {
    if (_pending != null) return _pending!;
    final account = widget.service.currentUserId;
    return _pending = _fetch().whenComplete(() {
      _pending = null;
      if (mounted && account != widget.service.currentUserId) {
        unawaited(_load());
      }
    });
  }

  Future<void> _fetch() async {
    final account = widget.service.currentUserId;
    try {
      final items = await widget.service.replyActivity();
      final unread = await widget.service.activityUnreadCount();
      if (mounted && account == widget.service.currentUserId)
        setState(() {
          final ids = <String>{};
          _items = items
              .where((item) => ids.add(item['id'] as String))
              .toList();
          _failed = false;
          _unreadCount = unread;
        });
    } catch (_) {
      if (mounted && account == widget.service.currentUserId)
        setState(() => _failed = true);
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
    if (_failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível carregar a atividade. Tente novamente.',
          ),
        ),
      );
      return;
    }
    final item = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommunityActivitySheet(
        service: widget.service,
        initialItems: _items,
        unreadCount: _unreadCount,
        onPreferences: _preferences,
      ),
    );
    if (!mounted || account != widget.service.currentUserId) return;
    if (item == null) {
      await _load();
      return;
    }
    try {
      final viewer = widget.service.currentUserId;
      final post = await widget.service.postById(item['post_id'] as String);
      if (post == null) throw StateError('Publicação indisponível.');
      if (!mounted || viewer != widget.service.currentUserId) return;
      await widget.service.readReply(item['id'] as String);
      if (!mounted || viewer != widget.service.currentUserId) return;
      var displayed = post;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => StatefulBuilder(
            builder: (detailContext, refresh) => Scaffold(
              appBar: AppBar(title: const Text('Atividade da comunidade')),
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
                  openCommentsInitially: item['kind'] != 'post_like',
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

  Future<void> _preferences() async {
    final viewer = widget.service.currentUserId;
    try {
      final preferences = await widget.service.activityPreferences();
      if (!mounted || viewer != widget.service.currentUserId) return;
      var replies = preferences['replies'] != false,
          comments = preferences['post_comments'] != false,
          likes = preferences['post_likes'] != false,
          mentions = preferences['mentions'] != false;
      var saving = false;
      String? error;
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('Avisos da comunidade'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Escolha quais novas atividades aparecem nesta central. Isso não altera os avisos já recebidos.',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Respostas aos comentários'),
                    value: replies,
                    onChanged: saving
                        ? null
                        : (v) => refresh(() => replies = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Comentários nas publicações'),
                    value: comments,
                    onChanged: saving
                        ? null
                        : (v) => refresh(() => comments = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Curtidas nas publicações'),
                    value: likes,
                    onChanged: saving ? null : (v) => refresh(() => likes = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Menções ao seu @usuário'),
                    value: mentions,
                    onChanged: saving
                        ? null
                        : (v) => refresh(() => mentions = v),
                  ),
                  if (error != null) Text(error!),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        refresh(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          if (viewer != widget.service.currentUserId)
                            throw StateError('A conta mudou.');
                          await widget.service.saveActivityOptions(
                            replies,
                            comments,
                            likes,
                            mentions,
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (context.mounted)
                            refresh(() {
                              saving = false;
                              error =
                                  'Não foi possível salvar. Tente novamente.';
                            });
                        }
                      },
                child: Text(saving ? 'Salvando…' : 'Salvar'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar as preferências.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Atividade da comunidade',
    onPressed: _open,
    icon: Badge(
      isLabelVisible: _unreadCount > 0,
      label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
      child: const Icon(Icons.forum_outlined),
    ),
  );
}
