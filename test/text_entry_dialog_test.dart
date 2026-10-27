import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/text_entry_dialog.dart';

void main() {
  testWidgets('saving a text dialog safely finishes its closing animation', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const TextEntryDialog(
                    title: 'Editar',
                    initialText: 'Texto',
                    maxLength: 1000,
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alterado');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(result, 'Alterado');
    expect(tester.takeException(), isNull);
  });
}
