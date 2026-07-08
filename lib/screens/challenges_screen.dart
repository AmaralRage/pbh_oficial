import 'package:flutter/material.dart';
import '../core/navigation/app_transitions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/challenge_model.dart';
import '../widgets/challenge_card.dart';
import '../widgets/featured_challenge_card.dart';
import '../widgets/filter_chip_row.dart';
import 'challenge_detail_screen.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  int _filterIndex = 0;

  static const _filters = ['Todos', 'Em andamento', 'Não iniciados', 'Concluídos'];

  ChallengeModel? get _activeChallenge {
    try {
      return mockChallenges.firstWhere((c) => c.status == ChallengeStatus.active);
    } catch (_) {
      return null;
    }
  }

  List<ChallengeModel> get _filteredChallenges {
    switch (_filterIndex) {
      case 1:
        return mockChallenges.where((c) => c.status == ChallengeStatus.active).toList();
      case 2:
        return mockChallenges.where((c) => c.status == ChallengeStatus.notStarted).toList();
      case 3:
        return mockChallenges.where((c) => c.status == ChallengeStatus.completed).toList();
      default:
        return mockChallenges;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeChallenge;
    final list = _filteredChallenges;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Desafios', style: AppTextStyles.headline),
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.textPrimary),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Busca de desafios em construção.')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Supere seus limites, um dia de cada vez.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 24),

          if (active != null) ...[
            FeaturedChallengeCard(
              challenge: active,
              onTap: () => _openChallenge(active),
            ),
            const SizedBox(height: 28),
          ],

          FilterChipRow(
            options: _filters,
            selectedIndex: _filterIndex,
            onSelected: (i) => setState(() => _filterIndex = i),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Todos os desafios', style: AppTextStyles.titleMedium),
              Text(
                '${list.length} desafios',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Nenhum desafio nessa categoria ainda.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return ChallengeCard(
                  challenge: list[index],
                  onTap: () => _openChallenge(list[index]),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openChallenge(ChallengeModel challenge) {
    Navigator.of(context).push(
      fadeSlideRoute(ChallengeDetailScreen(challenge: challenge)),
    );
  }
}
