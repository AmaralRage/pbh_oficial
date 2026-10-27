import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_style.dart';
import 'package:pbh_oficial/widgets/profile_effect_picker.dart';

void main() {
  testWidgets(
    'category browsing preserves selection and keeps none available',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileEffectPicker(
              options: ProfileStyle.coverEffects,
              selected: 'christmas',
              optionsBuilder: (options) =>
                  Wrap(children: [for (final o in options) Text(o.label)]),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Natureza'));
      await tester.pump();
      expect(find.text('Chuva'), findsOneWidget);
      expect(find.text('Sem animação'), findsOneWidget);
      expect(find.text('Natal'), findsNothing);
      expect(find.text('Selecionada: Natal'), findsOneWidget);
      await tester.tap(find.text('Celebrações'));
      await tester.pump();
      expect(find.text('Natal'), findsOneWidget);
      expect(find.text('Chuva'), findsNothing);
    },
  );
}
