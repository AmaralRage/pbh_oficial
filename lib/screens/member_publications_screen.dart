import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/loading_cards.dart';
import '../widgets/connection_notice.dart';
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
  bool _retryReset = false;
  int _offset = 0, _version = 0;
  final _postRefreshVersions = <String, int>{};
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
      if (mounted && version == _version)
        setState(() {
          _failed = true;
          _retryReset = reset;
        });
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  Future<void> _refreshPost(String id, {bool reportFailure = false}) async {
    final version = _version;
    final refresh = (_postRefreshVersions[id] ?? 0) + 1;
    _postRefreshVersions[id] = refresh;
    try {
      final post = await _service.postById(id);
      if (!mounted ||
          version != _version ||
          _postRefreshVersions[id] != refresh)
        return;
      setState(() {
        final index = _posts.indexWhere((p) => p.id == id);
        if (index < 0) return;
        if (post == null)
          _posts.removeAt(index);
        else
          _posts[index] = post.copyWith(
            isSaved: _posts[index].isSaved,
            isFollowing: _posts[index].isFollowing,
          );
      });
    } catch (_) {
      if (reportFailure && mounted && version == _version)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'A alteração foi salva, mas não foi possível atualizar a visualização.',
            ),
            action: SnackBarAction(
              label: 'Atualizar',
              onPressed: () => _refreshPost(id, reportFailure: true),
            ),
          ),
        );
      /* Keep the optimistic reaction until the next refresh. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Publicações do membro')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _loading && _posts.isEmpty
          ? const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: LoadingCards(),
            )
          : ListView.builder(
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
                          ? ConnectionNotice(
                              onRetry: () => _load(reset: _retryReset),
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
                    onRequireLogin: () =>
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Entre na sua conta para interagir.'),
                          ),
                        ),
                    onChanged: () => _load(reset: true),
                    onInteractionChanged: () => _refreshPost(post.id),
                    onPublicationChanged: () =>
                        _refreshPost(post.id, reportFailure: true),
                  ),
                );
              },
            ),
    ),
  );
}
