import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/widgets/profile_achievement_picker.dart';

void main() {
  testWidgets(
    'static achievement picker stays bounded on mobile with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final badges = List.generate(
        30,
        (i) => ProfileAchievement(
          id: 'test_$i',
          title: 'Conquista de dedica\u00e7\u00e3o $i',
          description: 'Example',
          icon: Icons.shield,
        ),
      );
      var selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 740),
                textScaler: TextScaler.linear(1.3),
              ),
              child: StatefulBuilder(
                builder: (context, update) => SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ProfileAchievementPicker(
                      earned: badges,
                      selected: selected,
                      onChanged: (ids) => update(() => selected = ids),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conquista de dedica\u00e7\u00e3o 29'), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Conquista de dedica\u00e7\u00e3o 0'));
      await tester.pumpAndSettle();
      expect(selected, ['test_0']);
      expect(tester.takeException(), isNull);
    },
  );
}
