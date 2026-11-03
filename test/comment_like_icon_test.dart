import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/comment_like_icon.dart';

void main() {
  Widget icon(bool liked, {bool reducedMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Center(
        child: CommentLikeIcon(liked: liked, color: Colors.orange),
      ),
    ),
  );
  testWidgets('like bounces once and returns to idle; unlike stays still', (
    tester,
  ) async {
    await tester.pumpWidget(icon(false));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(icon(true));
    await tester.pump(const Duration(milliseconds: 120));
    final transforms = tester.widgetList<Transform>(find.byType(Transform));
    expect(transforms.any((t) => t.transform.storage[0] > 1.1), isTrue);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(icon(false));
    expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });
  testWidgets('existing likes and reduced motion do not animate', (
    tester,
  ) async {
    await tester.pumpWidget(icon(true));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(icon(false, reducedMotion: true));
    await tester.pumpWidget(icon(true, reducedMotion: true));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
