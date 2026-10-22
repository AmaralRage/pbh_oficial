import 'package:flutter/material.dart';
import 'pbh_palette.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => forPalette(PbhPalette.catalog.first);
  static ThemeData forPalette(PbhPalette palette) {
    return ThemeData(
      useMaterial3: true,
      extensions: [palette],
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.background,
      fontFamily: AppTextStyles.body.fontFamily,
      colorScheme: ColorScheme.dark(
        primary: palette.orange,
        secondary: palette.orange,
        surface: palette.surface,
        onPrimary: palette.onAccent,
        onSecondary: palette.onAccent,
        onSurface: palette.textPrimary,
      ),
      splashColor: palette.orangeDim,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.displayLarge,
        headlineMedium: AppTextStyles.headline,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.button,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.orange,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.inactive,
          minimumSize: Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: AppTextStyles.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: Size(64, 56),
          side: BorderSide(color: palette.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
