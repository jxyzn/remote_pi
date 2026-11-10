/// User-selectable text size (issue #114).
///
/// Why an in-app control at all: every text size in the app is hardcoded
/// (`AppTypography` plus per-widget `copyWith(fontSize: …)`), and Flutter does
/// not participate in iOS's per-app "Text Size" entry — the engine derives its
/// scale factor exclusively from `preferredContentSizeCategory`, which only
/// surfaces for apps supporting UIKit Dynamic Type. So the only OS-level
/// workaround is the *global* Larger Text setting, which resizes every other
/// app on the device. This gives the app its own knob.
///
/// The factor is applied as a `TextScaler` on the `MediaQuery` above the router
/// rather than by multiplying `AppTypography`'s base sizes. That covers the
/// per-widget `copyWith(fontSize: …)` call sites too — multiplying the base
/// styles would leave every one-off size unscaled, which is most of the chat.
enum AppFontScale {
  small('Small', 0.9),
  standard('Default', 1.0),
  large('Large', 1.15),
  extraLarge('XL', 1.3);

  const AppFontScale(this.label, this.factor);

  /// Short label for the Settings segmented control.
  final String label;

  /// Multiplier applied to every text size in the app.
  final double factor;

  /// Parse a persisted value. Unknown/legacy/missing → [standard], so a bad
  /// stored string can never leave the app with unreadable text.
  static AppFontScale fromName(String? raw) {
    for (final v in AppFontScale.values) {
      if (v.name == raw) return v;
    }
    return AppFontScale.standard;
  }
}

/// User-selectable color & visual theme preset.
///
/// Defaults to [AppThemePreset.classic] (upstream's clean monochrome palette)
/// with [AppThemePreset.pico8] offering the PICO-8 / TIC-80 fantasy-console
/// palette and hard-edge offset shadows.
enum AppThemePreset {
  classic('Classic'),
  pico8('PICO-8');

  const AppThemePreset(this.label);

  /// Short label for the Settings segmented control.
  final String label;

  /// True when the PICO-8 / TIC-80 fantasy-console preset is active.
  bool get isPico8 => this == AppThemePreset.pico8;

  /// Parse a persisted value. Unknown/missing → [classic].
  static AppThemePreset fromName(String? raw) {
    for (final v in AppThemePreset.values) {
      if (v.name == raw) return v;
    }
    return AppThemePreset.classic;
  }
}

/// User-selectable header & badge typography style for the PICO-8 / TIC-80
/// aesthetic.
///
/// Body prose and UI descriptions always use proportional sans-serif, and
/// code/paths/IDs always use monospace. This toggle controls whether headers,
/// wordmarks, and status badges use the pixel/arcade display font
/// ([AppRetroFontMode.arcade], `Silkscreen`) or a clean geometric proportional
/// font ([AppRetroFontMode.clean], `Space Grotesk`).
enum AppRetroFontMode {
  arcade('Arcade Pixel'),
  clean('Clean Sans');

  const AppRetroFontMode(this.label);

  /// Short label for the Settings segmented control.
  final String label;

  /// True when pixel/arcade display typography should be used for headers and
  /// badges.
  bool get isPixel => this == AppRetroFontMode.arcade;

  /// Parse a persisted value. Unknown/missing → [arcade] (default retro look).
  static AppRetroFontMode fromName(String? raw) {
    for (final v in AppRetroFontMode.values) {
      if (v.name == raw) return v;
    }
    return AppRetroFontMode.arcade;
  }
}
