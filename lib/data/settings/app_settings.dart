import 'package:math_engine/math_engine.dart';

enum AppThemeMode { system, light, dark, amoled }

enum HapticLevel { off, light, medium }

enum ResultFormat { auto, decimal, fraction, mixed, exact }

enum KeyboardLayout { scientific, basic }

enum DisplaySize { small, medium, large }

enum ButtonSize { compact, normal, large }

/// All user preferences. Persisted as JSON in SharedPreferences.
class AppSettings {
  const AppSettings({
    this.angleMode = AngleMode.deg,
    this.resultFormat = ResultFormat.auto,
    this.notation = NumberNotation.normal,
    this.precision = 10,
    this.thousandsSeparator = false,
    this.decimalComma = false,
    this.complexFormat = ComplexFormat.rectangular,
    this.complexResults = false,
    this.engineeringSymbols = false,
    this.memoryPersists = true,
    this.themeMode = AppThemeMode.system,
    this.accent = 'indigo',
    this.fontScale = 1.0,
    this.displaySize = DisplaySize.medium,
    this.buttonSize = ButtonSize.normal,
    this.showSecondaryLabels = true,
    this.animations = true,
    this.haptics = HapticLevel.light,
    this.keySound = false,
    this.keyboardLayout = KeyboardLayout.scientific,
    this.livePreview = true,
    this.graphGrid = true,
    this.graphAxes = true,
    this.graphLabels = true,
    this.graphLineWidth = 2.5,
    this.graphDegrees = false,
    this.saveHistory = true,
    this.historyLimit = 1000,
    this.quickAccess = defaultQuickAccess,
    this.onboardingDone = false,
    this.randomSeed,
  });

  // Calculator
  final AngleMode angleMode;
  final ResultFormat resultFormat;
  final NumberNotation notation;

  /// Significant digits for calculation and display (10, 15, 20, 50, 100).
  final int precision;
  final bool thousandsSeparator;
  final bool decimalComma;
  final ComplexFormat complexFormat;
  final bool complexResults;
  final bool engineeringSymbols;
  final bool memoryPersists;

  // Appearance
  final AppThemeMode themeMode;
  final String accent;
  final double fontScale;
  final DisplaySize displaySize;
  final ButtonSize buttonSize;
  final bool showSecondaryLabels;
  final bool animations;
  final HapticLevel haptics;
  final bool keySound;

  // Input
  final KeyboardLayout keyboardLayout;
  final bool livePreview;

  // Graph
  final bool graphGrid;
  final bool graphAxes;
  final bool graphLabels;
  final double graphLineWidth;

  /// Graph trigonometry in degrees (default radians).
  final bool graphDegrees;

  // History
  final bool saveHistory;
  final int historyLimit;

  /// Ordered module ids shown as quick-access shortcuts.
  final List<String> quickAccess;
  final bool onboardingDone;

  /// Optional seed for reproducible random numbers.
  final int? randomSeed;

  static const precisionChoices = [10, 15, 20, 50, 100];
  static const defaultQuickAccess = ['equation', 'graph', 'matrix', 'integral', 'derivative', 'converter'];

  CalcSettings get calcSettings =>
      CalcSettings(precision: precision, angleMode: angleMode, complexResults: complexResults);

  FormatOptions formatOptions({ResultFormat? override}) {
    final f = override ?? resultFormat;
    return FormatOptions(
      digits: precision,
      notation: notation,
      fraction: switch (f) {
        ResultFormat.auto || ResultFormat.exact => FractionMode.auto,
        ResultFormat.decimal => FractionMode.decimal,
        ResultFormat.fraction => FractionMode.fraction,
        ResultFormat.mixed => FractionMode.mixed,
      },
      thousandsSeparator: thousandsSeparator,
      groupSeparator: decimalComma ? '.' : ',',
      decimalSeparator: decimalComma ? ',' : '.',
      engineeringSymbols: engineeringSymbols,
      complexFormat: complexFormat,
      angleMode: angleMode,
    );
  }

  AppSettings copyWith({
    AngleMode? angleMode,
    ResultFormat? resultFormat,
    NumberNotation? notation,
    int? precision,
    bool? thousandsSeparator,
    bool? decimalComma,
    ComplexFormat? complexFormat,
    bool? complexResults,
    bool? engineeringSymbols,
    bool? memoryPersists,
    AppThemeMode? themeMode,
    String? accent,
    double? fontScale,
    DisplaySize? displaySize,
    ButtonSize? buttonSize,
    bool? showSecondaryLabels,
    bool? animations,
    HapticLevel? haptics,
    bool? keySound,
    KeyboardLayout? keyboardLayout,
    bool? livePreview,
    bool? graphGrid,
    bool? graphAxes,
    bool? graphLabels,
    double? graphLineWidth,
    bool? graphDegrees,
    bool? saveHistory,
    int? historyLimit,
    List<String>? quickAccess,
    bool? onboardingDone,
    int? Function()? randomSeed,
  }) =>
      AppSettings(
        angleMode: angleMode ?? this.angleMode,
        resultFormat: resultFormat ?? this.resultFormat,
        notation: notation ?? this.notation,
        precision: precision ?? this.precision,
        thousandsSeparator: thousandsSeparator ?? this.thousandsSeparator,
        decimalComma: decimalComma ?? this.decimalComma,
        complexFormat: complexFormat ?? this.complexFormat,
        complexResults: complexResults ?? this.complexResults,
        engineeringSymbols: engineeringSymbols ?? this.engineeringSymbols,
        memoryPersists: memoryPersists ?? this.memoryPersists,
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
        fontScale: fontScale ?? this.fontScale,
        displaySize: displaySize ?? this.displaySize,
        buttonSize: buttonSize ?? this.buttonSize,
        showSecondaryLabels: showSecondaryLabels ?? this.showSecondaryLabels,
        animations: animations ?? this.animations,
        haptics: haptics ?? this.haptics,
        keySound: keySound ?? this.keySound,
        keyboardLayout: keyboardLayout ?? this.keyboardLayout,
        livePreview: livePreview ?? this.livePreview,
        graphGrid: graphGrid ?? this.graphGrid,
        graphAxes: graphAxes ?? this.graphAxes,
        graphLabels: graphLabels ?? this.graphLabels,
        graphLineWidth: graphLineWidth ?? this.graphLineWidth,
        graphDegrees: graphDegrees ?? this.graphDegrees,
        saveHistory: saveHistory ?? this.saveHistory,
        historyLimit: historyLimit ?? this.historyLimit,
        quickAccess: quickAccess ?? this.quickAccess,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        randomSeed: randomSeed != null ? randomSeed() : this.randomSeed,
      );

