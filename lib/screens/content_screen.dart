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
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  static const _filters = ['Todos', 'Iniciante', 'Intermediário', 'Avançado'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProgramModel> get _filtered {
    final level = switch (_filterIndex) {
      1 => ContentLevel.iniciante,
      2 => ContentLevel.intermediario,
      3 => ContentLevel.avancado,
      _ => null,
    };
    final query = _searchQuery.trim().toLowerCase();
    return programCatalog.where((program) {
      final matchesLevel = level == null || program.level == level;
      final matchesSearch = query.isEmpty ||
          program.title.toLowerCase().contains(query) ||
          program.tagline.toLowerCase().contains(query) ||
          program.description.toLowerCase().contains(query);
      return matchesLevel && matchesSearch;
    }).toList();
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
                tooltip: _searchOpen ? 'Fechar busca' : 'Buscar programas',
                icon: Icon(_searchOpen ? Icons.close : Icons.search, color: AppColors.textPrimary),
                onPressed: () => setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                }),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _searchOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome ou tema',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar busca',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
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

          Text('${list.length} programas encontrados', style: AppTextStyles.bodySmall),
          const SizedBox(height: 14),

          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Nenhum programa encontrado. Tente outro termo ou filtro.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ),
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
