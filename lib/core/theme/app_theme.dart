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
        onSurfaceVariant: palette.textSecondary,
        primaryContainer: Color.alphaBlend(palette.orangeDim, palette.surface),
        onPrimaryContainer: palette.textPrimary,
        secondaryContainer: Color.alphaBlend(
          palette.orangeDim,
          palette.surface,
        ),
        onSecondaryContainer: palette.textPrimary,
        outline: palette.textTertiary,
        outlineVariant: palette.border,
      ),
      splashColor: palette.orangeDim,
      highlightColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accent.withValues(alpha: .35),
        selectionHandleColor: palette.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.backgroundElevated,
        labelStyle: TextStyle(color: palette.textSecondary),
        floatingLabelStyle: TextStyle(color: palette.accent),
        hintStyle: TextStyle(color: palette.textTertiary),
        helperStyle: TextStyle(color: palette.textSecondary),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: palette.textTertiary.withValues(alpha: .65),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.accent,
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? palette.onAccent
                : palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        secondaryLabelStyle: TextStyle(
          color: palette.onAccent,
          fontWeight: FontWeight.w700,
        ),
        checkmarkColor: palette.onAccent,
        side: BorderSide(color: palette.border),
      ),
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
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: AppTextStyles.button,
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(64, 56),
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
