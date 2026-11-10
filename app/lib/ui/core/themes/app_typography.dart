import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:app/ui/core/themes/app_colors.dart';
import 'package:app/ui/core/themes/app_font_scale.dart';

/// Monospace font family — used strictly for code blocks, inline code,
/// terminal commands/diffs, file paths, URLs, timers, and cryptographic IDs.
const String kMonoFamily = 'JetBrains Mono';

/// Monospace fallback stack so code stays crisp even before runtime fonts load.
const List<String> kMonoFallback = <String>[
  'JetBrains Mono',
  'Menlo',
  'Monaco',
  'Courier',
  'monospace',
];

/// Proportional sans family for readable UI prose, chat messages, and controls.
const String? kSansFamily = null;

bool get _isFlutterTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Brand wordmark style — the "Remote Pi" marca.
///
/// Renders in `Inter` for [AppThemePreset.classic], or pixel-arcade
/// `Silkscreen` when [preset] is [AppThemePreset.pico8] and [fontMode] is
/// [AppRetroFontMode.arcade] (or geometric `Space Grotesk` when
/// [AppRetroFontMode.clean]).
TextStyle brandTextStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w700,
  Color? color,
  double? letterSpacing,
  double? height,
  AppThemePreset preset = AppThemePreset.classic,
  AppRetroFontMode fontMode = AppRetroFontMode.arcade,
}) {
  if (_isFlutterTest) {
    return TextStyle(
      fontFamily: kSansFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
  if (!preset.isPico8) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
  if (fontMode.isPixel) {
    return GoogleFonts.silkscreen(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? -0.3,
      height: height ?? 1.15,
    );
  }
  return GoogleFonts.spaceGrotesk(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing ?? -0.4,
    height: height ?? 1.15,
  );
}

/// Typographic styles for the app, themed per brightness and [AppRetroFontMode].
///
/// Design hierarchy:
/// - **Proportional sans** ([sansBody], [sansSmall], [sansTitle]) for chat
///   prose, session titles, settings, dialogs, and descriptions — maximizing
///   readability and horizontal screen efficiency.
/// - **Retro display / badge** ([display], [badge]) in pixel-arcade
///   (`Silkscreen`) or geometric sans (`Space Grotesk`) for console chrome,
///   section headers, filter pills, and status badges.
/// - **Monospace** ([mono], [monoSmall]) strictly for code, terminal commands,
///   diffs, file paths (`cwd`), URLs, timers, and cryptographic IDs.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  AppTypography({
    required this.mono,
    required this.monoSmall,
    required this.sansBody,
    TextStyle? sansSmall,
    TextStyle? sansTitle,
    TextStyle? display,
    TextStyle? badge,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
  }) : sansSmall =
           sansSmall ??
           sansBody.copyWith(fontSize: 12.0, height: 1.35),
       sansTitle =
           sansTitle ??
           sansBody.copyWith(
             fontSize: 15.0,
             fontWeight: FontWeight.w700,
             height: 1.25,
             letterSpacing: -0.2,
           ),
       display =
           display ??
           sansBody.copyWith(
             fontSize: 15.5,
             fontWeight: FontWeight.w700,
             height: 1.2,
           ),
       badge =
           badge ??
           monoSmall.copyWith(
             fontSize: 10.5,
             fontWeight: FontWeight.w700,
             letterSpacing: 0.4,
           ),
       headlineLarge =
           headlineLarge ??
           (sansTitle ?? sansBody).copyWith(
             fontSize: 20.0,
             fontWeight: FontWeight.w700,
             height: 1.3,
             letterSpacing: -0.2,
           ),
       headlineMedium =
           headlineMedium ??
           (sansTitle ?? sansBody).copyWith(
             fontSize: 17.0,
             fontWeight: FontWeight.w700,
             height: 1.3,
             letterSpacing: -0.2,
           ),
       headlineSmall =
           headlineSmall ??
           (sansTitle ?? sansBody).copyWith(
             fontSize: 15.0,
             fontWeight: FontWeight.w700,
             height: 1.3,
             letterSpacing: -0.1,
           );

  /// Primary monospace style (chat code blocks, terminal commands, paths).
  final TextStyle mono;

  /// Small monospace style (tokens, model slugs, short technical tags).
  final TextStyle monoSmall;

  /// Proportional sans body text (chat prose, user bubbles, inputs, dialogs).
  final TextStyle sansBody;

  /// Proportional small caption/subtitle text (timestamps, secondary labels).
  final TextStyle sansSmall;

  /// Proportional bold title text (session names, sheet headers, settings rows).
  final TextStyle sansTitle;

  /// Retro header/display style (`Silkscreen` in Arcade mode, `Space Grotesk`
  /// in Clean mode).
  final TextStyle display;

  /// Retro pill/badge/section header style (`Silkscreen` in Arcade mode,
  /// `Space Grotesk` in Clean mode).
  final TextStyle badge;

  /// Top-level heading style (Markdown H1).
  final TextStyle headlineLarge;

  /// Section heading style (Markdown H2, e.g. "Suggested additions...").
  final TextStyle headlineMedium;

  /// Subsection heading style (Markdown H3).
  final TextStyle headlineSmall;

  /// Build the style set for a given color palette, [preset], and [fontMode].
  factory AppTypography.fromColors(
    AppColors c, {
    required Color monoColor,
    AppThemePreset preset = AppThemePreset.classic,
    AppRetroFontMode fontMode = AppRetroFontMode.arcade,
  }) {
    final usePixel = preset.isPico8 && fontMode.isPixel;
    final baseSans = _isFlutterTest
        ? const TextStyle(fontFamily: kSansFamily)
        : GoogleFonts.plusJakartaSans(color: c.text);
    final baseMono = _isFlutterTest
        ? const TextStyle(
            fontFamily: kMonoFamily,
            fontFamilyFallback: kMonoFallback,
          )
        : GoogleFonts.jetBrainsMono(color: monoColor);

    final TextStyle displayStyle = _isFlutterTest
        ? baseSans.copyWith(
            fontSize: 15.0,
            fontWeight: FontWeight.w700,
            color: c.text,
            height: 1.2,
            letterSpacing: usePixel ? 0.2 : -0.3,
          )
        : usePixel
        ? GoogleFonts.silkscreen(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: c.text,
            height: 1.2,
            letterSpacing: -0.2,
          )
        : GoogleFonts.spaceGrotesk(
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
            color: c.text,
            height: 1.2,
            letterSpacing: -0.3,
          );

    final TextStyle badgeStyle = _isFlutterTest
        ? baseSans.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: c.text,
            height: 1.2,
            letterSpacing: 0.4,
          )
        : usePixel
        ? GoogleFonts.silkscreen(
            fontSize: 10.0,
            fontWeight: FontWeight.w700,
            color: c.text,
            height: 1.15,
            letterSpacing: 0.2,
          )
        : GoogleFonts.spaceGrotesk(
            fontSize: 11.0,
            fontWeight: FontWeight.w700,
            color: c.text,
            height: 1.15,
            letterSpacing: 0.5,
          );

    return AppTypography(
      mono: baseMono.copyWith(
        fontSize: 12.5,
        color: monoColor,
        height: 1.48,
        letterSpacing: 0,
      ),
      monoSmall: baseMono.copyWith(
        fontSize: 11.0,
        color: c.muted2,
        height: 1.38,
      ),
      sansBody: baseSans.copyWith(
        fontSize: 14.0,
        color: c.text,
        height: 1.42,
        letterSpacing: -0.1,
      ),
      sansSmall: baseSans.copyWith(
        fontSize: 12.0,
        color: c.muted2,
        height: 1.35,
        letterSpacing: -0.05,
      ),
      sansTitle: baseSans.copyWith(
        fontSize: 15.0,
        fontWeight: FontWeight.w700,
        color: c.text,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      display: displayStyle,
      badge: badgeStyle,
    );
  }

  /// Dark typography (Console Indigo).
  static final AppTypography dark = AppTypography.fromColors(
    AppColors.dark,
    monoColor: AppColors.dark.text,
  );

  /// Light typography (Bright Arcade).
  static final AppTypography light = AppTypography.fromColors(
    AppColors.light,
    monoColor: AppColors.light.text,
  );

  @override
  AppTypography copyWith({
    TextStyle? mono,
    TextStyle? monoSmall,
    TextStyle? sansBody,
    TextStyle? sansSmall,
    TextStyle? sansTitle,
    TextStyle? display,
    TextStyle? badge,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
  }) {
    return AppTypography(
      mono: mono ?? this.mono,
      monoSmall: monoSmall ?? this.monoSmall,
      sansBody: sansBody ?? this.sansBody,
      sansSmall: sansSmall ?? this.sansSmall,
      sansTitle: sansTitle ?? this.sansTitle,
      display: display ?? this.display,
      badge: badge ?? this.badge,
      headlineLarge: headlineLarge ?? this.headlineLarge,
      headlineMedium: headlineMedium ?? this.headlineMedium,
      headlineSmall: headlineSmall ?? this.headlineSmall,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      mono: TextStyle.lerp(mono, other.mono, t)!,
      monoSmall: TextStyle.lerp(monoSmall, other.monoSmall, t)!,
      sansBody: TextStyle.lerp(sansBody, other.sansBody, t)!,
      sansSmall: TextStyle.lerp(sansSmall, other.sansSmall, t)!,
      sansTitle: TextStyle.lerp(sansTitle, other.sansTitle, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      badge: TextStyle.lerp(badge, other.badge, t)!,
      headlineLarge: TextStyle.lerp(headlineLarge, other.headlineLarge, t)!,
      headlineMedium: TextStyle.lerp(headlineMedium, other.headlineMedium, t)!,
      headlineSmall: TextStyle.lerp(headlineSmall, other.headlineSmall, t)!,
    );
  }
}
