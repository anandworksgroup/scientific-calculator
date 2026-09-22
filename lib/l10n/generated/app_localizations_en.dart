// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Advanced Calculator';

  @override
  String get appTagline => 'Powerful mathematics, completely in your pocket.';

  @override
  String get navCalculator => 'Calculator';

  @override
  String get navScientific => 'Scientific';

  @override
  String get navGraph => 'Graph';

  @override
  String get navSolve => 'Solve';

  @override
  String get navTools => 'Tools';

  @override
  String get navHistory => 'History';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionOk => 'OK';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionShare => 'Share';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionDone => 'Done';

  @override
  String get actionClose => 'Close';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionReset => 'Reset';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionCalculate => 'Calculate';

  @override
  String get actionSolve => 'Solve';

  @override
  String get actionUse => 'Use';

  @override
  String get actionInsert => 'Insert';

  @override
  String get actionRename => 'Rename';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionRedo => 'Redo';

  @override
  String get actionPaste => 'Paste';

  @override
  String get actionSelectAll => 'Select all';

  @override
  String get actionFavorite => 'Add to favorites';

  @override
  String get actionUnfavorite => 'Remove from favorites';

  @override
  String get actionMore => 'More options';

  @override
  String get actionSettings => 'Settings';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionBack => 'Back';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get deletedItem => 'Deleted';

  @override
  String get savedItem => 'Saved';

  @override
  String get calculating => 'Calculating…';

  @override
  String get calculationCancelled => 'Calculation cancelled';

  @override
  String get emptyStateNothingHere => 'Nothing here yet';

  @override
  String get invalidNumber => 'Enter a valid number or expression';

  @override
  String get fieldRequired => 'Required';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingScientificTitle => 'Scientific calculator';

  @override
  String get onboardingScientificBody =>
      'Textbook-style input, exact fractions and surds, up to 100-digit precision.';

  @override
  String get onboardingSolveTitle => 'Solve equations';

  @override
  String get onboardingSolveBody =>
      'Polynomials, simultaneous equations, calculus and matrices with worked steps.';

  @override
  String get onboardingGraphTitle => 'Plot graphs';

  @override
  String get onboardingGraphBody =>
      'Cartesian, polar, parametric and implicit curves with roots, extrema and tangents.';

  @override
  String get onboardingOfflineTitle => 'Works offline';

  @override
  String get onboardingOfflineBody =>
      'No account and no internet needed. Your calculations stay on your device.';

  @override
  String get indicatorShift => 'S';

  @override
  String get indicatorAlpha => 'A';

  @override
  String get indicatorMemory => 'M';

  @override
  String get indicatorStore => 'STO';

  @override
  String get angleDeg => 'DEG';

  @override
  String get angleRad => 'RAD';

  @override
  String get angleGrad => 'GRAD';

  @override
  String get angleDegLong => 'Degrees';

  @override
  String get angleRadLong => 'Radians';

  @override
  String get angleGradLong => 'Gradians';

  @override
  String get notationNormal => 'Normal';

  @override
  String get notationScientific => 'Scientific';

  @override
  String get notationEngineering => 'Engineering';

  @override
  String get notationSciShort => 'SCI';

  @override
  String get notationEngShort => 'ENG';

  @override
  String get formatAuto => 'Auto';

  @override
  String get formatDecimal => 'Decimal';

  @override
  String get formatFraction => 'Fraction';

  @override
  String get formatMixed => 'Mixed fraction';

  @override
  String get formatExact => 'Exact';

  @override
  String get complexRect => 'a+bi';

  @override
  String get complexPolar => 'r∠θ';

  @override
  String get calcPlaceholder => 'Enter an expression';

  @override
  String get calcExactForm => 'Exact form';

  @override
  String get calcDecimalForm => 'Decimal form';

  @override
  String get calcFractionForm => 'Fraction';

  @override
  String get calcMixedForm => 'Mixed fraction';

  @override
  String get calcScientificForm => 'Scientific notation';

  @override
  String get calcEngineeringForm => 'Engineering notation';

  @override
  String get calcAllDigits => 'All digits';

  @override
  String get calcResultDetails => 'Result details';

  @override
  String get calcToggleFormat => 'Switch result format';

  @override
  String get calcCopyResult => 'Copy result';

  @override
  String get calcCopyExpression => 'Copy expression';

  @override
  String get calcCopyBoth => 'Copy expression and result';

  @override
  String get calcUseResult => 'Use result';

  @override
  String get calcUseExpression => 'Use expression';

  @override
  String calcShareText(String expression, String result) {
    return 'Expression:\n$expression\nResult:\n$result';
  }

  @override
  String calcStoredIn(String name) {
    return 'Stored in $name';
  }

  @override
  String calcFunctionDefined(String name) {
    return 'Function $name saved';
  }

  @override
  String get calcTrue => 'True';

  @override
  String get calcFalse => 'False';

  @override
  String get calcNoSolution => 'No solution';

  @override
  String get calcAllValues => 'True for every value';

  @override
  String get calcNumericalSolution => 'Numerical solution';

  @override
  String get calcFunctionCatalog => 'Function catalog';

  @override
  String get calcConstants => 'Constants';

  @override
  String get calcStore => 'Store result in…';

  @override
  String get calcRecall => 'Recall variable';

  @override
  String get calcMemoryClear => 'Memory cleared';

  @override
  String get calcMemoryStored => 'Stored in memory';

  @override
  String get calcModeMenu => 'Mode and setup';

  @override
  String get calcSwitchToBasic => 'Basic keypad';

  @override
  String get calcSwitchToScientific => 'Scientific keypad';

  @override
  String get calcLandscapeHint => 'Rotate for more functions';

  @override
  String get calcSteps => 'Show steps';

  @override
  String get calcHideSteps => 'Hide steps';

  @override
  String get calcCursorLeft => 'Move cursor left';

  @override
  String get calcCursorRight => 'Move cursor right';

  @override
  String get calcEmptyHistory => 'Your calculations will appear here';

  @override
  String calcMultiplicity(int count) {
    return 'multiplicity $count';
  }

  @override
  String get calcComplexRoot => 'complex';

  @override
  String get calcApprox => '≈';

  @override
  String calcIntervalNote(String from, String to) {
    return 'Real solutions found in [$from, $to]';
  }

  @override
  String get calcPeriodicNote =>
      'The equation is periodic, so it has infinitely many solutions; those in the search range are shown.';

  @override
  String get calcCatalogSearch => 'Search functions';

  @override
  String get keyShift => 'Shift';

  @override
  String get keyAlpha => 'Alpha';

  @override
  String get keyDel => 'Delete';

  @override
  String get keyAc => 'All clear';

  @override
  String get keyEquals => 'Equals';

  @override
  String get keyAns => 'Previous answer';

  @override
  String get keyExp => 'Times ten to the power';

  @override
  String get keyDecimal => 'Decimal point';

  @override
  String get keyPlus => 'Plus';

  @override
  String get keyMinus => 'Minus';

  @override
  String get keyTimes => 'Times';

  @override
  String get keyDivide => 'Divided by';

  @override
  String get keyOpenParen => 'Open parenthesis';

  @override
  String get keyCloseParen => 'Close parenthesis';

  @override
  String get keyComma => 'Comma';

  @override
  String get keyFraction => 'Fraction';

  @override
  String get keyMixedFraction => 'Mixed fraction';

  @override
  String get keySquare => 'Square';

  @override
  String get keyCube => 'Cube';

  @override
  String get keyPower => 'Power';

  @override
  String get keyInverse => 'Reciprocal';

  @override
  String get keySqrt => 'Square root';

  @override
  String get keyCbrt => 'Cube root';

  @override
  String get keyNthRoot => 'Nth root';

  @override
  String get keyLog => 'Logarithm base ten';

  @override
  String get keyLogBase => 'Logarithm with base';

  @override
  String get keyLn => 'Natural logarithm';

  @override
  String get keyTenPower => 'Ten to the power';

  @override
  String get keyExpPower => 'e to the power';

  @override
  String get keySin => 'Sine';

  @override
  String get keyCos => 'Cosine';

  @override
  String get keyTan => 'Tangent';

  @override
  String get keyAsin => 'Inverse sine';

  @override
  String get keyAcos => 'Inverse cosine';

  @override
  String get keyAtan => 'Inverse tangent';

  @override
  String get keySinh => 'Hyperbolic sine';

  @override
  String get keyCosh => 'Hyperbolic cosine';

  @override
  String get keyTanh => 'Hyperbolic tangent';

  @override
  String get keyAsinh => 'Inverse hyperbolic sine';

  @override
  String get keyAcosh => 'Inverse hyperbolic cosine';

  @override
  String get keyAtanh => 'Inverse hyperbolic tangent';

  @override
  String get keyPi => 'Pi';

  @override
  String get keyE => 'Euler\'s number';

  @override
  String get keyI => 'Imaginary unit';

  @override
  String get keyFactorial => 'Factorial';

  @override
  String get keyPercent => 'Percent';

  @override
  String get keyAbs => 'Absolute value';

  @override
  String get keyNcr => 'Combinations';

  @override
  String get keyNpr => 'Permutations';

  @override
  String get keyAngle => 'Angle (polar form)';

  @override
  String get keyDegree => 'Degree sign';

  @override
  String get keyIntegral => 'Definite integral';

  @override
  String get keyDerivative => 'Derivative at a point';

  @override
  String get keySum => 'Summation';

  @override
  String get keyProduct => 'Product';

  @override
  String get keyLimit => 'Limit';

  @override
  String get keyEquation => 'Equals sign';

  @override
  String get keyStore => 'Store';

  @override
  String get keyRandom => 'Random number';

  @override
  String get keyRandomInt => 'Random integer';

  @override
  String get keyVariableX => 'Variable x';

  @override
  String get keyMemoryClear => 'Memory clear';

  @override
  String get keyMemoryRecall => 'Memory recall';

  @override
  String get keyMemoryAdd => 'Memory add';

  @override
  String get keyMemorySubtract => 'Memory subtract';

  @override
  String get keyMemoryStore => 'Memory store';

  @override
  String get keyFormatToggle => 'Switch between exact and decimal';

  @override
  String keyDigit(String digit) {
    return '$digit';
  }

  @override
  String keyVariable(String name) {
    return 'Variable $name';
  }

  @override
  String get keyFloor => 'Floor';

  @override
  String get keyCeil => 'Ceiling';

  @override
  String get keyRound => 'Round';

  @override
  String get keyGcd => 'Greatest common divisor';

  @override
  String get keyLcm => 'Least common multiple';

  @override
  String get keyMod => 'Modulo';

  @override
  String get keyConj => 'Complex conjugate';

  @override
  String get errEmptyInput => 'Enter an expression first.';

  @override
  String get errInvalidExpression => 'Invalid expression.';

  @override
  String errInvalidExpressionDetail(String detail) {
    return 'Invalid expression: $detail.';
  }

  @override
  String errUnexpectedToken(String token) {
    return 'Unexpected “$token” in the expression.';
  }

  @override
  String get errMissingClose =>
      'Mismatched parentheses: a closing bracket is missing.';

  @override
  String get errMissingOpen =>
      'Mismatched parentheses: there is an extra closing bracket.';

  @override
  String get errMissingArgument => 'A number or expression is missing.';

  @override
  String errMissingArgumentAfter(String after) {
    return 'A number or expression is missing after “$after”.';
  }

  @override
  String errUnknownIdentifier(String name) {
    return 'Unknown function or variable “$name”.';
  }

  @override
  String errUndefinedVariable(String name) {
    return 'Variable “$name” has no value yet.';
  }

  @override
  String errWrongArgumentCount(String name, String expected, String got) {
    return '$name() expects $expected argument(s) but got $got.';
  }

  @override
  String get errDivisionByZero => 'Division by zero is undefined.';

  @override
  String get errUndefinedResult => 'The result is undefined.';

  @override
  String errUndefinedResultDetail(String detail) {
    return 'The result is undefined: $detail.';
  }

  @override
  String errDomain(String function, String value) {
    return 'Domain error: $function is not defined for $value.';
  }

  @override
  String get errComplexResult =>
      'Complex result: turn on complex results in settings or include i in the expression.';

  @override
  String get errOverflow => 'Overflow: the result is too large to represent.';

  @override
  String errNonInteger(String function) {
    return '$function requires whole numbers.';
  }

  @override
  String errNegative(String function) {
    return '$function requires non-negative numbers.';
  }

  @override
  String errTooLarge(String function, String limit) {
    return 'Input too large for $function (limit $limit).';
  }

  @override
  String get errDimension => 'Matrix dimensions do not match.';

  @override
  String errDimensionDetail(String detail) {
    return 'Dimensions do not match: $detail.';
  }

  @override
  String get errSingular =>
      'The matrix is singular (determinant 0), so it has no inverse.';

  @override
  String errNotSquare(String operation) {
    return '$operation requires a square matrix.';
  }

  @override
  String get errEmptyMatrix => 'The matrix is empty.';

  @override
  String get errNoRealSolution => 'There is no real solution.';

  @override
  String get errNoSolution =>
      'The system has no solution (it is inconsistent).';

  @override
  String get errInfiniteSolutions => 'There are infinitely many solutions.';

  @override
  String get errNoConvergence => 'The calculation did not converge.';

  @override
  String errNoConvergenceDetail(String detail) {
    return 'The calculation did not converge: $detail.';
  }

  @override
  String get errNotSupported => 'This operation is not supported.';

  @override
  String errInvalidAssignment(String name) {
    return 'Cannot assign a value to “$name”.';
  }

  @override
  String get errRecursion => 'The expression is nested too deeply.';

  @override
  String get errCancelled => 'Calculation cancelled.';

  @override
  String get errTimeout => 'The calculation took too long and was stopped.';

  @override
  String get historyTitle => 'History';

  @override
  String get historySearch => 'Search history';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String get historyPrevious7 => 'Previous 7 days';

  @override
  String get historyPrevious30 => 'Previous 30 days';

  @override
  String get historyOlder => 'Older';

  @override
  String get historyEmpty => 'No calculations yet';

  @override
  String get historyClearAll => 'Clear history';

  @override
  String get historyClearConfirm =>
      'Delete all history except favorites? This cannot be undone.';

  @override
  String get historyReuse => 'Reuse';

  @override
  String get historyFavoritesOnly => 'Favorites only';

  @override
  String get historyDisabled => 'Saving history is turned off in settings.';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesEmpty =>
      'Star calculations, formulas, constants and converters to find them here.';

  @override
  String get favoritesCalculations => 'Calculations';

  @override
  String get favoritesFormulas => 'Formulas';

  @override
  String get favoritesConstants => 'Constants';

  @override
  String get favoritesConverters => 'Converters';

  @override
  String get favoritesTools => 'Tools';

  @override
  String get variablesTitle => 'Variables';

  @override
  String get variablesEmpty =>
      'Store values with the STO key or write name = value in the calculator.';

  @override
  String get variablesAdd => 'New variable';

  @override
  String get variablesName => 'Name';

  @override
  String get variablesValue => 'Value';

  @override
  String get variablesInvalidName =>
      'Use letters, digits and _ ; start with a letter.';

  @override
  String get variablesReserved => 'This name is reserved.';

  @override
  String get variablesAnsNote => 'Ans holds the most recent successful result.';

  @override
  String get functionsTitle => 'Saved functions';

  @override
  String get functionsEmpty =>
      'Define functions such as f(x) = x² to use them in the calculator and graphs.';

  @override
  String get functionsAdd => 'New function';

  @override
  String get functionsName => 'Name';

  @override
  String get functionsExpression => 'Expression in x';

  @override
  String functionsLimitReached(int count) {
    return 'Free version limit reached ($count functions). Upgrade to Premium for unlimited saved functions and graphs.';
  }

  @override
  String get functionsPlot => 'Plot';

  @override
  String get functionsTable => 'Table';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search tools, functions, constants, formulas…';

  @override
  String get searchNoResults => 'No matches';

  @override
  String get searchSectionTools => 'Tools';

  @override
  String get searchSectionFunctions => 'Functions';

  @override
  String get searchSectionConstants => 'Constants';

  @override
  String get searchSectionFormulas => 'Formulas';

  @override
  String get searchSectionUnits => 'Unit converters';

  @override
  String get searchSectionSettings => 'Settings';

  @override
  String get toolsTitle => 'Tools';

  @override
  String get toolsQuickAccess => 'Quick access';

  @override
  String get toolsCustomize => 'Customize quick access';

  @override
  String get toolsAll => 'All tools';

  @override
  String get toolMatrix => 'Matrix';

  @override
  String get toolVector => 'Vector';

  @override
  String get toolComplex => 'Complex';

  @override
  String get toolCalculus => 'Calculus';

  @override
  String get toolDerivative => 'Derivative';

  @override
  String get toolIntegral => 'Integral';

  @override
  String get toolLimit => 'Limit';

  @override
  String get toolSeries => 'Sum & product';

  @override
  String get toolStatistics => 'Statistics';

  @override
  String get toolProbability => 'Probability';

  @override
  String get toolNumberTheory => 'Number theory';

  @override
  String get toolConverter => 'Unit converter';

  @override
  String get toolConstants => 'Constants';

  @override
  String get toolFormulas => 'Formulas';

  @override
  String get toolProgrammer => 'Programmer';

  @override
  String get toolTable => 'Function table';

  @override
  String get toolCas => 'Algebra (CAS)';

  @override
  String get toolEquation => 'Equation';

  @override
  String get toolPolynomial => 'Polynomial';

  @override
  String get toolSystem => 'Simultaneous equations';

  @override
  String get toolGraph => 'Graph';

  @override
  String get toolRandom => 'Random numbers';

  @override
  String get toolVariables => 'Variables';

  @override
  String get toolFunctions => 'Saved functions';

  @override
  String get toolFavorites => 'Favorites';

  @override
  String get toolHistory => 'History';

  @override
  String get solveTitle => 'Solve';

  @override
  String get solveEquationSubtitle => 'Any equation in one unknown';

  @override
  String get solvePolynomialSubtitle =>
      'Roots with multiplicity, real and complex';

  @override
  String get solveSystemSubtitle => '2 to 6 linear equations';

  @override
  String get solveCasSubtitle =>
      'Simplify, expand, factor, collect, substitute';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsCalculator => 'Calculator';

  @override
  String get settingsDisplay => 'Display';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsInput => 'Input';

  @override
  String get settingsGraph => 'Graph';

  @override
  String get settingsHistory => 'History';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsBackup => 'Backup & restore';

  @override
  String get settingsPremium => 'Premium';

  @override
  String get settingsAngleUnit => 'Angle unit';

  @override
  String get settingsResultFormat => 'Result format';

  @override
  String get settingsNumberFormat => 'Number format';

  @override
  String get settingsPrecision => 'Precision';

  @override
  String settingsPrecisionDigits(int digits) {
    return '$digits significant digits';
  }

  @override
  String get settingsThousands => 'Thousands separator';

  @override
  String get settingsDecimalSeparator => 'Decimal separator';

  @override
  String get settingsDecimalPoint => 'Point (1.5)';

  @override
  String get settingsDecimalComma => 'Comma (1,5)';

  @override
  String get settingsComplexFormat => 'Complex number format';

  @override
  String get settingsComplexResults => 'Allow complex results';

  @override
  String get settingsComplexResultsSub => '√(−1) = i instead of an error';

  @override
  String get settingsEngSymbols => 'Engineering symbols';

  @override
  String get settingsEngSymbolsSub =>
      'Show 1.2M instead of 1.2×10⁶ in engineering notation';

  @override
  String get settingsMemoryPersists => 'Keep memory after restart';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeAmoled => 'AMOLED black';

  @override
  String get settingsAccent => 'Accent color';

  @override
  String get settingsFontSize => 'Font size';

  @override
  String get settingsDisplaySize => 'Display size';

  @override
  String get settingsButtonSize => 'Button size';

  @override
  String get settingsSmall => 'Small';

  @override
  String get settingsMedium => 'Medium';

  @override
  String get settingsLarge => 'Large';

  @override
  String get settingsCompact => 'Compact';

  @override
  String get settingsNormal => 'Normal';

  @override
  String get settingsButtonLabels => 'Show secondary key labels';

  @override
  String get settingsAnimations => 'Animations';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsHapticsOff => 'Off';

  @override
  String get settingsHapticsLight => 'Light';

  @override
  String get settingsHapticsMedium => 'Medium';

  @override
  String get settingsSound => 'Key sounds';

  @override
  String get settingsSoundSub => 'Follows your device\'s sound settings';

  @override
  String get settingsKeyboard => 'Keyboard layout';

  @override
  String get settingsKeyboardScientific => 'Scientific';

  @override
  String get settingsKeyboardBasic => 'Basic';

  @override
  String get settingsLivePreview => 'Live result preview';

  @override
  String get settingsGraphGrid => 'Show grid';

  @override
  String get settingsGraphAxes => 'Show axes';

  @override
  String get settingsGraphLabels => 'Show axis labels';

  @override
  String get settingsGraphLineWidth => 'Line width';

  @override
  String get settingsGraphDegrees => 'Use degrees for graph trigonometry';

  @override
  String get settingsSaveHistory => 'Save calculation history';

  @override
  String settingsHistoryLimit(int count) {
    return 'Keep up to $count entries';
  }

  @override
  String get settingsRandomSeed => 'Random seed';

  @override
  String get settingsRandomSeedOff => 'Not set (unpredictable)';

  @override
  String get settingsResetAll => 'Reset settings';

  @override
  String get settingsResetConfirm => 'Restore all settings to their defaults?';

  @override
  String get settingsClearData => 'Delete all data';

  @override
  String get settingsClearDataConfirm =>
      'Delete history, favorites, variables, matrices and saved functions? This cannot be undone.';

  @override
  String get settingsPremiumTheme => 'Premium';

  @override
  String get backupTitle => 'Backup & restore';

  @override
  String get backupExport => 'Export backup';

  @override
  String get backupExportSub =>
      'Save history, favorites, variables, matrices, functions and settings to a file';

  @override
  String get backupImport => 'Import backup';

  @override
  String get backupImportSub => 'Restore from a backup file';

  @override
  String get backupImportConfirm =>
      'Importing replaces your current data with the backup. Continue?';

  @override
  String get backupImported => 'Backup restored';

  @override
  String get backupInvalid =>
      'This file is not a valid Advanced Calculator backup.';

  @override
  String get backupExported => 'Backup ready to save or share';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyBody =>
      'Advanced Calculator works fully offline. It does not require an account and does not collect analytics, crash reports, or advertising data. Your calculations, history, variables and settings are stored only on this device. They leave the device only when you choose to share, copy or export them.';

  @override
  String get privacyPurchases =>
      'If you buy Premium, the purchase is handled by Google Play or the App Store. The app only stores whether Premium is unlocked, in the device\'s secure storage.';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'A scientific, graphing and algebra calculator that runs entirely on your device.';

  @override
  String get aboutEngine =>
      'Exact rational arithmetic, arbitrary-precision decimals (up to 100 digits), a computer algebra system, numerical calculus and adaptive graphing — all implemented locally.';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumHeadline => 'Support development and unlock extras';

  @override
  String get premiumCoreFree =>
      'Every calculator, solver and tool stays free. Premium adds:';

  @override
  String get premiumFeatureThemes => '7 additional accent themes';

  @override
  String get premiumFeatureGraphs => 'Unlimited saved functions and graphs';

  @override
  String get premiumFeatureSupport => 'Support future updates';

  @override
  String premiumBuy(String price) {
    return 'Unlock Premium — $price';
  }

  @override
  String get premiumRestore => 'Restore purchase';

  @override
  String get premiumActive => 'Premium is active. Thank you!';

  @override
  String get premiumPending =>
      'Purchase pending… it will unlock once the payment completes.';

  @override
  String get premiumFailed => 'The purchase did not complete.';

  @override
  String get premiumUnavailable =>
      'The store is not available right now. Check your connection and try again.';

  @override
  String get premiumRestored => 'Purchases restored';

  @override
  String get premiumNothingToRestore =>
      'No previous purchase was found for this account.';

  @override
  String get premiumRequired => 'This is a Premium feature.';

  @override
  String get premiumLoading => 'Contacting the store…';

  @override
  String get catArithmetic => 'Arithmetic';

  @override
  String get catPowers => 'Powers & roots';

  @override
  String get catLogarithms => 'Logarithms';

  @override
  String get catTrigonometry => 'Trigonometry';

  @override
  String get catHyperbolic => 'Hyperbolic';

  @override
  String get catRounding => 'Rounding';

  @override
  String get catNumberTheory => 'Number theory';

  @override
  String get catProbability => 'Probability';

  @override
  String get catStatistics => 'Statistics';

  @override
  String get catComplex => 'Complex';

  @override
  String get catMatrix => 'Matrix & vector';

  @override
  String get catVector => 'Vector';

  @override
  String get catCalculus => 'Calculus';

  @override
  String get catRandom => 'Random';

  @override
  String get graphAddFunction => 'Add function';

  @override
  String get graphFunctions => 'Functions';

  @override
  String get graphWindow => 'Window';

  @override
  String get graphXMin => 'x min';

  @override
  String get graphXMax => 'x max';

  @override
  String get graphYMin => 'y min';

  @override
  String get graphYMax => 'y max';

  @override
  String get graphInvalidWindow =>
      'Each minimum must be less than its maximum.';

  @override
  String get graphZoomIn => 'Zoom in';

  @override
  String get graphZoomOut => 'Zoom out';

  @override
  String get graphReset => 'Reset view';

  @override
  String get graphAutoFit => 'Fit to curves';

  @override
  String get graphTrace => 'Trace';

  @override
  String get graphTangent => 'Tangent';

  @override
  String get graphAnalyze => 'Analyze';

  @override
  String get graphOnlyCartesian =>
      'Analysis works on y = f(x) graphs. Select one in the list.';

  @override
  String get graphRoots => 'Roots (x-intercepts)';

  @override
  String get graphExtrema => 'Minimum and maximum';

  @override
  String get graphIntersections => 'Intersections';

  @override
  String get graphYIntercept => 'y-intercept';

  @override
  String get graphArea => 'Area under curve';

  @override
  String get graphNeedTwo =>
      'Add a second y = f(x) graph to find intersections.';

  @override
  String get graphSecondFunction => 'Intersect with';

  @override
  String get graphNoPoints => 'Nothing found in the visible range.';

  @override
  String get graphAreaFrom => 'From x =';

  @override
  String get graphAreaTo => 'To x =';

  @override
  String get graphSlope => 'slope';

  @override
  String graphTangentEquation(String equation) {
    return 'Tangent: $equation';
  }

  @override
  String graphAreaResult(String value) {
    return 'Area ≈ $value';
  }

  @override
  String get graphRoot => 'Root';

  @override
  String get graphMinimum => 'Minimum';

  @override
  String get graphMaximum => 'Maximum';

  @override
  String get graphIntersection => 'Intersection';

  @override
  String get graphNoFunctions => 'Add a function to start graphing.';

  @override
  String get graphHide => 'Hide graph';

  @override
  String get graphShow => 'Show graph';

  @override
  String get graphTypeCartesian => 'Function y = f(x)';

  @override
  String get graphTypeCartesianShort => 'y=f(x)';

  @override
  String get graphTypePolar => 'Polar r = f(θ)';

  @override
  String get graphTypePolarShort => 'Polar';

  @override
  String get graphTypeParametric => 'Parametric x(t), y(t)';

  @override
  String get graphTypeParametricShort => 'Param.';

  @override
  String get graphTypeImplicit => 'Implicit F(x, y) = 0';

  @override
  String get graphTypeImplicitShort => 'Implicit';

  @override
  String get graphName => 'Name (optional)';

  @override
  String get graphNameHelp => 'Name it (e.g. f) to use f(x) in the calculator';

  @override
  String get graphExpressionCartesian => 'y =';

  @override
  String get graphExpressionPolar => 'r =';

  @override
  String get graphExpressionX => 'x(t) =';

  @override
  String get graphExpressionY => 'y(t) =';

  @override
  String get graphExpressionImplicit => 'Equation in x and y';

  @override
  String graphParamMin(String name) {
    return '$name min';
  }

  @override
  String graphParamMax(String name) {
    return '$name max';
  }

  @override
  String get graphColor => 'Color';

  @override
  String get convTitle => 'Unit converter';

  @override
  String get convCategory => 'Category';

  @override
  String get convFrom => 'From';

  @override
  String get convTo => 'To';

  @override
  String get convValue => 'Value';

  @override
  String get convValueHint => 'e.g. 2.5, 1/3 or 2.5E3';

  @override
  String get convSwap => 'Swap units';

  @override
  String get convSearchUnits => 'Search units';

  @override
  String get convSearchAllUnits => 'Search all units';

  @override
  String get convNoUnits => 'No units match your search.';

  @override
  String get convSelectFromUnit => 'Convert from';

  @override
  String get convSelectToUnit => 'Convert to';

  @override
  String convFromUnitLabel(String unit) {
    return 'From unit: $unit';
  }

  @override
  String convToUnitLabel(String unit) {
    return 'To unit: $unit';
  }

  @override
  String get convResult => 'Result';

  @override
  String convExactValue(String value) {
    return 'Exact: $value';
  }

  @override
  String get convAllUnits => 'All units in this category';

  @override
  String get convAllUnitsHint => 'Tap a unit to convert to it.';

  @override
  String get convRecent => 'Recent conversions';

  @override
  String get convRecentEmpty => 'Your conversions appear here.';

  @override
  String get convClearRecent => 'Clear recent conversions';

  @override
  String get convFavoriteUnits => 'Favorite units';

  @override
  String get convFavoriteCategory => 'Add category to favorites';

  @override
  String get convUnfavoriteCategory => 'Remove category from favorites';

  @override
  String convFavoriteUnit(String unit) {
    return 'Add $unit to favorites';
  }

  @override
  String convUnfavoriteUnit(String unit) {
    return 'Remove $unit from favorites';
  }

  @override
  String get convEnterValue => 'Enter a value to convert.';

  @override
  String get convNotReal =>
      'Enter a real number (complex values and lists cannot be converted).';

  @override
  String get convBelowAbsoluteZero =>
      'This temperature is below absolute zero (0 K = −273.15 °C = −459.67 °F). Nothing can be colder, so the value cannot be converted.';

  @override
  String get convReciprocalZero =>
      'Zero cannot be converted between these units: one of them is the reciprocal of the other (for example L/100 km and km/L), so the result would be infinite.';

  @override
  String get convCopyResult => 'Copy result';

  @override
  String get convOtherCategories => 'Units in other categories';

  @override
  String get constTitle => 'Constants';

  @override
  String get constSearch => 'Search constants';

  @override
  String get constAll => 'All';

  @override
  String get constFavorites => 'Favorites';

  @override
  String get constCatMathematical => 'Mathematical';

  @override
  String get constCatUniversal => 'Universal';

  @override
  String get constCatElectromagnetic => 'Electromagnetic';

  @override
  String get constCatAtomic => 'Atomic & nuclear';

  @override
  String get constCatPhysicoChemical => 'Physico-chemical';

  @override
  String get constCatAstronomical => 'Astronomical';

  @override
  String get constCatAdopted => 'Adopted values';

  @override
  String get constExact => 'Exact by definition';

  @override
  String constUncertainty(String value) {
    return 'Standard uncertainty: $value';
  }

  @override
  String get constMeasured => 'Measured value';

  @override
  String get constDimensionless => 'dimensionless';

  @override
  String constUsage(String code) {
    return 'Use in expressions as $code';
  }

  @override
  String get constCopyValue => 'Copy value';

  @override
  String get constInsert => 'Insert into calculator';

  @override
  String get constNoResults => 'No constants match your search.';

  @override
  String get constNoFavorites => 'Star a constant to keep it here.';

  @override
  String get formulaTitle => 'Formulas';

  @override
  String get formulaSearch => 'Search formulas';

  @override
  String get formulaAll => 'All';

  @override
  String get formulaFavorites => 'Favorites';

  @override
  String get formulaNoResults => 'No formulas match your search.';

  @override
  String get formulaNoFavorites => 'Star a formula to keep it here.';

  @override
  String get formulaCatAlgebra => 'Algebra';

  @override
  String get formulaCatGeometry => 'Geometry';

  @override
  String get formulaCatTrigonometry => 'Trigonometry';

  @override
  String get formulaCatCalculus => 'Calculus';

  @override
  String get formulaCatStatistics => 'Statistics';

  @override
  String get formulaCatProbability => 'Probability';

  @override
  String get formulaCatPhysics => 'Physics';

  @override
  String get formulaCatMechanics => 'Mechanics';

  @override
  String get formulaCatElectricity => 'Electricity';

  @override
  String get formulaCatMagnetism => 'Magnetism';

  @override
  String get formulaCatThermodynamics => 'Thermodynamics';

  @override
  String get formulaCatOptics => 'Optics';

  @override
  String get formulaCatWaves => 'Waves';

  @override
  String formulaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formulas',
      one: '1 formula',
    );
    return '$_temp0';
  }

  @override
  String get formulaNotFound => 'This formula could not be found.';

  @override
  String get formulaVariables => 'Variables';

  @override
  String get formulaDescription => 'About';

  @override
  String get formulaRelated => 'Related formulas';

  @override
  String get formulaCalculate => 'Calculate';

  @override
  String get formulaCalculateHint =>
      'Fill in every value except the one you want to find, then tap Solve.';

  @override
  String get formulaNeedOneEmpty =>
      'Leave exactly one field empty: that is the value to solve for.';

  @override
  String get formulaInvalidValue => 'Enter a real number';

  @override
  String formulaSolvingFor(String name) {
    return 'Solving for $name';
  }

  @override
  String formulaSeveralSolutions(int count) {
    return 'The equation has $count real solutions; all are shown.';
  }

  @override
  String get formulaNumericNote =>
      'Found numerically, so the value is approximate.';

  @override
  String formulaAlwaysTrue(String name) {
    return 'These values satisfy the formula for every value of $name.';
  }

  @override
  String get formulaComplexOnly =>
      'There is no real solution for these values (only complex ones).';

  @override
  String get formulaClearFields => 'Clear all fields';

  @override
  String get formulaCopySolution => 'Copy solution';

  @override
  String get formulaNoCalculator =>
      'This formula is a reference identity, so it has no calculator.';

  @override
  String get progTitle => 'Programmer';

  @override
  String get progBase => 'Input base';

  @override
  String get progWordSize => 'Word size';

  @override
  String progBitsLabel(int bits) {
    return '$bits-bit';
  }

  @override
  String get progSigned => 'Signed (two\'s complement)';

  @override
  String get progUnsigned => 'Unsigned';

  @override
  String get progExpression => 'Expression';

  @override
  String get progExpressionHint => 'e.g. FF AND 0F << 2';

  @override
  String progRange(String min, String max) {
    return 'Range: $min to $max';
  }

  @override
  String get progBin => 'Binary';

  @override
  String get progOct => 'Octal';

  @override
  String get progDec => 'Decimal';

  @override
  String get progHex => 'Hexadecimal';

  @override
  String progCopyBase(String base) {
    return 'Copy $base value';
  }

  @override
  String get progBits => 'Bits';

  @override
  String get progBitsHint => 'Tap a bit to toggle it.';

  @override
  String progBitLabel(int index, int value) {
    return 'Bit $index is $value. Double tap to toggle.';
  }

  @override
  String get progAllClear => 'All clear';

  @override
  String get progBackspace => 'Delete';

  @override
  String get progEquals => 'Equals';

  @override
  String progKeyLabel(String key) {
    return 'Insert $key';
  }

  @override
  String get progEmpty => 'Type an expression or use the keypad.';

  @override
  String get ntTitle => 'Number theory';

  @override
  String get ntNumber => 'Number n';

  @override
  String get ntNumberHint => 'Whole number, e.g. 360 or 2^61-1';

  @override
  String get ntAnalyze => 'Analyze';

  @override
  String get ntPrimeTest => 'Prime test';

  @override
  String ntIsPrime(String n) {
    return '$n is prime.';
  }

  @override
  String ntNotPrime(String n) {
    return '$n is not prime.';
  }

  @override
  String ntSmallestFactor(String p) {
    return 'Smallest prime factor: $p';
  }

  @override
  String get ntFactorization => 'Prime factorization';

  @override
  String get ntDivisors => 'Divisors';

  @override
  String ntDivisorCount(String count) {
    return 'Number of divisors: $count';
  }

  @override
  String ntDivisorSum(String sum) {
    return 'Sum of divisors: $sum';
  }

  @override
  String ntMoreDivisors(int count) {
    return '… and $count more';
  }

  @override
  String get ntNextPrime => 'Next prime';

  @override
  String get ntPrevPrime => 'Previous prime';

  @override
  String ntNoPrevPrime(String n) {
    return 'None: there is no prime below $n.';
  }

  @override
  String get ntTotient => 'Euler\'s totient φ(n)';

  @override
  String get ntGcdLcm => 'GCD & LCM';

  @override
  String get ntNumbers => 'Numbers';

  @override
  String get ntNumbersHint => 'Separate with commas, e.g. 48, 180, 36';

  @override
  String get ntNeedTwo =>
      'Enter at least two whole numbers separated by commas.';

  @override
  String get ntGcd => 'Greatest common divisor';

  @override
  String get ntLcm => 'Least common multiple';

  @override
  String ntEuclidStep(String a, String b, String q, String r) {
    return 'Divide $a by $b: quotient $q, remainder $r.';
  }

  @override
  String ntEuclidDone(String a, String b, String g) {
    return 'The remainder is 0, so gcd($a, $b) = $g (the last non-zero remainder).';
  }

  @override
  String ntEuclidZero(String a, String g) {
    return 'gcd($a, 0) = $g, because every number divides 0.';
  }

  @override
  String get ntDivision => 'Division & modulo';

  @override
  String get ntDividend => 'Dividend a';

  @override
  String get ntDivisor => 'Divisor b';

  @override
  String get ntQuotient => 'Quotient (truncated)';

  @override
  String get ntRemainder => 'Remainder (sign of a)';

  @override
  String get ntModulo => 'a mod b (sign of b)';

  @override
  String ntNotInteger(String field) {
    return '$field must be a whole number.';
  }

  @override
  String get randTitle => 'Random numbers';

  @override
  String get randSeed => 'Seed (optional)';

  @override
  String get randSeedHint => 'Whole number for a reproducible sequence';

  @override
  String get randApplySeed => 'Apply seed';

  @override
  String get randClearSeed => 'Clear seed';

  @override
  String randSeedActive(String seed) {
    return 'Seed $seed is active: the same seed always gives the same sequence. Apply it again to restart.';
  }

  @override
  String get randSeedOff => 'No seed: numbers are unpredictable.';

  @override
  String get randSeedInvalid => 'The seed must be a whole number.';

  @override
  String get randDecimal => 'Decimal in [0, 1)';

  @override
  String get randInteger => 'Integer in [a, b]';

  @override
  String get randRange => 'Decimal in [a, b)';

  @override
  String get randList => 'List of integers';

  @override
  String get randPermutation => 'Permutation of 1…n';

  @override
  String get randMin => 'a (minimum)';

  @override
  String get randMax => 'b (maximum)';

  @override
  String get randCount => 'n (how many)';

  @override
  String get randAllowDuplicates => 'Allow duplicates';

  @override
  String get randGenerate => 'Generate';

  @override
  String get randDice => 'Roll a die';

  @override
  String get randCoin => 'Flip a coin';

  @override
  String get randHeads => 'Heads';

  @override
  String get randTails => 'Tails';

  @override
  String get randResults => 'Results';

  @override
  String get randNoResults => 'Generated numbers appear here.';

  @override
  String get randClearResults => 'Clear results';

  @override
  String get randCopyAll => 'Copy all results';

  @override
  String randTooFew(String available, String count) {
    return 'Only $available different values exist between a and b, fewer than the $count requested.';
  }

  @override
  String get randCountRange => 'n must be a whole number from 1 to 10000.';

  @override
  String get randNotReal => 'Enter a real number.';

  @override
  String get matrixTitle => 'Matrix calculator';

  @override
  String get matrixEditorTitle => 'Matrix editor';

  @override
  String get matrixSlotEmpty => 'empty';

  @override
  String matrixSlotSize(int rows, int columns) {
    return '$rows×$columns';
  }

  @override
  String get matrixRows => 'Rows';

  @override
  String get matrixColumns => 'Columns';

  @override
  String get matrixRowsDecrease => 'Remove the last row';

  @override
  String get matrixRowsIncrease => 'Add a row';

  @override
  String get matrixColumnsDecrease => 'Remove the last column';

  @override
  String get matrixColumnsIncrease => 'Add a column';

  @override
  String get matrixInsertRow => 'Insert a row above the selected cell';

  @override
  String get matrixDeleteRow => 'Delete the selected row';

  @override
  String get matrixInsertColumn => 'Insert a column left of the selected cell';

  @override
  String get matrixDeleteColumn => 'Delete the selected column';

  @override
  String get matrixClearValues => 'Clear values';

  @override
  String get matrixIdentityFill => 'Fill with the identity matrix';

  @override
  String get matrixZeroFill => 'Fill with zeros';

  @override
  String get matrixPasteValues => 'Paste values';

  @override
  String get matrixCopyMatrix => 'Copy matrix';

  @override
  String get matrixDeleteMatrix => 'Delete matrix';

  @override
  String matrixDeleted(String name) {
    return '$name deleted';
  }

  @override
  String get matrixPasteEmpty =>
      'The clipboard does not contain matrix values.';

  @override
  String matrixPasted(int rows, int columns) {
    return 'Pasted a $rows×$columns matrix';
  }

  @override
  String matrixPasteTrimmed(int rows, int columns) {
    return 'The pasted values were trimmed to $rows×$columns.';
  }

  @override
  String get matrixIdentityNeedsSquare =>
      'The identity matrix is square: make the numbers of rows and columns equal first.';

  @override
  String get matrixMinSize => 'A matrix needs at least one row and one column.';

  @override
  String matrixMaxSize(int max) {
    return 'The editor allows up to $max rows and $max columns.';
  }

  @override
  String matrixCellLabel(String name, int row, int column) {
    return '$name, row $row, column $column';
  }

  @override
  String matrixCellError(String name, int row, int column, String error) {
    return '$name, row $row, column $column: $error';
  }

  @override
  String get matrixCellNotNumber => 'each cell must be a single number';

  @override
  String matrixUndefined(String name) {
    return '$name is empty. Enter its values in the matrix editor first.';
  }

  @override
  String matrixVariableHint(String name) {
    return 'Use $name in the calculator, for example det($name).';
  }

  @override
  String get matrixOperations => 'Operations';

  @override
  String get matrixOperandFirst => 'Matrix A';

  @override
  String get matrixOperandSecond => 'Matrix B';

  @override
  String get matrixScalar => 'Scalar k';

  @override
  String get matrixExponent => 'Exponent n';

  @override
  String get matrixExponentInteger => 'The exponent must be a whole number.';

  @override
  String get matrixOpAdd => 'A + B';

  @override
  String get matrixOpSubtract => 'A − B';

  @override
  String get matrixOpMultiply => 'A × B';

  @override
  String get matrixOpScalar => 'k × A';

  @override
  String get matrixOpTranspose => 'Transpose Aᵀ';

  @override
  String get matrixOpDeterminant => 'Determinant';

  @override
  String get matrixOpInverse => 'Inverse A⁻¹';

  @override
  String get matrixOpRank => 'Rank';

  @override
  String get matrixOpTrace => 'Trace';

  @override
  String get matrixOpRef => 'Row echelon form (REF)';

  @override
  String get matrixOpRref => 'Reduced row echelon form (RREF)';

  @override
  String get matrixOpPower => 'Power Aⁿ';

  @override
  String get matrixOpEigen => 'Eigenvalues and eigenvectors';

  @override
  String get matrixResult => 'Result';

  @override
  String get matrixSaveTo => 'Save to matrix';

  @override
  String matrixSavedTo(String name) {
    return 'Saved to $name';
  }

  @override
  String get matrixStoreVariable => 'Store in variable';

  @override
  String matrixStoredIn(String name) {
    return 'Stored in $name';
  }

  @override
  String matrixEigenvalueSemantics(int index, String value, int count) {
    return 'Eigenvalue $index: $value, multiplicity $count';
  }

  @override
  String matrixEigenvectorSemantics(String value) {
    return 'Eigenvector: $value';
  }

  @override
  String matrixMultiplicity(int count) {
    return 'multiplicity $count';
  }

  @override
  String get matrixNoEigenvector =>
      'No eigenvector could be computed for this eigenvalue.';

  @override
  String get vectorTitle => 'Vector calculator';

  @override
  String get vectorDimension => 'Dimension';

  @override
  String get vector2d => '2D';

  @override
  String get vector3d => '3D';

  @override
  String get vectorNd => 'n-D';

  @override
  String vectorComponentCount(int count) {
    return '$count components';
  }

  @override
  String get vectorFewerComponents => 'Fewer components';

  @override
  String get vectorMoreComponents => 'More components';

  @override
  String get vectorA => 'Vector A';

  @override
  String get vectorB => 'Vector B';

  @override
  String vectorComponentLabel(String name, int index) {
    return '$name component $index';
  }

  @override
  String vectorComponentError(String name, int index, String error) {
    return '$name, component $index: $error';
  }

  @override
  String get vectorNotNumber => 'each component must be a single number';

  @override
  String get vectorOperations => 'Operations';

  @override
  String get vectorOpAdd => 'A + B';

  @override
  String get vectorOpSubtract => 'A − B';

  @override
  String get vectorOpNormA => '|A|';

  @override
  String get vectorOpNormB => '|B|';

  @override
  String get vectorOpUnit => 'Unit vector of A';

  @override
  String get vectorOpDot => 'Dot product A · B';

  @override
  String get vectorOpCross => 'Cross product A × B';

  @override
  String get vectorOpAngle => 'Angle between A and B';

  @override
  String get vectorOpProjection => 'Projection of A onto B';

  @override
  String get vectorOpDistance => 'Distance between A and B';

  @override
  String get vectorResult => 'Result';

  @override
  String get complexTitle => 'Complex numbers';

  @override
  String get complexInputForm => 'Input form';

  @override
  String get complexInputRectangular => 'Rectangular a + bi';

  @override
  String get complexInputPolar => 'Polar r∠θ';

  @override
  String get complexFirst => 'z₁';

  @override
  String get complexSecond => 'z₂';

  @override
  String get complexRealPart => 'a (real part)';

  @override
  String get complexImaginaryPart => 'b (imaginary part)';

  @override
  String get complexModulusField => 'r (modulus)';

  @override
  String complexAngleField(String unit) {
    return 'θ ($unit)';
  }

  @override
  String complexFieldLabel(String number, String field) {
    return '$number $field';
  }

  @override
  String get complexExponentField => 'n (power and roots)';

  @override
  String complexFieldError(String field, String error) {
    return '$field: $error';
  }

  @override
  String get complexNotReal => 'enter a real number';

  @override
  String get complexRootsRange =>
      'For roots, n must be a whole number from 1 to 100.';

  @override
  String get complexOperations => 'Operations';

  @override
  String get complexOpAdd => 'z₁ + z₂';

  @override
  String get complexOpSubtract => 'z₁ − z₂';

  @override
  String get complexOpMultiply => 'z₁ × z₂';

  @override
  String get complexOpDivide => 'z₁ ÷ z₂';

  @override
  String get complexOpPowerN => 'Power z₁ⁿ';

  @override
  String get complexOpPowerZ => 'Power z₁^z₂';

  @override
  String get complexOpRoots => 'n-th roots of z₁';

  @override
  String get complexOpModulus => 'Modulus |z₁|';

  @override
  String get complexOpArgument => 'Argument arg z₁';

  @override
  String get complexOpConjugate => 'Conjugate of z₁';

  @override
  String get complexOpReal => 'Real part Re z₁';

  @override
  String get complexOpImaginary => 'Imaginary part Im z₁';

  @override
  String get complexOpConvert => 'Rectangular ↔ polar';

  @override
  String get complexResult => 'Result';

  @override
  String complexRootsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count roots',
      one: '1 root',
    );
    return '$_temp0';
  }

  @override
  String get solveWorking => 'Solving…';

  @override
  String get solveEquationInput => 'Equation';

  @override
  String get solveEquationHelp =>
      'Type an equation such as x^2-5x+6=0 or cos(x)=x. Put several linear equations on separate lines to solve them together.';

  @override
  String get solveUseExample => 'Use this example';

  @override
  String get solveVariable => 'Solve for';

  @override
  String solveSolveFor(String name) {
    return 'Solve for $name';
  }

  @override
  String get solveNoVariableYet =>
      'The unknown is detected from the equation (x by default).';

  @override
  String get solveInterval => 'Search interval (optional)';

  @override
  String get solveLower => 'From';

  @override
  String get solveUpper => 'To';

  @override
  String get solveIntervalHelp =>
      'Used when no exact method applies and the equation is solved numerically. Leave empty to search from −1000 to 1000.';

  @override
  String get solveIntervalBoth =>
      'Enter both ends of the search interval, or leave both empty.';

  @override
  String get solveIntervalOrder =>
      'The start of the search interval must be smaller than its end.';

  @override
  String get solveIntervalInvalid => 'Interval ends must be real numbers.';

  @override
  String solveIntervalError(String message) {
    return 'Search interval: $message';
  }

  @override
  String solveSystemDetected(int count) {
    return '$count equations: they will be solved as a system of linear equations.';
  }

  @override
  String solveLineNotEquation(int line) {
    return 'Line $line is not an equation. Write each line as left side = right side.';
  }

  @override
  String solveSystemNonlinear(int line) {
    return 'Line $line is not linear in the unknowns, so the lines cannot be solved as a linear system. Solve nonlinear equations one at a time (enter a single line).';
  }

  @override
  String get solveNoUnknowns => 'These equations contain no unknowns.';

  @override
  String get solveSolution => 'Solution';

  @override
  String solveSolutionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solutions',
      one: '1 solution',
      zero: 'No solutions',
    );
    return '$_temp0';
  }

  @override
  String solveAlwaysTrue(String name) {
    return 'The equation is true for all values of $name.';
  }

  @override
  String get solveNoSolutionFound => 'The equation has no solution.';

  @override
  String get solveNoRootInInterval =>
      'No solution was found in the search interval. Try a different interval.';

  @override
  String get solveNumericNote =>
      'Numerical solution: found by a numerical search and rounded to the current precision.';

  @override
  String solveSearchedInterval(String lower, String upper) {
    return 'Searched from $lower to $upper.';
  }

  @override
  String get solvePeriodicNote =>
      'The equation involves periodic functions, so there may be more solutions outside the searched interval.';

  @override
  String solveSymbolicNote(String name) {
    return 'Solution for $name in terms of the other letters:';
  }

  @override
  String solvePolynomialDegree(int degree) {
    return 'Polynomial of degree $degree';
  }

  @override
  String get solveRealRoot => 'Real';

  @override
  String get solveComplexRoot => 'Complex';

  @override
  String get solveExact => 'Exact';

  @override
  String get solveApproximate => 'Approximate';

  @override
  String solveMultiplicity(int count) {
    return 'Multiplicity $count';
  }

  @override
  String get solveDiscriminant => 'Discriminant';

  @override
  String get solveTwoRealRoots => 'Δ > 0: two distinct real roots.';

  @override
  String get solveRepeatedRoot => 'Δ = 0: one repeated real root.';

  @override
  String get solveComplexPair => 'Δ < 0: two complex conjugate roots.';

  @override
  String solveRootCounts(int real, int complex) {
    return '$real real, $complex complex (counted with multiplicity)';
  }

  @override
  String get solvePreview => 'Preview';

  @override
  String get solvePolyDegree => 'Degree';

  @override
  String get solvePolyQuadratic => 'Quadratic';

  @override
  String get solvePolyExample => 'Example';

  @override
  String solvePolyCoefficientOf(int power) {
    return 'Coefficient of x to the power $power';
  }

  @override
  String get solvePolyEnterCoefficients =>
      'Enter the coefficients of the polynomial.';

  @override
  String get solveSystemUnknowns => 'Number of unknowns';

  @override
  String solveSystemSize(int count) {
    return '$count unknowns';
  }

  @override
  String get solveSystemExample3 => '3 × 3 example';

  @override
  String solveSystemCoefficient(int row, String name) {
    return 'Equation $row, coefficient of $name';
  }

  @override
  String solveSystemConstant(int row) {
    return 'Equation $row, right-hand side';
  }

  @override
  String get solveSystemFieldHelp =>
      'Fields accept numbers and expressions such as 1/3, -2.5 or sqrt(2). Empty fields count as 0.';

  @override
  String get solveSystemEnterCoefficients =>
      'Enter the coefficients of the equations.';

  @override
  String get solveSystemUnique => 'Unique solution';

  @override
  String get solveSystemNone =>
      'The system has no solution (the equations are inconsistent).';

  @override
  String get solveSystemInfinite => 'The system has infinitely many solutions.';

  @override
  String get solveSystemParameters =>
      't₁, t₂, … are free parameters: every choice of their values gives a solution.';

  @override
  String get solveCasInput => 'Expression';

  @override
  String get solveCasInputHelp =>
      'For example (x+1)^2, x^2-9 or sin(x)^2+cos(x)^2. Use = for Solve.';

  @override
  String get solveCasOperation => 'Operation';

  @override
  String get solveCasSimplify => 'Simplify';

  @override
  String get solveCasExpand => 'Expand';

  @override
  String get solveCasFactor => 'Factor';

  @override
  String get solveCasCollect => 'Collect';

  @override
  String get solveCasSubstitute => 'Substitute';

  @override
  String get solveCasDifferentiate => 'Differentiate';

  @override
  String get solveCasIntegrate => 'Integrate';

  @override
  String get solveCasEvaluate => 'Evaluate';

  @override
  String get solveCasValue => 'Value';

  @override
  String get solveCasOrder => 'Order';

  @override
  String get solveCasEnterValue => 'Enter the value to substitute.';

  @override
  String get solveCasInvalidVariable => 'Enter a variable name such as x.';

  @override
  String get solveCasIntegrateNote =>
      'Indefinite integral: the result includes an arbitrary constant C.';

  @override
  String get solveCasSendToCalculator => 'Send to calculator';

  @override
  String get calculusWorking => 'Calculating…';

  @override
  String get calculusRadiansNote =>
      'Calculus uses radians for trigonometric functions, whatever the calculator\'s angle mode.';

  @override
  String get calculusInvalidVariable => 'Enter a variable name such as x.';

  @override
  String calculusFunctionLabel(String variable) {
    return 'f($variable)';
  }

  @override
  String get calculusVariable => 'Variable';

  @override
  String get calculusOrder => 'Order';

  @override
  String calculusAtPointOptional(String variable) {
    return 'At $variable = (optional)';
  }

  @override
  String get calculusPointHint => 'e.g. 2 or pi/4';

  @override
  String get calculusDerivativeHint => 'e.g. x^3+2x or sin(x)·e^x';

  @override
  String get calculusPartialNote =>
      'If the function contains other letters (e.g. y), the partial derivative is taken and those letters are held constant.';

  @override
  String get calculusPartialHeld =>
      'Partial derivative: all other variables were held constant.';

  @override
  String get calculusDifferentiate => 'Differentiate';

  @override
  String get calculusDerivativeEmpty =>
      'Enter a function and tap Differentiate.';

  @override
  String get calculusDerivativeResult => 'Derivative';

  @override
  String get calculusValueAt => 'Value at the point';

  @override
  String get calculusNumericValueAt => 'Numerical value at the point';

  @override
  String get calculusNumericLabel =>
      'Symbolic differentiation is not available for this function, so the value was computed numerically.';

  @override
  String get calculusNumericFallbackHint =>
      'Enter a point and choose order 1 or 2 to get a numerical derivative instead.';

  @override
  String get calculusIntegralHint => 'e.g. x^2 or 1/(1+x^2)';

  @override
  String get calculusLowerBound => 'Lower bound';

  @override
  String get calculusUpperBound => 'Upper bound';

  @override
  String get calculusBoundHint => 'e.g. 0, pi, inf';

  @override
  String get calculusBoundsNote =>
      'Leave both bounds empty for the antiderivative. Bounds accept numbers, expressions such as pi/2, and inf or -inf.';

  @override
  String get calculusBothBounds => 'Enter both bounds, or leave both empty.';

  @override
  String get calculusIntegrate => 'Integrate';

  @override
  String get calculusIntegralEmpty => 'Enter a function and tap Integrate.';

  @override
  String get calculusAntiderivative => 'Antiderivative';

  @override
  String get calculusNoAntiderivative =>
      'No closed-form antiderivative was found; the definite integral was computed numerically.';

  @override
  String get calculusDefiniteExact => 'Definite integral (exact)';

  @override
  String get calculusDefiniteNumeric => 'Definite integral (numerical)';

  @override
  String get calculusErrorEstimate => 'Estimated error';

  @override
  String get calculusDivergenceHint =>
      'An integral diverges when the area under the curve is infinite, for example 1/x on [0, 1] or 1/x on [1, ∞). Check the bounds and any points where the function is undefined.';

  @override
  String get calculusLimitHint => 'e.g. sin(x)/x';

  @override
  String calculusLimitPoint(String variable) {
    return '$variable approaches';
  }

  @override
  String get calculusLimitPointHint => 'e.g. 0, pi, inf, -inf';

  @override
  String get calculusPointRequired =>
      'Enter the point the variable approaches.';

  @override
  String get calculusSide => 'Direction';

  @override
  String get calculusSideBoth => 'Two-sided';

  @override
  String get calculusSideLeft => 'From left (a⁻)';

  @override
  String get calculusSideRight => 'From right (a⁺)';

  @override
  String get calculusFindLimit => 'Find limit';

  @override
  String get calculusLimitEmpty =>
      'Enter a function and the point, then tap Find limit.';

  @override
  String get calculusLimitResult => 'Limit';

  @override
  String get calculusLimitPlusInfinity =>
      'The function grows without bound (the limit is +∞).';

  @override
  String get calculusLimitMinusInfinity =>
      'The function decreases without bound (the limit is −∞).';

  @override
  String get calculusLimitDneHint =>
      'A limit exists only when the function approaches one single value. Try a one-sided limit (from the left or from the right).';

  @override
  String get calculusSeriesKind => 'Sum or product';

  @override
  String get calculusSum => 'Sum';

  @override
  String get calculusProduct => 'Product';

  @override
  String calculusTerm(String index) {
    return 'Term in $index';
  }

  @override
  String get calculusTermHint => 'e.g. k^2 or 1/k';

  @override
  String get calculusIndexVariable => 'Index';

  @override
  String calculusSeriesNote(String mode) {
    return 'The index runs over whole numbers from the lower to the upper bound. Trigonometric terms use the $mode angle mode.';
  }

  @override
  String get calculusExamples => 'Examples';

  @override
  String get calculusSeriesEmpty =>
      'Enter a term and bounds, then tap Calculate.';

  @override
  String get statsMode => 'Data type';

  @override
  String get statsOneVariable => 'One variable';

  @override
  String get statsTwoVariable => 'Two variables (X, Y)';

  @override
  String get statsUseFrequencies => 'Frequency column';

  @override
  String get statsDataTable => 'Data';

  @override
  String statsRowsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String get statsValue => 'Value';

  @override
  String get statsFrequency => 'Frequency';

  @override
  String get statsX => 'X';

  @override
  String get statsY => 'Y';

  @override
  String get statsAddRow => 'Add row';

  @override
  String statsRemoveRow(int row) {
    return 'Remove row $row';
  }

  @override
  String get statsPaste => 'Paste data';

  @override
  String get statsClear => 'Clear data';

  @override
  String get statsPasteEmpty => 'The clipboard contains no numbers.';

  @override
  String statsPasted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pasted $count rows',
      one: 'Pasted 1 row',
    );
    return '$_temp0';
  }

  @override
  String statsPasteTruncated(int max) {
    return 'Pasted the first $max rows only.';
  }

  @override
  String get statsPasteHelpOne =>
      'Paste numbers separated by commas, spaces or new lines. Cells also accept expressions such as 1/3 or sqrt(2).';

  @override
  String get statsPasteHelpTwo =>
      'Paste two columns (X and Y on each line), or a list of X, Y pairs.';

  @override
  String get statsCalculate => 'Calculate statistics';

  @override
  String get statsEmpty => 'Enter data and tap Calculate statistics.';

  @override
  String statsCellError(int row, String column, String message) {
    return 'Row $row, $column: $message';
  }

  @override
  String get statsCount => 'Count';

  @override
  String get statsSum => 'Sum';

  @override
  String get statsSumSquares => 'Sum of squares';

  @override
  String get statsMean => 'Mean';

  @override
  String get statsMedian => 'Median';

  @override
  String get statsModes => 'Mode';

  @override
  String get statsNoMode => 'No mode: every value occurs equally often.';

  @override
  String get statsMin => 'Minimum';

  @override
  String get statsMax => 'Maximum';

  @override
  String get statsRange => 'Range';

  @override
  String get statsSampleVariance => 'Sample variance';

  @override
  String get statsPopulationVariance => 'Population variance';

  @override
  String get statsSampleStdDev => 'Sample standard deviation';

  @override
  String get statsPopulationStdDev => 'Population standard deviation';

  @override
  String get statsSampleNeedsTwo =>
      'Sample variance and standard deviation need at least two values.';

  @override
  String get statsQ1 => 'First quartile';

  @override
  String get statsQ3 => 'Third quartile';

  @override
  String get statsIqr => 'Interquartile range';

  @override
  String get statsQuartileNote =>
      'Quartiles use the median-of-halves method, as on most scientific calculators.';

  @override
  String get statsPercentile => 'Percentile';

  @override
  String get statsPercentileP => 'Percentile p (0–100)';

  @override
  String get statsPercentileHint => 'e.g. 90';

  @override
  String get statsMeanX => 'Mean of X';

  @override
  String get statsMeanY => 'Mean of Y';

  @override
  String get statsSumX => 'Sum of X';

  @override
  String get statsSumY => 'Sum of Y';

  @override
  String get statsSumXY => 'Sum of XY';

  @override
  String get statsSumX2 => 'Sum of X²';

  @override
  String get statsSumY2 => 'Sum of Y²';

  @override
  String get statsSampleCovariance => 'Sample covariance';

  @override
  String get statsPopulationCovariance => 'Population covariance';

  @override
  String get statsCorrelation => 'Correlation coefficient (Pearson r)';

  @override
  String get statsCorrelationTransformed =>
      'Correlation of the transformed fit';

  @override
  String get statsNoCorrelation =>
      'The correlation is undefined because X or Y does not vary.';

  @override
  String get statsRegression => 'Regression';

  @override
  String get statsRegressionModel => 'Model';

  @override
  String get statsRegLinear => 'Linear';

  @override
  String get statsRegQuadratic => 'Quadratic';

  @override
  String get statsRegExponential => 'Exponential';

  @override
  String get statsRegLogarithmic => 'Logarithmic';

  @override
  String get statsRegPower => 'Power';

  @override
  String get statsR2 => 'Coefficient of determination';

  @override
  String statsScatterLabel(int count) {
    return 'Scatter plot of $count points with the fitted curve';
  }

  @override
  String get statsPredictX => 'Predict y for x =';

  @override
  String get statsPredict => 'Predict';

  @override
  String get statsPredictedY => 'Predicted y';

  @override
  String get probCombinatorics => 'Combinatorics';

  @override
  String get probNormal => 'Normal';

  @override
  String get probBinomial => 'Binomial';

  @override
  String get probPoisson => 'Poisson';

  @override
  String get probNItems => 'n (items)';

  @override
  String get probRChosen => 'r (chosen)';

  @override
  String get probMean => 'Mean μ';

  @override
  String get probStdDev => 'Standard deviation σ';

  @override
  String get probXValue => 'x';

  @override
  String get probLowerA => 'Lower a';

  @override
  String get probUpperB => 'Upper b';

  @override
  String get probAreaP => 'Probability p (inverse)';

  @override
  String get probTrials => 'Trials n';

  @override
  String get probSuccess => 'Success probability p';

  @override
  String get probK => 'k';

  @override
  String get probCumulativeQ => 'Cumulative probability (inverse)';

  @override
  String get probLambda => 'Mean λ';

  @override
  String get probCombinatoricsHelp => 'Leave r empty to compute only n!.';

  @override
  String get probOptionalHelp =>
      'Results are shown for every filled-in field; leave a field empty to skip the results that need it.';

  @override
  String get probEmpty => 'Enter the parameters and tap Calculate.';

  @override
  String get probCombinations => 'Combinations nCr';

  @override
  String get probPermutations => 'Permutations nPr';

  @override
  String get probFactorial => 'Factorial n!';

  @override
  String get probDensity => 'Probability density';

  @override
  String get probPmf => 'Probability P(X = k)';

  @override
  String get probCdf => 'Cumulative probability';

  @override
  String get probUpperTail => 'Upper tail';

  @override
  String get probBetween => 'Probability between a and b';

  @override
  String get probInverseNormal => 'Inverse normal';

  @override
  String get probInverseDiscrete =>
      'Inverse: smallest k reaching the cumulative probability';

  @override
  String get tableFunctionHint => 'e.g. x^2 or sin(x)';

  @override
  String get tableSavedFunctions => 'Saved functions';

  @override
  String get tableNoSavedFunctions =>
      'Functions you save in the graph or calculator appear in the saved-functions menu.';

  @override
  String get tableStart => 'Start';

  @override
  String get tableEnd => 'End';

  @override
  String get tableStep => 'Step';

  @override
  String tableAngleNote(String mode, int max) {
    return 'Trigonometric functions use the $mode angle mode. Up to $max rows.';
  }

  @override
  String get tableBuild => 'Build table';

  @override
  String get tableEmpty =>
      'Enter a function and a range, then tap Build table.';

  @override
  String tableRowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String get tableCopyCsv => 'Copy table as CSV';

  @override
  String get tableCopied => 'Table copied as CSV';

  @override
  String get tableShareFailed => 'Sharing is not available on this device.';
}
