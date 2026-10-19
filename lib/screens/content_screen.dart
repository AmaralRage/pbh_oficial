import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Set<String> _savedProgramIds = {};
  final Set<String> _startedProgramIds = {};
  final SharedPreferencesAsync _storage = SharedPreferencesAsync();
  final _searchController = TextEditingController();
  static const _filters = ['Todos', 'Iniciante', 'Intermediário', 'Avançado', 'Salvos'];

  @override
  void initState() {
    super.initState();
    _loadProgramState();
  }

  Future<void> _loadProgramState() async {
    try {
      final keys = await _storage.getKeys();
      final state = <String, List<bool?>>{};
      for (final program in programCatalog) {
        final savedKey = 'pbh.program.${program.id}.saved';
        final startedKey = 'pbh.program.${program.id}.started';
        if (!keys.contains(savedKey) && !keys.contains(startedKey)) continue;
        state[program.id] = await Future.wait([_storage.getBool(savedKey), _storage.getBool(startedKey)]);
      }
      if (!mounted) return;
      setState(() {
        _savedProgramIds
          ..clear()
          ..addAll(state.entries.where((entry) => entry.value[0] == true).map((entry) => entry.key));
        _startedProgramIds
          ..clear()
          ..addAll(state.entries.where((entry) => entry.value[1] == true).map((entry) => entry.key));
      });
    } catch (_) {
      // The catalog remains usable if local preferences are unavailable.
    }
  }

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
      final matchesSaved = _filterIndex != 4 || _savedProgramIds.contains(program.id);
      final matchesSearch = query.isEmpty ||
          program.title.toLowerCase().contains(query) ||
          program.tagline.toLowerCase().contains(query) ||
          program.description.toLowerCase().contains(query);
      return matchesLevel && matchesSaved && matchesSearch;
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
              Text('Conteúdo', style: AppTextStyles.brandHeadline),
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
              child: Stack(
                children: [
                  ProgramCard(
                    program: p,
                    onTap: () {
                      Navigator.of(context)
                          .push(fadeSlideRoute(ProgramDetailScreen(program: p)))
                          .then((_) => _loadProgramState());
                    },
                  ),
                  if (_startedProgramIds.contains(p.id) || _savedProgramIds.contains(p.id))
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (_startedProgramIds.contains(p.id)) const Icon(Icons.play_circle_fill, size: 16, color: AppColors.orange),
                        if (_savedProgramIds.contains(p.id)) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.bookmark, size: 16, color: AppColors.orange)),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
