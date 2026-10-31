import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/community_post_model.dart';
import '../models/community_topics.dart';
import '../services/community_service.dart';
import '../widgets/community_post_card.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/community_comment_avatar.dart';
import 'community_post_composer.dart';

const _weeklyPrompts = <String>[
  'Qual compromisso pequeno você conseguiu manter esta semana?',
  'O que ajudou você a recuperar o foco nos últimos dias?',
  'Que hábito você quer levar com você para a próxima semana?',
  'Qual foi uma escolha difícil que valeu a pena fazer?',
];

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    required this.isAuthenticated,
    required this.onRequireLogin,
    this.service,
  });

  final bool isAuthenticated;
  final VoidCallback onRequireLogin;
  final CommunityService? service;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late final _service = widget.service ?? CommunityService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _filterIndex = 0;
  int _topicIndex = 0;
  static const _filters = [
    'Recentes',
    'Seguindo',
    'Conquistas',
    'Populares',
    'Salvos',
  ];
  static final _topicFilters = ['Todos os temas', ...communityTopics.values];
  List<CommunityPostModel> _posts = const [];
  CommunityStats? _stats;
  bool _loading = true;
  bool _loadingMore = false;
  bool _fetching = false;
  bool _hasMore = true;
  int _nextPostOffset = 0;
  int _requestVersion = 0;
  String? _error;
  String? _loadMoreError;

  String? get _selectedTopic =>
      _topicIndex == 0 ? null : communityTopics.keys.elementAt(_topicIndex - 1);
  String get _weeklyPrompt =>
      _weeklyPrompts[(DateTime.now().difference(DateTime(2026, 1, 5)).inDays ~/
              7) %
          _weeklyPrompts.length];
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load(showLoading: false);
    });
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 &&
        !_loading &&
        !_fetching &&
        !_loadingMore &&
        _hasMore &&
        _error == null &&
        _loadMoreError == null) {
      _loadMore();
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    final requestVersion = ++_requestVersion;
    _fetching = true;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final filterIndex = _filterIndex;
      final statsFuture = _service
          .fetchStats()
          .then<CommunityStats?>((stats) => stats)
          .catchError((_) => null);
      final posts = await _service.fetchPosts(
        filterIndex: filterIndex,
        search: _searchController.text,
        topic: _selectedTopic,
      );
      // Estatísticas são complementares. Uma falha na RPC não deve esconder o feed.
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _posts = posts;
        _nextPostOffset = posts.length;
        _stats = null;
        _loading = false;
        _error = null;
        _loadMoreError = null;
        _hasMore = posts.length == 20;
      });
      unawaited(
        statsFuture.then((stats) {
          if (!mounted || requestVersion != _requestVersion) return;
          setState(() => _stats = stats);
        }),
      );
    } catch (error) {
      if (mounted && requestVersion == _requestVersion)
        setState(() {
          _loading = false;
          _error = _friendlyError(error);
        });
    } finally {
      if (requestVersion == _requestVersion) _fetching = false;
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _fetching || _loadingMore || !_hasMore) return;
    final requestVersion = _requestVersion;
    _fetching = true;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final filterIndex = _filterIndex;
      final posts = await _service.fetchPosts(
        filterIndex: filterIndex,
        offset: _nextPostOffset,
        search: _searchController.text,
        topic: _selectedTopic,
      );
      if (!mounted ||
          requestVersion != _requestVersion ||
          filterIndex != _filterIndex)
        return;
      setState(() {
        final existingIds = _posts.map((p) => p.id).toSet();
        _posts = [..._posts, ...posts.where((p) => existingIds.add(p.id))];
        _nextPostOffset += posts.length;
        _hasMore = posts.length == 20;
        _loadMoreError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _loadMoreError = _friendlyError(error));
    } finally {
      if (requestVersion == _requestVersion) _fetching = false;
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _friendlyError(Object error) {
    final details = error.toString();
    final normalized = details.toLowerCase();
    if (normalized.contains('community_feed') &&
        (normalized.contains('pgrst205') ||
            normalized.contains('schema cache') ||
            normalized.contains('does not exist'))) {
      return 'A estrutura da comunidade ainda não existe no Supabase. Execute a migration supabase/migrations/20261015000300_community_progress.sql no SQL Editor.';
    }
    if (normalized.contains('permission denied') ||
        normalized.contains('42501')) {
      return 'O Supabase recusou a consulta por falta de permissão. Confira as políticas RLS da migration 20261015000300.';
    }
    return details;
  }

  Future<void> _selectFilter(int index) async {
    if (!widget.isAuthenticated && (index == 1 || index == 4)) {
      widget.onRequireLogin();
      return;
    }
    if (_filterIndex == index) return;
    setState(() {
      _filterIndex = index;
      _loading = true;
    });
    await _load(showLoading: false);
  }

  Future<void> _selectTopic(int index) async {
    if (_topicIndex == index) return;
    setState(() {
      _topicIndex = index;
      _loading = true;
    });
    await _load(showLoading: false);
  }

  Future<void> _composePost({String? prompt, bool photos = false}) async {
    if (!widget.isAuthenticated) {
      widget.onRequireLogin();
      return;
    }
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityPostComposer(
          service: _service,
          prompt: prompt,
          initialTopic: _selectedTopic,
          pickOnOpen: photos,
        ),
      ),
    );
    if (published != true || !mounted) return;
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() {
      _filterIndex = 0;
      _topicIndex = 0;
    });
    await _load();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicação compartilhada.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _load(showLoading: false),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Comunidade', style: AppTextStyles.brandHeadline),
                        IconButton(
                          tooltip: 'Sobre a comunidade',
                          icon: Icon(
                            Icons.info_outline,
                            color: context.pbhColors.textPrimary,
                          ),
                          onPressed: _about,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Homens comprometidos com a mesma jornada.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    _publisher(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilterChipRow(
                            options: const [
                              'Recentes',
                              'Seguindo',
                              'Em destaque',
                            ],
                            selectedIndex: const [
                              0,
                              1,
                              3,
                            ].indexOf(_filterIndex),
                            onSelected: (index) =>
                                _selectFilter(const [0, 1, 3][index]),
                          ),
                        ),
                        PopupMenuButton<int>(
                          tooltip: 'Outros filtros',
                          onSelected: _selectFilter,
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 2, child: Text('Conquistas')),
                            PopupMenuItem(value: 4, child: Text('Salvos')),
                          ],
                        ),
                      ],
                    ),
                    if (_filterIndex == 2 || _filterIndex == 4)
                      InputChip(
                        label: Text(_filters[_filterIndex]),
                        onDeleted: () => _selectFilter(0),
                      ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Buscar e filtrar por assunto'),
                      children: [
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Buscar conversas e temas',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpar busca',
                                    onPressed: _searchController.clear,
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilterChipRow(
                          options: _topicFilters,
                          selectedIndex: _topicIndex,
                          onSelected: _selectTopic,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: _feedSliver(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    if (_stats != null)
                      ExpansionTile(
                        title: const Text('A comunidade em números'),
                        children: [_StatsPanel(stats: _stats!)],
                      ),
                    if (_loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_loadMoreError != null)
                      TextButton(
                        onPressed: _loadMore,
                        child: Text(
                          'Falha ao carregar mais. Tentar novamente: $_loadMoreError',
                        ),
                      )
                    else if (!_hasMore && _posts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'Você chegou ao fim do feed.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.statLabel,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _publisher() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          InkWell(
            onTap: _composePost,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (widget.isAuthenticated && _service.currentUserId != null)
                    ProfileCommentAvatar(
                      userId: _service.currentUserId!,
                      name: _service.currentUserName,
                    )
                  else
                    const CircleAvatar(child: Icon(Icons.person_outline)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Compartilhe sua jornada',
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _composePost,
                icon: const Icon(Icons.edit_note),
                label: const Text('Relato'),
              ),
              TextButton.icon(
                onPressed: () => _composePost(photos: true),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Fotos'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _about() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uma comunidade, muitas jornadas',
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Este é o espaço único do PBH para relatos, fotos, dúvidas e conquistas. Os assuntos organizam as conversas; não são comunidades separadas.',
            ),
            const SizedBox(height: 16),
            Text('Nossos combinados', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Respeite os membros. Compartilhe apenas fotos que você pode publicar e respeite a privacidade das outras pessoas. Evite ataques pessoais, spam e conteúdo ofensivo. Use o menu da publicação para denunciar ou bloquear.',
            ),
            const SizedBox(height: 16),
            Text('Pergunta da semana', style: AppTextStyles.titleMedium),
            Text(_weeklyPrompt),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _composePost(prompt: _weeklyPrompt);
              },
              child: const Text('Responder à comunidade'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _feedSliver() {
    if (_loading)
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    if (_error != null)
      return SliverToBoxAdapter(
        child: _FeedMessage(
          icon: Icons.cloud_off_outlined,
          message: 'Não foi possível carregar a comunidade.',
          details: _error,
          action: 'Tentar novamente',
          onTap: _load,
        ),
      );
    final posts = _posts;
    if (posts.isEmpty)
      return SliverToBoxAdapter(
        child: _FeedMessage(
          icon: Icons.forum_outlined,
          message: _filterIndex == 1
              ? 'Você ainda não segue ninguém.'
              : 'Ainda não há publicações por aqui.',
          action: _filterIndex == 1 ? null : 'Criar publicação',
          onTap: _filterIndex == 1 ? null : _composePost,
        ),
      );
    return SliverList.builder(
      itemCount: posts.length,
      findChildIndexCallback: (key) {
        final index = posts.indexWhere((p) => ValueKey(p.id) == key);
        return index < 0 ? null : index;
      },
      itemBuilder: (_, index) {
        final post = posts[index];
        return Padding(
          key: ValueKey(post.id),
          padding: const EdgeInsets.only(bottom: 14),
          child: CommunityPostCard(
            post: post,
            isAuthenticated: widget.isAuthenticated,
            onRequireLogin: widget.onRequireLogin,
            onChanged: post.isSample
                ? () async {}
                : () => _load(showLoading: false),
          ),
        );
      },
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});
  final CommunityStats stats;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: context.pbhColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.pbhColors.borderSubtle),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Stat(value: '${stats.posts}', label: 'Publicações'),
        Container(width: 1, height: 30, color: context.pbhColors.borderSubtle),
        _Stat(value: '${stats.comments}', label: 'Comentários'),
        Container(width: 1, height: 30, color: context.pbhColors.borderSubtle),
        _Stat(value: '${stats.likes}', label: 'Curtidas'),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: AppTextStyles.statNumber),
      const SizedBox(height: 4),
      Text(label, style: AppTextStyles.statLabel),
    ],
  );
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.message,
    this.details,
    this.action,
    this.onTap,
  });
  final IconData icon;
  final String message;
  final String? details;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 45),
    child: Column(
      children: [
        Icon(icon, size: 34, color: context.pbhColors.textTertiary),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
        if (details != null) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              details!,
              textAlign: TextAlign.center,
              style: AppTextStyles.statLabel,
            ),
          ),
        ],
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}
