import 'package:flutter/material.dart';
import '../core/navigation/app_transitions.dart';
import '../models/program_model.dart';
import '../services/program_service.dart';
import '../screens/program_detail_screen.dart';
import 'program_card.dart';

class ProgramRecommendations extends StatefulWidget {
  const ProgramRecommendations({super.key});
  @override
  State<ProgramRecommendations> createState() => _ProgramRecommendationsState();
}

class _ProgramRecommendationsState extends State<ProgramRecommendations> {
  final _service = ProgramService();
  List<ProgramModel> _items = [];
  bool? _active;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && _active == false) _load();
    _active = active;
  }

  Future<void> _load() async {
    try {
      final programs = await _service.availableCatalog();
      final progress = await _service.loadAll(programs);
      final topics = await _service.topics();
      final items = ProgramService.recommend(
        programs,
        progress,
        topics,
      ).take(2).toList();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as recomendações.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_error != null)
        TextButton(onPressed: _load, child: Text('$_error Tentar novamente')),
      for (final p in _items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProgramCard(
            program: p,
            onTap: () async {
              await Navigator.of(context).push(
                fadeSlideRoute(
                  ProgramDetailScreen(program: p, service: _service),
                ),
              );
              await _load();
            },
          ),
        ),
    ],
  );
}
