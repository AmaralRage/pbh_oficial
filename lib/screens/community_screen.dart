import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';
import '../widgets/community_post_card.dart';
import '../widgets/filter_chip_row.dart';

final _sampleCommunityPosts = <CommunityPostModel>[
  CommunityPostModel(
    id: 'sample-samuel',
    userId: '',
    authorName: 'Samuel',
    topic: 'disciplina',
    avatarAsset: 'assets/images/samuel.png',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    content:
        'Um passo de cada vez. Hoje mantive o compromisso que fiz comigo mesmo, mesmo sem estar motivado.',
    likes: 0,
    comments: 0,
    likedByMe: false,
    isSample: true,
  ),
  CommunityPostModel(
    id: 'sample-wellerson',
    userId: '',
    authorName: 'Wellerson',
    topic: 'treino',
    avatarAsset: 'assets/images/wellerson.png',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    content:
        'A rotina está começando a ficar mais natural. O segredo foi parar de esperar o momento perfeito e simplesmente começar.',
    likes: 0,
    comments: 0,
    likedByMe: false,
    isSample: true,
  ),
  CommunityPostModel(
    id: 'sample-kanye',
    userId: '',
    authorName: 'Kanye West',
    topic: 'reflexao',
    avatarAsset: 'assets/images/kanye.png',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    content:
        'Exemplo de publicação para preencher o feed enquanto a comunidade ganha novos membros e conversas reais.',
    likes: 0,
    comments: 0,
    likedByMe: false,
    isSample: true,
  ),
  CommunityPostModel(
    id: 'sample-chad',
    userId: '',
    authorName: 'Chad',
    topic: 'disciplina',
    avatarAsset: 'assets/images/chad.png',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    content:
        'Consistência não precisa ser perfeita. Só precisa continuar amanhã.',
    likes: 0,
    comments: 0,
    likedByMe: false,
    isSample: true,
  ),
];

const _communityTopics = <String, String>{
  'disciplina': 'Disciplina',
  'treino': 'Treino',
  'leitura': 'Leitura',
  'proposito': 'Propósito',
  'reflexao': 'Reflexão',
};
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
  });

  final bool isAuthenticated;
  final VoidCallback onRequireLogin;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _service = CommunityService();
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
  static const _topicFilters = [
    'Todos os temas',
    'Disciplina',
    'Treino',
    'Leitura',
    'Propósito',
    'Reflexão',
  ];
  List<CommunityPostModel> _posts = const [];
  CommunityStats? _stats;
  bool _loading = true;
  bool _loadingMore = false;
  bool _fetching = false;
  bool _hasMore = true;
  int _requestVersion = 0;
  String? _error;
  String? _loadMoreError;

  String? get _selectedTopic => _topicIndex == 0
      ? null
      : _communityTopics.keys.elementAt(_topicIndex - 1);
  String get _weeklyPrompt =>
      _weeklyPrompts[(DateTime.now().difference(DateTime(2026, 1, 5)).inDays ~/
              7) %
          _weeklyPrompts.length];
  List<CommunityPostModel> get _visibleSamplePosts {
    final query = _searchController.text.trim().toLowerCase();
    return _sampleCommunityPosts.where((post) {
      final matchesText =
          query.isEmpty ||
          post.authorName.toLowerCase().contains(query) ||
          post.content.toLowerCase().contains(query);
      return matchesText &&
          (_selectedTopic == null || post.topic == _selectedTopic);
    }).toList();
  }

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
        offset: _posts.length,
        search: _searchController.text,
        topic: _selectedTopic,
      );
      if (!mounted ||
          requestVersion != _requestVersion ||
          filterIndex != _filterIndex)
        return;
      setState(() {
        _posts = [..._posts, ...posts];
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

  Future<void> _composePost({String? prompt}) async {
    if (!widget.isAuthenticated) {
      widget.onRequireLogin();
      return;
    }
    final contentController = TextEditingController();
    if (prompt != null) contentController.text = '$prompt\n\n';
    final tagController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedTopic = _selectedTopic ?? _communityTopics.keys.first;
    final publish = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pbhColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SafeArea(
            top: false,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nova publicação', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 14),
                  Text(
                    'Esta publicação ficará visível na comunidade. Seu nome segue a opção definida em Privacidade.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedTopic,
                    decoration: const InputDecoration(labelText: 'Tema'),
                    items: _communityTopics.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        setSheetState(() => selectedTopic = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: contentController,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 2000,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Compartilhe sua jornada com a comunidade...',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Escreva sua publicação.'
                        : null,
                  ),
                  TextField(
                    controller: tagController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Conquista (opcional)',
                      prefixIcon: Icon(Icons.emoji_events_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (formKey.currentState!.validate())
                        Navigator.pop(sheetContext, true);
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Publicar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (publish != true || !mounted) {
      contentController.dispose();
      tagController.dispose();
      return;
    }
    try {
      await _service.createPost(
        contentController.text,
        achievementTag: tagController.text,
        topic: selectedTopic,
      );
      if (!mounted) return;
      contentController.dispose();
      tagController.dispose();
      setState(() => _filterIndex = 0);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicação compartilhada.')),
        );
    } catch (error) {
      contentController.dispose();
      tagController.dispose();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível publicar: $error')),
        );
    }
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
                          tooltip: 'Criar publicação',
                          icon: Icon(
                            Icons.edit_outlined,
                            color: context.pbhColors.textPrimary,
                          ),
                          onPressed: _composePost,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Homens comprometidos com a mesma jornada.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.pbhColors.orangeDim,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: context.pbhColors.orange.withOpacity(.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            color: context.pbhColors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PERGUNTA DA SEMANA',
                                  style: AppTextStyles.eyebrow
                                      .copyWith(
                                        color: context.pbhColors.orangeLight,
                                      )
                                      .copyWith(
                                        color: context.pbhColors.orange,
                                      ),
                                ),
                                const SizedBox(height: 5),
                                Text(_weeklyPrompt, style: AppTextStyles.body),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _composePost(prompt: _weeklyPrompt),
                            child: const Text('Responder'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_stats != null) _StatsPanel(stats: _stats!),
                    const SizedBox(height: 20),
                    FilterChipRow(
                      options: _filters,
                      selectedIndex: _filterIndex,
                      onSelected: _selectFilter,
                    ),
                    const SizedBox(height: 10),
                    FilterChipRow(
                      options: _topicFilters,
                      selectedIndex: _topicIndex,
                      onSelected: _selectTopic,
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
    final posts = _posts.isEmpty && _filterIndex == 0
        ? _visibleSamplePosts
        : _posts;
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
