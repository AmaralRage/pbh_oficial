import 'package:flutter/material.dart';
import '../services/personal_goal_service.dart';

String goalRecordDate(BuildContext context, String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return 'Data indisponível';
  return '${MaterialLocalizations.of(context).formatMediumDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}';
}

class PersonalGoalHistoryScreen extends StatefulWidget {
  const PersonalGoalHistoryScreen({
    super.key,
    required this.service,
    this.goalId,
    this.title = 'Objetivos concluídos',
    this.timeline = false,
  });
  final PersonalGoalService service;
  final String? goalId;
  final String title;
  final bool timeline;
  @override
  State<PersonalGoalHistoryScreen> createState() =>
      _PersonalGoalHistoryScreenState();
}

class _PersonalGoalHistoryScreenState extends State<PersonalGoalHistoryScreen> {
  final _rows = <Map<String, dynamic>>[];
  bool _loading = false, _more = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final rows = widget.timeline
          ? await widget.service.timeline(widget.goalId, offset: _rows.length)
          : await widget.service.history(offset: _rows.length);
      if (mounted)
        setState(() {
          _rows.addAll(rows);
          _more = rows.length == (widget.timeline ? 30 : 20);
          _failed = false;
        });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Seu histórico e os registros de avanço são privados.'),
        const SizedBox(height: 12),
        if (!widget.timeline)
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PersonalGoalHistoryScreen(
                  service: widget.service,
                  timeline: true,
                  title: 'Registros anteriores',
                ),
              ),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Ver registros anteriores sem vínculo'),
          ),
        for (final row in _rows)
          Card(
            child: widget.timeline
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goalRecordDate(context, row['created_at'] as String),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(row['content'] as String),
                        if (widget.goalId == null)
                          Text(
                            row['goal_title'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  )
                : ListTile(
                    leading: const Icon(Icons.task_alt),
                    title: Text(row['title'] as String),
                    subtitle: Text(
                      'Concluído em ${goalRecordDate(context, row['completed_at'] as String)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PersonalGoalHistoryScreen(
                          service: widget.service,
                          goalId: row['id'] as String,
                          title: row['title'] as String,
                          timeline: true,
                        ),
                      ),
                    ),
                  ),
          ),
        if (_rows.isEmpty && !_loading && !_failed)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum registro neste histórico ainda.'),
          ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_failed)
          TextButton(
            onPressed: _load,
            child: const Text('Não foi possível carregar. Tentar novamente'),
          ),
        if (_more && !_loading && !_failed && _rows.isNotEmpty)
          TextButton(onPressed: _load, child: const Text('Carregar mais')),
      ],
    ),
  );
}
