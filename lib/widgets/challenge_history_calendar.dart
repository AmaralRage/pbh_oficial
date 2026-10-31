import 'package:flutter/material.dart';

class ChallengeHistoryCalendar extends StatefulWidget {
  const ChallengeHistoryCalendar({
    super.key,
    required this.loadDays,
    this.today,
  });
  final Future<Set<DateTime>> Function(DateTime start, DateTime end) loadDays;
  final DateTime? today;
  @override
  State<ChallengeHistoryCalendar> createState() =>
      _ChallengeHistoryCalendarState();
}

class _ChallengeHistoryCalendarState extends State<ChallengeHistoryCalendar> {
  late final _today = DateUtils.dateOnly(widget.today ?? DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);
  Set<DateTime> _days = {};
  bool _loading = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _days = {};
    });
    try {
      final days = await widget.loadDays(
        _month,
        DateTime(_month.year, _month.month + 1, 0),
      );
      if (mounted && request == _request)
        setState(() => _days = days.map(DateUtils.dateOnly).toSet());
    } catch (_) {
      if (mounted && request == _request)
        setState(() => _error = 'Não foi possível carregar os registros.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _move(int offset) {
    _month = DateTime(_month.year, _month.month + offset);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    final count = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = _month.weekday - 1;
    final current = _month.year == _today.year && _month.month == _today.month;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'Seus dias registrados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${months[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed: current ? null : () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ] else ...[
              Row(
                children: [
                  for (final label in ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'])
                    Expanded(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
              const SizedBox(height: 8),
              for (var row = 0; row < ((count + offset) / 7).ceil(); row++)
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            final number = row * 7 + column - offset + 1;
                            if (number < 1 || number > count)
                              return const SizedBox(height: 34);
                            final date = DateTime(
                              _month.year,
                              _month.month,
                              number,
                            );
                            final marked = _days.contains(date);
                            return Semantics(
                              label:
                                  '${date.day}/${date.month}/${date.year}, ${marked ? 'registrado' : 'sem registro'}',
                              excludeSemantics: true,
                              child: Container(
                                height: 32,
                                margin: const EdgeInsets.all(1),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: marked
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                child: Text(
                                  '$number',
                                  style: TextStyle(
                                    color: marked
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                _days.isEmpty
                    ? 'Nenhum registro neste mês.'
                    : '${_days.length} dias registrados neste mês.',
              ),
              const SizedBox(height: 4),
              Text(
                'Somente registros reais. O calendário não altera seu progresso.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
