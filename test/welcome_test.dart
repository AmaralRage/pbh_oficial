import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:pbh_oficial/services/welcome_preferences.dart';
import 'package:pbh_oficial/screens/welcome_screen.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'only explicitly new accounts receive introduction, independently per account',
    () async {
      final preferences = WelcomePreferences();
      expect(
        await preferences.shouldShow('existing', newlyCreated: false),
        false,
      );
      expect(await preferences.shouldShow('', newlyCreated: false), false);
      expect(await preferences.shouldShow('new-a', newlyCreated: true), true);
      await preferences.complete('new-a');
      expect(
        await WelcomePreferences().shouldShow('new-a', newlyCreated: true),
        false,
      );
      expect(await preferences.shouldShow('new-b', newlyCreated: true), true);
      expect(
        await preferences.shouldShow('existing', newlyCreated: false),
        false,
      );
    },
  );
  testWidgets(
    'new member chooses a focus and can finish only once on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final choices = <WelcomeFocus>[];
      await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(onFinish: choices.add)),
      );
      await tester.scrollUntilVisible(
        find.text('Escolher meu primeiro passo'),
        200,
      );
      await tester.tap(find.text('Escolher meu primeiro passo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Aprender algo novo'), -150);
      await tester.tap(find.text('Aprender algo novo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ir para meu primeiro passo'),
        200,
      );
      await tester.tap(find.text('Ir para meu primeiro passo'));
      await tester.pump();
      expect(choices, [WelcomeFocus.learning]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('introduction can be skipped without choosing a goal', (
    tester,
  ) async {
    final choices = <WelcomeFocus>[];
    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(onFinish: choices.add)),
    );
    await tester.tap(find.text('Pular'));
    await tester.pump();
    expect(choices, [WelcomeFocus.explore]);
  });
}
