import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/mobile_app_viewport.dart';

void main() {
  testWidgets('reduced effects preserve the system accessibility preference', (
    tester,
  ) async {
    for (final system in [true, false]) {
      for (final app in [true, false]) {
        bool? reduced;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: system),
              child: MobileAppViewport(reduceEffects: app, child: child!),
            ),
            home: Builder(
              builder: (context) {
                reduced = MediaQuery.disableAnimationsOf(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(reduced, system || app);
      }
    }
  });
  for (final width in [390.0, 1920.0]) {
    testWidgets('viewport centers and reports its actual width on $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Size? reportedSize;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MobileAppViewport(child: child!),
          home: Builder(
            builder: (context) {
              reportedSize = MediaQuery.sizeOf(context);
              return const Scaffold(body: Text('App'));
            },
          ),
        ),
      );
      final expectedWidth = width > 430 ? 430.0 : width;
      final rect = tester.getRect(find.byType(Scaffold));
      expect(rect.width, expectedWidth);
      expect(rect.left, (width - expectedWidth) / 2);
      expect(rect.height, 900);
      expect(reportedSize, Size(expectedWidth, 900));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('drawer, pushed route and modal stay inside the desktop column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MobileAppViewport(child: child!),
        home: Scaffold(
          appBar: AppBar(),
          drawer: const Drawer(child: Text('Menu')),
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Abrir tela'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        child: const Text('Abrir janela'),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => const SizedBox(
                            key: Key('sheet'),
                            height: 200,
                            width: double.infinity,
                            child: Text('Janela'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final frame = tester.getRect(find.byType(Scaffold));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    final drawer = tester.getRect(find.byType(Drawer));
    expect(drawer.left, frame.left);
    expect(drawer.right, lessThanOrEqualTo(frame.right));
    Navigator.of(tester.element(find.text('Menu'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir tela'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(Scaffold)).width, 430);
    await tester.tap(find.text('Abrir janela'));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byKey(const Key('sheet')));
    expect(sheet.left, frame.left);
    expect(sheet.right, frame.right);
    expect(tester.takeException(), isNull);
  });
}
