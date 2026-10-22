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
    PbhPalette('pbh', 'PBH Original', Color(0xFF0B0B0B), Color(0xFFFF5A1F)),
    PbhPalette('midnight', 'Meia-noite', Color(0xFF090D16), Color(0xFF566A88)),
    PbhPalette(
      'starlight',
      'Azul estelar',
      Color(0xFF081425),
      Color(0xFF2469C7),
    ),
    PbhPalette(
      'cosmic',
      'Vermelho cósmico',
      Color(0xFF1C0B15),
      Color(0xFFBB355B),
    ),
    PbhPalette(
      'galactic',
      'Roxo galáctico',
      Color(0xFF140D25),
      Color(0xFF7951BF),
    ),
    PbhPalette('nova', 'Rosa nova', Color(0xFF200D1C), Color(0xFFAB3C79)),
    PbhPalette('emerald', 'Esmeralda', Color(0xFF091B18), Color(0xFF246E60)),
    PbhPalette(
      'founder',
      'Legado do fundador',
      Color(0xFF100D24),
      Color(0xFF624CBC),
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
  Color get border => tint(.19);
  Color get borderSubtle => tint(.12);
  Color get orange => accent;
  Color get orangeLight => Color.lerp(accent, Colors.white, .4)!;
  Color get orangeDim => accent.withValues(alpha: .2);
  Color get textPrimary => Colors.white;
  Color get textSecondary => const Color(0xFFBFC3CD);
  Color get textTertiary => const Color(0xFFA6ADB9);
  Color get success => accent;
  Color get inactive => tint(.2);
  Color get onAccent =>
      accent.computeLuminance() > .18 ? Colors.black : Colors.white;
  List<Color> get featuredGradient => [
    Color.lerp(surface, accent, .13)!,
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
