import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:pbh_oficial/core/theme/pbh_palette.dart';
import 'package:pbh_oficial/widgets/profile_surface.dart';
import 'package:pbh_oficial/widgets/stat_card.dart';

class _FontAssets extends AssetManifest {
  @override
  List<String> listAssets() => ['Manrope-Regular.ttf'];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  test(
    'reinforced cards maintain contrast over white backgrounds in every theme',
    () {
      for (final p in PbhPalette.catalog) {
        for (final color in [
          p.surface,
          Color.alphaBlend(p.accent.withValues(alpha: .09), p.surface),
        ]) {
          final surface = Color.alphaBlend(
            color.withValues(alpha: .96),
            Colors.white,
          );
          for (final ink in [
            p.textPrimary,
            p.textSecondary,
            p.textTertiary,
            p.accent,
          ]) {
            expect(
              contrast(ink, surface),
              greaterThanOrEqualTo(4.5),
              reason: p.id,
            );
          }
        }
      }
    },
  );
  testWidgets('system high contrast reinforces only the glass fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: ProfileSurfaceScope(
            enabled: true,
            child: ProfileSurface(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const SizedBox(
                width: 180,
                height: 100,
                child: Text('Conteúdo nítido'),
              ),
            ),
          ),
        ),
      ),
    );
    final card = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((w) => w.decoration is BoxDecoration);
    expect((card.decoration as BoxDecoration).color!.a, closeTo(.96, .01));
    expect(find.byType(Opacity), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
  });
  testWidgets(
    'profile statistics stay readable at double text size on a narrow phone',
    (tester) async {
      fonts.assetManifest = _FontAssets();
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          if (utf8.decode(message!.buffer.asUint8List()) ==
              'Manrope-Regular.ttf')
            return ByteData(0);
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(2),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 280,
                  child: ProfileStats(
                    children: [
                      StatCard(
                        icon: Icons.flag,
                        value: '2137',
                        label: 'Dias de dedicação',
                      ),
                      SizedBox(width: 12),
                      StatCard(
                        icon: Icons.emoji_events,
                        value: '62',
                        label: 'Desafios concluídos',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('2137'), findsOneWidget);
      expect(find.text('62'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('62')).dy,
        greaterThan(tester.getTopLeft(find.text('2137')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
