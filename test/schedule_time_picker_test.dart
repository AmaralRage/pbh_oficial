import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/schedule_time_picker.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    ValueChanged<TimeOfDay?> onResult, {
    TimeOfDay initial = const TimeOfDay(hour: 23, minute: 59),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showScheduleTimePicker(
                  context: context,
                  initialTime: initial,
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'keeps 24-hour selection without AM/PM and cancellation returns no time',
    (tester) async {
      TimeOfDay? selected;
      await open(tester, (time) => selected = time);
      expect(find.text('Horário do envio'), findsOneWidget);
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(selected, const TimeOfDay(hour: 23, minute: 59));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    },
  );

  testWidgets('numeric entry validates limits and accepts midnight', (
    tester,
  ) async {
    TimeOfDay? selected;
    await open(tester, (time) => selected = time);
    await tester.tap(find.byTooltip('Digitar horário'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '24');
    await tester.enterText(find.byType(TextFormField).last, '60');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('Use 00 a 23'), findsOneWidget);
    expect(find.text('Use 00 a 59'), findsOneWidget);
    expect(find.byType(ScheduleTimePicker), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '00');
    await tester.enterText(find.byType(TextFormField).last, '00');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(selected, const TimeOfDay(hour: 0, minute: 0));
  });

  testWidgets(
    'switching back to wheels preserves typed time on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TimeOfDay? selected;
      await open(tester, (time) => selected = time);
      await tester.tap(find.byTooltip('Digitar horário'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '09');
      await tester.enterText(find.byType(TextFormField).last, '18');
      await tester.tap(find.byTooltip('Selecionar rolando'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(selected, const TimeOfDay(hour: 9, minute: 18));
      expect(tester.takeException(), isNull);
    },
  );
}