  Map<String, Object?> toJson() => {
        'angleMode': angleMode.name,
        'resultFormat': resultFormat.name,
        'notation': notation.name,
        'precision': precision,
        'thousandsSeparator': thousandsSeparator,
        'decimalComma': decimalComma,
        'complexFormat': complexFormat.name,
        'complexResults': complexResults,
        'engineeringSymbols': engineeringSymbols,
        'memoryPersists': memoryPersists,
        'themeMode': themeMode.name,
        'accent': accent,
        'fontScale': fontScale,
        'displaySize': displaySize.name,
        'buttonSize': buttonSize.name,
        'showSecondaryLabels': showSecondaryLabels,
        'animations': animations,
        'haptics': haptics.name,
        'keySound': keySound,
        'keyboardLayout': keyboardLayout.name,
        'livePreview': livePreview,
        'graphGrid': graphGrid,
        'graphAxes': graphAxes,
        'graphLabels': graphLabels,
        'graphLineWidth': graphLineWidth,
        'graphDegrees': graphDegrees,
        'saveHistory': saveHistory,
        'historyLimit': historyLimit,
        'quickAccess': quickAccess,
        'onboardingDone': onboardingDone,
        'randomSeed': randomSeed,
      };

  /// Tolerant parsing: unknown or invalid values fall back to defaults so a
  /// corrupted or older settings blob can never crash startup.
  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    T pick<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.firstWhere((e) => e.name == v, orElse: () => fallback);
    bool b(String k, bool fb) => j[k] is bool ? j[k] as bool : fb;
    final precision = j['precision'] is int && precisionChoices.contains(j['precision']) ? j['precision'] as int : d.precision;
    double dbl(String k, double fb, double lo, double hi) {
      final v = j[k];
      if (v is num && v.isFinite) return v.toDouble().clamp(lo, hi);
      return fb;
    }

    final qa = j['quickAccess'];
    return AppSettings(
      angleMode: pick(AngleMode.values, j['angleMode'], d.angleMode),
      resultFormat: pick(ResultFormat.values, j['resultFormat'], d.resultFormat),
      notation: pick(NumberNotation.values, j['notation'], d.notation),
      precision: precision,
      thousandsSeparator: b('thousandsSeparator', d.thousandsSeparator),
      decimalComma: b('decimalComma', d.decimalComma),
      complexFormat: pick(ComplexFormat.values, j['complexFormat'], d.complexFormat),
      complexResults: b('complexResults', d.complexResults),
      engineeringSymbols: b('engineeringSymbols', d.engineeringSymbols),
      memoryPersists: b('memoryPersists', d.memoryPersists),
      themeMode: pick(AppThemeMode.values, j['themeMode'], d.themeMode),
      accent: j['accent'] is String ? j['accent'] as String : d.accent,
      fontScale: dbl('fontScale', d.fontScale, 0.8, 1.4),
      displaySize: pick(DisplaySize.values, j['displaySize'], d.displaySize),
      buttonSize: pick(ButtonSize.values, j['buttonSize'], d.buttonSize),
      showSecondaryLabels: b('showSecondaryLabels', d.showSecondaryLabels),
      animations: b('animations', d.animations),
      haptics: pick(HapticLevel.values, j['haptics'], d.haptics),
      keySound: b('keySound', d.keySound),
      keyboardLayout: pick(KeyboardLayout.values, j['keyboardLayout'], d.keyboardLayout),
      livePreview: b('livePreview', d.livePreview),
      graphGrid: b('graphGrid', d.graphGrid),
      graphAxes: b('graphAxes', d.graphAxes),
      graphLabels: b('graphLabels', d.graphLabels),
      graphLineWidth: dbl('graphLineWidth', d.graphLineWidth, 1, 6),
      graphDegrees: b('graphDegrees', d.graphDegrees),
      saveHistory: b('saveHistory', d.saveHistory),
      historyLimit: j['historyLimit'] is int ? (j['historyLimit'] as int).clamp(50, 100000) : d.historyLimit,
      quickAccess: qa is List ? qa.whereType<String>().toList() : d.quickAccess,
      onboardingDone: b('onboardingDone', d.onboardingDone),
      randomSeed: j['randomSeed'] is int ? j['randomSeed'] as int : null,
    );
  }
}
