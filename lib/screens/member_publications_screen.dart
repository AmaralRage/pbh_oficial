import 'dart:async';
import 'package:flutter/material.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';
import '../widgets/community_post_card.dart';

class MemberPublicationsScreen extends StatefulWidget {
  const MemberPublicationsScreen({super.key, required this.userId});
  final String userId;
  @override
  State<MemberPublicationsScreen> createState() =>
      _MemberPublicationsScreenState();
}

class _MemberPublicationsScreenState extends State<MemberPublicationsScreen> {
  final _service = CommunityService();
  final _posts = <CommunityPostModel>[];
  bool _loading = false, _failed = false, _more = true;
  int _offset = 0, _version = 0;
  StreamSubscription? _auth;
  String? _account;
  @override
  void initState() {
    super.initState();
    _account = _service.currentUserId;
    _auth = _service.authChanges.listen((_) {
      if (_account == _service.currentUserId) return;
      _account = _service.currentUserId;
      setState(() => _posts.clear());
      _load(reset: true);
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final version = ++_version;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _offset = 0;
      }
    });
    try {
      final posts = await _service.memberPosts(widget.userId, offset: _offset);
      if (!mounted || version != _version) return;
      setState(() {
        if (reset) _posts.clear();
        final ids = _posts.map((p) => p.id).toSet();
        _posts.addAll(posts.where((p) => ids.add(p.id)));
        _offset += posts.length;
        _more = posts.length == 20;
      });
    } catch (_) {
      if (mounted && version == _version) setState(() => _failed = true);
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  Future<void> _refreshPost(String id) async {
    final version = _version;
    try {
      final post = await _service.postById(id);
      if (!mounted || version != _version) return;
      setState(() {
        final index = _posts.indexWhere((p) => p.id == id);
        if (index < 0) return;
        if (post == null)
          _posts.removeAt(index);
        else
          _posts[index] = post;
      });
    } catch (_) {
      /* Keep the optimistic reaction until the next refresh. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Publicações do membro')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index == _posts.length)
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : _failed
                    ? TextButton(
                        onPressed: () => _load(),
                        child: const Text('Tentar novamente'),
                      )
                    : _posts.isEmpty
                    ? const Text('Nenhuma publicação disponível.')
                    : _more
                    ? TextButton(
                        onPressed: () => _load(),
                        child: const Text('Carregar mais'),
                      )
                    : const Text('Você chegou ao fim das publicações.'),
              ),
            );
          final post = _posts[index];
          return Padding(
            key: ValueKey(post.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: CommunityPostCard(
              post: post,
              isAuthenticated: _service.currentUserId != null,
              onRequireLogin: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entre na sua conta para interagir.'),
                ),
              ),
              onChanged: () => _load(reset: true),
              onInteractionChanged: () => _refreshPost(post.id),
            ),
          );
        },
      ),
    ),
  );
}
