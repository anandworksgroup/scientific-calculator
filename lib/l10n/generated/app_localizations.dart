import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Calculator'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Powerful mathematics, completely in your pocket.'**
  String get appTagline;

  /// No description provided for @navCalculator.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get navCalculator;

  /// No description provided for @navScientific.
  ///
  /// In en, this message translates to:
  /// **'Scientific'**
  String get navScientific;

  /// No description provided for @navGraph.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get navGraph;

  /// No description provided for @navSolve.
  ///
  /// In en, this message translates to:
  /// **'Solve'**
  String get navSolve;

  /// No description provided for @navTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get navTools;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get actionCalculate;

  /// No description provided for @actionSolve.
  ///
  /// In en, this message translates to:
  /// **'Solve'**
  String get actionSolve;

  /// No description provided for @actionUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get actionUse;

  /// No description provided for @actionInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get actionInsert;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get actionRedo;

  /// No description provided for @actionPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get actionPaste;

  /// No description provided for @actionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get actionSelectAll;

  /// No description provided for @actionFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get actionFavorite;

  /// No description provided for @actionUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get actionUnfavorite;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get actionMore;

  /// No description provided for @actionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @deletedItem.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deletedItem;

  /// No description provided for @savedItem.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedItem;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculating;

  /// No description provided for @calculationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Calculation cancelled'**
  String get calculationCancelled;

  /// No description provided for @emptyStateNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyStateNothingHere;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number or expression'**
  String get invalidNumber;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingScientificTitle.
  ///
  /// In en, this message translates to:
  /// **'Scientific calculator'**
  String get onboardingScientificTitle;

  /// No description provided for @onboardingScientificBody.
  ///
  /// In en, this message translates to:
  /// **'Textbook-style input, exact fractions and surds, up to 100-digit precision.'**
  String get onboardingScientificBody;

  /// No description provided for @onboardingSolveTitle.
  ///
  /// In en, this message translates to:
  /// **'Solve equations'**
  String get onboardingSolveTitle;

  /// No description provided for @onboardingSolveBody.
  ///
  /// In en, this message translates to:
  /// **'Polynomials, simultaneous equations, calculus and matrices with worked steps.'**
  String get onboardingSolveBody;

  /// No description provided for @onboardingGraphTitle.
  ///
  /// In en, this message translates to:
  /// **'Plot graphs'**
  String get onboardingGraphTitle;

  /// No description provided for @onboardingGraphBody.
  ///
  /// In en, this message translates to:
  /// **'Cartesian, polar, parametric and implicit curves with roots, extrema and tangents.'**
  String get onboardingGraphBody;

  /// No description provided for @onboardingOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Works offline'**
  String get onboardingOfflineTitle;

  /// No description provided for @onboardingOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'No account and no internet needed. Your calculations stay on your device.'**
  String get onboardingOfflineBody;

  /// No description provided for @indicatorShift.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get indicatorShift;

  /// No description provided for @indicatorAlpha.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get indicatorAlpha;

  /// No description provided for @indicatorMemory.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get indicatorMemory;

  /// No description provided for @indicatorStore.
  ///
  /// In en, this message translates to:
  /// **'STO'**
  String get indicatorStore;

  /// No description provided for @angleDeg.
  ///
  /// In en, this message translates to:
  /// **'DEG'**
  String get angleDeg;

  /// No description provided for @angleRad.
  ///
  /// In en, this message translates to:
  /// **'RAD'**
  String get angleRad;

  /// No description provided for @angleGrad.
  ///
  /// In en, this message translates to:
  /// **'GRAD'**
  String get angleGrad;

  /// No description provided for @angleDegLong.
  ///
  /// In en, this message translates to:
  /// **'Degrees'**
  String get angleDegLong;

  /// No description provided for @angleRadLong.
  ///
  /// In en, this message translates to:
  /// **'Radians'**
  String get angleRadLong;

  /// No description provided for @angleGradLong.
  ///
  /// In en, this message translates to:
  /// **'Gradians'**
  String get angleGradLong;

  /// No description provided for @notationNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get notationNormal;

  /// No description provided for @notationScientific.
  ///
  /// In en, this message translates to:
  /// **'Scientific'**
  String get notationScientific;

  /// No description provided for @notationEngineering.
  ///
  /// In en, this message translates to:
  /// **'Engineering'**
  String get notationEngineering;

  /// No description provided for @notationSciShort.
  ///
  /// In en, this message translates to:
  /// **'SCI'**
  String get notationSciShort;

  /// No description provided for @notationEngShort.
  ///
  /// In en, this message translates to:
  /// **'ENG'**
  String get notationEngShort;

  /// No description provided for @formatAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get formatAuto;

  /// No description provided for @formatDecimal.
  ///
  /// In en, this message translates to:
  /// **'Decimal'**
  String get formatDecimal;

  /// No description provided for @formatFraction.
  ///
  /// In en, this message translates to:
  /// **'Fraction'**
  String get formatFraction;

  /// No description provided for @formatMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed fraction'**
  String get formatMixed;

  /// No description provided for @formatExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get formatExact;

  /// No description provided for @complexRect.
  ///
  /// In en, this message translates to:
  /// **'a+bi'**
  String get complexRect;

  /// No description provided for @complexPolar.
  ///
  /// In en, this message translates to:
  /// **'r∠θ'**
  String get complexPolar;

  /// No description provided for @calcPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter an expression'**
  String get calcPlaceholder;

  /// No description provided for @calcExactForm.
  ///
  /// In en, this message translates to:
  /// **'Exact form'**
  String get calcExactForm;

  /// No description provided for @calcDecimalForm.
  ///
  /// In en, this message translates to:
  /// **'Decimal form'**
  String get calcDecimalForm;

  /// No description provided for @calcFractionForm.
  ///
  /// In en, this message translates to:
  /// **'Fraction'**
  String get calcFractionForm;

  /// No description provided for @calcMixedForm.
  ///
  /// In en, this message translates to:
  /// **'Mixed fraction'**
  String get calcMixedForm;

  /// No description provided for @calcScientificForm.
  ///
  /// In en, this message translates to:
  /// **'Scientific notation'**
  String get calcScientificForm;

  /// No description provided for @calcEngineeringForm.
  ///
  /// In en, this message translates to:
  /// **'Engineering notation'**
  String get calcEngineeringForm;

  /// No description provided for @calcAllDigits.
  ///
  /// In en, this message translates to:
  /// **'All digits'**
  String get calcAllDigits;

  /// No description provided for @calcResultDetails.
  ///
  /// In en, this message translates to:
  /// **'Result details'**
  String get calcResultDetails;

  /// No description provided for @calcToggleFormat.
  ///
  /// In en, this message translates to:
  /// **'Switch result format'**
  String get calcToggleFormat;

  /// No description provided for @calcCopyResult.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get calcCopyResult;

  /// No description provided for @calcCopyExpression.
  ///
  /// In en, this message translates to:
  /// **'Copy expression'**
  String get calcCopyExpression;

  /// No description provided for @calcCopyBoth.
  ///
  /// In en, this message translates to:
  /// **'Copy expression and result'**
  String get calcCopyBoth;

  /// No description provided for @calcUseResult.
  ///
  /// In en, this message translates to:
  /// **'Use result'**
  String get calcUseResult;

  /// No description provided for @calcUseExpression.
  ///
  /// In en, this message translates to:
  /// **'Use expression'**
  String get calcUseExpression;

  /// No description provided for @calcShareText.
  ///
  /// In en, this message translates to:
  /// **'Expression:\n{expression}\nResult:\n{result}'**
  String calcShareText(String expression, String result);

  /// No description provided for @calcStoredIn.
  ///
  /// In en, this message translates to:
  /// **'Stored in {name}'**
  String calcStoredIn(String name);

  /// No description provided for @calcFunctionDefined.
  ///
  /// In en, this message translates to:
  /// **'Function {name} saved'**
  String calcFunctionDefined(String name);

  /// No description provided for @calcTrue.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get calcTrue;

  /// No description provided for @calcFalse.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get calcFalse;

  /// No description provided for @calcNoSolution.
  ///
  /// In en, this message translates to:
  /// **'No solution'**
  String get calcNoSolution;

  /// No description provided for @calcAllValues.
  ///
  /// In en, this message translates to:
  /// **'True for every value'**
  String get calcAllValues;

  /// No description provided for @calcNumericalSolution.
  ///
  /// In en, this message translates to:
  /// **'Numerical solution'**
  String get calcNumericalSolution;

  /// No description provided for @calcFunctionCatalog.
  ///
  /// In en, this message translates to:
  /// **'Function catalog'**
  String get calcFunctionCatalog;

  /// No description provided for @calcConstants.
  ///
  /// In en, this message translates to:
  /// **'Constants'**
  String get calcConstants;

  /// No description provided for @calcStore.
  ///
  /// In en, this message translates to:
  /// **'Store result in…'**
  String get calcStore;

  /// No description provided for @calcRecall.
  ///
  /// In en, this message translates to:
  /// **'Recall variable'**
  String get calcRecall;

  /// No description provided for @calcMemoryClear.
  ///
  /// In en, this message translates to:
  /// **'Memory cleared'**
  String get calcMemoryClear;

  /// No description provided for @calcMemoryStored.
  ///
  /// In en, this message translates to:
  /// **'Stored in memory'**
  String get calcMemoryStored;

  /// No description provided for @calcModeMenu.
  ///
  /// In en, this message translates to:
  /// **'Mode and setup'**
  String get calcModeMenu;

  /// No description provided for @calcSwitchToBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic keypad'**
  String get calcSwitchToBasic;

  /// No description provided for @calcSwitchToScientific.
  ///
  /// In en, this message translates to:
  /// **'Scientific keypad'**
  String get calcSwitchToScientific;

  /// No description provided for @calcLandscapeHint.
  ///
  /// In en, this message translates to:
  /// **'Rotate for more functions'**
  String get calcLandscapeHint;

  /// No description provided for @calcSteps.
  ///
  /// In en, this message translates to:
  /// **'Show steps'**
  String get calcSteps;

  /// No description provided for @calcHideSteps.
  ///
  /// In en, this message translates to:
  /// **'Hide steps'**
  String get calcHideSteps;

  /// No description provided for @calcCursorLeft.
  ///
  /// In en, this message translates to:
  /// **'Move cursor left'**
  String get calcCursorLeft;

  /// No description provided for @calcCursorRight.
  ///
  /// In en, this message translates to:
  /// **'Move cursor right'**
  String get calcCursorRight;

  /// No description provided for @calcEmptyHistory.
  ///
  /// In en, this message translates to:
  /// **'Your calculations will appear here'**
  String get calcEmptyHistory;

  /// No description provided for @calcMultiplicity.
  ///
  /// In en, this message translates to:
  /// **'multiplicity {count}'**
  String calcMultiplicity(int count);

  /// No description provided for @calcComplexRoot.
  ///
  /// In en, this message translates to:
  /// **'complex'**
  String get calcComplexRoot;

  /// No description provided for @calcApprox.
  ///
  /// In en, this message translates to:
  /// **'≈'**
  String get calcApprox;

  /// No description provided for @calcIntervalNote.
  ///
  /// In en, this message translates to:
  /// **'Real solutions found in [{from}, {to}]'**
  String calcIntervalNote(String from, String to);

  /// No description provided for @calcPeriodicNote.
  ///
  /// In en, this message translates to:
  /// **'The equation is periodic, so it has infinitely many solutions; those in the search range are shown.'**
  String get calcPeriodicNote;

  /// No description provided for @calcCatalogSearch.
  ///
  /// In en, this message translates to:
  /// **'Search functions'**
  String get calcCatalogSearch;

  /// No description provided for @keyShift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get keyShift;

  /// No description provided for @keyAlpha.
  ///
  /// In en, this message translates to:
  /// **'Alpha'**
  String get keyAlpha;

  /// No description provided for @keyDel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get keyDel;

  /// No description provided for @keyAc.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get keyAc;

  /// No description provided for @keyEquals.
  ///
  /// In en, this message translates to:
  /// **'Equals'**
  String get keyEquals;

  /// No description provided for @keyAns.
  ///
  /// In en, this message translates to:
  /// **'Previous answer'**
  String get keyAns;

  /// No description provided for @keyExp.
  ///
  /// In en, this message translates to:
  /// **'Times ten to the power'**
  String get keyExp;

  /// No description provided for @keyDecimal.
  ///
  /// In en, this message translates to:
  /// **'Decimal point'**
  String get keyDecimal;

  /// No description provided for @keyPlus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get keyPlus;

  /// No description provided for @keyMinus.
  ///
  /// In en, this message translates to:
  /// **'Minus'**
  String get keyMinus;

  /// No description provided for @keyTimes.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get keyTimes;

  /// No description provided for @keyDivide.
  ///
  /// In en, this message translates to:
  /// **'Divided by'**
  String get keyDivide;

  /// No description provided for @keyOpenParen.
  ///
  /// In en, this message translates to:
  /// **'Open parenthesis'**
  String get keyOpenParen;

  /// No description provided for @keyCloseParen.
  ///
  /// In en, this message translates to:
  /// **'Close parenthesis'**
  String get keyCloseParen;

  /// No description provided for @keyComma.
  ///
  /// In en, this message translates to:
  /// **'Comma'**
  String get keyComma;

  /// No description provided for @keyFraction.
  ///
  /// In en, this message translates to:
  /// **'Fraction'**
  String get keyFraction;

  /// No description provided for @keyMixedFraction.
  ///
  /// In en, this message translates to:
  /// **'Mixed fraction'**
  String get keyMixedFraction;

  /// No description provided for @keySquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get keySquare;

  /// No description provided for @keyCube.
  ///
  /// In en, this message translates to:
  /// **'Cube'**
  String get keyCube;

  /// No description provided for @keyPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get keyPower;

  /// No description provided for @keyInverse.
  ///
  /// In en, this message translates to:
  /// **'Reciprocal'**
  String get keyInverse;

  /// No description provided for @keySqrt.
  ///
  /// In en, this message translates to:
  /// **'Square root'**
  String get keySqrt;

  /// No description provided for @keyCbrt.
  ///
  /// In en, this message translates to:
  /// **'Cube root'**
  String get keyCbrt;

  /// No description provided for @keyNthRoot.
  ///
  /// In en, this message translates to:
  /// **'Nth root'**
  String get keyNthRoot;

  /// No description provided for @keyLog.
  ///
  /// In en, this message translates to:
  /// **'Logarithm base ten'**
  String get keyLog;

  /// No description provided for @keyLogBase.
  ///
  /// In en, this message translates to:
  /// **'Logarithm with base'**
  String get keyLogBase;

  /// No description provided for @keyLn.
  ///
  /// In en, this message translates to:
  /// **'Natural logarithm'**
  String get keyLn;

  /// No description provided for @keyTenPower.
  ///
  /// In en, this message translates to:
  /// **'Ten to the power'**
  String get keyTenPower;

  /// No description provided for @keyExpPower.
  ///
  /// In en, this message translates to:
  /// **'e to the power'**
  String get keyExpPower;

  /// No description provided for @keySin.
  ///
  /// In en, this message translates to:
  /// **'Sine'**
  String get keySin;

  /// No description provided for @keyCos.
  ///
  /// In en, this message translates to:
  /// **'Cosine'**
  String get keyCos;

  /// No description provided for @keyTan.
  ///
  /// In en, this message translates to:
  /// **'Tangent'**
  String get keyTan;

  /// No description provided for @keyAsin.
  ///
  /// In en, this message translates to:
  /// **'Inverse sine'**
  String get keyAsin;

  /// No description provided for @keyAcos.
  ///
  /// In en, this message translates to:
  /// **'Inverse cosine'**
  String get keyAcos;

  /// No description provided for @keyAtan.
  ///
  /// In en, this message translates to:
  /// **'Inverse tangent'**
  String get keyAtan;

  /// No description provided for @keySinh.
  ///
  /// In en, this message translates to:
  /// **'Hyperbolic sine'**
  String get keySinh;

  /// No description provided for @keyCosh.
  ///
  /// In en, this message translates to:
  /// **'Hyperbolic cosine'**
  String get keyCosh;

  /// No description provided for @keyTanh.
  ///
  /// In en, this message translates to:
  /// **'Hyperbolic tangent'**
  String get keyTanh;

  /// No description provided for @keyAsinh.
  ///
  /// In en, this message translates to:
  /// **'Inverse hyperbolic sine'**
  String get keyAsinh;

  /// No description provided for @keyAcosh.
  ///
  /// In en, this message translates to:
  /// **'Inverse hyperbolic cosine'**
  String get keyAcosh;

  /// No description provided for @keyAtanh.
  ///
  /// In en, this message translates to:
  /// **'Inverse hyperbolic tangent'**
  String get keyAtanh;

  /// No description provided for @keyPi.
  ///
  /// In en, this message translates to:
  /// **'Pi'**
  String get keyPi;

  /// No description provided for @keyE.
  ///
  /// In en, this message translates to:
  /// **'Euler\'s number'**
  String get keyE;

  /// No description provided for @keyI.
  ///
  /// In en, this message translates to:
  /// **'Imaginary unit'**
  String get keyI;

  /// No description provided for @keyFactorial.
  ///
  /// In en, this message translates to:
  /// **'Factorial'**
  String get keyFactorial;

  /// No description provided for @keyPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get keyPercent;

  /// No description provided for @keyAbs.
  ///
  /// In en, this message translates to:
  /// **'Absolute value'**
  String get keyAbs;

  /// No description provided for @keyNcr.
  ///
  /// In en, this message translates to:
  /// **'Combinations'**
  String get keyNcr;

  /// No description provided for @keyNpr.
  ///
  /// In en, this message translates to:
  /// **'Permutations'**
  String get keyNpr;

  /// No description provided for @keyAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle (polar form)'**
  String get keyAngle;

  /// No description provided for @keyDegree.
  ///
  /// In en, this message translates to:
  /// **'Degree sign'**
  String get keyDegree;

  /// No description provided for @keyIntegral.
  ///
  /// In en, this message translates to:
  /// **'Definite integral'**
  String get keyIntegral;

  /// No description provided for @keyDerivative.
  ///
  /// In en, this message translates to:
  /// **'Derivative at a point'**
  String get keyDerivative;

  /// No description provided for @keySum.
  ///
  /// In en, this message translates to:
  /// **'Summation'**
  String get keySum;

  /// No description provided for @keyProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get keyProduct;

  /// No description provided for @keyLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get keyLimit;

  /// No description provided for @keyEquation.
  ///
  /// In en, this message translates to:
  /// **'Equals sign'**
  String get keyEquation;

  /// No description provided for @keyStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get keyStore;

  /// No description provided for @keyRandom.
  ///
  /// In en, this message translates to:
  /// **'Random number'**
  String get keyRandom;

  /// No description provided for @keyRandomInt.
  ///
  /// In en, this message translates to:
  /// **'Random integer'**
  String get keyRandomInt;

  /// No description provided for @keyVariableX.
  ///
  /// In en, this message translates to:
  /// **'Variable x'**
  String get keyVariableX;

  /// No description provided for @keyMemoryClear.
  ///
  /// In en, this message translates to:
  /// **'Memory clear'**
  String get keyMemoryClear;

  /// No description provided for @keyMemoryRecall.
  ///
  /// In en, this message translates to:
  /// **'Memory recall'**
  String get keyMemoryRecall;

  /// No description provided for @keyMemoryAdd.
  ///
  /// In en, this message translates to:
  /// **'Memory add'**
  String get keyMemoryAdd;

  /// No description provided for @keyMemorySubtract.
  ///
  /// In en, this message translates to:
  /// **'Memory subtract'**
  String get keyMemorySubtract;

  /// No description provided for @keyMemoryStore.
  ///
  /// In en, this message translates to:
  /// **'Memory store'**
  String get keyMemoryStore;

  /// No description provided for @keyFormatToggle.
  ///
  /// In en, this message translates to:
  /// **'Switch between exact and decimal'**
  String get keyFormatToggle;

  /// No description provided for @keyDigit.
  ///
  /// In en, this message translates to:
  /// **'{digit}'**
  String keyDigit(String digit);

  /// No description provided for @keyVariable.
  ///
  /// In en, this message translates to:
  /// **'Variable {name}'**
  String keyVariable(String name);

  /// No description provided for @keyFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get keyFloor;

  /// No description provided for @keyCeil.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get keyCeil;

  /// No description provided for @keyRound.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get keyRound;

  /// No description provided for @keyGcd.
  ///
  /// In en, this message translates to:
  /// **'Greatest common divisor'**
  String get keyGcd;

  /// No description provided for @keyLcm.
  ///
  /// In en, this message translates to:
  /// **'Least common multiple'**
  String get keyLcm;

  /// No description provided for @keyMod.
  ///
  /// In en, this message translates to:
  /// **'Modulo'**
  String get keyMod;

  /// No description provided for @keyConj.
  ///
  /// In en, this message translates to:
  /// **'Complex conjugate'**
  String get keyConj;

  /// No description provided for @errEmptyInput.
  ///
  /// In en, this message translates to:
  /// **'Enter an expression first.'**
  String get errEmptyInput;

  /// No description provided for @errInvalidExpression.
  ///
  /// In en, this message translates to:
  /// **'Invalid expression.'**
  String get errInvalidExpression;

  /// No description provided for @errInvalidExpressionDetail.
  ///
  /// In en, this message translates to:
  /// **'Invalid expression: {detail}.'**
  String errInvalidExpressionDetail(String detail);

  /// No description provided for @errUnexpectedToken.
  ///
  /// In en, this message translates to:
  /// **'Unexpected “{token}” in the expression.'**
  String errUnexpectedToken(String token);

  /// No description provided for @errMissingClose.
  ///
  /// In en, this message translates to:
  /// **'Mismatched parentheses: a closing bracket is missing.'**
  String get errMissingClose;

  /// No description provided for @errMissingOpen.
  ///
  /// In en, this message translates to:
  /// **'Mismatched parentheses: there is an extra closing bracket.'**
  String get errMissingOpen;

  /// No description provided for @errMissingArgument.
  ///
  /// In en, this message translates to:
  /// **'A number or expression is missing.'**
  String get errMissingArgument;

  /// No description provided for @errMissingArgumentAfter.
  ///
  /// In en, this message translates to:
  /// **'A number or expression is missing after “{after}”.'**
  String errMissingArgumentAfter(String after);

  /// No description provided for @errUnknownIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Unknown function or variable “{name}”.'**
  String errUnknownIdentifier(String name);

  /// No description provided for @errUndefinedVariable.
  ///
  /// In en, this message translates to:
  /// **'Variable “{name}” has no value yet.'**
  String errUndefinedVariable(String name);

  /// No description provided for @errWrongArgumentCount.
  ///
  /// In en, this message translates to:
  /// **'{name}() expects {expected} argument(s) but got {got}.'**
  String errWrongArgumentCount(String name, String expected, String got);

  /// No description provided for @errDivisionByZero.
  ///
  /// In en, this message translates to:
  /// **'Division by zero is undefined.'**
  String get errDivisionByZero;

  /// No description provided for @errUndefinedResult.
  ///
  /// In en, this message translates to:
  /// **'The result is undefined.'**
  String get errUndefinedResult;

  /// No description provided for @errUndefinedResultDetail.
  ///
  /// In en, this message translates to:
  /// **'The result is undefined: {detail}.'**
  String errUndefinedResultDetail(String detail);

  /// No description provided for @errDomain.
  ///
  /// In en, this message translates to:
  /// **'Domain error: {function} is not defined for {value}.'**
  String errDomain(String function, String value);

  /// No description provided for @errComplexResult.
  ///
  /// In en, this message translates to:
  /// **'Complex result: turn on complex results in settings or include i in the expression.'**
  String get errComplexResult;

  /// No description provided for @errOverflow.
  ///
  /// In en, this message translates to:
  /// **'Overflow: the result is too large to represent.'**
  String get errOverflow;

  /// No description provided for @errNonInteger.
  ///
  /// In en, this message translates to:
  /// **'{function} requires whole numbers.'**
  String errNonInteger(String function);

  /// No description provided for @errNegative.
  ///
  /// In en, this message translates to:
  /// **'{function} requires non-negative numbers.'**
  String errNegative(String function);

  /// No description provided for @errTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Input too large for {function} (limit {limit}).'**
  String errTooLarge(String function, String limit);

  /// No description provided for @errDimension.
  ///
  /// In en, this message translates to:
  /// **'Matrix dimensions do not match.'**
  String get errDimension;

  /// No description provided for @errDimensionDetail.
  ///
  /// In en, this message translates to:
  /// **'Dimensions do not match: {detail}.'**
  String errDimensionDetail(String detail);

  /// No description provided for @errSingular.
  ///
  /// In en, this message translates to:
  /// **'The matrix is singular (determinant 0), so it has no inverse.'**
  String get errSingular;

  /// No description provided for @errNotSquare.
  ///
  /// In en, this message translates to:
  /// **'{operation} requires a square matrix.'**
  String errNotSquare(String operation);

  /// No description provided for @errEmptyMatrix.
  ///
  /// In en, this message translates to:
  /// **'The matrix is empty.'**
  String get errEmptyMatrix;

  /// No description provided for @errNoRealSolution.
  ///
  /// In en, this message translates to:
  /// **'There is no real solution.'**
  String get errNoRealSolution;

  /// No description provided for @errNoSolution.
  ///
  /// In en, this message translates to:
  /// **'The system has no solution (it is inconsistent).'**
  String get errNoSolution;

  /// No description provided for @errInfiniteSolutions.
  ///
  /// In en, this message translates to:
  /// **'There are infinitely many solutions.'**
  String get errInfiniteSolutions;

  /// No description provided for @errNoConvergence.
  ///
  /// In en, this message translates to:
  /// **'The calculation did not converge.'**
  String get errNoConvergence;

  /// No description provided for @errNoConvergenceDetail.
  ///
  /// In en, this message translates to:
  /// **'The calculation did not converge: {detail}.'**
  String errNoConvergenceDetail(String detail);

  /// No description provided for @errNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This operation is not supported.'**
  String get errNotSupported;

  /// No description provided for @errInvalidAssignment.
  ///
  /// In en, this message translates to:
  /// **'Cannot assign a value to “{name}”.'**
  String errInvalidAssignment(String name);

  /// No description provided for @errRecursion.
  ///
  /// In en, this message translates to:
  /// **'The expression is nested too deeply.'**
  String get errRecursion;

  /// No description provided for @errCancelled.
  ///
  /// In en, this message translates to:
  /// **'Calculation cancelled.'**
  String get errCancelled;

  /// No description provided for @errTimeout.
  ///
  /// In en, this message translates to:
  /// **'The calculation took too long and was stopped.'**
  String get errTimeout;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historySearch.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get historySearch;

  /// No description provided for @historyToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyToday;

  /// No description provided for @historyYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyYesterday;

  /// No description provided for @historyPrevious7.
  ///
  /// In en, this message translates to:
  /// **'Previous 7 days'**
  String get historyPrevious7;

  /// No description provided for @historyPrevious30.
  ///
  /// In en, this message translates to:
  /// **'Previous 30 days'**
  String get historyPrevious30;

  /// No description provided for @historyOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get historyOlder;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No calculations yet'**
  String get historyEmpty;

  /// No description provided for @historyClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClearAll;

  /// No description provided for @historyClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all history except favorites? This cannot be undone.'**
  String get historyClearConfirm;

  /// No description provided for @historyReuse.
  ///
  /// In en, this message translates to:
  /// **'Reuse'**
  String get historyReuse;

  /// No description provided for @historyFavoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorites only'**
  String get historyFavoritesOnly;

  /// No description provided for @historyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Saving history is turned off in settings.'**
  String get historyDisabled;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Star calculations, formulas, constants and converters to find them here.'**
  String get favoritesEmpty;

  /// No description provided for @favoritesCalculations.
  ///
  /// In en, this message translates to:
  /// **'Calculations'**
  String get favoritesCalculations;

  /// No description provided for @favoritesFormulas.
  ///
  /// In en, this message translates to:
  /// **'Formulas'**
  String get favoritesFormulas;

  /// No description provided for @favoritesConstants.
  ///
  /// In en, this message translates to:
  /// **'Constants'**
  String get favoritesConstants;

  /// No description provided for @favoritesConverters.
  ///
  /// In en, this message translates to:
  /// **'Converters'**
  String get favoritesConverters;

  /// No description provided for @favoritesTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get favoritesTools;

  /// No description provided for @variablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get variablesTitle;

  /// No description provided for @variablesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Store values with the STO key or write name = value in the calculator.'**
  String get variablesEmpty;

  /// No description provided for @variablesAdd.
  ///
  /// In en, this message translates to:
  /// **'New variable'**
  String get variablesAdd;

  /// No description provided for @variablesName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get variablesName;

  /// No description provided for @variablesValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get variablesValue;

  /// No description provided for @variablesInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Use letters, digits and _ ; start with a letter.'**
  String get variablesInvalidName;

  /// No description provided for @variablesReserved.
  ///
  /// In en, this message translates to:
  /// **'This name is reserved.'**
  String get variablesReserved;

  /// No description provided for @variablesAnsNote.
  ///
  /// In en, this message translates to:
  /// **'Ans holds the most recent successful result.'**
  String get variablesAnsNote;

  /// No description provided for @functionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved functions'**
  String get functionsTitle;

  /// No description provided for @functionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Define functions such as f(x) = x² to use them in the calculator and graphs.'**
  String get functionsEmpty;

  /// No description provided for @functionsAdd.
  ///
  /// In en, this message translates to:
  /// **'New function'**
  String get functionsAdd;

  /// No description provided for @functionsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get functionsName;

  /// No description provided for @functionsExpression.
  ///
  /// In en, this message translates to:
  /// **'Expression in x'**
  String get functionsExpression;

  /// No description provided for @functionsLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Free version limit reached ({count} functions). Upgrade to Premium for unlimited saved functions and graphs.'**
  String functionsLimitReached(int count);

  /// No description provided for @functionsPlot.
  ///
  /// In en, this message translates to:
  /// **'Plot'**
  String get functionsPlot;

  /// No description provided for @functionsTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get functionsTable;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tools, functions, constants, formulas…'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get searchNoResults;

  /// No description provided for @searchSectionTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get searchSectionTools;

  /// No description provided for @searchSectionFunctions.
  ///
  /// In en, this message translates to:
  /// **'Functions'**
  String get searchSectionFunctions;

  /// No description provided for @searchSectionConstants.
  ///
  /// In en, this message translates to:
  /// **'Constants'**
  String get searchSectionConstants;

  /// No description provided for @searchSectionFormulas.
  ///
  /// In en, this message translates to:
  /// **'Formulas'**
  String get searchSectionFormulas;

  /// No description provided for @searchSectionUnits.
  ///
  /// In en, this message translates to:
  /// **'Unit converters'**
  String get searchSectionUnits;

  /// No description provided for @searchSectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get searchSectionSettings;

  /// No description provided for @toolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsTitle;

  /// No description provided for @toolsQuickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick access'**
  String get toolsQuickAccess;

  /// No description provided for @toolsCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize quick access'**
  String get toolsCustomize;

  /// No description provided for @toolsAll.
  ///
  /// In en, this message translates to:
  /// **'All tools'**
  String get toolsAll;

  /// No description provided for @toolMatrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix'**
  String get toolMatrix;

  /// No description provided for @toolVector.
  ///
  /// In en, this message translates to:
  /// **'Vector'**
  String get toolVector;

  /// No description provided for @toolComplex.
  ///
  /// In en, this message translates to:
  /// **'Complex'**
  String get toolComplex;

  /// No description provided for @toolCalculus.
  ///
  /// In en, this message translates to:
  /// **'Calculus'**
  String get toolCalculus;

  /// No description provided for @toolDerivative.
  ///
  /// In en, this message translates to:
  /// **'Derivative'**
  String get toolDerivative;

  /// No description provided for @toolIntegral.
  ///
  /// In en, this message translates to:
  /// **'Integral'**
  String get toolIntegral;

  /// No description provided for @toolLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get toolLimit;

  /// No description provided for @toolSeries.
  ///
  /// In en, this message translates to:
  /// **'Sum & product'**
  String get toolSeries;

  /// No description provided for @toolStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get toolStatistics;

  /// No description provided for @toolProbability.
  ///
  /// In en, this message translates to:
  /// **'Probability'**
  String get toolProbability;

  /// No description provided for @toolNumberTheory.
  ///
  /// In en, this message translates to:
  /// **'Number theory'**
  String get toolNumberTheory;

  /// No description provided for @toolConverter.
  ///
  /// In en, this message translates to:
  /// **'Unit converter'**
  String get toolConverter;

  /// No description provided for @toolConstants.
  ///
  /// In en, this message translates to:
  /// **'Constants'**
  String get toolConstants;

  /// No description provided for @toolFormulas.
  ///
  /// In en, this message translates to:
  /// **'Formulas'**
  String get toolFormulas;

  /// No description provided for @toolProgrammer.
  ///
  /// In en, this message translates to:
  /// **'Programmer'**
  String get toolProgrammer;

  /// No description provided for @toolTable.
  ///
  /// In en, this message translates to:
  /// **'Function table'**
  String get toolTable;

  /// No description provided for @toolCas.
  ///
  /// In en, this message translates to:
  /// **'Algebra (CAS)'**
  String get toolCas;

  /// No description provided for @toolEquation.
  ///
  /// In en, this message translates to:
  /// **'Equation'**
  String get toolEquation;

  /// No description provided for @toolPolynomial.
  ///
  /// In en, this message translates to:
  /// **'Polynomial'**
  String get toolPolynomial;

  /// No description provided for @toolSystem.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous equations'**
  String get toolSystem;

  /// No description provided for @toolGraph.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get toolGraph;

  /// No description provided for @toolRandom.
  ///
  /// In en, this message translates to:
  /// **'Random numbers'**
  String get toolRandom;

  /// No description provided for @toolVariables.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get toolVariables;

  /// No description provided for @toolFunctions.
  ///
  /// In en, this message translates to:
  /// **'Saved functions'**
  String get toolFunctions;

  /// No description provided for @toolFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get toolFavorites;

  /// No description provided for @toolHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get toolHistory;

  /// No description provided for @solveTitle.
  ///
  /// In en, this message translates to:
  /// **'Solve'**
  String get solveTitle;

  /// No description provided for @solveEquationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Any equation in one unknown'**
  String get solveEquationSubtitle;

  /// No description provided for @solvePolynomialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Roots with multiplicity, real and complex'**
  String get solvePolynomialSubtitle;

  /// No description provided for @solveSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'2 to 6 linear equations'**
  String get solveSystemSubtitle;

  /// No description provided for @solveCasSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Simplify, expand, factor, collect, substitute'**
  String get solveCasSubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsCalculator.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get settingsCalculator;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplay;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get settingsInput;

  /// No description provided for @settingsGraph.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get settingsGraph;

  /// No description provided for @settingsHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get settingsHistory;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get settingsBackup;

  /// No description provided for @settingsPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get settingsPremium;

  /// No description provided for @settingsAngleUnit.
  ///
  /// In en, this message translates to:
  /// **'Angle unit'**
  String get settingsAngleUnit;

  /// No description provided for @settingsResultFormat.
  ///
  /// In en, this message translates to:
  /// **'Result format'**
  String get settingsResultFormat;

  /// No description provided for @settingsNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get settingsNumberFormat;

  /// No description provided for @settingsPrecision.
  ///
  /// In en, this message translates to:
  /// **'Precision'**
  String get settingsPrecision;

  /// No description provided for @settingsPrecisionDigits.
  ///
  /// In en, this message translates to:
  /// **'{digits} significant digits'**
  String settingsPrecisionDigits(int digits);

  /// No description provided for @settingsThousands.
  ///
  /// In en, this message translates to:
  /// **'Thousands separator'**
  String get settingsThousands;

  /// No description provided for @settingsDecimalSeparator.
  ///
  /// In en, this message translates to:
  /// **'Decimal separator'**
  String get settingsDecimalSeparator;

  /// No description provided for @settingsDecimalPoint.
  ///
  /// In en, this message translates to:
  /// **'Point (1.5)'**
  String get settingsDecimalPoint;

  /// No description provided for @settingsDecimalComma.
  ///
  /// In en, this message translates to:
  /// **'Comma (1,5)'**
  String get settingsDecimalComma;

  /// No description provided for @settingsComplexFormat.
  ///
  /// In en, this message translates to:
  /// **'Complex number format'**
  String get settingsComplexFormat;

  /// No description provided for @settingsComplexResults.
  ///
  /// In en, this message translates to:
  /// **'Allow complex results'**
  String get settingsComplexResults;

  /// No description provided for @settingsComplexResultsSub.
  ///
  /// In en, this message translates to:
  /// **'√(−1) = i instead of an error'**
  String get settingsComplexResultsSub;

  /// No description provided for @settingsEngSymbols.
  ///
  /// In en, this message translates to:
  /// **'Engineering symbols'**
  String get settingsEngSymbols;

  /// No description provided for @settingsEngSymbolsSub.
  ///
  /// In en, this message translates to:
  /// **'Show 1.2M instead of 1.2×10⁶ in engineering notation'**
  String get settingsEngSymbolsSub;

  /// No description provided for @settingsMemoryPersists.
  ///
  /// In en, this message translates to:
  /// **'Keep memory after restart'**
  String get settingsMemoryPersists;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeAmoled.
  ///
  /// In en, this message translates to:
  /// **'AMOLED black'**
  String get settingsThemeAmoled;

  /// No description provided for @settingsAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccent;

  /// No description provided for @settingsFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsFontSize;

  /// No description provided for @settingsDisplaySize.
  ///
  /// In en, this message translates to:
  /// **'Display size'**
  String get settingsDisplaySize;

  /// No description provided for @settingsButtonSize.
  ///
  /// In en, this message translates to:
  /// **'Button size'**
  String get settingsButtonSize;

  /// No description provided for @settingsSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsSmall;

  /// No description provided for @settingsMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsMedium;

  /// No description provided for @settingsLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsLarge;

  /// No description provided for @settingsCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settingsCompact;

  /// No description provided for @settingsNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get settingsNormal;

  /// No description provided for @settingsButtonLabels.
  ///
  /// In en, this message translates to:
  /// **'Show secondary key labels'**
  String get settingsButtonLabels;

  /// No description provided for @settingsAnimations.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get settingsAnimations;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsHapticsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsHapticsOff;

  /// No description provided for @settingsHapticsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsHapticsLight;

  /// No description provided for @settingsHapticsMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsHapticsMedium;

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Key sounds'**
  String get settingsSound;

  /// No description provided for @settingsSoundSub.
  ///
  /// In en, this message translates to:
  /// **'Follows your device\'s sound settings'**
  String get settingsSoundSub;

  /// No description provided for @settingsKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard layout'**
  String get settingsKeyboard;

  /// No description provided for @settingsKeyboardScientific.
  ///
  /// In en, this message translates to:
  /// **'Scientific'**
  String get settingsKeyboardScientific;

  /// No description provided for @settingsKeyboardBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get settingsKeyboardBasic;

  /// No description provided for @settingsLivePreview.
  ///
  /// In en, this message translates to:
  /// **'Live result preview'**
  String get settingsLivePreview;

  /// No description provided for @settingsGraphGrid.
  ///
  /// In en, this message translates to:
  /// **'Show grid'**
  String get settingsGraphGrid;

  /// No description provided for @settingsGraphAxes.
  ///
  /// In en, this message translates to:
  /// **'Show axes'**
  String get settingsGraphAxes;

  /// No description provided for @settingsGraphLabels.
  ///
  /// In en, this message translates to:
  /// **'Show axis labels'**
  String get settingsGraphLabels;

  /// No description provided for @settingsGraphLineWidth.
  ///
  /// In en, this message translates to:
  /// **'Line width'**
  String get settingsGraphLineWidth;

  /// No description provided for @settingsGraphDegrees.
  ///
  /// In en, this message translates to:
  /// **'Use degrees for graph trigonometry'**
  String get settingsGraphDegrees;

  /// No description provided for @settingsSaveHistory.
  ///
  /// In en, this message translates to:
  /// **'Save calculation history'**
  String get settingsSaveHistory;

  /// No description provided for @settingsHistoryLimit.
  ///
  /// In en, this message translates to:
  /// **'Keep up to {count} entries'**
  String settingsHistoryLimit(int count);

  /// No description provided for @settingsRandomSeed.
  ///
  /// In en, this message translates to:
  /// **'Random seed'**
  String get settingsRandomSeed;

  /// No description provided for @settingsRandomSeedOff.
  ///
  /// In en, this message translates to:
  /// **'Not set (unpredictable)'**
  String get settingsRandomSeedOff;

  /// No description provided for @settingsResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get settingsResetAll;

  /// No description provided for @settingsResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore all settings to their defaults?'**
  String get settingsResetConfirm;

  /// No description provided for @settingsClearData.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get settingsClearData;

  /// No description provided for @settingsClearDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete history, favorites, variables, matrices and saved functions? This cannot be undone.'**
  String get settingsClearDataConfirm;

  /// No description provided for @settingsPremiumTheme.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get settingsPremiumTheme;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get backupTitle;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get backupExport;

  /// No description provided for @backupExportSub.
  ///
  /// In en, this message translates to:
  /// **'Save history, favorites, variables, matrices, functions and settings to a file'**
  String get backupExportSub;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get backupImport;

  /// No description provided for @backupImportSub.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup file'**
  String get backupImportSub;

  /// No description provided for @backupImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Importing replaces your current data with the backup. Continue?'**
  String get backupImportConfirm;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupImported;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is not a valid Advanced Calculator backup.'**
  String get backupInvalid;

  /// No description provided for @backupExported.
  ///
  /// In en, this message translates to:
  /// **'Backup ready to save or share'**
  String get backupExported;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Advanced Calculator works fully offline. It does not require an account and does not collect analytics, crash reports, or advertising data. Your calculations, history, variables and settings are stored only on this device. They leave the device only when you choose to share, copy or export them.'**
  String get privacyBody;

  /// No description provided for @privacyPurchases.
  ///
  /// In en, this message translates to:
  /// **'If you buy Premium, the purchase is handled by Google Play or the App Store. The app only stores whether Premium is unlocked, in the device\'s secure storage.'**
  String get privacyPurchases;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'A scientific, graphing and algebra calculator that runs entirely on your device.'**
  String get aboutDescription;

  /// No description provided for @aboutEngine.
  ///
  /// In en, this message translates to:
  /// **'Exact rational arithmetic, arbitrary-precision decimals (up to 100 digits), a computer algebra system, numerical calculus and adaptive graphing — all implemented locally.'**
  String get aboutEngine;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutLicenses;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumTitle;

  /// No description provided for @premiumHeadline.
  ///
  /// In en, this message translates to:
  /// **'Support development and unlock extras'**
  String get premiumHeadline;

  /// No description provided for @premiumCoreFree.
  ///
  /// In en, this message translates to:
  /// **'Every calculator, solver and tool stays free. Premium adds:'**
  String get premiumCoreFree;

  /// No description provided for @premiumFeatureThemes.
  ///
  /// In en, this message translates to:
  /// **'7 additional accent themes'**
  String get premiumFeatureThemes;

  /// No description provided for @premiumFeatureGraphs.
  ///
  /// In en, this message translates to:
  /// **'Unlimited saved functions and graphs'**
  String get premiumFeatureGraphs;

  /// No description provided for @premiumFeatureSupport.
  ///
  /// In en, this message translates to:
  /// **'Support future updates'**
  String get premiumFeatureSupport;

  /// No description provided for @premiumBuy.
  ///
  /// In en, this message translates to:
  /// **'Unlock Premium — {price}'**
  String premiumBuy(String price);

  /// No description provided for @premiumRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get premiumRestore;

  /// No description provided for @premiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium is active. Thank you!'**
  String get premiumActive;

  /// No description provided for @premiumPending.
  ///
  /// In en, this message translates to:
  /// **'Purchase pending… it will unlock once the payment completes.'**
  String get premiumPending;

  /// No description provided for @premiumFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase did not complete.'**
  String get premiumFailed;

  /// No description provided for @premiumUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store is not available right now. Check your connection and try again.'**
  String get premiumUnavailable;

  /// No description provided for @premiumRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored'**
  String get premiumRestored;

  /// No description provided for @premiumNothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase was found for this account.'**
  String get premiumNothingToRestore;

  /// No description provided for @premiumRequired.
  ///
  /// In en, this message translates to:
  /// **'This is a Premium feature.'**
  String get premiumRequired;

  /// No description provided for @premiumLoading.
  ///
  /// In en, this message translates to:
  /// **'Contacting the store…'**
  String get premiumLoading;

  /// No description provided for @catArithmetic.
  ///
  /// In en, this message translates to:
  /// **'Arithmetic'**
  String get catArithmetic;

  /// No description provided for @catPowers.
  ///
  /// In en, this message translates to:
  /// **'Powers & roots'**
  String get catPowers;

  /// No description provided for @catLogarithms.
  ///
  /// In en, this message translates to:
  /// **'Logarithms'**
  String get catLogarithms;

  /// No description provided for @catTrigonometry.
  ///
  /// In en, this message translates to:
  /// **'Trigonometry'**
  String get catTrigonometry;

  /// No description provided for @catHyperbolic.
  ///
  /// In en, this message translates to:
  /// **'Hyperbolic'**
  String get catHyperbolic;

  /// No description provided for @catRounding.
  ///
  /// In en, this message translates to:
  /// **'Rounding'**
  String get catRounding;

  /// No description provided for @catNumberTheory.
  ///
  /// In en, this message translates to:
  /// **'Number theory'**
  String get catNumberTheory;

  /// No description provided for @catProbability.
  ///
  /// In en, this message translates to:
  /// **'Probability'**
  String get catProbability;

  /// No description provided for @catStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get catStatistics;

  /// No description provided for @catComplex.
  ///
  /// In en, this message translates to:
  /// **'Complex'**
  String get catComplex;

  /// No description provided for @catMatrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix & vector'**
  String get catMatrix;

  /// No description provided for @catVector.
  ///
  /// In en, this message translates to:
  /// **'Vector'**
  String get catVector;

  /// No description provided for @catCalculus.
  ///
  /// In en, this message translates to:
  /// **'Calculus'**
  String get catCalculus;

  /// No description provided for @catRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get catRandom;

  /// No description provided for @graphAddFunction.
  ///
  /// In en, this message translates to:
  /// **'Add function'**
  String get graphAddFunction;

  /// No description provided for @graphFunctions.
  ///
  /// In en, this message translates to:
  /// **'Functions'**
  String get graphFunctions;

  /// No description provided for @graphWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get graphWindow;

  /// No description provided for @graphXMin.
  ///
  /// In en, this message translates to:
  /// **'x min'**
  String get graphXMin;

  /// No description provided for @graphXMax.
  ///
  /// In en, this message translates to:
  /// **'x max'**
  String get graphXMax;

  /// No description provided for @graphYMin.
  ///
  /// In en, this message translates to:
  /// **'y min'**
  String get graphYMin;

  /// No description provided for @graphYMax.
  ///
  /// In en, this message translates to:
  /// **'y max'**
  String get graphYMax;

  /// No description provided for @graphInvalidWindow.
  ///
  /// In en, this message translates to:
  /// **'Each minimum must be less than its maximum.'**
  String get graphInvalidWindow;

  /// No description provided for @graphZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get graphZoomIn;

  /// No description provided for @graphZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get graphZoomOut;

  /// No description provided for @graphReset.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get graphReset;

  /// No description provided for @graphAutoFit.
  ///
  /// In en, this message translates to:
  /// **'Fit to curves'**
  String get graphAutoFit;

  /// No description provided for @graphTrace.
  ///
  /// In en, this message translates to:
  /// **'Trace'**
  String get graphTrace;

  /// No description provided for @graphTangent.
  ///
  /// In en, this message translates to:
  /// **'Tangent'**
  String get graphTangent;

  /// No description provided for @graphAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get graphAnalyze;

  /// No description provided for @graphOnlyCartesian.
  ///
  /// In en, this message translates to:
  /// **'Analysis works on y = f(x) graphs. Select one in the list.'**
  String get graphOnlyCartesian;

  /// No description provided for @graphRoots.
  ///
  /// In en, this message translates to:
  /// **'Roots (x-intercepts)'**
  String get graphRoots;

  /// No description provided for @graphExtrema.
  ///
  /// In en, this message translates to:
  /// **'Minimum and maximum'**
  String get graphExtrema;

  /// No description provided for @graphIntersections.
  ///
  /// In en, this message translates to:
  /// **'Intersections'**
  String get graphIntersections;

  /// No description provided for @graphYIntercept.
  ///
  /// In en, this message translates to:
  /// **'y-intercept'**
  String get graphYIntercept;

  /// No description provided for @graphArea.
  ///
  /// In en, this message translates to:
  /// **'Area under curve'**
  String get graphArea;

  /// No description provided for @graphNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Add a second y = f(x) graph to find intersections.'**
  String get graphNeedTwo;

  /// No description provided for @graphSecondFunction.
  ///
  /// In en, this message translates to:
  /// **'Intersect with'**
  String get graphSecondFunction;

  /// No description provided for @graphNoPoints.
  ///
  /// In en, this message translates to:
  /// **'Nothing found in the visible range.'**
  String get graphNoPoints;

  /// No description provided for @graphAreaFrom.
  ///
  /// In en, this message translates to:
  /// **'From x ='**
  String get graphAreaFrom;

  /// No description provided for @graphAreaTo.
  ///
  /// In en, this message translates to:
  /// **'To x ='**
  String get graphAreaTo;

  /// No description provided for @graphSlope.
  ///
  /// In en, this message translates to:
  /// **'slope'**
  String get graphSlope;

  /// No description provided for @graphTangentEquation.
  ///
  /// In en, this message translates to:
  /// **'Tangent: {equation}'**
  String graphTangentEquation(String equation);

  /// No description provided for @graphAreaResult.
  ///
  /// In en, this message translates to:
  /// **'Area ≈ {value}'**
  String graphAreaResult(String value);

  /// No description provided for @graphRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get graphRoot;

  /// No description provided for @graphMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get graphMinimum;

  /// No description provided for @graphMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get graphMaximum;

  /// No description provided for @graphIntersection.
  ///
  /// In en, this message translates to:
  /// **'Intersection'**
  String get graphIntersection;

  /// No description provided for @graphNoFunctions.
  ///
  /// In en, this message translates to:
  /// **'Add a function to start graphing.'**
  String get graphNoFunctions;

  /// No description provided for @graphHide.
  ///
  /// In en, this message translates to:
  /// **'Hide graph'**
  String get graphHide;

  /// No description provided for @graphShow.
  ///
  /// In en, this message translates to:
  /// **'Show graph'**
  String get graphShow;

  /// No description provided for @graphTypeCartesian.
  ///
  /// In en, this message translates to:
  /// **'Function y = f(x)'**
  String get graphTypeCartesian;

  /// No description provided for @graphTypeCartesianShort.
  ///
  /// In en, this message translates to:
  /// **'y=f(x)'**
  String get graphTypeCartesianShort;

  /// No description provided for @graphTypePolar.
  ///
  /// In en, this message translates to:
  /// **'Polar r = f(θ)'**
  String get graphTypePolar;

  /// No description provided for @graphTypePolarShort.
  ///
  /// In en, this message translates to:
  /// **'Polar'**
  String get graphTypePolarShort;

  /// No description provided for @graphTypeParametric.
  ///
  /// In en, this message translates to:
  /// **'Parametric x(t), y(t)'**
  String get graphTypeParametric;

  /// No description provided for @graphTypeParametricShort.
  ///
  /// In en, this message translates to:
  /// **'Param.'**
  String get graphTypeParametricShort;

  /// No description provided for @graphTypeImplicit.
  ///
  /// In en, this message translates to:
  /// **'Implicit F(x, y) = 0'**
  String get graphTypeImplicit;

  /// No description provided for @graphTypeImplicitShort.
  ///
  /// In en, this message translates to:
  /// **'Implicit'**
  String get graphTypeImplicitShort;

  /// No description provided for @graphName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get graphName;

  /// No description provided for @graphNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Name it (e.g. f) to use f(x) in the calculator'**
  String get graphNameHelp;

  /// No description provided for @graphExpressionCartesian.
  ///
  /// In en, this message translates to:
  /// **'y ='**
  String get graphExpressionCartesian;

  /// No description provided for @graphExpressionPolar.
  ///
  /// In en, this message translates to:
  /// **'r ='**
  String get graphExpressionPolar;

  /// No description provided for @graphExpressionX.
  ///
  /// In en, this message translates to:
  /// **'x(t) ='**
  String get graphExpressionX;

  /// No description provided for @graphExpressionY.
  ///
  /// In en, this message translates to:
  /// **'y(t) ='**
  String get graphExpressionY;

  /// No description provided for @graphExpressionImplicit.
  ///
  /// In en, this message translates to:
  /// **'Equation in x and y'**
  String get graphExpressionImplicit;

  /// No description provided for @graphParamMin.
  ///
  /// In en, this message translates to:
  /// **'{name} min'**
  String graphParamMin(String name);

  /// No description provided for @graphParamMax.
  ///
  /// In en, this message translates to:
  /// **'{name} max'**
  String graphParamMax(String name);

  /// No description provided for @graphColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get graphColor;

  /// No description provided for @convTitle.
  ///
  /// In en, this message translates to:
  /// **'Unit converter'**
  String get convTitle;

  /// No description provided for @convCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get convCategory;

  /// No description provided for @convFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get convFrom;

  /// No description provided for @convTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get convTo;

  /// No description provided for @convValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get convValue;

  /// No description provided for @convValueHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2.5, 1/3 or 2.5E3'**
  String get convValueHint;

  /// No description provided for @convSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap units'**
  String get convSwap;

  /// No description provided for @convSearchUnits.
  ///
  /// In en, this message translates to:
  /// **'Search units'**
  String get convSearchUnits;

  /// No description provided for @convSearchAllUnits.
  ///
  /// In en, this message translates to:
  /// **'Search all units'**
  String get convSearchAllUnits;

  /// No description provided for @convNoUnits.
  ///
  /// In en, this message translates to:
  /// **'No units match your search.'**
  String get convNoUnits;

  /// No description provided for @convSelectFromUnit.
  ///
  /// In en, this message translates to:
  /// **'Convert from'**
  String get convSelectFromUnit;

  /// No description provided for @convSelectToUnit.
  ///
  /// In en, this message translates to:
  /// **'Convert to'**
  String get convSelectToUnit;

  /// No description provided for @convFromUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'From unit: {unit}'**
  String convFromUnitLabel(String unit);

  /// No description provided for @convToUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'To unit: {unit}'**
  String convToUnitLabel(String unit);

  /// No description provided for @convResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get convResult;

  /// No description provided for @convExactValue.
  ///
  /// In en, this message translates to:
  /// **'Exact: {value}'**
  String convExactValue(String value);

  /// No description provided for @convAllUnits.
  ///
  /// In en, this message translates to:
  /// **'All units in this category'**
  String get convAllUnits;

  /// No description provided for @convAllUnitsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a unit to convert to it.'**
  String get convAllUnitsHint;

  /// No description provided for @convRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent conversions'**
  String get convRecent;

  /// No description provided for @convRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your conversions appear here.'**
  String get convRecentEmpty;

  /// No description provided for @convClearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear recent conversions'**
  String get convClearRecent;

  /// No description provided for @convFavoriteUnits.
  ///
  /// In en, this message translates to:
  /// **'Favorite units'**
  String get convFavoriteUnits;

  /// No description provided for @convFavoriteCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category to favorites'**
  String get convFavoriteCategory;

  /// No description provided for @convUnfavoriteCategory.
  ///
  /// In en, this message translates to:
  /// **'Remove category from favorites'**
  String get convUnfavoriteCategory;

  /// No description provided for @convFavoriteUnit.
  ///
  /// In en, this message translates to:
  /// **'Add {unit} to favorites'**
  String convFavoriteUnit(String unit);

  /// No description provided for @convUnfavoriteUnit.
  ///
  /// In en, this message translates to:
  /// **'Remove {unit} from favorites'**
  String convUnfavoriteUnit(String unit);

  /// No description provided for @convEnterValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a value to convert.'**
  String get convEnterValue;

  /// No description provided for @convNotReal.
  ///
  /// In en, this message translates to:
  /// **'Enter a real number (complex values and lists cannot be converted).'**
  String get convNotReal;

  /// No description provided for @convBelowAbsoluteZero.
  ///
  /// In en, this message translates to:
  /// **'This temperature is below absolute zero (0 K = −273.15 °C = −459.67 °F). Nothing can be colder, so the value cannot be converted.'**
  String get convBelowAbsoluteZero;

  /// No description provided for @convReciprocalZero.
  ///
  /// In en, this message translates to:
  /// **'Zero cannot be converted between these units: one of them is the reciprocal of the other (for example L/100 km and km/L), so the result would be infinite.'**
  String get convReciprocalZero;

  /// No description provided for @convCopyResult.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get convCopyResult;

  /// No description provided for @convOtherCategories.
  ///
  /// In en, this message translates to:
  /// **'Units in other categories'**
  String get convOtherCategories;

  /// No description provided for @constTitle.
  ///
  /// In en, this message translates to:
  /// **'Constants'**
  String get constTitle;

  /// No description provided for @constSearch.
  ///
  /// In en, this message translates to:
  /// **'Search constants'**
  String get constSearch;

  /// No description provided for @constAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get constAll;

  /// No description provided for @constFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get constFavorites;

  /// No description provided for @constCatMathematical.
  ///
  /// In en, this message translates to:
  /// **'Mathematical'**
  String get constCatMathematical;

  /// No description provided for @constCatUniversal.
  ///
  /// In en, this message translates to:
  /// **'Universal'**
  String get constCatUniversal;

  /// No description provided for @constCatElectromagnetic.
  ///
  /// In en, this message translates to:
  /// **'Electromagnetic'**
  String get constCatElectromagnetic;

  /// No description provided for @constCatAtomic.
  ///
  /// In en, this message translates to:
  /// **'Atomic & nuclear'**
  String get constCatAtomic;

  /// No description provided for @constCatPhysicoChemical.
  ///
  /// In en, this message translates to:
  /// **'Physico-chemical'**
  String get constCatPhysicoChemical;

  /// No description provided for @constCatAstronomical.
  ///
  /// In en, this message translates to:
  /// **'Astronomical'**
  String get constCatAstronomical;

  /// No description provided for @constCatAdopted.
  ///
  /// In en, this message translates to:
  /// **'Adopted values'**
  String get constCatAdopted;

  /// No description provided for @constExact.
  ///
  /// In en, this message translates to:
  /// **'Exact by definition'**
  String get constExact;

  /// No description provided for @constUncertainty.
  ///
  /// In en, this message translates to:
  /// **'Standard uncertainty: {value}'**
  String constUncertainty(String value);

  /// No description provided for @constMeasured.
  ///
  /// In en, this message translates to:
  /// **'Measured value'**
  String get constMeasured;

  /// No description provided for @constDimensionless.
  ///
  /// In en, this message translates to:
  /// **'dimensionless'**
  String get constDimensionless;

  /// No description provided for @constUsage.
  ///
  /// In en, this message translates to:
  /// **'Use in expressions as {code}'**
  String constUsage(String code);

  /// No description provided for @constCopyValue.
  ///
  /// In en, this message translates to:
  /// **'Copy value'**
  String get constCopyValue;

  /// No description provided for @constInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert into calculator'**
  String get constInsert;

  /// No description provided for @constNoResults.
  ///
  /// In en, this message translates to:
  /// **'No constants match your search.'**
  String get constNoResults;

  /// No description provided for @constNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'Star a constant to keep it here.'**
  String get constNoFavorites;

  /// No description provided for @formulaTitle.
  ///
  /// In en, this message translates to:
  /// **'Formulas'**
  String get formulaTitle;

  /// No description provided for @formulaSearch.
  ///
  /// In en, this message translates to:
  /// **'Search formulas'**
  String get formulaSearch;

  /// No description provided for @formulaAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get formulaAll;

  /// No description provided for @formulaFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get formulaFavorites;

  /// No description provided for @formulaNoResults.
  ///
  /// In en, this message translates to:
  /// **'No formulas match your search.'**
  String get formulaNoResults;

  /// No description provided for @formulaNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'Star a formula to keep it here.'**
  String get formulaNoFavorites;

  /// No description provided for @formulaCatAlgebra.
  ///
  /// In en, this message translates to:
  /// **'Algebra'**
  String get formulaCatAlgebra;

  /// No description provided for @formulaCatGeometry.
  ///
  /// In en, this message translates to:
  /// **'Geometry'**
  String get formulaCatGeometry;

  /// No description provided for @formulaCatTrigonometry.
  ///
  /// In en, this message translates to:
  /// **'Trigonometry'**
  String get formulaCatTrigonometry;

  /// No description provided for @formulaCatCalculus.
  ///
  /// In en, this message translates to:
  /// **'Calculus'**
  String get formulaCatCalculus;

  /// No description provided for @formulaCatStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get formulaCatStatistics;

  /// No description provided for @formulaCatProbability.
  ///
  /// In en, this message translates to:
  /// **'Probability'**
  String get formulaCatProbability;

  /// No description provided for @formulaCatPhysics.
  ///
  /// In en, this message translates to:
  /// **'Physics'**
  String get formulaCatPhysics;

  /// No description provided for @formulaCatMechanics.
  ///
  /// In en, this message translates to:
  /// **'Mechanics'**
  String get formulaCatMechanics;

  /// No description provided for @formulaCatElectricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get formulaCatElectricity;

  /// No description provided for @formulaCatMagnetism.
  ///
  /// In en, this message translates to:
  /// **'Magnetism'**
  String get formulaCatMagnetism;

  /// No description provided for @formulaCatThermodynamics.
  ///
  /// In en, this message translates to:
  /// **'Thermodynamics'**
  String get formulaCatThermodynamics;

  /// No description provided for @formulaCatOptics.
  ///
  /// In en, this message translates to:
  /// **'Optics'**
  String get formulaCatOptics;

  /// No description provided for @formulaCatWaves.
  ///
  /// In en, this message translates to:
  /// **'Waves'**
  String get formulaCatWaves;

  /// No description provided for @formulaCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 formula} other{{count} formulas}}'**
  String formulaCount(int count);

  /// No description provided for @formulaNotFound.
  ///
  /// In en, this message translates to:
  /// **'This formula could not be found.'**
  String get formulaNotFound;

  /// No description provided for @formulaVariables.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get formulaVariables;

  /// No description provided for @formulaDescription.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get formulaDescription;

  /// No description provided for @formulaRelated.
  ///
  /// In en, this message translates to:
  /// **'Related formulas'**
  String get formulaRelated;

  /// No description provided for @formulaCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get formulaCalculate;

  /// No description provided for @formulaCalculateHint.
  ///
  /// In en, this message translates to:
  /// **'Fill in every value except the one you want to find, then tap Solve.'**
  String get formulaCalculateHint;

  /// No description provided for @formulaNeedOneEmpty.
  ///
  /// In en, this message translates to:
  /// **'Leave exactly one field empty: that is the value to solve for.'**
  String get formulaNeedOneEmpty;

  /// No description provided for @formulaInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a real number'**
  String get formulaInvalidValue;

  /// No description provided for @formulaSolvingFor.
  ///
  /// In en, this message translates to:
  /// **'Solving for {name}'**
  String formulaSolvingFor(String name);

  /// No description provided for @formulaSeveralSolutions.
  ///
  /// In en, this message translates to:
  /// **'The equation has {count} real solutions; all are shown.'**
  String formulaSeveralSolutions(int count);

  /// No description provided for @formulaNumericNote.
  ///
  /// In en, this message translates to:
  /// **'Found numerically, so the value is approximate.'**
  String get formulaNumericNote;

  /// No description provided for @formulaAlwaysTrue.
  ///
  /// In en, this message translates to:
  /// **'These values satisfy the formula for every value of {name}.'**
  String formulaAlwaysTrue(String name);

  /// No description provided for @formulaComplexOnly.
  ///
  /// In en, this message translates to:
  /// **'There is no real solution for these values (only complex ones).'**
  String get formulaComplexOnly;

  /// No description provided for @formulaClearFields.
  ///
  /// In en, this message translates to:
  /// **'Clear all fields'**
  String get formulaClearFields;

  /// No description provided for @formulaCopySolution.
  ///
  /// In en, this message translates to:
  /// **'Copy solution'**
  String get formulaCopySolution;

  /// No description provided for @formulaNoCalculator.
  ///
  /// In en, this message translates to:
  /// **'This formula is a reference identity, so it has no calculator.'**
  String get formulaNoCalculator;

  /// No description provided for @progTitle.
  ///
  /// In en, this message translates to:
  /// **'Programmer'**
  String get progTitle;

  /// No description provided for @progBase.
  ///
  /// In en, this message translates to:
  /// **'Input base'**
  String get progBase;

  /// No description provided for @progWordSize.
  ///
  /// In en, this message translates to:
  /// **'Word size'**
  String get progWordSize;

  /// No description provided for @progBitsLabel.
  ///
  /// In en, this message translates to:
  /// **'{bits}-bit'**
  String progBitsLabel(int bits);

  /// No description provided for @progSigned.
  ///
  /// In en, this message translates to:
  /// **'Signed (two\'s complement)'**
  String get progSigned;

  /// No description provided for @progUnsigned.
  ///
  /// In en, this message translates to:
  /// **'Unsigned'**
  String get progUnsigned;

  /// No description provided for @progExpression.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get progExpression;

  /// No description provided for @progExpressionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. FF AND 0F << 2'**
  String get progExpressionHint;

  /// No description provided for @progRange.
  ///
  /// In en, this message translates to:
  /// **'Range: {min} to {max}'**
  String progRange(String min, String max);

  /// No description provided for @progBin.
  ///
  /// In en, this message translates to:
  /// **'Binary'**
  String get progBin;

  /// No description provided for @progOct.
  ///
  /// In en, this message translates to:
  /// **'Octal'**
  String get progOct;

  /// No description provided for @progDec.
  ///
  /// In en, this message translates to:
  /// **'Decimal'**
  String get progDec;

  /// No description provided for @progHex.
  ///
  /// In en, this message translates to:
  /// **'Hexadecimal'**
  String get progHex;

  /// No description provided for @progCopyBase.
  ///
  /// In en, this message translates to:
  /// **'Copy {base} value'**
  String progCopyBase(String base);

  /// No description provided for @progBits.
  ///
  /// In en, this message translates to:
  /// **'Bits'**
  String get progBits;

  /// No description provided for @progBitsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a bit to toggle it.'**
  String get progBitsHint;

  /// No description provided for @progBitLabel.
  ///
  /// In en, this message translates to:
  /// **'Bit {index} is {value}. Double tap to toggle.'**
  String progBitLabel(int index, int value);

  /// No description provided for @progAllClear.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get progAllClear;

  /// No description provided for @progBackspace.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get progBackspace;

  /// No description provided for @progEquals.
  ///
  /// In en, this message translates to:
  /// **'Equals'**
  String get progEquals;

  /// No description provided for @progKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Insert {key}'**
  String progKeyLabel(String key);

  /// No description provided for @progEmpty.
  ///
  /// In en, this message translates to:
  /// **'Type an expression or use the keypad.'**
  String get progEmpty;

  /// No description provided for @ntTitle.
  ///
  /// In en, this message translates to:
  /// **'Number theory'**
  String get ntTitle;

  /// No description provided for @ntNumber.
  ///
  /// In en, this message translates to:
  /// **'Number n'**
  String get ntNumber;

  /// No description provided for @ntNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Whole number, e.g. 360 or 2^61-1'**
  String get ntNumberHint;

  /// No description provided for @ntAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get ntAnalyze;

  /// No description provided for @ntPrimeTest.
  ///
  /// In en, this message translates to:
  /// **'Prime test'**
  String get ntPrimeTest;

  /// No description provided for @ntIsPrime.
  ///
  /// In en, this message translates to:
  /// **'{n} is prime.'**
  String ntIsPrime(String n);

  /// No description provided for @ntNotPrime.
  ///
  /// In en, this message translates to:
  /// **'{n} is not prime.'**
  String ntNotPrime(String n);

  /// No description provided for @ntSmallestFactor.
  ///
  /// In en, this message translates to:
  /// **'Smallest prime factor: {p}'**
  String ntSmallestFactor(String p);

  /// No description provided for @ntFactorization.
  ///
  /// In en, this message translates to:
  /// **'Prime factorization'**
  String get ntFactorization;

  /// No description provided for @ntDivisors.
  ///
  /// In en, this message translates to:
  /// **'Divisors'**
  String get ntDivisors;

  /// No description provided for @ntDivisorCount.
  ///
  /// In en, this message translates to:
  /// **'Number of divisors: {count}'**
  String ntDivisorCount(String count);

  /// No description provided for @ntDivisorSum.
  ///
  /// In en, this message translates to:
  /// **'Sum of divisors: {sum}'**
  String ntDivisorSum(String sum);

  /// No description provided for @ntMoreDivisors.
  ///
  /// In en, this message translates to:
  /// **'… and {count} more'**
  String ntMoreDivisors(int count);

  /// No description provided for @ntNextPrime.
  ///
  /// In en, this message translates to:
  /// **'Next prime'**
  String get ntNextPrime;

  /// No description provided for @ntPrevPrime.
  ///
  /// In en, this message translates to:
  /// **'Previous prime'**
  String get ntPrevPrime;

  /// No description provided for @ntNoPrevPrime.
  ///
  /// In en, this message translates to:
  /// **'None: there is no prime below {n}.'**
  String ntNoPrevPrime(String n);

  /// No description provided for @ntTotient.
  ///
  /// In en, this message translates to:
  /// **'Euler\'s totient φ(n)'**
  String get ntTotient;

  /// No description provided for @ntGcdLcm.
  ///
  /// In en, this message translates to:
  /// **'GCD & LCM'**
  String get ntGcdLcm;

  /// No description provided for @ntNumbers.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get ntNumbers;

  /// No description provided for @ntNumbersHint.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas, e.g. 48, 180, 36'**
  String get ntNumbersHint;

  /// No description provided for @ntNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Enter at least two whole numbers separated by commas.'**
  String get ntNeedTwo;

  /// No description provided for @ntGcd.
  ///
  /// In en, this message translates to:
  /// **'Greatest common divisor'**
  String get ntGcd;

  /// No description provided for @ntLcm.
  ///
  /// In en, this message translates to:
  /// **'Least common multiple'**
  String get ntLcm;

  /// No description provided for @ntEuclidStep.
  ///
  /// In en, this message translates to:
  /// **'Divide {a} by {b}: quotient {q}, remainder {r}.'**
  String ntEuclidStep(String a, String b, String q, String r);

  /// No description provided for @ntEuclidDone.
  ///
  /// In en, this message translates to:
  /// **'The remainder is 0, so gcd({a}, {b}) = {g} (the last non-zero remainder).'**
  String ntEuclidDone(String a, String b, String g);

  /// No description provided for @ntEuclidZero.
  ///
  /// In en, this message translates to:
  /// **'gcd({a}, 0) = {g}, because every number divides 0.'**
  String ntEuclidZero(String a, String g);

  /// No description provided for @ntDivision.
  ///
  /// In en, this message translates to:
  /// **'Division & modulo'**
  String get ntDivision;

  /// No description provided for @ntDividend.
  ///
  /// In en, this message translates to:
  /// **'Dividend a'**
  String get ntDividend;

  /// No description provided for @ntDivisor.
  ///
  /// In en, this message translates to:
  /// **'Divisor b'**
  String get ntDivisor;

  /// No description provided for @ntQuotient.
  ///
  /// In en, this message translates to:
  /// **'Quotient (truncated)'**
  String get ntQuotient;

  /// No description provided for @ntRemainder.
  ///
  /// In en, this message translates to:
  /// **'Remainder (sign of a)'**
  String get ntRemainder;

  /// No description provided for @ntModulo.
  ///
  /// In en, this message translates to:
  /// **'a mod b (sign of b)'**
  String get ntModulo;

  /// No description provided for @ntNotInteger.
  ///
  /// In en, this message translates to:
  /// **'{field} must be a whole number.'**
  String ntNotInteger(String field);

  /// No description provided for @randTitle.
  ///
  /// In en, this message translates to:
  /// **'Random numbers'**
  String get randTitle;

  /// No description provided for @randSeed.
  ///
  /// In en, this message translates to:
  /// **'Seed (optional)'**
  String get randSeed;

  /// No description provided for @randSeedHint.
  ///
  /// In en, this message translates to:
  /// **'Whole number for a reproducible sequence'**
  String get randSeedHint;

  /// No description provided for @randApplySeed.
  ///
  /// In en, this message translates to:
  /// **'Apply seed'**
  String get randApplySeed;

  /// No description provided for @randClearSeed.
  ///
  /// In en, this message translates to:
  /// **'Clear seed'**
  String get randClearSeed;

  /// No description provided for @randSeedActive.
  ///
  /// In en, this message translates to:
  /// **'Seed {seed} is active: the same seed always gives the same sequence. Apply it again to restart.'**
  String randSeedActive(String seed);

  /// No description provided for @randSeedOff.
  ///
  /// In en, this message translates to:
  /// **'No seed: numbers are unpredictable.'**
  String get randSeedOff;

  /// No description provided for @randSeedInvalid.
  ///
  /// In en, this message translates to:
  /// **'The seed must be a whole number.'**
  String get randSeedInvalid;

  /// No description provided for @randDecimal.
  ///
  /// In en, this message translates to:
  /// **'Decimal in [0, 1)'**
  String get randDecimal;

  /// No description provided for @randInteger.
  ///
  /// In en, this message translates to:
  /// **'Integer in [a, b]'**
  String get randInteger;

  /// No description provided for @randRange.
  ///
  /// In en, this message translates to:
  /// **'Decimal in [a, b)'**
  String get randRange;

  /// No description provided for @randList.
  ///
  /// In en, this message translates to:
  /// **'List of integers'**
  String get randList;

  /// No description provided for @randPermutation.
  ///
  /// In en, this message translates to:
  /// **'Permutation of 1…n'**
  String get randPermutation;

  /// No description provided for @randMin.
  ///
  /// In en, this message translates to:
  /// **'a (minimum)'**
  String get randMin;

  /// No description provided for @randMax.
  ///
  /// In en, this message translates to:
  /// **'b (maximum)'**
  String get randMax;

  /// No description provided for @randCount.
  ///
  /// In en, this message translates to:
  /// **'n (how many)'**
  String get randCount;

  /// No description provided for @randAllowDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Allow duplicates'**
  String get randAllowDuplicates;

  /// No description provided for @randGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get randGenerate;

  /// No description provided for @randDice.
  ///
  /// In en, this message translates to:
  /// **'Roll a die'**
  String get randDice;

  /// No description provided for @randCoin.
  ///
  /// In en, this message translates to:
  /// **'Flip a coin'**
  String get randCoin;

  /// No description provided for @randHeads.
  ///
  /// In en, this message translates to:
  /// **'Heads'**
  String get randHeads;

  /// No description provided for @randTails.
  ///
  /// In en, this message translates to:
  /// **'Tails'**
  String get randTails;

  /// No description provided for @randResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get randResults;

  /// No description provided for @randNoResults.
  ///
  /// In en, this message translates to:
  /// **'Generated numbers appear here.'**
  String get randNoResults;

  /// No description provided for @randClearResults.
  ///
  /// In en, this message translates to:
  /// **'Clear results'**
  String get randClearResults;

  /// No description provided for @randCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all results'**
  String get randCopyAll;

  /// No description provided for @randTooFew.
  ///
  /// In en, this message translates to:
  /// **'Only {available} different values exist between a and b, fewer than the {count} requested.'**
  String randTooFew(String available, String count);

  /// No description provided for @randCountRange.
  ///
  /// In en, this message translates to:
  /// **'n must be a whole number from 1 to 10000.'**
  String get randCountRange;

  /// No description provided for @randNotReal.
  ///
  /// In en, this message translates to:
  /// **'Enter a real number.'**
  String get randNotReal;

  /// No description provided for @matrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Matrix calculator'**
  String get matrixTitle;

  /// No description provided for @matrixEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Matrix editor'**
  String get matrixEditorTitle;

  /// No description provided for @matrixSlotEmpty.
  ///
  /// In en, this message translates to:
  /// **'empty'**
  String get matrixSlotEmpty;

  /// No description provided for @matrixSlotSize.
  ///
  /// In en, this message translates to:
  /// **'{rows}×{columns}'**
  String matrixSlotSize(int rows, int columns);

  /// No description provided for @matrixRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get matrixRows;

  /// No description provided for @matrixColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get matrixColumns;

  /// No description provided for @matrixRowsDecrease.
  ///
  /// In en, this message translates to:
  /// **'Remove the last row'**
  String get matrixRowsDecrease;

  /// No description provided for @matrixRowsIncrease.
  ///
  /// In en, this message translates to:
  /// **'Add a row'**
  String get matrixRowsIncrease;

  /// No description provided for @matrixColumnsDecrease.
  ///
  /// In en, this message translates to:
  /// **'Remove the last column'**
  String get matrixColumnsDecrease;

  /// No description provided for @matrixColumnsIncrease.
  ///
  /// In en, this message translates to:
  /// **'Add a column'**
  String get matrixColumnsIncrease;

  /// No description provided for @matrixInsertRow.
  ///
  /// In en, this message translates to:
  /// **'Insert a row above the selected cell'**
  String get matrixInsertRow;

  /// No description provided for @matrixDeleteRow.
  ///
  /// In en, this message translates to:
  /// **'Delete the selected row'**
  String get matrixDeleteRow;

  /// No description provided for @matrixInsertColumn.
  ///
  /// In en, this message translates to:
  /// **'Insert a column left of the selected cell'**
  String get matrixInsertColumn;

  /// No description provided for @matrixDeleteColumn.
  ///
  /// In en, this message translates to:
  /// **'Delete the selected column'**
  String get matrixDeleteColumn;

  /// No description provided for @matrixClearValues.
  ///
  /// In en, this message translates to:
  /// **'Clear values'**
  String get matrixClearValues;

  /// No description provided for @matrixIdentityFill.
  ///
  /// In en, this message translates to:
  /// **'Fill with the identity matrix'**
  String get matrixIdentityFill;

  /// No description provided for @matrixZeroFill.
  ///
  /// In en, this message translates to:
  /// **'Fill with zeros'**
  String get matrixZeroFill;

  /// No description provided for @matrixPasteValues.
  ///
  /// In en, this message translates to:
  /// **'Paste values'**
  String get matrixPasteValues;

  /// No description provided for @matrixCopyMatrix.
  ///
  /// In en, this message translates to:
  /// **'Copy matrix'**
  String get matrixCopyMatrix;

  /// No description provided for @matrixDeleteMatrix.
  ///
  /// In en, this message translates to:
  /// **'Delete matrix'**
  String get matrixDeleteMatrix;

  /// No description provided for @matrixDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String matrixDeleted(String name);

  /// No description provided for @matrixPasteEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard does not contain matrix values.'**
  String get matrixPasteEmpty;

  /// No description provided for @matrixPasted.
  ///
  /// In en, this message translates to:
  /// **'Pasted a {rows}×{columns} matrix'**
  String matrixPasted(int rows, int columns);

  /// No description provided for @matrixPasteTrimmed.
  ///
  /// In en, this message translates to:
  /// **'The pasted values were trimmed to {rows}×{columns}.'**
  String matrixPasteTrimmed(int rows, int columns);

  /// No description provided for @matrixIdentityNeedsSquare.
  ///
  /// In en, this message translates to:
  /// **'The identity matrix is square: make the numbers of rows and columns equal first.'**
  String get matrixIdentityNeedsSquare;

  /// No description provided for @matrixMinSize.
  ///
  /// In en, this message translates to:
  /// **'A matrix needs at least one row and one column.'**
  String get matrixMinSize;

  /// No description provided for @matrixMaxSize.
  ///
  /// In en, this message translates to:
  /// **'The editor allows up to {max} rows and {max} columns.'**
  String matrixMaxSize(int max);

  /// No description provided for @matrixCellLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}, row {row}, column {column}'**
  String matrixCellLabel(String name, int row, int column);

  /// No description provided for @matrixCellError.
  ///
  /// In en, this message translates to:
  /// **'{name}, row {row}, column {column}: {error}'**
  String matrixCellError(String name, int row, int column, String error);

  /// No description provided for @matrixCellNotNumber.
  ///
  /// In en, this message translates to:
  /// **'each cell must be a single number'**
  String get matrixCellNotNumber;

  /// No description provided for @matrixUndefined.
  ///
  /// In en, this message translates to:
  /// **'{name} is empty. Enter its values in the matrix editor first.'**
  String matrixUndefined(String name);

  /// No description provided for @matrixVariableHint.
  ///
  /// In en, this message translates to:
  /// **'Use {name} in the calculator, for example det({name}).'**
  String matrixVariableHint(String name);

  /// No description provided for @matrixOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get matrixOperations;

  /// No description provided for @matrixOperandFirst.
  ///
  /// In en, this message translates to:
  /// **'Matrix A'**
  String get matrixOperandFirst;

  /// No description provided for @matrixOperandSecond.
  ///
  /// In en, this message translates to:
  /// **'Matrix B'**
  String get matrixOperandSecond;

  /// No description provided for @matrixScalar.
  ///
  /// In en, this message translates to:
  /// **'Scalar k'**
  String get matrixScalar;

  /// No description provided for @matrixExponent.
  ///
  /// In en, this message translates to:
  /// **'Exponent n'**
  String get matrixExponent;

  /// No description provided for @matrixExponentInteger.
  ///
  /// In en, this message translates to:
  /// **'The exponent must be a whole number.'**
  String get matrixExponentInteger;

  /// No description provided for @matrixOpAdd.
  ///
  /// In en, this message translates to:
  /// **'A + B'**
  String get matrixOpAdd;

  /// No description provided for @matrixOpSubtract.
  ///
  /// In en, this message translates to:
  /// **'A − B'**
  String get matrixOpSubtract;

  /// No description provided for @matrixOpMultiply.
  ///
  /// In en, this message translates to:
  /// **'A × B'**
  String get matrixOpMultiply;

  /// No description provided for @matrixOpScalar.
  ///
  /// In en, this message translates to:
  /// **'k × A'**
  String get matrixOpScalar;

  /// No description provided for @matrixOpTranspose.
  ///
  /// In en, this message translates to:
  /// **'Transpose Aᵀ'**
  String get matrixOpTranspose;

  /// No description provided for @matrixOpDeterminant.
  ///
  /// In en, this message translates to:
  /// **'Determinant'**
  String get matrixOpDeterminant;

  /// No description provided for @matrixOpInverse.
  ///
  /// In en, this message translates to:
  /// **'Inverse A⁻¹'**
  String get matrixOpInverse;

  /// No description provided for @matrixOpRank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get matrixOpRank;

  /// No description provided for @matrixOpTrace.
  ///
  /// In en, this message translates to:
  /// **'Trace'**
  String get matrixOpTrace;

  /// No description provided for @matrixOpRef.
  ///
  /// In en, this message translates to:
  /// **'Row echelon form (REF)'**
  String get matrixOpRef;

  /// No description provided for @matrixOpRref.
  ///
  /// In en, this message translates to:
  /// **'Reduced row echelon form (RREF)'**
  String get matrixOpRref;

  /// No description provided for @matrixOpPower.
  ///
  /// In en, this message translates to:
  /// **'Power Aⁿ'**
  String get matrixOpPower;

  /// No description provided for @matrixOpEigen.
  ///
  /// In en, this message translates to:
  /// **'Eigenvalues and eigenvectors'**
  String get matrixOpEigen;

  /// No description provided for @matrixResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get matrixResult;

  /// No description provided for @matrixSaveTo.
  ///
  /// In en, this message translates to:
  /// **'Save to matrix'**
  String get matrixSaveTo;

  /// No description provided for @matrixSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {name}'**
  String matrixSavedTo(String name);

  /// No description provided for @matrixStoreVariable.
  ///
  /// In en, this message translates to:
  /// **'Store in variable'**
  String get matrixStoreVariable;

  /// No description provided for @matrixStoredIn.
  ///
  /// In en, this message translates to:
  /// **'Stored in {name}'**
  String matrixStoredIn(String name);

  /// No description provided for @matrixEigenvalueSemantics.
  ///
  /// In en, this message translates to:
  /// **'Eigenvalue {index}: {value}, multiplicity {count}'**
  String matrixEigenvalueSemantics(int index, String value, int count);

  /// No description provided for @matrixEigenvectorSemantics.
  ///
  /// In en, this message translates to:
  /// **'Eigenvector: {value}'**
  String matrixEigenvectorSemantics(String value);

  /// No description provided for @matrixMultiplicity.
  ///
  /// In en, this message translates to:
  /// **'multiplicity {count}'**
  String matrixMultiplicity(int count);

  /// No description provided for @matrixNoEigenvector.
  ///
  /// In en, this message translates to:
  /// **'No eigenvector could be computed for this eigenvalue.'**
  String get matrixNoEigenvector;

  /// No description provided for @vectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Vector calculator'**
  String get vectorTitle;

  /// No description provided for @vectorDimension.
  ///
  /// In en, this message translates to:
  /// **'Dimension'**
  String get vectorDimension;

  /// No description provided for @vector2d.
  ///
  /// In en, this message translates to:
  /// **'2D'**
  String get vector2d;

  /// No description provided for @vector3d.
  ///
  /// In en, this message translates to:
  /// **'3D'**
  String get vector3d;

  /// No description provided for @vectorNd.
  ///
  /// In en, this message translates to:
  /// **'n-D'**
  String get vectorNd;

  /// No description provided for @vectorComponentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} components'**
  String vectorComponentCount(int count);

  /// No description provided for @vectorFewerComponents.
  ///
  /// In en, this message translates to:
  /// **'Fewer components'**
  String get vectorFewerComponents;

  /// No description provided for @vectorMoreComponents.
  ///
  /// In en, this message translates to:
  /// **'More components'**
  String get vectorMoreComponents;

  /// No description provided for @vectorA.
  ///
  /// In en, this message translates to:
  /// **'Vector A'**
  String get vectorA;

  /// No description provided for @vectorB.
  ///
  /// In en, this message translates to:
  /// **'Vector B'**
  String get vectorB;

  /// No description provided for @vectorComponentLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} component {index}'**
  String vectorComponentLabel(String name, int index);

  /// No description provided for @vectorComponentError.
  ///
  /// In en, this message translates to:
  /// **'{name}, component {index}: {error}'**
  String vectorComponentError(String name, int index, String error);

  /// No description provided for @vectorNotNumber.
  ///
  /// In en, this message translates to:
  /// **'each component must be a single number'**
  String get vectorNotNumber;

  /// No description provided for @vectorOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get vectorOperations;

  /// No description provided for @vectorOpAdd.
  ///
  /// In en, this message translates to:
  /// **'A + B'**
  String get vectorOpAdd;

  /// No description provided for @vectorOpSubtract.
  ///
  /// In en, this message translates to:
  /// **'A − B'**
  String get vectorOpSubtract;

  /// No description provided for @vectorOpNormA.
  ///
  /// In en, this message translates to:
  /// **'|A|'**
  String get vectorOpNormA;

  /// No description provided for @vectorOpNormB.
  ///
  /// In en, this message translates to:
  /// **'|B|'**
  String get vectorOpNormB;

  /// No description provided for @vectorOpUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit vector of A'**
  String get vectorOpUnit;

  /// No description provided for @vectorOpDot.
  ///
  /// In en, this message translates to:
  /// **'Dot product A · B'**
  String get vectorOpDot;

  /// No description provided for @vectorOpCross.
  ///
  /// In en, this message translates to:
  /// **'Cross product A × B'**
  String get vectorOpCross;

  /// No description provided for @vectorOpAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle between A and B'**
  String get vectorOpAngle;

  /// No description provided for @vectorOpProjection.
  ///
  /// In en, this message translates to:
  /// **'Projection of A onto B'**
  String get vectorOpProjection;

  /// No description provided for @vectorOpDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance between A and B'**
  String get vectorOpDistance;

  /// No description provided for @vectorResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get vectorResult;

  /// No description provided for @complexTitle.
  ///
  /// In en, this message translates to:
  /// **'Complex numbers'**
  String get complexTitle;

  /// No description provided for @complexInputForm.
  ///
  /// In en, this message translates to:
  /// **'Input form'**
  String get complexInputForm;

  /// No description provided for @complexInputRectangular.
  ///
  /// In en, this message translates to:
  /// **'Rectangular a + bi'**
  String get complexInputRectangular;

  /// No description provided for @complexInputPolar.
  ///
  /// In en, this message translates to:
  /// **'Polar r∠θ'**
  String get complexInputPolar;

  /// No description provided for @complexFirst.
  ///
  /// In en, this message translates to:
  /// **'z₁'**
  String get complexFirst;

  /// No description provided for @complexSecond.
  ///
  /// In en, this message translates to:
  /// **'z₂'**
  String get complexSecond;

  /// No description provided for @complexRealPart.
  ///
  /// In en, this message translates to:
  /// **'a (real part)'**
  String get complexRealPart;

  /// No description provided for @complexImaginaryPart.
  ///
  /// In en, this message translates to:
  /// **'b (imaginary part)'**
  String get complexImaginaryPart;

  /// No description provided for @complexModulusField.
  ///
  /// In en, this message translates to:
  /// **'r (modulus)'**
  String get complexModulusField;

  /// No description provided for @complexAngleField.
  ///
  /// In en, this message translates to:
  /// **'θ ({unit})'**
  String complexAngleField(String unit);

  /// No description provided for @complexFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'{number} {field}'**
  String complexFieldLabel(String number, String field);

  /// No description provided for @complexExponentField.
  ///
  /// In en, this message translates to:
  /// **'n (power and roots)'**
  String get complexExponentField;

  /// No description provided for @complexFieldError.
  ///
  /// In en, this message translates to:
  /// **'{field}: {error}'**
  String complexFieldError(String field, String error);

  /// No description provided for @complexNotReal.
  ///
  /// In en, this message translates to:
  /// **'enter a real number'**
  String get complexNotReal;

  /// No description provided for @complexRootsRange.
  ///
  /// In en, this message translates to:
  /// **'For roots, n must be a whole number from 1 to 100.'**
  String get complexRootsRange;

  /// No description provided for @complexOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get complexOperations;

  /// No description provided for @complexOpAdd.
  ///
  /// In en, this message translates to:
  /// **'z₁ + z₂'**
  String get complexOpAdd;

  /// No description provided for @complexOpSubtract.
  ///
  /// In en, this message translates to:
  /// **'z₁ − z₂'**
  String get complexOpSubtract;

  /// No description provided for @complexOpMultiply.
  ///
  /// In en, this message translates to:
  /// **'z₁ × z₂'**
  String get complexOpMultiply;

  /// No description provided for @complexOpDivide.
  ///
  /// In en, this message translates to:
  /// **'z₁ ÷ z₂'**
  String get complexOpDivide;

  /// No description provided for @complexOpPowerN.
  ///
  /// In en, this message translates to:
  /// **'Power z₁ⁿ'**
  String get complexOpPowerN;

  /// No description provided for @complexOpPowerZ.
  ///
  /// In en, this message translates to:
  /// **'Power z₁^z₂'**
  String get complexOpPowerZ;

  /// No description provided for @complexOpRoots.
  ///
  /// In en, this message translates to:
  /// **'n-th roots of z₁'**
  String get complexOpRoots;

  /// No description provided for @complexOpModulus.
  ///
  /// In en, this message translates to:
  /// **'Modulus |z₁|'**
  String get complexOpModulus;

  /// No description provided for @complexOpArgument.
  ///
  /// In en, this message translates to:
  /// **'Argument arg z₁'**
  String get complexOpArgument;

  /// No description provided for @complexOpConjugate.
  ///
  /// In en, this message translates to:
  /// **'Conjugate of z₁'**
  String get complexOpConjugate;

  /// No description provided for @complexOpReal.
  ///
  /// In en, this message translates to:
  /// **'Real part Re z₁'**
  String get complexOpReal;

  /// No description provided for @complexOpImaginary.
  ///
  /// In en, this message translates to:
  /// **'Imaginary part Im z₁'**
  String get complexOpImaginary;

  /// No description provided for @complexOpConvert.
  ///
  /// In en, this message translates to:
  /// **'Rectangular ↔ polar'**
  String get complexOpConvert;

  /// No description provided for @complexResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get complexResult;

  /// No description provided for @complexRootsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 root} other{{count} roots}}'**
  String complexRootsCount(int count);

  /// No description provided for @solveWorking.
  ///
  /// In en, this message translates to:
  /// **'Solving…'**
  String get solveWorking;

  /// No description provided for @solveEquationInput.
  ///
  /// In en, this message translates to:
  /// **'Equation'**
  String get solveEquationInput;

  /// No description provided for @solveEquationHelp.
  ///
  /// In en, this message translates to:
  /// **'Type an equation such as x^2-5x+6=0 or cos(x)=x. Put several linear equations on separate lines to solve them together.'**
  String get solveEquationHelp;

  /// No description provided for @solveUseExample.
  ///
  /// In en, this message translates to:
  /// **'Use this example'**
  String get solveUseExample;

  /// No description provided for @solveVariable.
  ///
  /// In en, this message translates to:
  /// **'Solve for'**
  String get solveVariable;

  /// No description provided for @solveSolveFor.
  ///
  /// In en, this message translates to:
  /// **'Solve for {name}'**
  String solveSolveFor(String name);

  /// No description provided for @solveNoVariableYet.
  ///
  /// In en, this message translates to:
  /// **'The unknown is detected from the equation (x by default).'**
  String get solveNoVariableYet;

  /// No description provided for @solveInterval.
  ///
  /// In en, this message translates to:
  /// **'Search interval (optional)'**
  String get solveInterval;

  /// No description provided for @solveLower.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get solveLower;

  /// No description provided for @solveUpper.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get solveUpper;

  /// No description provided for @solveIntervalHelp.
  ///
  /// In en, this message translates to:
  /// **'Used when no exact method applies and the equation is solved numerically. Leave empty to search from −1000 to 1000.'**
  String get solveIntervalHelp;

  /// No description provided for @solveIntervalBoth.
  ///
  /// In en, this message translates to:
  /// **'Enter both ends of the search interval, or leave both empty.'**
  String get solveIntervalBoth;

  /// No description provided for @solveIntervalOrder.
  ///
  /// In en, this message translates to:
  /// **'The start of the search interval must be smaller than its end.'**
  String get solveIntervalOrder;

  /// No description provided for @solveIntervalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Interval ends must be real numbers.'**
  String get solveIntervalInvalid;

  /// No description provided for @solveIntervalError.
  ///
  /// In en, this message translates to:
  /// **'Search interval: {message}'**
  String solveIntervalError(String message);

  /// No description provided for @solveSystemDetected.
  ///
  /// In en, this message translates to:
  /// **'{count} equations: they will be solved as a system of linear equations.'**
  String solveSystemDetected(int count);

  /// No description provided for @solveLineNotEquation.
  ///
  /// In en, this message translates to:
  /// **'Line {line} is not an equation. Write each line as left side = right side.'**
  String solveLineNotEquation(int line);

  /// No description provided for @solveSystemNonlinear.
  ///
  /// In en, this message translates to:
  /// **'Line {line} is not linear in the unknowns, so the lines cannot be solved as a linear system. Solve nonlinear equations one at a time (enter a single line).'**
  String solveSystemNonlinear(int line);

  /// No description provided for @solveNoUnknowns.
  ///
  /// In en, this message translates to:
  /// **'These equations contain no unknowns.'**
  String get solveNoUnknowns;

  /// No description provided for @solveSolution.
  ///
  /// In en, this message translates to:
  /// **'Solution'**
  String get solveSolution;

  /// No description provided for @solveSolutionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No solutions} =1{1 solution} other{{count} solutions}}'**
  String solveSolutionsCount(int count);

  /// No description provided for @solveAlwaysTrue.
  ///
  /// In en, this message translates to:
  /// **'The equation is true for all values of {name}.'**
  String solveAlwaysTrue(String name);

  /// No description provided for @solveNoSolutionFound.
  ///
  /// In en, this message translates to:
  /// **'The equation has no solution.'**
  String get solveNoSolutionFound;

  /// No description provided for @solveNoRootInInterval.
  ///
  /// In en, this message translates to:
  /// **'No solution was found in the search interval. Try a different interval.'**
  String get solveNoRootInInterval;

  /// No description provided for @solveNumericNote.
  ///
  /// In en, this message translates to:
  /// **'Numerical solution: found by a numerical search and rounded to the current precision.'**
  String get solveNumericNote;

  /// No description provided for @solveSearchedInterval.
  ///
  /// In en, this message translates to:
  /// **'Searched from {lower} to {upper}.'**
  String solveSearchedInterval(String lower, String upper);

  /// No description provided for @solvePeriodicNote.
  ///
  /// In en, this message translates to:
  /// **'The equation involves periodic functions, so there may be more solutions outside the searched interval.'**
  String get solvePeriodicNote;

  /// No description provided for @solveSymbolicNote.
  ///
  /// In en, this message translates to:
  /// **'Solution for {name} in terms of the other letters:'**
  String solveSymbolicNote(String name);

  /// No description provided for @solvePolynomialDegree.
  ///
  /// In en, this message translates to:
  /// **'Polynomial of degree {degree}'**
  String solvePolynomialDegree(int degree);

  /// No description provided for @solveRealRoot.
  ///
  /// In en, this message translates to:
  /// **'Real'**
  String get solveRealRoot;

  /// No description provided for @solveComplexRoot.
  ///
  /// In en, this message translates to:
  /// **'Complex'**
  String get solveComplexRoot;

  /// No description provided for @solveExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get solveExact;

  /// No description provided for @solveApproximate.
  ///
  /// In en, this message translates to:
  /// **'Approximate'**
  String get solveApproximate;

  /// No description provided for @solveMultiplicity.
  ///
  /// In en, this message translates to:
  /// **'Multiplicity {count}'**
  String solveMultiplicity(int count);

  /// No description provided for @solveDiscriminant.
  ///
  /// In en, this message translates to:
  /// **'Discriminant'**
  String get solveDiscriminant;

  /// No description provided for @solveTwoRealRoots.
  ///
  /// In en, this message translates to:
  /// **'Δ > 0: two distinct real roots.'**
  String get solveTwoRealRoots;

  /// No description provided for @solveRepeatedRoot.
  ///
  /// In en, this message translates to:
  /// **'Δ = 0: one repeated real root.'**
  String get solveRepeatedRoot;

  /// No description provided for @solveComplexPair.
  ///
  /// In en, this message translates to:
  /// **'Δ < 0: two complex conjugate roots.'**
  String get solveComplexPair;

  /// No description provided for @solveRootCounts.
  ///
  /// In en, this message translates to:
  /// **'{real} real, {complex} complex (counted with multiplicity)'**
  String solveRootCounts(int real, int complex);

  /// No description provided for @solvePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get solvePreview;

  /// No description provided for @solvePolyDegree.
  ///
  /// In en, this message translates to:
  /// **'Degree'**
  String get solvePolyDegree;

  /// No description provided for @solvePolyQuadratic.
  ///
  /// In en, this message translates to:
  /// **'Quadratic'**
  String get solvePolyQuadratic;

  /// No description provided for @solvePolyExample.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get solvePolyExample;

  /// No description provided for @solvePolyCoefficientOf.
  ///
  /// In en, this message translates to:
  /// **'Coefficient of x to the power {power}'**
  String solvePolyCoefficientOf(int power);

  /// No description provided for @solvePolyEnterCoefficients.
  ///
  /// In en, this message translates to:
  /// **'Enter the coefficients of the polynomial.'**
  String get solvePolyEnterCoefficients;

  /// No description provided for @solveSystemUnknowns.
  ///
  /// In en, this message translates to:
  /// **'Number of unknowns'**
  String get solveSystemUnknowns;

  /// No description provided for @solveSystemSize.
  ///
  /// In en, this message translates to:
  /// **'{count} unknowns'**
  String solveSystemSize(int count);

  /// No description provided for @solveSystemExample3.
  ///
  /// In en, this message translates to:
  /// **'3 × 3 example'**
  String get solveSystemExample3;

  /// No description provided for @solveSystemCoefficient.
  ///
  /// In en, this message translates to:
  /// **'Equation {row}, coefficient of {name}'**
  String solveSystemCoefficient(int row, String name);

  /// No description provided for @solveSystemConstant.
  ///
  /// In en, this message translates to:
  /// **'Equation {row}, right-hand side'**
  String solveSystemConstant(int row);

  /// No description provided for @solveSystemFieldHelp.
  ///
  /// In en, this message translates to:
  /// **'Fields accept numbers and expressions such as 1/3, -2.5 or sqrt(2). Empty fields count as 0.'**
  String get solveSystemFieldHelp;

  /// No description provided for @solveSystemEnterCoefficients.
  ///
  /// In en, this message translates to:
  /// **'Enter the coefficients of the equations.'**
  String get solveSystemEnterCoefficients;

  /// No description provided for @solveSystemUnique.
  ///
  /// In en, this message translates to:
  /// **'Unique solution'**
  String get solveSystemUnique;

  /// No description provided for @solveSystemNone.
  ///
  /// In en, this message translates to:
  /// **'The system has no solution (the equations are inconsistent).'**
  String get solveSystemNone;

  /// No description provided for @solveSystemInfinite.
  ///
  /// In en, this message translates to:
  /// **'The system has infinitely many solutions.'**
  String get solveSystemInfinite;

  /// No description provided for @solveSystemParameters.
  ///
  /// In en, this message translates to:
  /// **'t₁, t₂, … are free parameters: every choice of their values gives a solution.'**
  String get solveSystemParameters;

  /// No description provided for @solveCasInput.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get solveCasInput;

  /// No description provided for @solveCasInputHelp.
  ///
  /// In en, this message translates to:
  /// **'For example (x+1)^2, x^2-9 or sin(x)^2+cos(x)^2. Use = for Solve.'**
  String get solveCasInputHelp;

  /// No description provided for @solveCasOperation.
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get solveCasOperation;

  /// No description provided for @solveCasSimplify.
  ///
  /// In en, this message translates to:
  /// **'Simplify'**
  String get solveCasSimplify;

  /// No description provided for @solveCasExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get solveCasExpand;

  /// No description provided for @solveCasFactor.
  ///
  /// In en, this message translates to:
  /// **'Factor'**
  String get solveCasFactor;

  /// No description provided for @solveCasCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get solveCasCollect;

  /// No description provided for @solveCasSubstitute.
  ///
  /// In en, this message translates to:
  /// **'Substitute'**
  String get solveCasSubstitute;

  /// No description provided for @solveCasDifferentiate.
  ///
  /// In en, this message translates to:
  /// **'Differentiate'**
  String get solveCasDifferentiate;

  /// No description provided for @solveCasIntegrate.
  ///
  /// In en, this message translates to:
  /// **'Integrate'**
  String get solveCasIntegrate;

  /// No description provided for @solveCasEvaluate.
  ///
  /// In en, this message translates to:
  /// **'Evaluate'**
  String get solveCasEvaluate;

  /// No description provided for @solveCasValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get solveCasValue;

  /// No description provided for @solveCasOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get solveCasOrder;

  /// No description provided for @solveCasEnterValue.
  ///
  /// In en, this message translates to:
  /// **'Enter the value to substitute.'**
  String get solveCasEnterValue;

  /// No description provided for @solveCasInvalidVariable.
  ///
  /// In en, this message translates to:
  /// **'Enter a variable name such as x.'**
  String get solveCasInvalidVariable;

  /// No description provided for @solveCasIntegrateNote.
  ///
  /// In en, this message translates to:
  /// **'Indefinite integral: the result includes an arbitrary constant C.'**
  String get solveCasIntegrateNote;

  /// No description provided for @solveCasSendToCalculator.
  ///
  /// In en, this message translates to:
  /// **'Send to calculator'**
  String get solveCasSendToCalculator;

  /// No description provided for @calculusWorking.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculusWorking;

  /// No description provided for @calculusRadiansNote.
  ///
  /// In en, this message translates to:
  /// **'Calculus uses radians for trigonometric functions, whatever the calculator\'s angle mode.'**
  String get calculusRadiansNote;

  /// No description provided for @calculusInvalidVariable.
  ///
  /// In en, this message translates to:
  /// **'Enter a variable name such as x.'**
  String get calculusInvalidVariable;

  /// No description provided for @calculusFunctionLabel.
  ///
  /// In en, this message translates to:
  /// **'f({variable})'**
  String calculusFunctionLabel(String variable);

  /// No description provided for @calculusVariable.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get calculusVariable;

  /// No description provided for @calculusOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get calculusOrder;

  /// No description provided for @calculusAtPointOptional.
  ///
  /// In en, this message translates to:
  /// **'At {variable} = (optional)'**
  String calculusAtPointOptional(String variable);

  /// No description provided for @calculusPointHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2 or pi/4'**
  String get calculusPointHint;

  /// No description provided for @calculusDerivativeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. x^3+2x or sin(x)·e^x'**
  String get calculusDerivativeHint;

  /// No description provided for @calculusPartialNote.
  ///
  /// In en, this message translates to:
  /// **'If the function contains other letters (e.g. y), the partial derivative is taken and those letters are held constant.'**
  String get calculusPartialNote;

  /// No description provided for @calculusPartialHeld.
  ///
  /// In en, this message translates to:
  /// **'Partial derivative: all other variables were held constant.'**
  String get calculusPartialHeld;

  /// No description provided for @calculusDifferentiate.
  ///
  /// In en, this message translates to:
  /// **'Differentiate'**
  String get calculusDifferentiate;

  /// No description provided for @calculusDerivativeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a function and tap Differentiate.'**
  String get calculusDerivativeEmpty;

  /// No description provided for @calculusDerivativeResult.
  ///
  /// In en, this message translates to:
  /// **'Derivative'**
  String get calculusDerivativeResult;

  /// No description provided for @calculusValueAt.
  ///
  /// In en, this message translates to:
  /// **'Value at the point'**
  String get calculusValueAt;

  /// No description provided for @calculusNumericValueAt.
  ///
  /// In en, this message translates to:
  /// **'Numerical value at the point'**
  String get calculusNumericValueAt;

  /// No description provided for @calculusNumericLabel.
  ///
  /// In en, this message translates to:
  /// **'Symbolic differentiation is not available for this function, so the value was computed numerically.'**
  String get calculusNumericLabel;

  /// No description provided for @calculusNumericFallbackHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a point and choose order 1 or 2 to get a numerical derivative instead.'**
  String get calculusNumericFallbackHint;

  /// No description provided for @calculusIntegralHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. x^2 or 1/(1+x^2)'**
  String get calculusIntegralHint;

  /// No description provided for @calculusLowerBound.
  ///
  /// In en, this message translates to:
  /// **'Lower bound'**
  String get calculusLowerBound;

  /// No description provided for @calculusUpperBound.
  ///
  /// In en, this message translates to:
  /// **'Upper bound'**
  String get calculusUpperBound;

  /// No description provided for @calculusBoundHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 0, pi, inf'**
  String get calculusBoundHint;

  /// No description provided for @calculusBoundsNote.
  ///
  /// In en, this message translates to:
  /// **'Leave both bounds empty for the antiderivative. Bounds accept numbers, expressions such as pi/2, and inf or -inf.'**
  String get calculusBoundsNote;

  /// No description provided for @calculusBothBounds.
  ///
  /// In en, this message translates to:
  /// **'Enter both bounds, or leave both empty.'**
  String get calculusBothBounds;

  /// No description provided for @calculusIntegrate.
  ///
  /// In en, this message translates to:
  /// **'Integrate'**
  String get calculusIntegrate;

  /// No description provided for @calculusIntegralEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a function and tap Integrate.'**
  String get calculusIntegralEmpty;

  /// No description provided for @calculusAntiderivative.
  ///
  /// In en, this message translates to:
  /// **'Antiderivative'**
  String get calculusAntiderivative;

  /// No description provided for @calculusNoAntiderivative.
  ///
  /// In en, this message translates to:
  /// **'No closed-form antiderivative was found; the definite integral was computed numerically.'**
  String get calculusNoAntiderivative;

  /// No description provided for @calculusDefiniteExact.
  ///
  /// In en, this message translates to:
  /// **'Definite integral (exact)'**
  String get calculusDefiniteExact;

  /// No description provided for @calculusDefiniteNumeric.
  ///
  /// In en, this message translates to:
  /// **'Definite integral (numerical)'**
  String get calculusDefiniteNumeric;

  /// No description provided for @calculusErrorEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated error'**
  String get calculusErrorEstimate;

  /// No description provided for @calculusDivergenceHint.
  ///
  /// In en, this message translates to:
  /// **'An integral diverges when the area under the curve is infinite, for example 1/x on [0, 1] or 1/x on [1, ∞). Check the bounds and any points where the function is undefined.'**
  String get calculusDivergenceHint;

  /// No description provided for @calculusLimitHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. sin(x)/x'**
  String get calculusLimitHint;

  /// No description provided for @calculusLimitPoint.
  ///
  /// In en, this message translates to:
  /// **'{variable} approaches'**
  String calculusLimitPoint(String variable);

  /// No description provided for @calculusLimitPointHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 0, pi, inf, -inf'**
  String get calculusLimitPointHint;

  /// No description provided for @calculusPointRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the point the variable approaches.'**
  String get calculusPointRequired;

  /// No description provided for @calculusSide.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get calculusSide;

  /// No description provided for @calculusSideBoth.
  ///
  /// In en, this message translates to:
  /// **'Two-sided'**
  String get calculusSideBoth;

  /// No description provided for @calculusSideLeft.
  ///
  /// In en, this message translates to:
  /// **'From left (a⁻)'**
  String get calculusSideLeft;

  /// No description provided for @calculusSideRight.
  ///
  /// In en, this message translates to:
  /// **'From right (a⁺)'**
  String get calculusSideRight;

  /// No description provided for @calculusFindLimit.
  ///
  /// In en, this message translates to:
  /// **'Find limit'**
  String get calculusFindLimit;

  /// No description provided for @calculusLimitEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a function and the point, then tap Find limit.'**
  String get calculusLimitEmpty;

  /// No description provided for @calculusLimitResult.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get calculusLimitResult;

  /// No description provided for @calculusLimitPlusInfinity.
  ///
  /// In en, this message translates to:
  /// **'The function grows without bound (the limit is +∞).'**
  String get calculusLimitPlusInfinity;

  /// No description provided for @calculusLimitMinusInfinity.
  ///
  /// In en, this message translates to:
  /// **'The function decreases without bound (the limit is −∞).'**
  String get calculusLimitMinusInfinity;

  /// No description provided for @calculusLimitDneHint.
  ///
  /// In en, this message translates to:
  /// **'A limit exists only when the function approaches one single value. Try a one-sided limit (from the left or from the right).'**
  String get calculusLimitDneHint;

  /// No description provided for @calculusSeriesKind.
  ///
  /// In en, this message translates to:
  /// **'Sum or product'**
  String get calculusSeriesKind;

  /// No description provided for @calculusSum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get calculusSum;

  /// No description provided for @calculusProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get calculusProduct;

  /// No description provided for @calculusTerm.
  ///
  /// In en, this message translates to:
  /// **'Term in {index}'**
  String calculusTerm(String index);

  /// No description provided for @calculusTermHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. k^2 or 1/k'**
  String get calculusTermHint;

  /// No description provided for @calculusIndexVariable.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get calculusIndexVariable;

  /// No description provided for @calculusSeriesNote.
  ///
  /// In en, this message translates to:
  /// **'The index runs over whole numbers from the lower to the upper bound. Trigonometric terms use the {mode} angle mode.'**
  String calculusSeriesNote(String mode);

  /// No description provided for @calculusExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get calculusExamples;

  /// No description provided for @calculusSeriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a term and bounds, then tap Calculate.'**
  String get calculusSeriesEmpty;

  /// No description provided for @statsMode.
  ///
  /// In en, this message translates to:
  /// **'Data type'**
  String get statsMode;

  /// No description provided for @statsOneVariable.
  ///
  /// In en, this message translates to:
  /// **'One variable'**
  String get statsOneVariable;

  /// No description provided for @statsTwoVariable.
  ///
  /// In en, this message translates to:
  /// **'Two variables (X, Y)'**
  String get statsTwoVariable;

  /// No description provided for @statsUseFrequencies.
  ///
  /// In en, this message translates to:
  /// **'Frequency column'**
  String get statsUseFrequencies;

  /// No description provided for @statsDataTable.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get statsDataTable;

  /// No description provided for @statsRowsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String statsRowsCount(int count);

  /// No description provided for @statsValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get statsValue;

  /// No description provided for @statsFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get statsFrequency;

  /// No description provided for @statsX.
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get statsX;

  /// No description provided for @statsY.
  ///
  /// In en, this message translates to:
  /// **'Y'**
  String get statsY;

  /// No description provided for @statsAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get statsAddRow;

  /// No description provided for @statsRemoveRow.
  ///
  /// In en, this message translates to:
  /// **'Remove row {row}'**
  String statsRemoveRow(int row);

  /// No description provided for @statsPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste data'**
  String get statsPaste;

  /// No description provided for @statsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear data'**
  String get statsClear;

  /// No description provided for @statsPasteEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard contains no numbers.'**
  String get statsPasteEmpty;

  /// No description provided for @statsPasted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Pasted 1 row} other{Pasted {count} rows}}'**
  String statsPasted(int count);

  /// No description provided for @statsPasteTruncated.
  ///
  /// In en, this message translates to:
  /// **'Pasted the first {max} rows only.'**
  String statsPasteTruncated(int max);

  /// No description provided for @statsPasteHelpOne.
  ///
  /// In en, this message translates to:
  /// **'Paste numbers separated by commas, spaces or new lines. Cells also accept expressions such as 1/3 or sqrt(2).'**
  String get statsPasteHelpOne;

  /// No description provided for @statsPasteHelpTwo.
  ///
  /// In en, this message translates to:
  /// **'Paste two columns (X and Y on each line), or a list of X, Y pairs.'**
  String get statsPasteHelpTwo;

  /// No description provided for @statsCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate statistics'**
  String get statsCalculate;

  /// No description provided for @statsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter data and tap Calculate statistics.'**
  String get statsEmpty;

  /// No description provided for @statsCellError.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, {column}: {message}'**
  String statsCellError(int row, String column, String message);

  /// No description provided for @statsCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get statsCount;

  /// No description provided for @statsSum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get statsSum;

  /// No description provided for @statsSumSquares.
  ///
  /// In en, this message translates to:
  /// **'Sum of squares'**
  String get statsSumSquares;

  /// No description provided for @statsMean.
  ///
  /// In en, this message translates to:
  /// **'Mean'**
  String get statsMean;

  /// No description provided for @statsMedian.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get statsMedian;

  /// No description provided for @statsModes.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get statsModes;

  /// No description provided for @statsNoMode.
  ///
  /// In en, this message translates to:
  /// **'No mode: every value occurs equally often.'**
  String get statsNoMode;

  /// No description provided for @statsMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get statsMin;

  /// No description provided for @statsMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get statsMax;

  /// No description provided for @statsRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get statsRange;

  /// No description provided for @statsSampleVariance.
  ///
  /// In en, this message translates to:
  /// **'Sample variance'**
  String get statsSampleVariance;

  /// No description provided for @statsPopulationVariance.
  ///
  /// In en, this message translates to:
  /// **'Population variance'**
  String get statsPopulationVariance;

  /// No description provided for @statsSampleStdDev.
  ///
  /// In en, this message translates to:
  /// **'Sample standard deviation'**
  String get statsSampleStdDev;

  /// No description provided for @statsPopulationStdDev.
  ///
  /// In en, this message translates to:
  /// **'Population standard deviation'**
  String get statsPopulationStdDev;

  /// No description provided for @statsSampleNeedsTwo.
  ///
  /// In en, this message translates to:
  /// **'Sample variance and standard deviation need at least two values.'**
  String get statsSampleNeedsTwo;

  /// No description provided for @statsQ1.
  ///
  /// In en, this message translates to:
  /// **'First quartile'**
  String get statsQ1;

  /// No description provided for @statsQ3.
  ///
  /// In en, this message translates to:
  /// **'Third quartile'**
  String get statsQ3;

  /// No description provided for @statsIqr.
  ///
  /// In en, this message translates to:
  /// **'Interquartile range'**
  String get statsIqr;

  /// No description provided for @statsQuartileNote.
  ///
  /// In en, this message translates to:
  /// **'Quartiles use the median-of-halves method, as on most scientific calculators.'**
  String get statsQuartileNote;

  /// No description provided for @statsPercentile.
  ///
  /// In en, this message translates to:
  /// **'Percentile'**
  String get statsPercentile;

  /// No description provided for @statsPercentileP.
  ///
  /// In en, this message translates to:
  /// **'Percentile p (0–100)'**
  String get statsPercentileP;

  /// No description provided for @statsPercentileHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 90'**
  String get statsPercentileHint;

  /// No description provided for @statsMeanX.
  ///
  /// In en, this message translates to:
  /// **'Mean of X'**
  String get statsMeanX;

  /// No description provided for @statsMeanY.
  ///
  /// In en, this message translates to:
  /// **'Mean of Y'**
  String get statsMeanY;

  /// No description provided for @statsSumX.
  ///
  /// In en, this message translates to:
  /// **'Sum of X'**
  String get statsSumX;

  /// No description provided for @statsSumY.
  ///
  /// In en, this message translates to:
  /// **'Sum of Y'**
  String get statsSumY;

  /// No description provided for @statsSumXY.
  ///
  /// In en, this message translates to:
  /// **'Sum of XY'**
  String get statsSumXY;

  /// No description provided for @statsSumX2.
  ///
  /// In en, this message translates to:
  /// **'Sum of X²'**
  String get statsSumX2;

  /// No description provided for @statsSumY2.
  ///
  /// In en, this message translates to:
  /// **'Sum of Y²'**
  String get statsSumY2;

  /// No description provided for @statsSampleCovariance.
  ///
  /// In en, this message translates to:
  /// **'Sample covariance'**
  String get statsSampleCovariance;

  /// No description provided for @statsPopulationCovariance.
  ///
  /// In en, this message translates to:
  /// **'Population covariance'**
  String get statsPopulationCovariance;

  /// No description provided for @statsCorrelation.
  ///
  /// In en, this message translates to:
  /// **'Correlation coefficient (Pearson r)'**
  String get statsCorrelation;

  /// No description provided for @statsCorrelationTransformed.
  ///
  /// In en, this message translates to:
  /// **'Correlation of the transformed fit'**
  String get statsCorrelationTransformed;

  /// No description provided for @statsNoCorrelation.
  ///
  /// In en, this message translates to:
  /// **'The correlation is undefined because X or Y does not vary.'**
  String get statsNoCorrelation;

  /// No description provided for @statsRegression.
  ///
  /// In en, this message translates to:
  /// **'Regression'**
  String get statsRegression;

  /// No description provided for @statsRegressionModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get statsRegressionModel;

  /// No description provided for @statsRegLinear.
  ///
  /// In en, this message translates to:
  /// **'Linear'**
  String get statsRegLinear;

  /// No description provided for @statsRegQuadratic.
  ///
  /// In en, this message translates to:
  /// **'Quadratic'**
  String get statsRegQuadratic;

  /// No description provided for @statsRegExponential.
  ///
  /// In en, this message translates to:
  /// **'Exponential'**
  String get statsRegExponential;

  /// No description provided for @statsRegLogarithmic.
  ///
  /// In en, this message translates to:
  /// **'Logarithmic'**
  String get statsRegLogarithmic;

  /// No description provided for @statsRegPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get statsRegPower;

  /// No description provided for @statsR2.
  ///
  /// In en, this message translates to:
  /// **'Coefficient of determination'**
  String get statsR2;

  /// No description provided for @statsScatterLabel.
  ///
  /// In en, this message translates to:
  /// **'Scatter plot of {count} points with the fitted curve'**
  String statsScatterLabel(int count);

  /// No description provided for @statsPredictX.
  ///
  /// In en, this message translates to:
  /// **'Predict y for x ='**
  String get statsPredictX;

  /// No description provided for @statsPredict.
  ///
  /// In en, this message translates to:
  /// **'Predict'**
  String get statsPredict;

  /// No description provided for @statsPredictedY.
  ///
  /// In en, this message translates to:
  /// **'Predicted y'**
  String get statsPredictedY;

  /// No description provided for @probCombinatorics.
  ///
  /// In en, this message translates to:
  /// **'Combinatorics'**
  String get probCombinatorics;

  /// No description provided for @probNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get probNormal;

  /// No description provided for @probBinomial.
  ///
  /// In en, this message translates to:
  /// **'Binomial'**
  String get probBinomial;

  /// No description provided for @probPoisson.
  ///
  /// In en, this message translates to:
  /// **'Poisson'**
  String get probPoisson;

  /// No description provided for @probNItems.
  ///
  /// In en, this message translates to:
  /// **'n (items)'**
  String get probNItems;

  /// No description provided for @probRChosen.
  ///
  /// In en, this message translates to:
  /// **'r (chosen)'**
  String get probRChosen;

  /// No description provided for @probMean.
  ///
  /// In en, this message translates to:
  /// **'Mean μ'**
  String get probMean;

  /// No description provided for @probStdDev.
  ///
  /// In en, this message translates to:
  /// **'Standard deviation σ'**
  String get probStdDev;

  /// No description provided for @probXValue.
  ///
  /// In en, this message translates to:
  /// **'x'**
  String get probXValue;

  /// No description provided for @probLowerA.
  ///
  /// In en, this message translates to:
  /// **'Lower a'**
  String get probLowerA;

  /// No description provided for @probUpperB.
  ///
  /// In en, this message translates to:
  /// **'Upper b'**
  String get probUpperB;

  /// No description provided for @probAreaP.
  ///
  /// In en, this message translates to:
  /// **'Probability p (inverse)'**
  String get probAreaP;

  /// No description provided for @probTrials.
  ///
  /// In en, this message translates to:
  /// **'Trials n'**
  String get probTrials;

  /// No description provided for @probSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success probability p'**
  String get probSuccess;

  /// No description provided for @probK.
  ///
  /// In en, this message translates to:
  /// **'k'**
  String get probK;

  /// No description provided for @probCumulativeQ.
  ///
  /// In en, this message translates to:
  /// **'Cumulative probability (inverse)'**
  String get probCumulativeQ;

  /// No description provided for @probLambda.
  ///
  /// In en, this message translates to:
  /// **'Mean λ'**
  String get probLambda;

  /// No description provided for @probCombinatoricsHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave r empty to compute only n!.'**
  String get probCombinatoricsHelp;

  /// No description provided for @probOptionalHelp.
  ///
  /// In en, this message translates to:
  /// **'Results are shown for every filled-in field; leave a field empty to skip the results that need it.'**
  String get probOptionalHelp;

  /// No description provided for @probEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter the parameters and tap Calculate.'**
  String get probEmpty;

  /// No description provided for @probCombinations.
  ///
  /// In en, this message translates to:
  /// **'Combinations nCr'**
  String get probCombinations;

  /// No description provided for @probPermutations.
  ///
  /// In en, this message translates to:
  /// **'Permutations nPr'**
  String get probPermutations;

  /// No description provided for @probFactorial.
  ///
  /// In en, this message translates to:
  /// **'Factorial n!'**
  String get probFactorial;

  /// No description provided for @probDensity.
  ///
  /// In en, this message translates to:
  /// **'Probability density'**
  String get probDensity;

  /// No description provided for @probPmf.
  ///
  /// In en, this message translates to:
  /// **'Probability P(X = k)'**
  String get probPmf;

  /// No description provided for @probCdf.
  ///
  /// In en, this message translates to:
  /// **'Cumulative probability'**
  String get probCdf;

  /// No description provided for @probUpperTail.
  ///
  /// In en, this message translates to:
  /// **'Upper tail'**
  String get probUpperTail;

  /// No description provided for @probBetween.
  ///
  /// In en, this message translates to:
  /// **'Probability between a and b'**
  String get probBetween;

  /// No description provided for @probInverseNormal.
  ///
  /// In en, this message translates to:
  /// **'Inverse normal'**
  String get probInverseNormal;

  /// No description provided for @probInverseDiscrete.
  ///
  /// In en, this message translates to:
  /// **'Inverse: smallest k reaching the cumulative probability'**
  String get probInverseDiscrete;

  /// No description provided for @tableFunctionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. x^2 or sin(x)'**
  String get tableFunctionHint;

  /// No description provided for @tableSavedFunctions.
  ///
  /// In en, this message translates to:
  /// **'Saved functions'**
  String get tableSavedFunctions;

  /// No description provided for @tableNoSavedFunctions.
  ///
  /// In en, this message translates to:
  /// **'Functions you save in the graph or calculator appear in the saved-functions menu.'**
  String get tableNoSavedFunctions;

  /// No description provided for @tableStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get tableStart;

  /// No description provided for @tableEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get tableEnd;

  /// No description provided for @tableStep.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get tableStep;

  /// No description provided for @tableAngleNote.
  ///
  /// In en, this message translates to:
  /// **'Trigonometric functions use the {mode} angle mode. Up to {max} rows.'**
  String tableAngleNote(String mode, int max);

  /// No description provided for @tableBuild.
  ///
  /// In en, this message translates to:
  /// **'Build table'**
  String get tableBuild;

  /// No description provided for @tableEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a function and a range, then tap Build table.'**
  String get tableEmpty;

  /// No description provided for @tableRowCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String tableRowCount(int count);

  /// No description provided for @tableCopyCsv.
  ///
  /// In en, this message translates to:
  /// **'Copy table as CSV'**
  String get tableCopyCsv;

  /// No description provided for @tableCopied.
  ///
  /// In en, this message translates to:
  /// **'Table copied as CSV'**
  String get tableCopied;

  /// No description provided for @tableShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Sharing is not available on this device.'**
  String get tableShareFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
