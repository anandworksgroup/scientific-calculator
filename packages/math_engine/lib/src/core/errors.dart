/// Structured errors produced by the math engine.
///
/// The engine never lets raw exceptions escape its public API: every
/// operation returns an [EngineResult]. Errors carry a machine-readable
/// [MathErrorCode] plus parameters so the UI can show a localized,
/// explanatory message; [MathError.message] is an English fallback.
library;

enum MathErrorCode {
  emptyInput,
  invalidExpression,
  unexpectedToken,
  mismatchedParentheses,
  missingArgument,
  unknownIdentifier,
  undefinedVariable,
  wrongArgumentCount,
  divisionByZero,
  undefinedResult,
  domainError,
  complexResult,
  overflow,
  nonIntegerArgument,
  negativeArgument,
  tooLarge,
  dimensionMismatch,
  singularMatrix,
  notSquare,
  emptyMatrix,
  noRealSolution,
  noSolution,
  infiniteSolutions,
  noConvergence,
  notSupported,
  typeMismatch,
  invalidAssignment,
  recursionLimit,
  cancelled,
  timeout,
}

class MathError implements Exception {
  const MathError(this.code, [this.params = const {}, this.position]);

  final MathErrorCode code;

  /// Extra detail used to build explanatory messages, e.g. `{'name': 'foo'}`.
  final Map<String, Object> params;

  /// Character offset in the source expression, when known.
  final int? position;

  String get message {
    String p(String k) => '${params[k] ?? ''}';
    switch (code) {
      case MathErrorCode.emptyInput:
        return 'Enter an expression first.';
      case MathErrorCode.invalidExpression:
        final d = params['detail'];
        return d == null ? 'Invalid expression.' : 'Invalid expression: $d.';
      case MathErrorCode.unexpectedToken:
        return "Unexpected '${p('token')}' in the expression.";
      case MathErrorCode.mismatchedParentheses:
        return params['missing'] == 'close'
            ? 'Mismatched parentheses: a closing bracket is missing.'
            : 'Mismatched parentheses: there is an extra closing bracket.';
      case MathErrorCode.missingArgument:
        return 'A number or expression is missing${params['after'] != null ? " after '${p('after')}'" : ''}.';
      case MathErrorCode.unknownIdentifier:
        return "Unknown function or variable '${p('name')}'.";
      case MathErrorCode.undefinedVariable:
        return "Variable '${p('name')}' has no value yet.";
      case MathErrorCode.wrongArgumentCount:
        return "${p('name')}() expects ${p('expected')} argument(s) but got ${p('got')}.";
      case MathErrorCode.divisionByZero:
        return 'Division by zero is undefined.';
      case MathErrorCode.undefinedResult:
        final d = params['detail'];
        return d == null ? 'The result is undefined.' : 'The result is undefined: $d.';
      case MathErrorCode.domainError:
        return "Domain error: ${p('function')} is not defined for ${p('value')}.";
      case MathErrorCode.complexResult:
        return 'The result is a complex number. Enable complex results in settings or include i in the expression.';
      case MathErrorCode.overflow:
        return 'Overflow: the result is too large to represent.';
      case MathErrorCode.nonIntegerArgument:
        return "${p('function')} requires whole-number arguments.";
      case MathErrorCode.negativeArgument:
        return "${p('function')} requires non-negative arguments.";
      case MathErrorCode.tooLarge:
        return "Input too large for ${p('function')} (limit ${p('limit')}).";
      case MathErrorCode.dimensionMismatch:
        final d = params['detail'];
        return d == null ? 'Matrix dimensions do not match.' : 'Dimensions do not match: $d.';
      case MathErrorCode.singularMatrix:
        return 'The matrix is singular (determinant is 0), so it has no inverse.';
      case MathErrorCode.notSquare:
        return "${p('operation')} requires a square matrix.";
      case MathErrorCode.emptyMatrix:
        return 'The matrix is empty.';
      case MathErrorCode.noRealSolution:
        return 'There is no real solution.';
      case MathErrorCode.noSolution:
        return 'The system has no solution (it is inconsistent).';
      case MathErrorCode.infiniteSolutions:
        return 'The system has infinitely many solutions.';
      case MathErrorCode.noConvergence:
        final d = params['detail'];
        return d == null ? 'The calculation did not converge.' : 'The calculation did not converge: $d.';
      case MathErrorCode.notSupported:
        return params['detail']?.toString() ?? 'This operation is not supported.';
      case MathErrorCode.typeMismatch:
        return params['detail']?.toString() ?? 'This operation cannot be applied to these values.';
      case MathErrorCode.invalidAssignment:
        return "Cannot assign to '${p('name')}'.";
      case MathErrorCode.recursionLimit:
        return 'The expression is nested too deeply.';
      case MathErrorCode.cancelled:
        return 'Calculation cancelled.';
      case MathErrorCode.timeout:
        return 'The calculation took too long and was stopped.';
    }
  }

  @override
  String toString() => 'MathError(${code.name}): $message';
}

/// Result type returned by public engine operations.
sealed class EngineResult<T> {
  const EngineResult();

  bool get isSuccess => this is Success<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        _ => null,
      };

  MathError? get errorOrNull => switch (this) {
        Failure<T>(:final error) => error,
        Cancelled<T>() => const MathError(MathErrorCode.cancelled),
        _ => null,
      };
}

final class Success<T> extends EngineResult<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends EngineResult<T> {
  const Failure(this.error);
  final MathError error;
}

final class Cancelled<T> extends EngineResult<T> {
  const Cancelled();
}

/// Runs [body], converting any thrown error into a structured result so
/// that no exception leaks into the UI.
EngineResult<T> guard<T>(T Function() body) {
  try {
    return Success(body());
  } on MathError catch (e) {
    if (e.code == MathErrorCode.cancelled) return Cancelled<T>();
    return Failure(e);
  } on StackOverflowError {
    return const Failure(MathError(MathErrorCode.recursionLimit));
  } on OutOfMemoryError {
    return const Failure(MathError(MathErrorCode.overflow));
  } on UnsupportedError catch (e) {
    return Failure(MathError(MathErrorCode.notSupported, {'detail': '${e.message}'}));
  } on RangeError {
    return const Failure(MathError(MathErrorCode.invalidExpression));
  } on ArgumentError catch (e) {
    return Failure(MathError(MathErrorCode.invalidExpression, {'detail': '${e.message}'}));
  } on FormatException catch (e) {
    return Failure(MathError(MathErrorCode.invalidExpression, {'detail': e.message}));
  } catch (e) {
    return Failure(MathError(MathErrorCode.invalidExpression, {'detail': '$e'}));
  }
}
