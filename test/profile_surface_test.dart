import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_style.dart';
import 'package:pbh_oficial/widgets/profile_background.dart';
import 'package:pbh_oficial/widgets/profile_surface.dart';

void main() {
  test('glass preference survives metadata, copying and validation', () {
    const original = ProfileStyle(glassCards: true);
    final saved = ProfileStyle.fromMetadata({
      'profile_style': original.toMap(),
    }).validated(founder: false, completed: 0, earned: []);
    expect(saved.glassCards, isTrue);
    expect(saved.copyWith(cover: 'night').glassCards, isTrue);
    expect(saved.copyWith(glassCards: false).glassCards, isFalse);
    expect(
      ProfileStyle.fromMetadata({
        'profile_style': {'glass_cards': 'true'},
      }).glassCards,
      isFalse,
    );
  });
  testWidgets('only the card decoration changes; child content stays opaque', (
    tester,
  ) async {
    Widget page(bool glass) => MaterialApp(
      home: Scaffold(
        body: ProfileBackground(
          style: ProfileStyle(glassCards: glass),
          child: ProfileSurface(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const SizedBox(
              width: 180,
              height: 100,
              child: Text('Troféu nítido'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpWidget(page(true));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.text('Troféu nítido'), findsOneWidget);
    final card = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((w) => w.decoration is BoxDecoration);
    expect((card.decoration as BoxDecoration).color!.a, closeTo(.52, .01));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
