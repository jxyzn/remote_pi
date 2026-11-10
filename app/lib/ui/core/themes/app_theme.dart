import 'package:flutter/material.dart';

import 'package:app/ui/core/themes/app_colors.dart';
import 'package:app/ui/core/themes/app_font_scale.dart';
import 'package:app/ui/core/themes/app_typography.dart';

/// Builds the [ThemeData] for a given [AppColors] / [AppTypography] pair.
///
/// Wires the semantic tokens into both the standard Material [ColorScheme]
/// (so framework widgets — dialogs, switches, progress indicators, text
/// fields — render with the PICO-8 / TIC-80 aesthetic per brightness) AND
/// attaches [AppColors] / [AppTypography] as theme extensions (so app widgets
/// read `context.colors.*` / `context.typo.*`).
ThemeData _buildTheme({
  required Brightness brightness,
  required AppColors colors,
  required AppTypography typo,
}) {
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: colors.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      surface: colors.surface,
      onSurface: colors.text,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.highlight,
      onSecondary: colors.onAccent,
      error: colors.error,
      onError: colors.onAccent,
      outline: colors.border,
    ),
    dividerColor: colors.border,
    extensions: <ThemeExtension<dynamic>>[colors, typo],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 48,
      titleTextStyle: typo.display,
    ),
    textTheme: TextTheme(
      displayLarge: typo.display.copyWith(fontSize: 32, color: colors.text),
      displayMedium: typo.display.copyWith(fontSize: 28, color: colors.text),
      displaySmall: typo.display.copyWith(fontSize: 24, color: colors.text),
      headlineLarge: typo.headlineLarge,
      headlineMedium: typo.headlineMedium,
      headlineSmall: typo.headlineSmall,
      titleLarge: typo.display,
      titleMedium: typo.sansTitle,
      titleSmall: typo.sansTitle.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      bodyLarge: typo.sansBody,
      bodyMedium: typo.sansBody,
      bodySmall: typo.sansSmall,
      labelLarge: typo.sansBody.copyWith(fontWeight: FontWeight.w600),
      labelMedium: typo.sansSmall.copyWith(fontWeight: FontWeight.w600),
      labelSmall: typo.badge,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border, width: 2),
      ),
      titleTextStyle: typo.sansTitle.copyWith(fontSize: 16),
      contentTextStyle: typo.sansBody.copyWith(color: colors.muted2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        textStyle: typo.sansTitle.copyWith(fontSize: 13.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border, width: 1.5),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        backgroundColor: colors.surface,
        textStyle: typo.sansBody.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: BorderSide(color: colors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          typo.sansSmall.copyWith(fontWeight: FontWeight.w700),
        ),
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(
          BorderSide(color: colors.border, width: 1.5),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.surface2,
      contentTextStyle: typo.sansBody.copyWith(color: colors.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border, width: 1.5),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputFill,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.accent, width: 2.0),
      ),
      hintStyle: typo.sansBody.copyWith(
        color: colors.muted,
        fontSize: 13.5,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    ),
  );
}

/// Dark theme — Classic dark or PICO-8 Vibrant Console Indigo.
ThemeData buildDarkTheme({
  AppThemePreset preset = AppThemePreset.classic,
  AppRetroFontMode fontMode = AppRetroFontMode.arcade,
}) {
  final colors = AppColors.forPreset(preset, Brightness.dark);
  return _buildTheme(
    brightness: Brightness.dark,
    colors: colors,
    typo: AppTypography.fromColors(
      colors,
      monoColor: colors.text,
      preset: preset,
      fontMode: fontMode,
    ),
  );
}

/// Light theme — Classic light or PICO-8 Bright Arcade.
ThemeData buildLightTheme({
  AppThemePreset preset = AppThemePreset.classic,
  AppRetroFontMode fontMode = AppRetroFontMode.arcade,
}) {
  final colors = AppColors.forPreset(preset, Brightness.light);
  return _buildTheme(
    brightness: Brightness.light,
    colors: colors,
    typo: AppTypography.fromColors(
      colors,
      monoColor: colors.text,
      preset: preset,
      fontMode: fontMode,
    ),
  );
}
