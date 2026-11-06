import 'dart:async';
import 'package:flutter/material.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';
import '../widgets/community_post_card.dart';
import '../widgets/loading_cards.dart';
import '../widgets/connection_notice.dart';

class CommunityPublicationScreen extends StatefulWidget {
  const CommunityPublicationScreen({super.key, required this.postId});
  final String postId;
  @override
  State<CommunityPublicationScreen> createState() =>
      _CommunityPublicationScreenState();
}

class _CommunityPublicationScreenState
    extends State<CommunityPublicationScreen> {
  final _service = CommunityService();
  CommunityPostModel? _post;
  bool _loading = true, _failed = false;
  int _version = 0;
  StreamSubscription? _auth;
  @override
  void initState() {
    super.initState();
    _load();
    _auth = _service.authChanges.listen((_) {
      if (mounted) {
        setState(() => _post = null);
        _load();
      }
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_version;
    try {
      final post = await _service.postById(widget.postId);
      if (mounted && version == _version)
        setState(() {
          _post = post;
          _failed = false;
        });
    } catch (_) {
      if (mounted && version == _version) setState(() => _failed = true);
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Publicação da comunidade')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading && _post == null)
            const LoadingCards(count: 1)
          else if (_post == null && !_failed)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Esta publicação não está mais disponível.'),
            ),
          if (_failed) ConnectionNotice(onRetry: _load),
          if (_post != null)
            CommunityPostCard(
              key: ValueKey(_post!.id),
              post: _post!,
              isAuthenticated: _service.currentUserId != null,
              onRequireLogin: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entre na sua conta para interagir.'),
                ),
              ),
              onChanged: _load,
              onInteractionChanged: _load,
              onPublicationChanged: _load,
            ),
        ],
      ),
    ),
  );
}
