import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/deferred_seal_art.dart';

void main() {
  testWidgets('creates the animated art only after the dialog transition', (
    tester,
  ) async {
    var creations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showGeneralDialog<void>(
                  context: context,
                  transitionDuration: const Duration(milliseconds: 380),
                  pageBuilder: (_, __, ___) => Center(
                    child: DeferredSealArt(
                      preview: const Text('preview'),
                      builder: () {
                        creations++;
                        return const Text('animated art');
                      },
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(creations, 0);
    expect(find.text('preview'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(creations, 1);
    expect(find.text('animated art'), findsOneWidget);
  });

  testWidgets('closing during expansion does not initialize the art', (
    tester,
  ) async {
    var creations = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox()),
    );
    showGeneralDialog<void>(
      context: navigator.currentContext!,
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => DeferredSealArt(
        preview: const SizedBox(),
        builder: () {
          creations++;
          return const SizedBox();
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(creations, 0);
  });
}
