import 'package:flutter/material.dart';

import '../core/navigation/app_transitions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/challenge_model.dart';
import '../models/challenge_journey.dart';
import '../models/profile_achievement.dart';
import '../widgets/profile_achievement_seals.dart';
import '../services/challenge_service.dart';
import '../widgets/challenge_card.dart';
import '../widgets/featured_challenge_card.dart';
import '../widgets/filter_chip_row.dart';
import 'challenge_detail_screen.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({
    super.key,
    required this.isAuthenticated,
    required this.onRequireLogin,
  });

  final bool isAuthenticated;
  final VoidCallback onRequireLogin;

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final _service = ChallengeService();
  final _searchController = TextEditingController();
  int _filterIndex = 0;
  int _achievementFilterIndex = 0;
  int _pageIndex = 0;
  bool _searching = false;
  bool _loading = true;
  String? _error;
  List<ChallengeModel> _challenges = const [];
  ChallengeJourney _journey = ChallengeJourney.original;
  List<ChallengeModel> get _journeyChallenges =>
      _challenges.where((c) => _journey.challengeIds.contains(c.id)).toList();
  ProfileAchievement get _journeyPlatinum => _journey.id == 'knowledge'
      ? ProfileAchievement.knowledgePlatinum
      : ProfileAchievement.platinum;
  bool? _tabActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && _tabActive == false) _load();
    _tabActive = active;
  }

  static const _filters = [
    'Todos',
    'Em andamento',
    'Não iniciados',
    'Concluídos',
  ];
  static const _achievementFilters = [
    'Todos',
    'Conquistados',
    'Em andamento',
    'Bloqueados',
  ];

  List<ChallengeModel> get _completedChallenges => _journeyChallenges
      .where((challenge) => challenge.status == ChallengeStatus.completed)
      .toList();

  bool get _supremeUnlocked =>
      _journey.unlocked(_completedChallenges.map((c) => c.id).toSet());

  int get _achievementPoints => _completedChallenges.fold<int>(
    _supremeUnlocked ? 100 : 0,
    (points, challenge) => points + _tierFor(challenge).points,
  );

  ChallengeModel? get _activeChallenge {
    for (final challenge in _journeyChallenges) {
      if (challenge.status == ChallengeStatus.active) return challenge;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final challenges = await _service.fetchChallenges();
      if (mounted) {
        setState(() {
          _challenges = challenges;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  List<ChallengeModel> get _filteredChallenges {
    final byStatus = switch (_filterIndex) {
      1 =>
        _journeyChallenges
            .where((challenge) => challenge.status == ChallengeStatus.active)
            .toList(),
      2 =>
        _journeyChallenges
            .where(
              (challenge) => challenge.status == ChallengeStatus.notStarted,
            )
            .toList(),
      3 =>
        _journeyChallenges
            .where((challenge) => challenge.status == ChallengeStatus.completed)
            .toList(),
      _ => _journeyChallenges,
    };
    final search = _searchController.text.trim().toLowerCase();
    return search.isEmpty
        ? byStatus
        : byStatus
              .where(
                (item) =>
                    item.title.toLowerCase().contains(search) ||
                    item.description.toLowerCase().contains(search),
              )
              .toList();
  }

  List<ChallengeModel> get _filteredAchievements {
    return switch (_achievementFilterIndex) {
      1 => _completedChallenges,
      2 =>
        _journeyChallenges
            .where((item) => item.status == ChallengeStatus.active)
            .toList(),
      3 =>
        _journeyChallenges
            .where((item) => item.status == ChallengeStatus.notStarted)
            .toList(),
      _ => _journeyChallenges,
    };
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeChallenge;
    final list = _filteredChallenges;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
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
                        Text('Desafios', style: AppTextStyles.brandHeadline),
                        if (_pageIndex == 0)
                          IconButton(
                            tooltip: 'Buscar desafios',
                            icon: Icon(
                              _searching ? Icons.close : Icons.search,
                              color: context.pbhColors.textPrimary,
                            ),
                            onPressed: () => setState(() {
                              _searching = !_searching;
                              if (!_searching) _searchController.clear();
                            }),
                          ),
                      ],
                    ),
                    if (_pageIndex == 0 && _searching)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Buscar desafios',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      _pageIndex == 0
                          ? 'Supere seus limites, um dia de cada vez.'
                          : 'Cada compromisso cumprido deixa sua marca.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    _PageSelector(
                      selectedIndex: _pageIndex,
                      onSelected: (index) => setState(() {
                        _pageIndex = index;
                        if (index == 1) {
                          _searching = false;
                          _searchController.clear();
                        }
                      }),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final journey in ChallengeJourney.all)
                          ChoiceChip(
                            label: Text(
                              journey.id == 'original'
                                  ? 'Original PBH'
                                  : 'Conhecimento',
                            ),
                            avatar: Icon(
                              journey.icon,
                              size: 18,
                              color: _journey.id == journey.id
                                  ? context.pbhColors.onAccent
                                  : journey.color,
                            ),
                            labelStyle: TextStyle(
                              color: _journey.id == journey.id
                                  ? context.pbhColors.onAccent
                                  : context.pbhColors.textPrimary,
                            ),
                            selected: _journey.id == journey.id,
                            onSelected: (_) => setState(() {
                              _journey = journey;
                              _filterIndex = 0;
                              _achievementFilterIndex = 0;
                              _searchController.clear();
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_journey.title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 6),
                    Text(_journey.description, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(38),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: _EmptyChallengeState(
                  message: 'Não foi possível carregar seus desafios.',
                  action: 'Tentar novamente',
                  onTap: _load,
                ),
              )
            else if (_pageIndex == 0)
              ..._buildChallenges(active, list)
            else
              ..._buildAchievements(),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChallenges(
    ChallengeModel? active,
    List<ChallengeModel> list,
  ) {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active != null &&
                  _filterIndex == 0 &&
                  _searchController.text.isEmpty) ...[
                FeaturedChallengeCard(
                  challenge: active,
                  onTap: () => _openChallenge(active),
                ),
                const SizedBox(height: 24),
              ],
              FilterChipRow(
                options: _filters,
                selectedIndex: _filterIndex,
                onSelected: (index) => setState(() => _filterIndex = index),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Desafios disponíveis',
                    style: AppTextStyles.titleMedium,
                  ),
                  Text('${list.length}', style: AppTextStyles.bodySmall),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
      if (list.isEmpty)
        SliverToBoxAdapter(
          child: _EmptyChallengeState(
            message: _searchController.text.isNotEmpty
                ? 'Nenhum desafio corresponde à busca.'
                : _filterIndex == 1
                ? 'Você ainda não iniciou um desafio.'
                : _filterIndex == 3
                ? 'Você ainda não concluiu desafios.'
                : 'Nenhum desafio disponível agora.',
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => ChallengeCard(
              challenge: list[index],
              onTap: () => _openChallenge(list[index]),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildAchievements() {
    if (!widget.isAuthenticated) {
      return [
        SliverToBoxAdapter(child: _LoginPrompt(onTap: widget.onRequireLogin)),
      ];
    }

    final earned = _completedChallenges.length + (_supremeUnlocked ? 1 : 0);
    final total = _journey.challengeIds.length + 1;
    final progress = total == 0
        ? 0.0
        : (earned / total).clamp(0.0, 1.0).toDouble();
    final achievementList = _filteredAchievements;

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrophySummaryCard(
                journey: _journey,
                earned: earned,
                total: total,
                points: _achievementPoints,
                progress: progress,
                tiers: _TrophyTier.values
                    .map(
                      (tier) => MapEntry(
                        tier,
                        tier == _TrophyTier.platinum
                            ? (_supremeUnlocked ? 1 : 0)
                            : _completedChallenges
                                  .where(
                                    (challenge) => _tierFor(challenge) == tier,
                                  )
                                  .length,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              _SupremeTrophyCard(
                completedCount: _completedChallenges.length,
                challengeCount: _journey.challengeIds.length,
                badge: _journeyPlatinum,
                unlocked: _supremeUnlocked,
              ),
              const SizedBox(height: 24),
              Text('Troféus dos desafios', style: AppTextStyles.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Bronze: até 7 dias · Prata: até 14 dias · Ouro: acima de 14 dias. ${_journey.id == 'knowledge' ? 'O rubi' : 'A platina'} exige concluir os desafios desta jornada.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              FilterChipRow(
                options: _achievementFilters,
                selectedIndex: _achievementFilterIndex,
                onSelected: (index) =>
                    setState(() => _achievementFilterIndex = index),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
      if (achievementList.isEmpty)
        SliverToBoxAdapter(
          child: _EmptyChallengeState(
            message: _achievementFilterIndex == 1
                ? 'Você ainda não conquistou um troféu de desafio. Seu primeiro desafio pode começar hoje.'
                : _achievementFilterIndex == 2
                ? 'Não há troféus em andamento agora.'
                : 'Não há troféus bloqueados nesta lista.',
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: achievementList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final challenge = achievementList[index];
              return _AchievementCard(
                challenge: challenge,
                tier: _tierFor(challenge),
                onTap: () => _openChallenge(challenge),
              );
            },
          ),
        ),
    ];
  }

  Future<void> _openChallenge(ChallengeModel challenge) async {
    final completedBefore = _completedChallenges.map((item) => item.id).toSet();
    final supremeBefore = _supremeUnlocked;
    await Navigator.of(context).push(
      fadeSlideRoute(
        ChallengeDetailScreen(
          challenge: challenge,
          isAuthenticated: widget.isAuthenticated,
          onRequireLogin: widget.onRequireLogin,
        ),
      ),
    );
    if (!mounted) return;
    await _load();

    final newlyCompleted = _completedChallenges
        .where((item) => !completedBefore.contains(item.id))
        .toList();
    if (newlyCompleted.isEmpty || !mounted) return;

    final earnedSupreme = !supremeBefore && _supremeUnlocked;
    await _showTrophyUnlocked(
      newlyCompleted.first,
      earnedSupreme: earnedSupreme,
    );
  }

  Future<void> _showTrophyUnlocked(
    ChallengeModel challenge, {
    required bool earnedSupreme,
  }) async {
    final tier = _tierFor(challenge);
    final awardedTier = earnedSupreme ? _TrophyTier.platinum : tier;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: context.pbhColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: awardedTier.color.withOpacity(.55)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: .55, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: _TrophyMedallion(tier: awardedTier, size: 92),
              ),
              const SizedBox(height: 18),
              Text(
                earnedSupreme
                    ? 'Troféu supremo conquistado!'
                    : 'Troféu conquistado!',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge.copyWith(
                  color: awardedTier.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                earnedSupreme
                    ? 'Você concluiu esta jornada e desbloqueou ${_journeyPlatinum.title}.'
                    : '${tier.label} • ${challenge.title}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() => _pageIndex = 1);
                  },
                  child: const Text('Ver meus troféus'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_TrophyTier _tierFor(ChallengeModel challenge) {
  if (challenge.totalDays <= 7) return _TrophyTier.bronze;
  if (challenge.totalDays <= 14) return _TrophyTier.silver;
  return _TrophyTier.gold;
}

enum _TrophyTier {
  bronze('Bronze', Color(0xFFCD8756), Icons.military_tech_rounded, 10),
  silver('Prata', Color(0xFFBFC4CA), Icons.workspace_premium_rounded, 25),
  gold('Ouro', Color(0xFFFFB547), Icons.emoji_events_rounded, 50),
  platinum('Platina', Color(0xFFE4F4FF), Icons.workspace_premium_rounded, 100);

  const _TrophyTier(this.label, this.color, this.icon, this.points);
  final String label;
  final Color color;
  final IconData icon;
  final int points;
}

class _PageSelector extends StatelessWidget {
  const _PageSelector({required this.selectedIndex, required this.onSelected});
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: context.pbhColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.pbhColors.borderSubtle),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PageSelectorButton(
          label: 'Desafios',
          icon: Icons.flag_rounded,
          selected: selectedIndex == 0,
          onTap: () => onSelected(0),
        ),
        _PageSelectorButton(
          label: 'Conquistas',
          icon: Icons.emoji_events_rounded,
          selected: selectedIndex == 1,
          onTap: () => onSelected(1),
        ),
      ],
    ),
  );
}

class _PageSelectorButton extends StatefulWidget {
  const _PageSelectorButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PageSelectorButton> createState() => _PageSelectorButtonState();
}

class _PageSelectorButtonState extends State<_PageSelectorButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _inflate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.065,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.065,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 60,
    ),
  ]).animate(_inflate);

  @override
  void dispose() {
    _inflate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Semantics(
        selected: widget.selected,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(
            scale: MediaQuery.disableAnimationsOf(context) ? 1 : _scale.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: widget.selected
                  ? const Color(0xFF23150F)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.selected
                    ? context.pbhColors.orange
                    : Colors.transparent,
                width: 1.3,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: context.pbhColors.orange.withValues(alpha: .35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: context.pbhColors.orange.withValues(alpha: .13),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: TextButton(
              onPressed: () {
                if (!MediaQuery.disableAnimationsOf(context)) {
                  _inflate.forward(from: 0);
                }
                widget.onTap();
              },
              style: TextButton.styleFrom(
                foregroundColor: widget.selected
                    ? context.pbhColors.orange
                    : context.pbhColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 18),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.chip.copyWith(
                        color: widget.selected
                            ? context.pbhColors.orange
                            : context.pbhColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        shadows: widget.selected
                            ? [
                                Shadow(
                                  color: context.pbhColors.orange.withValues(
                                    alpha: .5,
                                  ),
                                  blurRadius: 10,
                                ),
                              ]
                            : const [],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TrophySummaryCard extends StatelessWidget {
  const _TrophySummaryCard({
    required this.journey,
    required this.earned,
    required this.total,
    required this.points,
    required this.progress,
    required this.tiers,
  });
  final int earned;
  final ChallengeJourney journey;
  final int total;
  final int points;
  final double progress;
  final List<MapEntry<_TrophyTier, int>> tiers;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          context.pbhColors.surfaceElevated,
          context.pbhColors.surface,
          context.pbhColors.backgroundElevated,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.pbhColors.orange.withOpacity(.32)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Tooltip(
              message: 'Ampliar capa da coleção',
              child: Semantics(
                button: true,
                label: 'Ampliar capa da coleção',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => Dialog.fullscreen(
                      backgroundColor: Colors.black,
                      child: Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          title: const Text('Capa da coleção'),
                          leading: IconButton(
                            tooltip: 'Fechar imagem',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                        body: SafeArea(
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 5,
                            child: SizedBox.expand(
                              child: Image.asset(
                                journey.coverAsset,
                                fit: BoxFit.contain,
                                semanticLabel:
                                    'Arte completa: ${journey.title}',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: Container(
                    width: 60,
                    height: 60,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: journey.color.withValues(alpha: .35),
                      ),
                    ),
                    child: Image.asset(
                      journey.coverAsset,
                      fit: BoxFit.cover,
                      alignment: journey.coverAlignment,
                      cacheWidth: 180,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUA COLEÇÃO',
                    style: AppTextStyles.eyebrow.copyWith(
                      color: context.pbhColors.orangeLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    journey.id == 'original' ? 'Troféus PBH' : 'Conhecimento',
                    style: AppTextStyles.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$earned',
              style: AppTextStyles.displayLarge.copyWith(fontSize: 34),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text('/ $total conquistados', style: AppTextStyles.body),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$points',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.pbhColors.orange,
                  ),
                ),
                Text(
                  'PONTOS PBH',
                  style: AppTextStyles.eyebrow
                      .copyWith(color: context.pbhColors.orangeLight)
                      .copyWith(fontSize: 9),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: context.pbhColors.background,
            valueColor: AlwaysStoppedAnimation(context.pbhColors.orange),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tiers
              .map(
                (entry) => _TierCount(
                  tier: entry.key,
                  count: entry.value,
                  ruby:
                      journey.id == 'knowledge' &&
                      entry.key == _TrophyTier.platinum,
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class _TierCount extends StatelessWidget {
  const _TierCount({
    required this.tier,
    required this.count,
    this.ruby = false,
  });
  final bool ruby;
  final _TrophyTier tier;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: (ruby ? ProfileAchievement.knowledgePlatinum.color : tier.color)
          .withOpacity(.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: tier.color.withOpacity(.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          tier.icon,
          size: 15,
          color: ruby ? ProfileAchievement.knowledgePlatinum.color : tier.color,
        ),
        const SizedBox(width: 5),
        Text('${ruby ? 'Rubi' : tier.label} $count', style: AppTextStyles.chip),
      ],
    ),
  );
}

class _SupremeTrophyCard extends StatelessWidget {
  const _SupremeTrophyCard({
    required this.completedCount,
    required this.challengeCount,
    required this.unlocked,
    required this.badge,
  });
  final int completedCount, challengeCount;
  final bool unlocked;
  final ProfileAchievement badge;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: context.pbhColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: unlocked ? badge.color : context.pbhColors.border,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: unlocked,
          label: unlocked ? 'Ver ${badge.title}' : '${badge.title}, bloqueada',
          child: InkWell(
            onTap: unlocked
                ? () => ProfileAchievementSeals.showDetails(context, badge)
                : null,
            child: SizedBox.square(
              dimension: 60,
              child: unlocked && badge.artAsset != null
                  ? Image.asset(badge.artAsset!, fit: BoxFit.contain)
                  : Icon(
                      unlocked ? badge.icon : Icons.lock_outline,
                      color: unlocked
                          ? badge.color
                          : context.pbhColors.textTertiary,
                      size: 40,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                badge.title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: unlocked ? badge.color : context.pbhColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                unlocked
                    ? 'Todos os desafios desta jornada concluídos. ${badge.isRuby ? 'Rubi desbloqueado!' : 'Platina desbloqueada!'}'
                    : 'Conquiste os $challengeCount troféus desta jornada para desbloquear ${badge.isRuby ? 'este rubi' : 'esta platina'}.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: challengeCount == 0
                      ? 0
                      : (completedCount / challengeCount)
                            .clamp(0, 1)
                            .toDouble(),
                  minHeight: 5,
                  color: badge.color,
                  backgroundColor: context.pbhColors.background,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$completedCount de $challengeCount troféus conquistados',
                style: AppTextStyles.statLabel,
              ),
              if (unlocked)
                TextButton(
                  onPressed: () =>
                      ProfileAchievementSeals.showDetails(context, badge),
                  child: Text(
                    badge.isRuby
                        ? 'Ver troféu de rubi'
                        : 'Ver troféu de platina',
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.challenge,
    required this.tier,
    required this.onTap,
  });
  final ChallengeModel challenge;
  final _TrophyTier tier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = challenge.status == ChallengeStatus.completed;
    final active = challenge.status == ChallengeStatus.active;
    return Material(
      color: context.pbhColors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: unlocked
                  ? tier.color.withOpacity(.42)
                  : context.pbhColors.border,
            ),
          ),
          child: Row(
            children: [
              _TrophyMedallion(tier: tier, size: 64, locked: !unlocked),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        if (unlocked)
                          Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: tier.color,
                          )
                        else if (!active)
                          Icon(
                            Icons.lock_rounded,
                            size: 15,
                            color: context.pbhColors.textTertiary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${tier.label} • ${unlocked ? '${challenge.totalDays} dias concluídos' : challenge.achievementStatus}',
                      style: AppTextStyles.statLabel.copyWith(
                        color: tier.color,
                      ),
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: challenge.progress,
                        minHeight: 4,
                        backgroundColor: context.pbhColors.background,
                        valueColor: AlwaysStoppedAnimation(
                          unlocked ? tier.color : context.pbhColors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      unlocked
                          ? '${challenge.achievementStatus} • +${tier.points} pontos'
                          : active
                          ? '${challenge.currentDay}/${challenge.totalDays} dias • em andamento'
                          : 'Bloqueado • ${challenge.totalDays} dias',
                      style: AppTextStyles.statLabel.copyWith(
                        color: unlocked
                            ? tier.color
                            : context.pbhColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: context.pbhColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrophyMedallion extends StatelessWidget {
  const _TrophyMedallion({
    required this.tier,
    required this.size,
    this.locked = false,
  });
  final _TrophyTier tier;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final artwork = switch (tier) {
      _TrophyTier.gold => 'assets/images/trofeu_ouro_pbh.png',
      _TrophyTier.silver => 'assets/images/trofeu_prata_pbh.png',
      _TrophyTier.bronze => 'assets/images/trofeu_bronze_pbh.png',
      _TrophyTier.platinum => 'assets/images/trofeu_platina_pbh.png',
    };
    return RepaintBoundary(
      child: Opacity(
        opacity: locked ? .35 : 1,
        child: SizedBox.square(
          dimension: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * .2),
            child: Image.asset(
              artwork,
              fit: BoxFit.contain,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              semanticLabel: locked
                  ? 'Troféu de ${tier.label.toLowerCase()} PBH bloqueado'
                  : 'Troféu de ${tier.label.toLowerCase()} PBH',
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: context.pbhColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.pbhColors.border),
    ),
    child: Column(
      children: [
        const _TrophyMedallion(
          tier: _TrophyTier.bronze,
          size: 68,
          locked: true,
        ),
        const SizedBox(height: 14),
        Text(
          'Sua coleção começa com sua conta',
          textAlign: TextAlign.center,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Entre para salvar seu progresso e desbloquear troféus ao concluir desafios.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Entrar na conta'),
        ),
      ],
    ),
  );
}

class _EmptyChallengeState extends StatelessWidget {
  const _EmptyChallengeState({required this.message, this.action, this.onTap});
  final String message;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42),
    child: Column(
      children: [
        Icon(
          Icons.flag_outlined,
          size: 34,
          color: context.pbhColors.textTertiary,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}
