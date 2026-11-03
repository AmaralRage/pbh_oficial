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
      Color(0xFF1C0B15),
      Color(0xFFFF9AB2),
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
      Color(0xFF100D24),
      Color(0xFFC5ADFF),
      founderOnly: true,
    ),
  ];
  static PbhPalette resolve(String? id, {bool founder = false}) =>
      catalog.firstWhere(
        (p) => p.id == id && (!p.founderOnly || founder),
        orElse: () => catalog.first,
      );
  Color get background => base;
  Color tint(double amount) => Color.lerp(base, Colors.white, amount)!;
  Color get backgroundElevated =>
      id == 'pbh' ? const Color(0xFF111111) : tint(.025);
  Color get surface => id == 'pbh' ? const Color(0xFF161616) : tint(.045);
  Color get surfaceElevated =>
      id == 'pbh' ? const Color(0xFF1C1C1C) : tint(.075);
  Color get surfacePressed => tint(.11);
  Color get border => tint(id == 'pbh' ? .19 : .26);
  Color get borderSubtle => tint(id == 'pbh' ? .12 : .19);
  Color get orange => accent;
  Color get orangeLight => Color.lerp(accent, Colors.white, .4)!;
  Color get orangeDim => accent.withValues(alpha: id == 'pbh' ? .2 : .14);
  Color get textPrimary => Colors.white;
  Color get textSecondary =>
      id == 'pbh' ? const Color(0xFFCDD4E0) : const Color(0xFFE0E6EF);
  Color get textTertiary =>
      id == 'pbh' ? const Color(0xFFAFBBD0) : const Color(0xFFC5CEDD);
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
