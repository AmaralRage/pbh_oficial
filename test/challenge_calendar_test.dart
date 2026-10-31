import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/challenge_history_calendar.dart';
import 'package:pbh_oficial/models/challenge_model.dart';

void main() {
  testWidgets(
    'calendar shows real records, browses months and retries failures',
    (tester) async {
      var fail = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChallengeHistoryCalendar(
                today: DateTime(2026, 10, 30),
                loadDays: (start, end) async {
                  if (fail) throw StateError('offline');
                  return start.month == 10
                      ? {DateTime(2026, 10, 2), DateTime(2026, 10, 29)}
                      : {};
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 dias registrados neste mês.'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Próximo mês',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Setembro 2026'), findsOneWidget);
      expect(find.text('Nenhum registro neste mês.'), findsOneWidget);
      fail = true;
      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível carregar os registros.'),
        findsOneWidget,
      );
      expect(find.text('Nenhum registro neste mês.'), findsNothing);
      fail = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Agosto 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('milestones count records rather than consecutive days', () {
    const challenge = ChallengeModel(
      id: 'x',
      title: 'X',
      description: '',
      totalDays: 7,
      currentDay: 2,
      level: ChallengeLevel.iniciante,
      status: ChallengeStatus.active,
      icon: Icons.flag,
    );
    expect(challenge.nextMilestone, 4);
    expect(challenge.milestoneLabel, contains('faltam 2'));
  });
}
