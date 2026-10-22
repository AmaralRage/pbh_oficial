import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';
import '../services/minute_clock.dart';

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

class _CommunityPostCardState extends State<CommunityPostCard>
    with SingleTickerProviderStateMixin {
  final _service = CommunityService();
  final _commentController = TextEditingController();
  late bool _liked;
  late int _likeCount;
  late int _commentCount;
  bool _saved = false;
  bool _following = false;
  bool _showBurst = false;
  bool _busy = false;
  DateTime _now = DateTime.now();
  bool _listeningToClock = false;
  late final AnimationController _likeController;
  late final Animation<double> _likeScale;
  late final Animation<double> _likeRotation;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likeCount = widget.post.likes;
    _commentCount = widget.post.comments;
    _saved = widget.post.isSaved;
    _following = widget.post.isFollowing;
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.45,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.45,
          end: .9,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: .9,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
    ]).animate(_likeController);
    _likeRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -.12), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -.12, end: .08), weight: 30),
      TweenSequenceItem(tween: Tween(begin: .08, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _likeController, curve: Curves.easeOut));
    _likeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted)
        setState(() => _showBurst = false);
    });
    if (widget.post.isSample) unawaited(_loadSampleInteraction());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TickerMode.of(context) && (ModalRoute.isCurrentOf(context) ?? true);
    if (visible && !_listeningToClock) {
      MinuteClock.shared.addListener(_updateTime);
      _now = MinuteClock.shared.now;
    } else if (!visible && _listeningToClock) {
      MinuteClock.shared.removeListener(_updateTime);
    }
    _listeningToClock = visible;
  }

  void _updateTime() {
    if (mounted) setState(() => _now = MinuteClock.shared.now);
  }

  @override
  void didUpdateWidget(covariant CommunityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.likes != widget.post.likes ||
        oldWidget.post.likedByMe != widget.post.likedByMe) {
      _likeCount = widget.post.likes;
      _liked = widget.post.likedByMe;
    }
    if (oldWidget.post.comments != widget.post.comments) {
      _commentCount = widget.post.comments;
    }
    _saved = widget.post.isSaved;
    _following = widget.post.isFollowing;
  }

  Future<void> _toggleFollow() async {
    if (widget.post.isSample) return;
    if (!widget.isAuthenticated) {
      widget.onRequireLogin();
      return;
    }
    final previous = _following;
    setState(() => _following = !_following);
    try {
      await _service.toggleFollow(widget.post.userId, previous);
      if (!widget.post.isSample) unawaited(widget.onChanged());
    } catch (error) {
      if (mounted) {
        setState(() => _following = previous);
        _showError(error);
      }
    }
  }

  @override
  void dispose() {
    if (_listeningToClock) MinuteClock.shared.removeListener(_updateTime);
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
    setState(() => _busy = true);
    try {
      await _service.toggleLike(
        widget.post.id,
        oldLiked,
        isSample: widget.post.isSample,
      );
      if (!widget.post.isSample) unawaited(widget.onChanged());
    } catch (error) {
      if (mounted) {
        setState(() {
          _liked = oldLiked;
          _likeCount = oldCount;
          _showBurst = false;
        });
        _showError(error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadSampleInteraction() async {
    try {
      final interaction = await _service.fetchSamplePostInteraction(
        widget.post.id,
      );
      if (!mounted) return;
      setState(() {
        _likeCount = (interaction['likes_count'] as num?)?.toInt() ?? 0;
        _commentCount = (interaction['comments_count'] as num?)?.toInt() ?? 0;
        _liked = interaction['liked_by_me'] as bool? ?? false;
      });
    } catch (_) {
      // The sample interactions become available after the community migration.
    }
  }

  Future<void> _showComments() async {
    final comments = <CommunityComment>[];
    var isLoading = true;
    var loadStarted = false;
    var loadingMore = false;
    var loadFailed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pbhColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void refreshSheet(VoidCallback update) {
            if (context.mounted) setSheetState(update);
          }

          if (!loadStarted) {
            loadStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final loadedComments = await _loadComments();
                refreshSheet(() {
                  comments
                    ..clear()
                    ..addAll(loadedComments);
                  isLoading = false;
                });
              } catch (_) {
                refreshSheet(() {
                  loadFailed = true;
                  isLoading = false;
                });
              }
            });
          }
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.pbhColors.borderSubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Comentários ($_commentCount)',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (!isLoading && _commentCount > comments.length)
                    TextButton(
                      onPressed: loadingMore
                          ? null
                          : () async {
                              refreshSheet(() => loadingMore = true);
                              try {
                                final page = await _service.fetchComments(
                                  widget.post.id,
                                  isSample: widget.post.isSample,
                                  offset: comments.length,
                                );
                                if (!context.mounted) return;
                                refreshSheet(() {
                                  final known = comments
                                      .map((c) => c.id)
                                      .toSet();
                                  comments.addAll(
                                    page.where((c) => !known.contains(c.id)),
                                  );
                                  if (page.isEmpty)
                                    _commentCount = comments.length;
                                });
                              } catch (error) {
                                if (mounted) _showError(error);
                              } finally {
                                if (context.mounted)
                                  refreshSheet(() => loadingMore = false);
                              }
                            },
                      child: Text(
                        loadingMore
                            ? 'Carregando…'
                            : 'Carregar mais comentários',
                      ),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: isLoading
                        ? SizedBox(
                            height: 96,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: context.pbhColors.orange,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : loadFailed
                        ? TextButton.icon(
                            onPressed: () => refreshSheet(() {
                              loadFailed = false;
                              loadStarted = false;
                              isLoading = true;
                            }),
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              'Não foi possível carregar. Tentar novamente',
                            ),
                          )
                        : comments.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'Seja a primeira pessoa a comentar.',
                                style: AppTextStyles.bodySmall,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: comments.length,
                            itemBuilder: (_, index) {
                              final comment = comments[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _commentAvatar(
                                  comment.author,
                                  comment.avatarUrl,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        comment.author,
                                        style: AppTextStyles.titleMedium
                                            .copyWith(fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      _formatElapsed(comment.createdAt),
                                      style: AppTextStyles.statLabel,
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    comment.content,
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ),
                                trailing:
                                    widget.isAuthenticated &&
                                        comment.userId == _service.currentUserId
                                    ? IconButton(
                                        tooltip: 'Excluir meu comentário',
                                        onPressed: _busy
                                            ? null
                                            : () => _deleteComment(
                                                comment,
                                                comments,
                                                refreshSheet,
                                              ),
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: context.pbhColors.textTertiary,
                                          size: 20,
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.isAuthenticated)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            maxLength: 1000,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) =>
                                _addComment(comments, refreshSheet),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Escreva um comentário...',
                              filled: true,
                              fillColor: context.pbhColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _busy
                              ? null
                              : () => _addComment(comments, refreshSheet),
                          icon: Icon(
                            Icons.send_rounded,
                            color: context.pbhColors.orange,
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          widget.onRequireLogin();
                        },
                        child: const Text('Entre para comentar'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<List<CommunityComment>> _loadComments() async {
    try {
      return await _service.fetchComments(
        widget.post.id,
        isSample: widget.post.isSample,
      );
    } catch (error) {
      if (mounted) _showError(error);
      rethrow;
    }
  }

  Future<void> _addComment(
    List<CommunityComment> comments,
    StateSetter refreshSheet,
  ) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.addComment(
        widget.post.id,
        content,
        isSample: widget.post.isSample,
      );
      _commentController.clear();
      final visibleLimit = comments.length < 30 ? 30 : comments.length + 1;
      final refreshed = await _service.fetchComments(
        widget.post.id,
        isSample: widget.post.isSample,
        limit: visibleLimit,
      );
      comments
        ..clear()
        ..addAll(refreshed);
      if (mounted) setState(() => _commentCount++);
      refreshSheet(() {});
      if (!widget.post.isSample) unawaited(widget.onChanged());
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteComment(
    CommunityComment comment,
    List<CommunityComment> comments,
    StateSetter refreshSheet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir comentário?'),
        content: const Text(
          'Você poderá remover somente um comentário escrito por você.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.deleteComment(comment.id, isSample: widget.post.isSample);
      final visibleLimit = comments.length < 30 ? 30 : comments.length;
      final refreshed = await _service.fetchComments(
        widget.post.id,
        isSample: widget.post.isSample,
        limit: visibleLimit,
      );
      comments
        ..clear()
        ..addAll(refreshed);
      if (mounted) {
        setState(
          () => _commentCount = _commentCount > 0 ? _commentCount - 1 : 0,
        );
      }
      refreshSheet(() {});
      if (!widget.post.isSample) unawaited(widget.onChanged());
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPostMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.pbhColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
              title: Text(_saved ? 'Remover dos salvos' : 'Salvar publicação'),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copiar texto'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Denunciar publicação'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            if (widget.isAuthenticated &&
                widget.post.userId != _service.currentUserId)
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('Bloquear este membro'),
                onTap: () => Navigator.pop(context, 'block'),
              ),
            if (widget.isAuthenticated &&
                widget.post.userId == _service.currentUserId)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: context.pbhColors.orange,
                ),
                title: const Text('Excluir minha publicação'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
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
        _showMessage(
          _saved ? 'Publicação salva.' : 'Publicação removida dos salvos.',
        );
      } else if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: widget.post.content));
        _showMessage('Texto copiado.');
      } else if (action == 'report') {
        if (!widget.isAuthenticated) {
          widget.onRequireLogin();
          return;
        }
        final reason = await _chooseReportReason();
        if (reason == null || !mounted) return;
        await _service.report(widget.post.id, reason: reason);
        _showMessage('Denúncia enviada para análise.');
      } else if (action == 'block') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Bloquear membro?'),
            content: const Text(
              'As publicações deste membro deixarão de aparecer para você.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Bloquear'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await _service.blockMember(widget.post.userId);
        await widget.onChanged();
        _showMessage('Membro bloqueado.');
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Excluir publicação?'),
            content: const Text(
              'Esta ação remove sua publicação e seus comentários associados.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await _service.deleteOwnPost(widget.post.id);
        await widget.onChanged();
        _showMessage('Publicação excluída.');
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<String?> _chooseReportReason() => showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Por que você está denunciando?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final reason in <({String id, String label})>[
            (id: 'spam', label: 'Spam'),
            (id: 'harassment', label: 'Assédio'),
            (id: 'inappropriate', label: 'Conteúdo inadequado'),
            (id: 'other', label: 'Outro motivo'),
          ])
            ListTile(
              title: Text(reason.label),
              onTap: () => Navigator.pop(context, reason.id),
            ),
        ],
      ),
    ),
  );

  Future<void> _sharePost() async => Share.share(
    '${widget.post.authorName}: ${widget.post.content}',
    subject: 'Publicação de ${widget.post.authorName}',
  );

  void _showError(Object error) =>
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  String _formatElapsed(DateTime date) {
    final elapsed = _now.difference(date);
    if (elapsed.isNegative || elapsed.inSeconds < 60) return 'agora';
    if (elapsed.inMinutes < 60) return 'há ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'há ${elapsed.inHours} h';
    if (elapsed.inDays < 7) return 'há ${elapsed.inDays} d';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _commentAvatar(String author, String? avatarUrl) {
    final image = switch (author.trim().toLowerCase()) {
      'amaral' => 'assets/images/profile_photo.png',
      'samuel' => 'assets/images/samuel.png',
      'wellerson' => 'assets/images/wellerson.png',
      'kanye west' => 'assets/images/kanye.png',
      'chad' => 'assets/images/chad.png',
      _ => null,
    };
    final placeholder = Text(
      _initials(author),
      style: TextStyle(color: context.pbhColors.orange, fontSize: 12),
    );
    return CircleAvatar(
      backgroundColor: context.pbhColors.orangeDim,
      child: image == null
          ? avatarUrl == null || avatarUrl.isEmpty
                ? placeholder
                : ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(child: placeholder),
                    ),
                  )
          : ClipOval(
              child: Image.asset(
                image,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: placeholder),
              ),
            ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'M';
    return parts.length == 1
        ? parts.first[0].toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _topicLabel(String topic) => switch (topic) {
    'disciplina' => 'Disciplina',
    'treino' => 'Treino',
    'leitura' => 'Leitura',
    'proposito' => 'Propósito',
    'reflexao' => 'Reflexão',
    _ => topic,
  };

  Widget _postAvatar(CommunityPostModel post) {
    final placeholder = Text(
      post.authorInitials,
      style: AppTextStyles.chip.copyWith(
        color: context.pbhColors.orange,
        fontWeight: FontWeight.w800,
      ),
    );
    if (post.avatarAsset != null) {
      return ClipOval(
        child: Image.asset(
          post.avatarAsset!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: placeholder),
        ),
      );
    }
    if (post.avatarUrl != null && post.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          post.avatarUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: placeholder),
        ),
      );
    }
    return placeholder;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.pbhColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.pbhColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.pbhColors.orangeDim,
                child: _postAvatar(post),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: AppTextStyles.titleMedium.copyWith(fontSize: 14),
                    ),
                    Text(
                      post.isSample
                          ? 'Exemplo · ${_formatElapsed(post.createdAt)}'
                          : _formatElapsed(post.createdAt),
                      style: AppTextStyles.statLabel,
                    ),
                  ],
                ),
              ),
              if (!post.isSample &&
                  widget.isAuthenticated &&
                  post.userId != _service.currentUserId)
                IconButton(
                  tooltip: _following ? 'Deixar de seguir' : 'Seguir',
                  onPressed: _toggleFollow,
                  icon: Icon(
                    _following
                        ? Icons.person_remove_alt_1_rounded
                        : Icons.person_add_alt_1_rounded,
                    size: 19,
                    color: _following
                        ? context.pbhColors.orange
                        : context.pbhColors.textTertiary,
                  ),
                ),
              if (!post.isSample)
                IconButton(
                  tooltip: 'Mais opções',
                  onPressed: _showPostMenu,
                  icon: Icon(
                    Icons.more_horiz,
                    color: context.pbhColors.textTertiary,
                  ),
                ),
            ],
          ),
          if (post.achievementTag != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.pbhColors.orangeDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 13,
                    color: context.pbhColors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    post.achievementTag!,
                    style: AppTextStyles.chip.copyWith(
                      color: context.pbhColors.orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (post.topic != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: context.pbhColors.backgroundElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _topicLabel(post.topic!),
                style: AppTextStyles.chip.copyWith(
                  color: context.pbhColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            post.content,
            style: AppTextStyles.body.copyWith(
              color: context.pbhColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Semantics(
                button: true,
                toggled: _liked,
                label: 'Curtir publicação, $_likeCount curtidas',
                child: GestureDetector(
                  onTap: _busy ? null : _toggleLike,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _likeController,
                        builder: (_, child) => Transform.rotate(
                          angle: _likeRotation.value,
                          child: Transform.scale(
                            scale: _likeScale.value,
                            child: child,
                          ),
                        ),
                        child: Icon(
                          _liked
                              ? Icons.local_fire_department
                              : Icons.local_fire_department_outlined,
                          size: 19,
                          color: _liked
                              ? context.pbhColors.orange
                              : context.pbhColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('$_likeCount', style: AppTextStyles.bodySmall),
                      if (_showBurst)
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Text(
                            '+1',
                            style: AppTextStyles.chip.copyWith(
                              color: context.pbhColors.orange,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Semantics(
                button: true,
                label: 'Ver $_commentCount comentários',
                child: GestureDetector(
                  onTap: _showComments,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 18,
                        color: context.pbhColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text('$_commentCount', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Compartilhar publicação',
                onPressed: _sharePost,
                icon: Icon(
                  Icons.share_outlined,
                  size: 18,
                  color: context.pbhColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
