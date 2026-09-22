import 'package:math_engine/math_engine.dart';

import '../l10n/generated/app_localizations.dart';

/// Localized, explanatory text for an engine error (never just "ERROR").
String errorText(AppLocalizations l, MathError e) {
  String p(String k) => '${e.params[k] ?? ''}';
  bool has(String k) => e.params[k] != null && '${e.params[k]}'.isNotEmpty;
  switch (e.code) {
    case MathErrorCode.emptyInput:
      return l.errEmptyInput;
    case MathErrorCode.invalidExpression:
      return has('detail') ? l.errInvalidExpressionDetail(p('detail')) : l.errInvalidExpression;
    case MathErrorCode.unexpectedToken:
      return l.errUnexpectedToken(p('token'));
    case MathErrorCode.mismatchedParentheses:
      return p('missing') == 'close' ? l.errMissingClose : l.errMissingOpen;
    case MathErrorCode.missingArgument:
      return has('after') ? l.errMissingArgumentAfter(p('after')) : l.errMissingArgument;
    case MathErrorCode.unknownIdentifier:
      return l.errUnknownIdentifier(p('name'));
    case MathErrorCode.undefinedVariable:
      return l.errUndefinedVariable(p('name'));
    case MathErrorCode.wrongArgumentCount:
      return l.errWrongArgumentCount(p('name'), p('expected'), p('got'));
    case MathErrorCode.divisionByZero:
      return l.errDivisionByZero;
    case MathErrorCode.undefinedResult:
      return has('detail') ? l.errUndefinedResultDetail(p('detail')) : l.errUndefinedResult;
    case MathErrorCode.domainError:
      return l.errDomain(p('function'), p('value'));
    case MathErrorCode.complexResult:
      return l.errComplexResult;
    case MathErrorCode.overflow:
      return l.errOverflow;
    case MathErrorCode.nonIntegerArgument:
      return l.errNonInteger(p('function'));
    case MathErrorCode.negativeArgument:
      return l.errNegative(p('function'));
    case MathErrorCode.tooLarge:
      return l.errTooLarge(p('function'), p('limit'));
    case MathErrorCode.dimensionMismatch:
      return has('detail') ? l.errDimensionDetail(p('detail')) : l.errDimension;
    case MathErrorCode.singularMatrix:
      return l.errSingular;
    case MathErrorCode.notSquare:
      return l.errNotSquare(p('operation'));
    case MathErrorCode.emptyMatrix:
      return l.errEmptyMatrix;
    case MathErrorCode.noRealSolution:
      return l.errNoRealSolution;
    case MathErrorCode.noSolution:
      return l.errNoSolution;
    case MathErrorCode.infiniteSolutions:
      return l.errInfiniteSolutions;
    case MathErrorCode.noConvergence:
      return has('detail') ? l.errNoConvergenceDetail(p('detail')) : l.errNoConvergence;
    case MathErrorCode.notSupported:
    case MathErrorCode.typeMismatch:
      return has('detail') ? p('detail') : l.errNotSupported;
    case MathErrorCode.invalidAssignment:
      return l.errInvalidAssignment(p('name'));
    case MathErrorCode.recursionLimit:
      return l.errRecursion;
    case MathErrorCode.cancelled:
      return l.errCancelled;
    case MathErrorCode.timeout:
      return l.errTimeout;
  }
}
