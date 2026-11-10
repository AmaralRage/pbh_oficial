import 'package:flutter/material.dart';

@immutable
class PbhPalette extends ThemeExtension<PbhPalette> {
  const PbhPalette(
    this.id,
    this.name,
    this.base,
    this.accent, {
    this.founderOnly = false,
  });
  final String id;
  final String name;
  final Color base;
  final Color accent;
  final bool founderOnly;
  static const catalog = [
    PbhPalette('pbh', 'PBH Original', Color(0xFF0B0B0B), Color(0xFFFF6B2C)),
    PbhPalette('midnight', 'Meia-noite', Color(0xFF080F20), Color(0xFFA5C2FF)),
    PbhPalette(
      'starlight',
      'Azul estelar',
      Color(0xFF081425),
      Color(0xFF8DBEFF),
    ),
    PbhPalette(
      'cosmic',
      'Vermelho cósmico',
      Color(0xFF1C0808),
      Color(0xFFFF625C),
    ),
    PbhPalette(
      'galactic',
      'Roxo galáctico',
      Color(0xFF140D25),
      Color(0xFFD0ADFF),
    ),
    PbhPalette('nova', 'Rosa nova', Color(0xFF200B1D), Color(0xFFFF99D2)),
    PbhPalette('emerald', 'Esmeralda', Color(0xFF071D18), Color(0xFF69E8CB)),
    PbhPalette(
      'founder',
      'Legado do fundador',
      Color(0xFF0B0B0B),
      Color(0xFFB57AFF),
      founderOnly: true,
    ),
    PbhPalette(
      'midnight_classic',
      'Meia-noite · Clássico',
      Color(0xFF0B0B0B),
      Color(0xFF8BAFFF),
    ),
    PbhPalette(
      'graphite_classic',
      'Grafite · Clássico',
      Color(0xFF0B0B0B),
      Color(0xFF9498A0),
    ),
    PbhPalette(
      'starlight_classic',
      'Azul estelar · Clássico',
      Color(0xFF0B0B0B),
      Color(0xFF62AEFF),
    ),
    PbhPalette(
      'cosmic_classic',
      'Vermelho cósmico · Clássico',
      Color(0xFF0B0B0B),
      Color(0xFFFF625C),
    ),
    PbhPalette(
      'galactic_classic',
      'Roxo galáctico · Clássico',
      Color(0xFF0B0B0B),
      Color(0xFFBE87FF),
    ),
    PbhPalette(
      'nova_classic',
      'Rosa nova · Clássico',
      Color(0xFF0B0B0B),
      Color(0xFFFF6FBD),
    ),
    PbhPalette(
      'emerald_classic',
      'Esmeralda · Clássico',
      Color(0xFF0B0B0B),
      Color(0xFF32D9AC),
    ),
  ];
  static PbhPalette resolve(String? id, {bool founder = false}) =>
      catalog.firstWhere(
        (p) => p.id == id && (!p.founderOnly || founder),
        orElse: () => catalog.first,
      );
  bool get _originalSurfaces =>
      id == 'pbh' || id == 'founder' || id.endsWith('_classic');
  Color get background => base;
  Color tint(double amount) => Color.lerp(base, Colors.white, amount)!;
  Color get backgroundElevated =>
      _originalSurfaces ? const Color(0xFF111111) : tint(.025);
  Color get surface => _originalSurfaces ? const Color(0xFF161616) : tint(.045);
  Color get surfaceElevated =>
      _originalSurfaces ? const Color(0xFF1C1C1C) : tint(.075);
  Color get surfacePressed => tint(.11);
  Color get border => tint(_originalSurfaces ? .19 : .26);
  Color get borderSubtle => tint(_originalSurfaces ? .12 : .19);
  Color get orange => accent;
  Color get orangeLight => Color.lerp(accent, Colors.white, .4)!;
  Color get orangeDim => accent.withValues(alpha: _originalSurfaces ? .2 : .14);
  Color get textPrimary => Colors.white;
  Color get textSecondary =>
      _originalSurfaces ? const Color(0xFFCDD4E0) : const Color(0xFFE0E6EF);
  Color get textTertiary =>
      _originalSurfaces ? const Color(0xFFAFBBD0) : const Color(0xFFC5CEDD);
  Color get success => accent;
  Color get inactive => tint(.2);
  Color get onAccent =>
      accent.computeLuminance() > .18 ? Colors.black : Colors.white;
  List<Color> get featuredGradient => [
    Color.lerp(surface, accent, .14)!,
    backgroundElevated,
  ];
  @override
  PbhPalette copyWith({
    String? id,
    String? name,
    Color? base,
    Color? accent,
    bool? founderOnly,
  }) => PbhPalette(
    id ?? this.id,
    name ?? this.name,
    base ?? this.base,
    accent ?? this.accent,
    founderOnly: founderOnly ?? this.founderOnly,
  );
  @override
  PbhPalette lerp(covariant PbhPalette? other, double t) => other == null
      ? this
      : PbhPalette(
          other.id,
          other.name,
          Color.lerp(base, other.base, t)!,
          Color.lerp(accent, other.accent, t)!,
          founderOnly: other.founderOnly,
        );
}

extension PbhThemeContext on BuildContext {
  PbhPalette get pbhColors =>
      Theme.of(this).extension<PbhPalette>() ?? PbhPalette.catalog.first;
}
