import 'package:flutter/material.dart';

import '../core/navigation/app_transitions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/challenge_model.dart';
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

  List<ChallengeModel> get _completedChallenges => _challenges
      .where((challenge) => challenge.status == ChallengeStatus.completed)
      .toList();

  bool get _supremeUnlocked =>
      _challenges.isNotEmpty &&
      _completedChallenges.length == _challenges.length;

  int get _achievementPoints => _completedChallenges.fold<int>(
        _supremeUnlocked ? 100 : 0,
        (points, challenge) => points + _tierFor(challenge).points,
      );

  ChallengeModel? get _activeChallenge {
    for (final challenge in _challenges) {
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
      1 => _challenges
          .where((challenge) => challenge.status == ChallengeStatus.active)
          .toList(),
      2 => _challenges
          .where((challenge) => challenge.status == ChallengeStatus.notStarted)
          .toList(),
      3 => _challenges
          .where((challenge) => challenge.status == ChallengeStatus.completed)
          .toList(),
      _ => _challenges,
    };
    final search = _searchController.text.trim().toLowerCase();
    return search.isEmpty
        ? byStatus
        : byStatus
            .where((item) =>
                item.title.toLowerCase().contains(search) ||
                item.description.toLowerCase().contains(search))
            .toList();
  }

  List<ChallengeModel> get _filteredAchievements {
    return switch (_achievementFilterIndex) {
      1 => _completedChallenges,
      2 => _challenges
          .where((item) => item.status == ChallengeStatus.active)
          .toList(),
      3 => _challenges
          .where((item) => item.status == ChallengeStatus.notStarted)
          .toList(),
      _ => _challenges,
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                      color: AppColors.textPrimary,
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
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(38),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _EmptyChallengeState(
                message: 'Não foi possível carregar seus desafios.',
                action: 'Tentar novamente',
                onTap: _load,
              )
            else if (_pageIndex == 0)
              _buildChallenges(active, list)
            else
              _buildAchievements(),
          ],
        ),
      ),
    );
  }

  Widget _buildChallenges(
    ChallengeModel? active,
    List<ChallengeModel> list,
  ) {
    return Column(
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
            Text('Desafios disponíveis', style: AppTextStyles.titleMedium),
            Text('${list.length}', style: AppTextStyles.bodySmall),
          ],
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          _EmptyChallengeState(
            message: _searchController.text.isNotEmpty
                ? 'Nenhum desafio corresponde à busca.'
                : _filterIndex == 1
                    ? 'Você ainda não iniciou um desafio.'
                    : _filterIndex == 3
                        ? 'Você ainda não concluiu desafios.'
                        : 'Nenhum desafio disponível agora.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => ChallengeCard(
              challenge: list[index],
              onTap: () => _openChallenge(list[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildAchievements() {
    if (!widget.isAuthenticated) {
      return _LoginPrompt(onTap: widget.onRequireLogin);
    }

    final earned = _completedChallenges.length + (_supremeUnlocked ? 1 : 0);
    final total = _challenges.length + 1;
    final progress =
        total == 0 ? 0.0 : (earned / total).clamp(0.0, 1.0).toDouble();
    final achievementList = _filteredAchievements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TrophySummaryCard(
          earned: earned,
          total: total,
          points: _achievementPoints,
          progress: progress,
          tiers: _TrophyTier.values
              .map((tier) => MapEntry(
                    tier,
                    _completedChallenges
                        .where((challenge) => _tierFor(challenge) == tier)
                        .length,
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        _SupremeTrophyCard(
          completedCount: _completedChallenges.length,
          challengeCount: _challenges.length,
          unlocked: _supremeUnlocked,
        ),
        const SizedBox(height: 24),
        Text('Troféus dos desafios', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        FilterChipRow(
          options: _achievementFilters,
          selectedIndex: _achievementFilterIndex,
          onSelected: (index) =>
              setState(() => _achievementFilterIndex = index),
        ),
        const SizedBox(height: 14),
        if (achievementList.isEmpty)
          _EmptyChallengeState(
            message: _achievementFilterIndex == 1
                ? 'Você ainda não conquistou um troféu. Seu primeiro desafio pode começar hoje.'
                : _achievementFilterIndex == 2
                    ? 'Não há troféus em andamento agora.'
                    : 'Não há troféus bloqueados nesta lista.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
      ],
    );
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
        backgroundColor: AppColors.surface,
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
                style:
                    AppTextStyles.titleLarge.copyWith(color: awardedTier.color),
              ),
              const SizedBox(height: 8),
              Text(
                earnedSupreme
                    ? 'Você concluiu todos os desafios e desbloqueou a Platina PBH.'
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
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(children: [
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
        ]),
      );
}

class _PageSelectorButton extends StatelessWidget {
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
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? AppColors.orange : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 17,
                    color: selected ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppTextStyles.chip.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TrophySummaryCard extends StatelessWidget {
  const _TrophySummaryCard({
    required this.earned,
    required this.total,
    required this.points,
    required this.progress,
    required this.tiers,
  });
  final int earned;
  final int total;
  final int points;
  final double progress;
  final List<MapEntry<_TrophyTier, int>> tiers;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF24201E), AppColors.surface, Color(0xFF111111)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.orange.withOpacity(.32)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const _TrophyMedallion(tier: _TrophyTier.gold, size: 54),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SUA COLEÇÃO', style: AppTextStyles.eyebrow),
                  const SizedBox(height: 3),
                  Text('Troféus PBH', style: AppTextStyles.titleLarge),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$earned',
                style: AppTextStyles.displayLarge.copyWith(fontSize: 34)),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text('/ $total conquistados', style: AppTextStyles.body),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$points',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: AppColors.orange)),
              Text('PONTOS PBH',
                  style: AppTextStyles.eyebrow.copyWith(fontSize: 9)),
            ]),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation(AppColors.orange),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tiers
                .map((entry) => _TierCount(tier: entry.key, count: entry.value))
                .toList(),
          ),
        ]),
      );
}

