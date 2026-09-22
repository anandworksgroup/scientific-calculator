import '../ast/ast.dart';
import '../core/budget.dart';
import '../core/errors.dart';
import '../engine.dart';
import '../eval/evaluator.dart';
import '../eval/values.dart';
import '../numbers/num.dart';
import '../parser/parser.dart';

class TableRow {
  const TableRow(this.x, this.value, this.error);
  final Num x;
  final Value? value;
  final MathError? error;
}

/// Builds x | f(x) tables with exact arithmetic (e.g. step 0.1 does not
/// drift: 0.1 + 0.1 + 0.1 is exactly 0.3).
abstract final class FunctionTable {
  static const maxRows = 1000;

  static EngineResult<List<TableRow>> build({
    required String expression,
    required String variable,
    required String start,
    required String end,
    required String step,
    required CalcSettings settings,
    required Environment env,
  }) {
    return guard(() {
      final funcs = env.compileFunctions();
      final scope = ParseScope(
        variables: env.variables.keys.toSet(),
        userFunctions: funcs.keys.toSet(),
        boundVariables: {variable},
        allowDefinitions: false,
      );
      var src = expression.trim();
      // Accept "f(x) = …" / "y = …".
      final eq = src.indexOf('=');
      if (eq >= 0) src = src.substring(eq + 1);
      final body = Parser.parseExpression(src, scope: scope);
      final arith = Arith(precision: settings.precision, allowComplex: settings.complexResults);
      Num num(String s, String what) {
        final ctx = EvalContext(arith: arith, angleMode: settings.angleMode, variables: Map.of(env.variables), functions: funcs);
        final v = Evaluator(ctx).evalNumber(Parser.parseExpression(s, scope: scope), what);
        if (v is Cpx) throw const MathError(MathErrorCode.typeMismatch, {'detail': 'Table bounds must be real.'});
        return v;
      }

      final a = num(start, 'Start'), b = num(end, 'End'), h = num(step, 'Step');
      if (h.isZero || arith.signOf(h) < 0) {
        throw const MathError(MathErrorCode.domainError, {'function': 'the table step', 'value': 'zero or negative steps'});
      }
      if (arith.compare(a, b) > 0) {
        throw const MathError(MathErrorCode.invalidExpression, {'detail': 'the start value must not exceed the end value'});
      }
      final count = arith.floor(arith.div(arith.sub(b, a), h));
      final n = Arith.asInt(count);
      if (n == null || n + 1 > maxRows) {
        throw const MathError(MathErrorCode.tooLarge, {'function': 'function tables', 'limit': '$maxRows rows'});
      }
      final rows = <TableRow>[];
      final budget = Budget(timeLimit: const Duration(seconds: 20));
      for (var k = 0; k <= n; k++) {
        final x = arith.add(a, arith.mul(h, Rat.int(k)));
        final vars = Map<String, Value>.of(env.variables)..[variable] = NumberValue(x);
        final ctx = EvalContext(arith: arith, angleMode: settings.angleMode, variables: vars, functions: funcs, budget: budget);
        try {
          rows.add(TableRow(x, Evaluator(ctx).eval(body), null));
        } on MathError catch (e) {
          if (e.code == MathErrorCode.timeout || e.code == MathErrorCode.cancelled) rethrow;
          rows.add(TableRow(x, null, e));
        }
      }
      return rows;
    });
  }

  /// Free variables of an expression (used to suggest the table variable).
  static Set<String> variablesOf(String expression) {
    try {
      final src = expression.contains('=') ? expression.substring(expression.indexOf('=') + 1) : expression;
      return freeVariables(Parser.parseExpression(src));
    } on MathError {
      return const {};
    }
  }
}
