import 'package:flutter/material.dart';

import 'package:app/ui/core/themes/app_font_scale.dart';

/// Semantic color tokens for the whole app — supports both the upstream
/// Classic monochrome palette (default) and PICO-8 / TIC-80 (Sweetie-16)
/// fantasy-console inspired palettes in Bright Arcade (light) and Vibrant
/// Console Indigo (dark) variants.
///
/// This is the SINGLE source of truth for every color used in the UI. Widgets
/// must never hardcode `Color(0x…)` or `Colors.*` — they read from here via
/// `context.colors.<token>` (see `theme_extensions.dart`).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.muted2,
    required this.accent,
    required this.onAccent,
    required this.highlight,
    required this.success,
    required this.error,
    required this.warning,
    required this.working,
    required this.codeBg,
    required this.userBubble,
    required this.modelBadgeBg,
    required this.modelBadgeBorder,
    required this.denyBorder,
    required this.inputFill,
    this.shadow = const Color(0x00000000),
    this.retroPink = const Color(0xFFFF004D),
    this.retroYellow = const Color(0xFFFFEC27),
    this.retroOrange = const Color(0xFFFFA300),
    this.retroPurple = const Color(0xFF83769C),
    this.surface2 = const Color(0xFF121212),
    this.userBubbleBorder = const Color(0xFF2A2A2A),
  });

  /// App background (scaffold).
  final Color bg;

  /// Raised surface (cards, sheets, headers).
  final Color surface;

  /// Secondary recessed/header surface (code block headers, pill wells, toasts).
  final Color surface2;

  /// Crisp pixel/cartridge borders and dividers.
  final Color border;

  /// Border color for user chat bubbles.
  final Color userBubbleBorder;

  /// Primary foreground text.
  final Color text;

  /// Secondary / de-emphasized text.
  final Color muted;

  /// Tertiary text — slightly more prominent than [muted].
  final Color muted2;

  /// Brand accent (links, active states, primary buttons).
  final Color accent;

  /// Foreground painted on top of [accent].
  final Color onAccent;

  /// Inline code / file paths inside agent messages.
  final Color highlight;

  /// Success state (✓ tool results, online presence).
  final Color success;

  /// Error / destructive state (✗ tool results, failed sends, delete).
  final Color error;

  /// Warning state (relay offline / reconnecting).
  final Color warning;

  /// "Working" / in-progress accent (session running a turn).
  final Color working;

  /// Background of inline/fenced code blocks.
  final Color codeBg;

  /// User chat bubble background.
  final Color userBubble;

  /// Model badge background.
  final Color modelBadgeBg;

  /// Model badge border.
  final Color modelBadgeBorder;

  /// Border for a denied tool-call card.
  final Color denyBorder;

  /// Text-field fill.
  final Color inputFill;

  /// Crisp hard-edge offset shadow color (PICO-8 / TIC-80 cartridge shadow).
  final Color shadow;

  /// PICO-8 radical pink/red accent (`#FF004D` / `#FF77A8`).
  final Color retroPink;

  /// PICO-8 laser yellow accent (`#FFEC27` / `#FFCD75`).
  final Color retroYellow;

  /// PICO-8 warm orange accent (`#FFA300` / `#EF7D57`).
  final Color retroOrange;

  /// PICO-8 indigo-lavender accent (`#83769C` / `#7E2553`).
  final Color retroPurple;

  /// Standard 2.5px hard-edge offset shadow for cards and primary buttons
  /// (empty in Classic mode when [shadow] is transparent).
  List<BoxShadow> get retroShadow => shadow.a == 0
      ? const <BoxShadow>[]
      : [
          BoxShadow(
            color: shadow,
            offset: const Offset(2.5, 2.5),
            blurRadius: 0,
          ),
        ];

  /// Subtle 1.5px hard-edge offset shadow for badges, pills, and compact tiles
  /// (empty in Classic mode when [shadow] is transparent).
  List<BoxShadow> get retroShadowSm => shadow.a == 0
      ? const <BoxShadow>[]
      : [
          BoxShadow(
            color: shadow,
            offset: const Offset(1.5, 1.5),
            blurRadius: 0,
          ),
        ];

  /// Deterministic PICO-8 / TIC-80 accent color for a session or peer name.
  Color avatarColorFor(String seed) {
    final palette = <Color>[
      accent,
      retroPink,
      retroOrange,
      success,
      retroPurple,
    ];
    var hash = 0;
    for (final code in seed.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }

  /// Resolve the [AppColors] palette for [preset] and [brightness].
  static AppColors forPreset(AppThemePreset preset, Brightness brightness) {
    if (preset.isPico8) {
      return brightness == Brightness.dark ? pico8Dark : pico8Light;
    }
    return brightness == Brightness.dark ? dark : light;
  }

  /// Upstream Classic dark palette (pure black + cyan accent).
  static const AppColors dark = AppColors(
    bg: Color(0xFF000000),
    surface: Color(0xFF0A0A0A),
    surface2: Color(0xFF121212),
    border: Color(0xFF1A1A1A),
    userBubbleBorder: Color(0xFF2A2A2A),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF6B6B6B),
    muted2: Color(0xFF8A8A8A),
    accent: Color(0xFF00D4FF),
    onAccent: Color(0xFF000000),
    highlight: Color(0xFF9FE6FF),
    success: Color(0xFF6CD28A),
    error: Color(0xFFE5484D),
    warning: Color(0xFFFFB300),
    working: Color(0xFF3FA9F5),
    codeBg: Color(0xFF050505),
    userBubble: Color(0xFF1A1A1A),
    modelBadgeBg: Color(0xFF161616),
    modelBadgeBorder: Color(0xFF1F1F1F),
    denyBorder: Color(0xFF2A2A2A),
    inputFill: Color(0xFF0E0E0E),
    shadow: Color(0x00000000),
  );

  /// Upstream Classic light palette (crisp white + deep teal-blue accent).
  static const AppColors light = AppColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F4F5),
    surface2: Color(0xFFEAEAEC),
    border: Color(0xFFDADADD),
    userBubbleBorder: Color(0xFFDADADD),
    text: Color(0xFF0A0A0A),
    muted: Color(0xFF565656),
    muted2: Color(0xFF424242),
    accent: Color(0xFF0077A3),
    onAccent: Color(0xFFFFFFFF),
    highlight: Color(0xFF005F82),
    success: Color(0xFF1E7A41),
    error: Color(0xFFC42026),
    warning: Color(0xFF9A6300),
    working: Color(0xFF1A6CB0),
    codeBg: Color(0xFFF0F0F0),
    userBubble: Color(0xFFEAEAEC),
    modelBadgeBg: Color(0xFFEDEDEF),
    modelBadgeBorder: Color(0xFFD7D7DA),
    denyBorder: Color(0xFFC9C9CD),
    inputFill: Color(0xFFF0F0F2),
    shadow: Color(0x00000000),
  );

  /// Vibrant Console Indigo (PICO-8 / TIC-80 dark palette) — replaces
  /// pitch-black with TIC-80 / PICO-8 deep indigo (`#1A1C2C`) and console navy
  /// (`#252A44`), paired with warm cream text (`#FFF1E8`) and bright 16-color
  /// accents.
  static const AppColors pico8Dark = AppColors(
    bg: Color(0xFF1A1C2C), // TIC-80 Deep Indigo
    surface: Color(0xFF252A44), // Console Navy (PICO-8 #1D2B53 / TIC-80 #29366F)
    border: Color(0xFF43537D), // Crisp Steel-Indigo Border
    text: Color(0xFFFFF1E8), // PICO-8 Warm Cream
    muted: Color(0xFF8B8EA8), // Lavender-Slate
    muted2: Color(0xFFC2C3C7), // PICO-8 Light Grey
    accent: Color(0xFF29ADFF), // PICO-8 Sky Blue
    onAccent: Color(0xFF1A1C2C), // Deep Indigo on Sky Blue
    highlight: Color(0xFFFF77A8), // PICO-8 Bubblegum Pink
    success: Color(0xFF00E436), // PICO-8 Arcade Green
    error: Color(0xFFFF004D), // PICO-8 Radical Red-Pink
    warning: Color(0xFFFFA300), // PICO-8 Orange-Gold
    working: Color(0xFFFFEC27), // PICO-8 Laser Yellow
    codeBg: Color(0xFF121420), // Recessed CRT Well
    userBubble: Color(0xFF29366F), // TIC-80 Royal Navy Bubble
    modelBadgeBg: Color(0xFF332752), // Plum Cartridge Badge
    modelBadgeBorder: Color(0xFF83769C), // PICO-8 Lavender
    denyBorder: Color(0xFF566C86), // TIC-80 Steel
    inputFill: Color(0xFF141726), // Console Input Well
    shadow: Color(0xFF0D0F18), // Hard Pixel Shadow
    retroPink: Color(0xFFFF004D),
    retroYellow: Color(0xFFFFEC27),
    retroOrange: Color(0xFFFFA300),
    retroPurple: Color(0xFF83769C),
    surface2: Color(0xFF1E2238),
    userBubbleBorder: Color(0xFF43537D),
  );

  /// Bright Arcade (PICO-8 light palette) — PICO-8 warm cream (`#FFF1E8`)
  /// backdrop with crisp white cards, charcoal-indigo borders (`#29366F`),
  /// hard offset shadows, and punchy 16-color arcade accents.
  static const AppColors pico8Light = AppColors(
    bg: Color(0xFFFFF1E8), // PICO-8 Warm Cream
    surface: Color(0xFFFFFFFF), // Crisp Cartridge White
    border: Color(0xFF29366F), // TIC-80 Royal Navy / Charcoal Outline
    text: Color(0xFF1A1C2C), // TIC-80 Deep Indigo
    muted: Color(0xFF566C86), // TIC-80 Steel Slate
    muted2: Color(0xFF29366F), // TIC-80 Royal Navy
    accent: Color(0xFF1D63D8), // Punchy Arcade Cobalt-Sky Blue
    onAccent: Color(0xFFFFFFFF), // Crisp White on Cobalt
    highlight: Color(0xFFD90042), // PICO-8 Berry Red-Pink for inline code
    success: Color(0xFF008751), // PICO-8 Emerald Green
    error: Color(0xFFE00043), // PICO-8 Radical Red
    warning: Color(0xFFD46B00), // PICO-8 Deep Orange
    working: Color(0xFF0077CC), // PICO-8 Bright Sky Blue
    codeBg: Color(0xFFF5E4D7), // Warm Recessed Cream
    userBubble: Color(0xFFD9EFFF), // Bright Sky Arcade Bubble
    modelBadgeBg: Color(0xFFFFE8B3), // PICO-8 Sunny Gold-Peach Pill
    modelBadgeBorder: Color(0xFF29366F), // Crisp Navy Pill Border
    denyBorder: Color(0xFF94B0C2), // TIC-80 Light Slate
    inputFill: Color(0xFFFFFFFF), // Crisp White Input Well
    shadow: Color(0xFF1D2B53), // PICO-8 Dark Navy Offset Shadow
    retroPink: Color(0xFFFF004D),
    retroYellow: Color(0xFFFFEC27),
    retroOrange: Color(0xFFFFA300),
    retroPurple: Color(0xFF7E2553),
    surface2: Color(0xFFF5E4D7),
    userBubbleBorder: Color(0xFF29366F),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? userBubbleBorder,
    Color? text,
    Color? muted,
    Color? muted2,
    Color? accent,
    Color? onAccent,
    Color? highlight,
    Color? success,
    Color? error,
    Color? warning,
    Color? working,
    Color? codeBg,
    Color? userBubble,
    Color? modelBadgeBg,
    Color? modelBadgeBorder,
    Color? denyBorder,
    Color? inputFill,
    Color? shadow,
    Color? retroPink,
    Color? retroYellow,
    Color? retroOrange,
    Color? retroPurple,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      userBubbleBorder: userBubbleBorder ?? this.userBubbleBorder,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      muted2: muted2 ?? this.muted2,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      highlight: highlight ?? this.highlight,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      working: working ?? this.working,
      codeBg: codeBg ?? this.codeBg,
      userBubble: userBubble ?? this.userBubble,
      modelBadgeBg: modelBadgeBg ?? this.modelBadgeBg,
      modelBadgeBorder: modelBadgeBorder ?? this.modelBadgeBorder,
      denyBorder: denyBorder ?? this.denyBorder,
      inputFill: inputFill ?? this.inputFill,
      shadow: shadow ?? this.shadow,
      retroPink: retroPink ?? this.retroPink,
      retroYellow: retroYellow ?? this.retroYellow,
      retroOrange: retroOrange ?? this.retroOrange,
      retroPurple: retroPurple ?? this.retroPurple,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      userBubbleBorder: Color.lerp(userBubbleBorder, other.userBubbleBorder, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      muted2: Color.lerp(muted2, other.muted2, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      working: Color.lerp(working, other.working, t)!,
      codeBg: Color.lerp(codeBg, other.codeBg, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      modelBadgeBg: Color.lerp(modelBadgeBg, other.modelBadgeBg, t)!,
      modelBadgeBorder: Color.lerp(modelBadgeBorder, other.modelBadgeBorder, t)!,
      denyBorder: Color.lerp(denyBorder, other.denyBorder, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      retroPink: Color.lerp(retroPink, other.retroPink, t)!,
      retroYellow: Color.lerp(retroYellow, other.retroYellow, t)!,
      retroOrange: Color.lerp(retroOrange, other.retroOrange, t)!,
      retroPurple: Color.lerp(retroPurple, other.retroPurple, t)!,
    );
  }
}
