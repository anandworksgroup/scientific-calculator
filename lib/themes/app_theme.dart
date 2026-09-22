import 'package:flutter/material.dart';

import '../data/settings/app_settings.dart';

/// Accent palettes. The first entries are free; the rest are premium.
class AccentPalette {
  const AccentPalette(this.id, this.seed, {this.premium = false});
  final String id;
  final Color seed;
  final bool premium;
}

const accentPalettes = [
  AccentPalette('indigo', Color(0xFF3F51B5)),
  AccentPalette('teal', Color(0xFF00897B)),
  AccentPalette('slate', Color(0xFF546E7A)),
  AccentPalette('amber', Color(0xFFFFA000), premium: true),
  AccentPalette('crimson', Color(0xFFC62828), premium: true),
  AccentPalette('violet', Color(0xFF7B1FA2), premium: true),
  AccentPalette('forest', Color(0xFF2E7D32), premium: true),
  AccentPalette('ocean', Color(0xFF0277BD), premium: true),
  AccentPalette('rose', Color(0xFFD81B60), premium: true),
  AccentPalette('graphite', Color(0xFF37474F), premium: true),
];

AccentPalette paletteById(String id) =>
    accentPalettes.firstWhere((p) => p.id == id, orElse: () => accentPalettes.first);

/// Extra semantic colors for calculator surfaces.
@immutable
class CalcColors extends ThemeExtension<CalcColors> {
  const CalcColors({
    required this.displayBackground,
    required this.displayForeground,
    required this.keyNumber,
    required this.keyFunction,
    required this.keyOperator,
    required this.keyAction,
    required this.keyEquals,
    required this.onKeyNumber,
    required this.onKeyFunction,
    required this.onKeyOperator,
    required this.onKeyAction,
    required this.onKeyEquals,
    required this.shiftLabel,
    required this.alphaLabel,
    required this.cursor,
    required this.placeholder,
    required this.error,
    required this.graphPalette,
    required this.gridMinor,
    required this.gridMajor,
    required this.axis,
  });

  final Color displayBackground;
  final Color displayForeground;
  final Color keyNumber, keyFunction, keyOperator, keyAction, keyEquals;
  final Color onKeyNumber, onKeyFunction, onKeyOperator, onKeyAction, onKeyEquals;
  final Color shiftLabel;
  final Color alphaLabel;
  final Color cursor;
  final Color placeholder;
  final Color error;
  final List<Color> graphPalette;
  final Color gridMinor, gridMajor, axis;

  static CalcColors of(BuildContext context) => Theme.of(context).extension<CalcColors>()!;

  @override
  CalcColors copyWith() => this;

  @override
  CalcColors lerp(ThemeExtension<CalcColors>? other, double t) => t < 0.5 ? this : (other as CalcColors? ?? this);
}

String colorToHex(Color c) {
  final argb = c.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

class AppTheme {
  static ThemeData build({required Brightness brightness, required String accent, bool amoled = false}) {
    final seed = paletteById(accent).seed;
    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    if (amoled) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF111111),
        surfaceContainerHigh: const Color(0xFF161616),
        surfaceContainerHighest: const Color(0xFF1C1C1C),
      );
    }
    final dark = brightness == Brightness.dark;
    final calc = CalcColors(
      displayBackground: amoled ? Colors.black : scheme.surfaceContainerHighest,
      displayForeground: scheme.onSurface,
      keyNumber: amoled ? const Color(0xFF151515) : scheme.surfaceContainerHigh,
      keyFunction: amoled ? const Color(0xFF0D0D0D) : scheme.surfaceContainerLow,
      keyOperator: scheme.secondaryContainer,
      keyAction: scheme.tertiaryContainer,
      keyEquals: scheme.primary,
      onKeyNumber: scheme.onSurface,
      onKeyFunction: scheme.onSurface,
      onKeyOperator: scheme.onSecondaryContainer,
      onKeyAction: scheme.onTertiaryContainer,
      onKeyEquals: scheme.onPrimary,
      shiftLabel: dark ? const Color(0xFFFFC857) : const Color(0xFFB26A00),
      alphaLabel: dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
      cursor: scheme.primary,
      placeholder: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      error: scheme.error,
      graphPalette: dark
          ? const [Color(0xFF64B5F6), Color(0xFFE57373), Color(0xFF81C784), Color(0xFFFFB74D), Color(0xFFBA68C8), Color(0xFF4DD0E1), Color(0xFFF06292), Color(0xFFAED581)]
          : const [Color(0xFF1565C0), Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFFEF6C00), Color(0xFF6A1B9A), Color(0xFF00838F), Color(0xFFAD1457), Color(0xFF558B2F)],
      gridMinor: scheme.outlineVariant.withValues(alpha: 0.35),
      gridMajor: scheme.outlineVariant.withValues(alpha: 0.8),
      axis: scheme.onSurfaceVariant,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: amoled ? Colors.black : null,
      extensions: [calc],
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: amoled ? Colors.black : null,
        scrolledUnderElevation: amoled ? 0 : null,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: amoled ? Colors.black : null,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: amoled ? const Color(0xFF0E0E0E) : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
    );
  }

  static ThemeMode themeMode(AppThemeMode m) => switch (m) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark || AppThemeMode.amoled => ThemeMode.dark,
      };
}
