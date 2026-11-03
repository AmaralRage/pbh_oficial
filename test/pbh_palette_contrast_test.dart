import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/core/theme/pbh_palette.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}
void main() {
  test('original palette keeps its existing colors', () {
    final p = PbhPalette.catalog.first;
    expect(p.accent, const Color(0xFFFF6B2C));
    expect(p.surface, const Color(0xFF161616));
    expect(p.textSecondary, const Color(0xFFCDD4E0));
    expect(p.textTertiary, const Color(0xFFAFBBD0));
    expect(p.orangeDim, p.accent.withValues(alpha: .2));
  });
  for (final p in PbhPalette.catalog.skip(1)) {
    test('readable text and actions on ${p.id} surfaces', () {
      final surfaces = [p.background, p.surface, p.surfaceElevated, p.surfacePressed,
        Color.alphaBlend(p.orangeDim, p.surface), ...p.featuredGradient];
      for (final surface in surfaces) {
        for (final ink in [p.textPrimary, p.textSecondary, p.textTertiary, p.accent]) {
          expect(contrast(ink, surface), greaterThanOrEqualTo(4.5), reason: '${p.id} text contrast');
        }
      }
      expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
    });
  }
}
