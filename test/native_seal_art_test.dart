import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/widgets/native_seal_art.dart';

void main() {
  Widget app({bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: const Center(
        child: NativeSealArt(
          size: 300,
          achievement: ProfileAchievement.dedication2000,
        ),
      ),
    ),
  );

  testWidgets('animates the cached artwork without rebuilding the image', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    final image = tester.widget<Image>(find.byType(Image));
    final start = tester
        .widget<Transform>(find.byType(Transform).first)
        .transform;
    await tester.pump(const Duration(milliseconds: 1500));
    expect(identical(image, tester.widget<Image>(find.byType(Image))), isTrue);
    expect(
      tester.widget<Transform>(find.byType(Transform).first).transform,
      isNot(start),
    );
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(UiKitView), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion keeps the trophy still without an active ticker',
    (tester) async {
      await tester.pumpWidget(app(reduced: true));
      final start = tester
          .widget<Transform>(find.byType(Transform).first)
          .transform;
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Transform>(find.byType(Transform).first).transform,
        start,
      );
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
