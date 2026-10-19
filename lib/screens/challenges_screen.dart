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
  const ChallengesScreen({super.key, required this.isAuthenticated, required this.onRequireLogin});
  final bool isAuthenticated;
  final VoidCallback onRequireLogin;

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final _service = ChallengeService();
  final _searchController = TextEditingController();
  int _filterIndex = 0;
  bool _searching = false;
  bool _loading = true;
  String? _error;
  List<ChallengeModel> _challenges = const [];
  static const _filters = ['Todos', 'Em andamento', 'Não iniciados', 'Concluídos'];

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
      if (mounted) setState(() { _challenges = challenges; _loading = false; _error = null; });
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = error.toString(); });
    }
  }

  List<ChallengeModel> get _filteredChallenges {
    final byStatus = switch (_filterIndex) {
      1 => _challenges.where((challenge) => challenge.status == ChallengeStatus.active).toList(),
      2 => _challenges.where((challenge) => challenge.status == ChallengeStatus.notStarted).toList(),
      3 => _challenges.where((challenge) => challenge.status == ChallengeStatus.completed).toList(),
      _ => _challenges,
    };
    final search = _searchController.text.trim().toLowerCase();
    return search.isEmpty ? byStatus : byStatus.where((item) => item.title.toLowerCase().contains(search) || item.description.toLowerCase().contains(search)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeChallenge;
    final list = _filteredChallenges;
    return SafeArea(bottom: false, child: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Desafios', style: AppTextStyles.brandHeadline),
        IconButton(tooltip: 'Buscar desafios', icon: Icon(_searching ? Icons.close : Icons.search, color: AppColors.textPrimary), onPressed: () { setState(() { _searching = !_searching; if (!_searching) _searchController.clear(); }); }),
      ]),
      if (_searching) Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: _searchController, autofocus: true, decoration: const InputDecoration(hintText: 'Buscar desafios', prefixIcon: Icon(Icons.search)))),
      const SizedBox(height: 6),
      Text('Supere seus limites, um dia de cada vez.', style: AppTextStyles.bodySmall),
      if (active != null && _filterIndex == 0 && _searchController.text.isEmpty) ...[
        const SizedBox(height: 24),
        FeaturedChallengeCard(challenge: active, onTap: () => _openChallenge(active)),
      ],
      const SizedBox(height: 24),
      FilterChipRow(options: _filters, selectedIndex: _filterIndex, onSelected: (index) => setState(() => _filterIndex = index)),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Desafios disponíveis', style: AppTextStyles.titleMedium), Text('${list.length}', style: AppTextStyles.bodySmall)]),
      const SizedBox(height: 14),
      if (_loading)
        const Padding(padding: EdgeInsets.all(38), child: Center(child: CircularProgressIndicator()))
      else if (_error != null)
        _EmptyChallengeState(message: 'Não foi possível carregar os desafios.', action: 'Tentar novamente', onTap: _load)
      else if (list.isEmpty)
        _EmptyChallengeState(message: _searchController.text.isNotEmpty ? 'Nenhum desafio corresponde à busca.' : _filterIndex == 1 ? 'Você ainda não iniciou um desafio.' : _filterIndex == 3 ? 'Você ainda não concluiu desafios.' : 'Nenhum desafio disponível agora.')
      else
        ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: list.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (context, index) => ChallengeCard(challenge: list[index], onTap: () => _openChallenge(list[index]))),
    ])));
  }

  Future<void> _openChallenge(ChallengeModel challenge) async {
    await Navigator.of(context).push(fadeSlideRoute(ChallengeDetailScreen(challenge: challenge, isAuthenticated: widget.isAuthenticated, onRequireLogin: widget.onRequireLogin)));
    if (mounted) _load();
  }
}

class _EmptyChallengeState extends StatelessWidget {
  const _EmptyChallengeState({required this.message, this.action, this.onTap});
  final String message;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 42), child: Column(children: [const Icon(Icons.flag_outlined, size: 34, color: AppColors.textTertiary), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodySmall), if (action != null) TextButton(onPressed: onTap, child: Text(action!))]));
}
