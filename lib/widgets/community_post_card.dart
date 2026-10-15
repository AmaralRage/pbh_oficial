import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';

class CommunityPostCard extends StatefulWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.isAuthenticated,
    required this.onRequireLogin,
    required this.onChanged,
  });

  final CommunityPostModel post;
  final bool isAuthenticated;
  final VoidCallback onRequireLogin;
  final Future<void> Function() onChanged;

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> with SingleTickerProviderStateMixin {
  final _service = CommunityService();
  final _commentController = TextEditingController();
  late bool _liked;
  late int _likeCount;
  bool _saved = false;
  bool _following = false;
  bool _showBurst = false;
  bool _busy = false;
  DateTime _now = DateTime.now();
  Timer? _timer;
  late final AnimationController _likeController;
  late final Animation<double> _likeScale;
  late final Animation<double> _likeRotation;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likeCount = widget.post.likes;
    _saved = widget.post.isSaved;
    _following = widget.post.isFollowing;
    _likeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: .9).chain(CurveTween(curve: Curves.easeInOut)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: .9, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 35),
    ]).animate(_likeController);
    _likeRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -.12), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -.12, end: .08), weight: 30),
      TweenSequenceItem(tween: Tween(begin: .08, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _likeController, curve: Curves.easeOut));
    _likeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _showBurst = false);
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didUpdateWidget(covariant CommunityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.likes != widget.post.likes || oldWidget.post.likedByMe != widget.post.likedByMe) {
      _likeCount = widget.post.likes;
      _liked = widget.post.likedByMe;
    }
    _saved = widget.post.isSaved;
    _following = widget.post.isFollowing;
  }

  Future<void> _toggleFollow() async {
    if (!widget.isAuthenticated) {
      widget.onRequireLogin();
      return;
    }
    final previous = _following;
    setState(() => _following = !_following);
    try {
      await _service.toggleFollow(widget.post.userId, previous);
      await widget.onChanged();
    } catch (error) {
      if (mounted) {
        setState(() => _following = previous);
        _showError(error);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _likeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (!widget.isAuthenticated) {
      widget.onRequireLogin();
      return;
    }
    final oldLiked = _liked;
    final oldCount = _likeCount;
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
      _showBurst = _liked;
    });
    _likeController.forward(from: 0);
    try {
      await _service.toggleLike(widget.post.id, oldLiked);
      await widget.onChanged();
    } catch (error) {
      if (mounted) {
        setState(() {
          _liked = oldLiked;
          _likeCount = oldCount;
          _showBurst = false;
        });
        _showError(error);
      }
    }
  }

  Future<void> _showComments() async {
    final comments = await _loadComments();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 18),
                Text('Comentários (${comments.length})', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: comments.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Seja a primeira pessoa a comentar.', style: AppTextStyles.bodySmall)))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: comments.length,
                          itemBuilder: (_, index) {
                            final comment = comments[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(backgroundColor: AppColors.orangeDim, child: Text(_initials(comment.author), style: const TextStyle(color: AppColors.orange, fontSize: 12))),
                              title: Row(children: [Expanded(child: Text(comment.author, style: AppTextStyles.titleMedium.copyWith(fontSize: 13))), Text(_formatElapsed(comment.createdAt), style: AppTextStyles.statLabel)]),
                              subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(comment.content, style: AppTextStyles.bodySmall)),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                if (widget.isAuthenticated)
                  Row(children: [
                    Expanded(child: TextField(controller: _commentController, textInputAction: TextInputAction.send, onSubmitted: (_) => _addComment(comments, refreshSheet), decoration: InputDecoration(hintText: 'Escreva um comentário...', filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
                    IconButton(onPressed: _busy ? null : () => _addComment(comments, refreshSheet), icon: const Icon(Icons.send_rounded, color: AppColors.orange)),
                  ])
                else
                  SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () { Navigator.pop(sheetContext); widget.onRequireLogin(); }, child: const Text('Entre para comentar'))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<CommunityComment>> _loadComments() async {
    try {
      return await _service.fetchComments(widget.post.id);
    } catch (error) {
      if (mounted) _showError(error);
      return const [];
    }
  }

  Future<void> _addComment(List<CommunityComment> comments, StateSetter refreshSheet) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.addComment(widget.post.id, content);
      _commentController.clear();
      comments
        ..clear()
        ..addAll(await _service.fetchComments(widget.post.id));
      refreshSheet(() {});
      await widget.onChanged();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPostMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(_saved ? Icons.bookmark : Icons.bookmark_border), title: Text(_saved ? 'Remover dos salvos' : 'Salvar publicação'), onTap: () => Navigator.pop(context, 'save')),
        ListTile(leading: const Icon(Icons.copy_outlined), title: const Text('Copiar texto'), onTap: () => Navigator.pop(context, 'copy')),
        ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Denunciar publicação'), onTap: () => Navigator.pop(context, 'report')),
      ])),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'save') {
        if (!widget.isAuthenticated) {
          widget.onRequireLogin();
          return;
        }
        await _service.toggleSaved(widget.post.id, _saved);
        setState(() => _saved = !_saved);
        _showMessage(_saved ? 'Publicação salva.' : 'Publicação removida dos salvos.');
      } else if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: widget.post.content));
        _showMessage('Texto copiado.');
      } else if (action == 'report') {
        if (!widget.isAuthenticated) {
          widget.onRequireLogin();
          return;
        }
        await _service.report(widget.post.id);
        _showMessage('Denúncia enviada para análise.');
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _sharePost() async => Share.share('${widget.post.authorName}: ${widget.post.content}', subject: 'Publicação de ${widget.post.authorName}');

  void _showError(Object error) => _showMessage(error.toString().replaceFirst('Exception: ', ''));
  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  String _formatElapsed(DateTime date) {
    final elapsed = _now.difference(date);
    if (elapsed.isNegative || elapsed.inSeconds < 60) return 'agora';
    if (elapsed.inMinutes < 60) return 'há ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'há ${elapsed.inHours} h';
    if (elapsed.inDays < 7) return 'há ${elapsed.inDays} d';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'M';
    return parts.length == 1 ? parts.first[0].toUpperCase() : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: AppColors.orangeDim, child: Text(post.authorInitials, style: AppTextStyles.chip.copyWith(color: AppColors.orange, fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(post.authorName, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)), Text(_formatElapsed(post.createdAt), style: AppTextStyles.statLabel)])),
          if (widget.isAuthenticated && post.userId != _service.currentUserId)
            IconButton(tooltip: _following ? 'Deixar de seguir' : 'Seguir', onPressed: _toggleFollow, icon: Icon(_following ? Icons.person_remove_alt_1_rounded : Icons.person_add_alt_1_rounded, size: 19, color: _following ? AppColors.orange : AppColors.textTertiary)),
          IconButton(tooltip: 'Mais opções', onPressed: _showPostMenu, icon: const Icon(Icons.more_horiz, color: AppColors.textTertiary)),
        ]),
        if (post.achievementTag != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.emoji_events, size: 13, color: AppColors.orange), const SizedBox(width: 6), Text(post.achievementTag!, style: AppTextStyles.chip.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700))])),
        ],
        const SizedBox(height: 12),
        Text(post.content, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, height: 1.5)),
        const SizedBox(height: 16),
        Row(children: [
          GestureDetector(onTap: _busy ? null : _toggleLike, child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(animation: _likeController, builder: (_, child) => Transform.rotate(angle: _likeRotation.value, child: Transform.scale(scale: _likeScale.value, child: child)), child: Icon(_liked ? Icons.local_fire_department : Icons.local_fire_department_outlined, size: 19, color: _liked ? AppColors.orange : AppColors.textSecondary)),
            const SizedBox(width: 6), Text('$_likeCount', style: AppTextStyles.bodySmall),
            if (_showBurst) Padding(padding: const EdgeInsets.only(left: 5), child: Text('+1', style: AppTextStyles.chip.copyWith(color: AppColors.orange, fontWeight: FontWeight.w800))),
          ])),
          const SizedBox(width: 20),
          GestureDetector(onTap: _showComments, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textSecondary), const SizedBox(width: 6), Text('${post.comments}', style: AppTextStyles.bodySmall)])),
          const Spacer(),
          IconButton(tooltip: 'Compartilhar publicação', onPressed: _sharePost, icon: const Icon(Icons.share_outlined, size: 18, color: AppColors.textTertiary)),
        ]),
      ]),
    );
  }
}
