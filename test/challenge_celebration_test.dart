import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/challenge_model.dart';
import 'package:pbh_oficial/widgets/challenge_celebration.dart';

void main() {
  testWidgets(
    'celebration supports reduced motion and dismisses without sharing',
    (tester) async {
      const challenge = ChallengeModel(
        id: 'test',
        title: 'Foco por 7 dias',
        description: '',
        totalDays: 7,
        level: ChallengeLevel.iniciante,
        status: ChallengeStatus.completed,
        icon: Icons.flag,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      ChallengeCelebration.show(context, challenge),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Você conquistou!'), findsOneWidget);
      expect(find.textContaining('Bronze · 7 dias'), findsOneWidget);
      expect(find.text('Compartilhar conquista'), findsOneWidget);
      await tester.tap(find.text('Continuar minha jornada'));
      await tester.pumpAndSettle();
      expect(find.text('Você conquistou!'), findsNothing);
    },
  );
}