class _TierCount extends StatelessWidget {
  const _TierCount({required this.tier, required this.count});
  final _TrophyTier tier;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: tier.color.withOpacity(.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tier.color.withOpacity(.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(tier.icon, size: 15, color: tier.color),
          const SizedBox(width: 5),
          Text('${tier.label} $count', style: AppTextStyles.chip),
        ]),
      );
}

class _SupremeTrophyCard extends StatelessWidget {
  const _SupremeTrophyCard({
    required this.completedCount,
    required this.challengeCount,
    required this.unlocked,
  });
  final int completedCount;
  final int challengeCount;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final color = _TrophyTier.platinum.color;
    final progress = challengeCount == 0
        ? 0.0
        : (completedCount / challengeCount).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked ? color.withOpacity(.8) : AppColors.border,
          width: unlocked ? 1.4 : 1,
        ),
        boxShadow: unlocked
            ? [BoxShadow(color: color.withOpacity(.12), blurRadius: 22)]
            : null,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TrophyMedallion(
          tier: _TrophyTier.platinum,
          size: 60,
          locked: !unlocked,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text('Platina PBH', style: AppTextStyles.titleMedium),
                ),
                if (!unlocked)
                  const Icon(Icons.lock_rounded,
                      size: 16, color: AppColors.textTertiary)
                else
                  Icon(Icons.check_circle_rounded, size: 18, color: color),
              ]),
              const SizedBox(height: 4),
              Text(
                'Conclua todos os desafios do catálogo para se tornar um Homem Supremo.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation(
                    unlocked ? color : AppColors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$completedCount de $challengeCount desafios concluídos',
                style: AppTextStyles.statLabel.copyWith(
                  color: unlocked ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: unlocked ? tier.color.withOpacity(.42) : AppColors.border,
            ),
          ),
          child: Row(children: [
            _TrophyMedallion(
              tier: tier,
              size: 54,
              locked: !unlocked,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        challenge.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    if (unlocked)
                      Icon(Icons.check_circle_rounded,
                          size: 17, color: tier.color)
                    else if (!active)
                      const Icon(Icons.lock_rounded,
                          size: 15, color: AppColors.textTertiary),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    '${tier.label} • Complete ${challenge.totalDays} dias',
                    style: AppTextStyles.statLabel.copyWith(color: tier.color),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: challenge.progress,
                      minHeight: 4,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation(
                        unlocked ? tier.color : AppColors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    unlocked
                        ? 'CONQUISTADO  •  +${tier.points} PONTOS'
                        : active
                            ? '${challenge.currentDay}/${challenge.totalDays} dias • em andamento'
                            : 'Bloqueado • ${challenge.totalDays} dias',
                    style: AppTextStyles.statLabel.copyWith(
                      color: unlocked ? tier.color : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ]),
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
    final color = tier.color;
    return Opacity(
      opacity: locked ? .35 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(.24), AppColors.background],
          ),
          border: Border.all(color: color.withOpacity(locked ? .25 : .75)),
          boxShadow: locked
              ? null
              : [BoxShadow(color: color.withOpacity(.16), blurRadius: 14)],
        ),
        child: Icon(tier.icon, color: color, size: size * .52),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          const _TrophyMedallion(
              tier: _TrophyTier.bronze, size: 68, locked: true),
          const SizedBox(height: 14),
          Text('Sua coleção começa com sua conta',
              textAlign: TextAlign.center, style: AppTextStyles.titleMedium),
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
        ]),
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
        child: Column(children: [
          const Icon(Icons.flag_outlined,
              size: 34, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
          if (action != null)
            TextButton(onPressed: onTap, child: Text(action!)),
        ]),
      );
}
