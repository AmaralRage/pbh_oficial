import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Hierarquia tipográfica do PBH Oficial.
/// Sans-serif moderna, peso forte em títulos, muito espaçamento entre
/// elementos, hierarquia clara — como na referência (ex: "Bom dia, guerreiro.").
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.manrope(color: AppColors.textPrimary);

  // Título de tela / hero (ex.: "Fundamentos do Homem de Valor.")
  static TextStyle get displayLarge => _base.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: 0,
      );

  // Título de seção (ex.: "Bom dia, guerreiro.")
  static TextStyle get headline => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: 0,
      );

  // Título de card grande (ex.: "30 Dias de Disciplina")
  static TextStyle get titleLarge => _base.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  // Título de card médio
  static TextStyle get titleMedium => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );

  // Corpo de texto padrão
  static TextStyle get body => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // Texto secundário pequeno (ex.: "Seja intencional em cada escolha.")
  static TextStyle get bodySmall => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // Rótulos / eyebrow (ex.: "PROGRAMA", "DESAFIO ATUAL")
  static TextStyle get eyebrow => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.orange,
        letterSpacing: 1.1,
      );

  // Números grandes de estatística (ex.: "81%", "23")
  static TextStyle get statNumber => _base.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.0,
      );

  static TextStyle get statLabel => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        height: 1.3,
      );

  // Botões
  static TextStyle get button => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      );

  // Nav bar inferior
  static TextStyle get navLabel => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      );

  static TextStyle get navLabelActive => navLabel.copyWith(
        color: AppColors.orange,
        fontWeight: FontWeight.w700,
      );

  // Chips / tags
  static TextStyle get chip => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle get chipActive => chip.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      );
}
