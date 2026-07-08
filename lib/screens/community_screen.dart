import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/community_post_model.dart';
import '../widgets/community_post_card.dart';
import '../widgets/filter_chip_row.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _filterIndex = 0;
  static const _filters = ['Para você', 'Seguindo', 'Conquistas', 'Populares'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Comunidade', style: AppTextStyles.headline),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Criação de post em construção.')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Homens comprometidos com a mesma jornada.', style: AppTextStyles.bodySmall),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CommunityStat(value: '48.2k', label: 'Membros'),
                _VerticalDivider(),
                _CommunityStat(value: '1.2k', label: 'Online agora'),
                _VerticalDivider(),
                _CommunityStat(value: '312', label: 'Posts hoje'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FilterChipRow(
            options: _filters,
            selectedIndex: _filterIndex,
            onSelected: (i) => setState(() => _filterIndex = i),
          ),
          const SizedBox(height: 20),

          ...mockPosts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: CommunityPostCard(post: post),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityStat extends StatelessWidget {
  final String value;
  final String label;

  const _CommunityStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.statNumber),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.statLabel),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.borderSubtle);
  }
}
