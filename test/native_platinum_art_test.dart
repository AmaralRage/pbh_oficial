import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/widgets/native_platinum_art.dart';
import 'package:pbh_oficial/widgets/supreme_seal_art_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> preload(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() async {
      await NativePlatinumArt.preload();
      await NativePlatinumArt.preloadRuby();
    });
  }

  NativePlatinumPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<NativePlatinumPainter>()
      .single;

  testWidgets(
    'native platinum uses original layers at miniature and detail sizes without a WebView',
    (tester) async {
      await preload(tester);
      for (final badge in [
        ProfileAchievement.platinum,
        ProfileAchievement.knowledgePlatinum,
      ]) {
        for (final size in [30.0, 160.0, 300.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SupremeSealArt(size: size, achievement: badge),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
          expect(find.byType(NativePlatinumArt), findsOneWidget);
          expect(painter(tester).ruby, badge.isRuby);
          expect(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == 'WebViewWidget',
            ),
            findsNothing,
          );
          expect(
            tester.getSize(find.byType(NativePlatinumArt)),
            Size.square(size),
          );
          await tester.pump(const Duration(milliseconds: 250));
          expect(tester.takeException(), isNull);
        }
      }
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: const NativePlatinumArt(size: 300),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'build/native-platinum-preview.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unlock shares one timeline, pauses in background and never replays its start sound',
    (tester) async {
      await preload(tester);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: NativePlatinumArt(
              size: 300,
              celebrate: true,
              onAnimationStarted: () => starts++,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(starts, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(starts, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(starts, 1);
      await tester.pump(const Duration(milliseconds: 400));
      final before = painter(tester).revealSeconds;
      expect(before, inInclusiveRange(.9, 1.2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(painter(tester).revealSeconds, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(seconds: 5));
      expect(painter(tester).revealSeconds, 5.2);
      await tester.pump(const Duration(seconds: 15));
      expect(starts, 1);
      expect(painter(tester).revealSeconds, 5.2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reduced motion and covered routes stop both native animation clocks',
    (tester) async {
      await preload(tester);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: NativePlatinumArt(
                size: 160,
                celebrate: true,
                onAnimationStarted: () => starts++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(painter(tester).revealSeconds, 5.2);
      expect(starts, 0);
      expect(tester.binding.transientCallbackCount, 0);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Center(child: NativePlatinumArt(size: 160)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outra tela')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
