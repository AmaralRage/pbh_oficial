import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/profile_ornament.dart';

void main() {
  testWidgets(
    'decorations pause when hidden, covered, offscreen or motion is reduced',
    (tester) async {
      final scroll = ScrollController();
      final navigator = GlobalKey<NavigatorState>();
      Widget app({bool enabled = true, bool reduced = false}) => MaterialApp(
        navigatorKey: navigator,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            disableAnimations: reduced,
          ),
          child: TickerMode(
            enabled: enabled,
            child: SingleChildScrollView(
              controller: scroll,
              child: const Column(
                children: [
                  SizedBox(
                    height: 132,
                    width: 320,
                    child: ProfileOrnament(color: Colors.amber, founder: true),
                  ),
                  SizedBox(height: 1600),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
      scroll.jumpTo(700);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      scroll.jumpTo(0);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(app(enabled: false));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(app(reduced: true));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(app());
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('avatar rim renders independently of the photo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 96,
            height: 96,
            child: ProfileOrnament(color: Colors.amber, frame: true),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(find.byType(IgnorePointer), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
