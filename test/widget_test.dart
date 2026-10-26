import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pbh_oficial/core/theme/pbh_palette.dart';
import 'package:pbh_oficial/models/habit_model.dart';
import 'package:pbh_oficial/screens/app_startup_screen.dart';
import 'package:pbh_oficial/widgets/habit_item_card.dart';

void main() {
  testWidgets('habit card completes from the full row', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [PbhPalette.resolve('pbh')]),
        home: Scaffold(
          body: HabitItemCard(
            habit: const HabitModel(
              key: 'train',
              title: 'Treinar o corpo',
              subtitle: '45 min',
              icon: Icons.fitness_center_rounded,
            ),
            onToggle: (value) => completed = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Treinar o corpo'));

    expect(completed, isTrue);
  });

  testWidgets('shows a first frame while initialization is pending', (
    tester,
  ) async {
    final startup = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: AppStartupScreen(
          initialize: () => startup.future,
          child: const Text('App pronto'),
        ),
      ),
    );
    expect(find.text('Abrindo PBH Oficial…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('App pronto'), findsNothing);
    startup.complete();
    await tester.pump();
    expect(find.text('App pronto'), findsOneWidget);
  });

  testWidgets('startup failure is visible and retry reaches the app', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppStartupScreen(
          initialize: () async {
            if (++attempts == 1) throw StateError('Storage unavailable');
          },
          child: const Text('App pronto'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Não foi possível iniciar o PBH'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('App pronto'), findsOneWidget);
  });

  testWidgets('slow startup still completes without duplicate initialization', (
    tester,
  ) async {
    final startup = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppStartupScreen(
          initialize: () {
            attempts++;
            return startup.future;
          },
          child: const Text('App pronto'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 16));
    expect(find.textContaining('A abertura está demorando'), findsOneWidget);
    startup.complete();
    await tester.pump();
    expect(find.text('App pronto'), findsOneWidget);
    expect(attempts, 1);
  });
}
