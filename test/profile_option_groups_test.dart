import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_style.dart';
import 'package:pbh_oficial/widgets/profile_option_groups.dart';

void main() {
  testWidgets('groups rewards without disclosing ungranted supreme crown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileOptionGroups(
              options: ProfileStyle.frameEffects,
              founder: false,
              completed: 0,
              earned: {},
              builder: (options) =>
                  Wrap(children: [for (final o in options) Text(o.label)]),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Opções disponíveis'), findsOneWidget);
    expect(find.text('Recompensas de jornadas'), findsOneWidget);
    expect(find.text('Exclusivas'), findsOneWidget);
    expect(find.text('Coroa Suprema'), findsNothing);
    expect(find.text('Órbita de luz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
