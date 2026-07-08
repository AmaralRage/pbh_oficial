import 'package:flutter/material.dart';
import '../core/navigation/app_transitions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/program_model.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/program_card.dart';
import 'program_detail_screen.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  int _filterIndex = 0;
  static const _filters = ['Todos', 'Em andamento', 'Iniciante', 'Avançado'];

  List<ProgramModel> get _filtered {
    switch (_filterIndex) {
      case 1:
        return mockPrograms.where((p) => p.progress > 0).toList();
      case 2:
        return mockPrograms.where((p) => p.level == ContentLevel.iniciante).toList();
      case 3:
        return mockPrograms.where((p) => p.level == ContentLevel.avancado).toList();
      default:
        return mockPrograms;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Conteúdo', style: AppTextStyles.headline),
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.textPrimary),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Busca de programas em construção.')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Programas para sua evolução contínua.', style: AppTextStyles.bodySmall),
          const SizedBox(height: 24),

          FilterChipRow(
            options: _filters,
            selectedIndex: _filterIndex,
            onSelected: (i) => setState(() => _filterIndex = i),
          ),
          const SizedBox(height: 20),

          Text('${list.length} programas disponíveis', style: AppTextStyles.bodySmall),
          const SizedBox(height: 14),

          ...list.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProgramCard(
                program: p,
                onTap: () {
                  Navigator.of(context).push(
                    fadeSlideRoute(ProgramDetailScreen(program: p)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
