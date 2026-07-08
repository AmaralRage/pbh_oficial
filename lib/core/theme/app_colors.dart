import 'package:flutter/material.dart';

/// Paleta oficial do Design System PBH Oficial.
/// Extraída fielmente da referência visual: dark mode profundo,
/// cards em preto fosco e um único acento — laranja intenso.
/// Não introduzir outras cores predominantes.
class AppColors {
  AppColors._();

  // Fundo
  static const Color background = Color(0xFF0B0B0B);
  static const Color backgroundElevated = Color(0xFF111111);

  // Superfícies / Cards
  static const Color surface = Color(0xFF161616);
  static const Color surfaceElevated = Color(0xFF1C1C1C);
  static const Color surfacePressed = Color(0xFF212121);

  // Bordas discretas
  static const Color border = Color(0xFF2A2A2A);
  static const Color borderSubtle = Color(0xFF1F1F1F);

  // Acento — laranja intenso (cor de marca)
  static const Color orange = Color(0xFFFF5A1F);
  static const Color orangeLight = Color(0xFFFF8A4D);
  static const Color orangeDim = Color(0x33FF5A1F); // 20% opacidade, para fundos de badge

  // Texto
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA3A3A3);
  static const Color textTertiary = Color(0xFF6E6E6E);

  // Estados
  static const Color success = orange; // no design de referência, check = laranja
  static const Color inactive = Color(0xFF3A3A3A);

  // Gradiente sutil usado em cards em destaque (ex: card de desafio ativo)
  static const List<Color> featuredGradient = [
    Color(0xFF1A1A1A),
    Color(0xFF0D0D0D),
  ];
}
