import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/profile_cover_media.dart';
import 'package:pbh_oficial/widgets/profile_ornament.dart';
import 'package:pbh_oficial/widgets/html_cover_renderer.dart';

void main() {
  testWidgets(
    'visible HTML starts playing and replacement inherits playback state',
    (tester) async {
      final first = Uint8List.fromList(
        utf8.encode(
          '<!doctype html><html><body><div class="stage">First</div></body></html>',
        ),
      );
      final second = Uint8List.fromList(
        utf8.encode(
          '<!doctype html><html><body><div class="stage">Second</div></body></html>',
        ),
      );
      Widget card(Uint8List bytes, {bool active = true}) => MaterialApp(
        home: TickerMode(
          enabled: active,
          child: Center(
            child: SizedBox(
              width: 360,
              height: 270,
              child: ProfileCoverMedia(bytes: bytes, communityAttachment: true),
            ),
          ),
        ),
      );
      await tester.pumpWidget(card(first));
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<HtmlCoverRenderer>(find.byType(HtmlCoverRenderer).first)
            .playing,
        true,
      );
      await tester.pumpWidget(card(second));
      await tester.pump();
      final renderer = tester.widget<HtmlCoverRenderer>(
        find.byType(HtmlCoverRenderer).first,
      );
      expect(renderer.playing, true);
      expect(renderer.document, contains("let state='pbh-cover:play'"));
      await tester.pumpWidget(card(second, active: false));
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<HtmlCoverRenderer>(find.byType(HtmlCoverRenderer).first)
            .playing,
        false,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'GIF renders a still frame with reduced motion and retains cover effects',
    (tester) async {
      final gif = base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      );
      Widget card(bool reduced, Uint8List bytes) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: SizedBox(
              width: 390,
              height: 132,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProfileCoverMedia(bytes: bytes),
                  const ProfileOrnament(color: Colors.blue, effect: 'rain'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(card(true, gif));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      final still = tester.widget<RawImage>(
        find
            .descendant(
              of: find.byType(ProfileCoverMedia),
              matching: find.byType(RawImage),
            )
            .first,
      );
      expect(still.image, isNotNull);
      expect(find.byType(ProfileOrnament), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(card(false, gif));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.descendant(
          of: find.byType(ProfileCoverMedia),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      final html = Uint8List.fromList(
        utf8.encode(
          '<!doctype html><html><body><div data-pbh-cover>Arte</div></body></html>',
        ),
      );
      await tester.pumpWidget(card(true, html));
      await tester.pump();
      expect(find.byType(ProfileOrnament), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
