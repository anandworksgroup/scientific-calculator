import 'dart:math' as math;

import 'algebra/polynomial.dart';
import 'algebra/solve.dart';
import 'ast/ast.dart';
import 'calculus/numeric_calculus.dart';
import 'cas/cas.dart' as cas;
import 'cas/integrate.dart';
import 'cas/sym.dart';
import 'core/budget.dart';
import 'core/errors.dart';
import 'eval/evaluator.dart';
import 'eval/values.dart';
import 'format/printers.dart';
import 'linalg/matrix_ops.dart';
import 'numbers/num.dart';
import 'parser/parser.dart';

/// Calculation settings that affect results.
class CalcSettings {
  const CalcSettings({
    this.precision = 15,
    this.angleMode = AngleMode.deg,
    this.complexResults = false,
  });

  /// Significant digits (10, 15, 20, 50, 100 …).
  final int precision;
  final AngleMode angleMode;

  /// Allow real-looking operations (√−1, ln(−1)) to return complex values.
  final bool complexResults;

  CalcSettings copyWith({int? precision, AngleMode? angleMode, bool? complexResults}) => CalcSettings(
        precision: precision ?? this.precision,
        angleMode: angleMode ?? this.angleMode,
        complexResults: complexResults ?? this.complexResults,
      );
}

/// User state the engine reads: variables and saved functions.
class Environment {
  Environment({
    Map<String, Value>? variables,
    Map<String, String>? functions,
    this.randomSeed,
  })  : variables = variables ?? {},
        functions = functions ?? {};

  final Map<String, Value> variables;

  /// Saved function definitions as source text, e.g. `{'f': 'f(x)=x^2'}`.
  final Map<String, String> functions;
  final int? randomSeed;

  Map<String, UserFunction> compileFunctions() {
    final out = <String, UserFunction>{};
    // Definitions may reference each other; parse with all names known.
    final names = functions.keys.toSet();
    for (final e in functions.entries) {
      try {
        final node = Parser.parse(e.value, scope: ParseScope(userFunctions: names, variables: variables.keys.toSet()));
        if (node is FunctionDefNode) out[node.name] = UserFunction(node.params, node.body, source: e.value);
      } on MathError {
        // Invalid saved definitions are ignored here; the Saved Functions
        // screen validates on edit.
      }
    }
    return out;
  }

  Environment copy() => Environment(
        variables: Map.of(variables),
        functions: Map.of(functions),
        randomSeed: randomSeed,
      );
}

/// Result of evaluating a calculator input.
class Evaluation {
  Evaluation({
    required this.ast,
    required this.value,
    required this.preferDecimal,
    required this.variables,
    this.exact,
    this.assignedName,
    this.definedFunction,
    this.solution,
  });

  final Node ast;
  final Value value;

  /// Show as decimal in "auto" format.
  final bool preferDecimal;

  /// Exact symbolic form when the numeric value is irrational (e.g. 2√2).
  final Sym? exact;
  final String? assignedName;
  final String? definedFunction;

  /// Present when the input was an equation that was solved.
  final EquationSolution? solution;

  /// Variables after evaluation (includes assignments).
  final Map<String, Value> variables;

  String get inputLatex => const LatexPrinter().print(ast);
  String get inputText => const TextPrinter().print(ast);
  String? get exactLatex => exact == null ? null : const LatexPrinter().print(cas.symToNode(exact!));
  String? get exactText => exact == null ? null : const TextPrinter(pretty: true).print(cas.symToNode(exact!));
}

class SymbolicResult {
  SymbolicResult(this.result, {this.note});
  final Sym result;
  final String? note;
  String get latex => const LatexPrinter().print(cas.symToNode(result));
  String get text => const TextPrinter(pretty: true).print(cas.symToNode(result));
  String get plain => const TextPrinter().print(cas.symToNode(result));
}

class DerivativeResult {
  DerivativeResult({required this.derivative, this.valueAt, required this.variable, required this.order});
  final Sym derivative;
  final Num? valueAt;
  final String variable;
  final int order;
  String get latex => const LatexPrinter().print(cas.symToNode(derivative));
  String get text => const TextPrinter(pretty: true).print(cas.symToNode(derivative));
}

class IntegralInfo {
  IntegralInfo({this.antiderivative, this.definite});
  final Sym? antiderivative;
  final IntegralResult? definite;
  String? get antiderivativeLatex =>
      antiderivative == null ? null : const LatexPrinter().print(cas.symToNode(antiderivative!));
  String? get antiderivativeText =>
      antiderivative == null ? null : const TextPrinter(pretty: true).print(cas.symToNode(antiderivative!));
}

class PolynomialSolution {
  PolynomialSolution(this.roots, this.steps, this.discriminant, this.degree);
  final List<PolyRoot> roots;
  final List<SolutionStep> steps;
  final Num? discriminant;
  final int degree;
}

class EigenPair {
  EigenPair(this.value, this.multiplicity, this.vectors);
  final Num value;
  final int multiplicity;
  final List<VectorValue> vectors;
}

/// The engine interface used by the app. Implementations can be replaced
/// without touching UI code.
abstract class MathEngine {
  EngineResult<Evaluation> evaluate(String input, CalcSettings settings, Environment env, {Budget? budget});
  EngineResult<SymbolicResult> simplify(String input, CalcSettings settings, Environment env);
  EngineResult<SymbolicResult> expand(String input, CalcSettings settings, Environment env);
  EngineResult<SymbolicResult> factor(String input, CalcSettings settings, Environment env);
  EngineResult<SymbolicResult> collect(String input, String variable, CalcSettings settings, Environment env);
  EngineResult<SymbolicResult> substitute(String input, String variable, String value, CalcSettings settings, Environment env);
  EngineResult<EquationSolution> solve(String equation, String variable, CalcSettings settings, Environment env,
      {double? lower, double? upper});
  EngineResult<PolynomialSolution> solvePolynomial(List<String> coefficientsHighToLow, CalcSettings settings, Environment env);
  EngineResult<LinearSystemSolution> solveLinearSystem(
      List<List<String>> coefficients, List<String> constants, List<String> variables, CalcSettings settings, Environment env);
  EngineResult<DerivativeResult> differentiate(String input, String variable, int order, CalcSettings settings, Environment env,
      {String? at});
  EngineResult<IntegralInfo> integrate(String input, String variable, CalcSettings settings, Environment env,
      {String? lower, String? upper});
  EngineResult<Value> limit(String input, String variable, String point, int side, CalcSettings settings, Environment env);
  EngineResult<List<EigenPair>> eigen(MatrixValue matrix, CalcSettings settings);
}

class DefaultMathEngine implements MathEngine {
  const DefaultMathEngine();

  static const defaultTimeLimit = Duration(seconds: 30);

  EvalContext _ctx(CalcSettings s, Environment env, {bool complex = false, Budget? budget}) => EvalContext(
        arith: Arith(precision: s.precision, allowComplex: s.complexResults || complex),
        angleMode: s.angleMode,
        variables: Map.of(env.variables),
        functions: env.compileFunctions(),
        random: env.randomSeed == null ? math.Random() : math.Random(env.randomSeed),
        budget: budget ?? Budget(timeLimit: defaultTimeLimit),
      );

  ParseScope _scope(Environment env, {Set<String> bound = const {}}) => ParseScope(
        variables: env.variables.keys.toSet(),
        userFunctions: env.functions.keys.toSet(),
        boundVariables: bound,
      );

  // --------------------------------------------------------------- evaluate

  @override
  EngineResult<Evaluation> evaluate(String input, CalcSettings settings, Environment env, {Budget? budget}) {
    return guard(() {
      final ast = Parser.parse(input, scope: _scope(env));
      final ctx = _ctx(settings, env, complex: containsImaginaryUnit(ast), budget: budget);
      final ev = Evaluator(ctx);
      if (ast is FunctionDefNode) {
        // Validate the body parses with its parameters bound.
        ev.eval(ast);
        return Evaluation(ast: ast, value: const BoolValue(true), preferDecimal: false,
            variables: ctx.variables, definedFunction: ast.name);
      }
      if (ast is EquationNode && ast.op == RelOp.eq) {
        final unknowns = freeVariables(ast).where((v) => !ctx.variables.containsKey(v)).toList();
        if (unknowns.length == 1) {
          final sol = EquationSolver(ctx).solve(ast, unknowns.first);
          final value = SolutionsValue(unknowns.first, [for (final r in sol.roots) r.value],
              numeric: sol.method == SolveMethod.numeric);
          return Evaluation(ast: ast, value: value, preferDecimal: containsDecimalLiteral(ast),
              variables: ctx.variables, solution: sol);
        }
        if (unknowns.length > 1) {
          throw MathError(MathErrorCode.notSupported, {
            'detail': 'The equation has several unknowns (${unknowns.join(', ')}). Use the equation solver to choose one.'
          });
        }
      }
      final value = ev.eval(ast);
      Sym? exact;
      if (value is NumberValue && _isApproximate(value.n)) {
        exact = _exactForm(ast is AssignmentNode ? ast.value : ast, ctx, value.n);
      }
      return Evaluation(
        ast: ast,
        value: value,
        preferDecimal: ev.preferDecimal || containsDecimalLiteral(ast),
        exact: exact,
        variables: ctx.variables,
        assignedName: ast is AssignmentNode ? ast.name : null,
      );
    });
  }

  bool _isApproximate(Num n) => n is Dec || (n is Cpx && (n.re is Dec || n.im is Dec));

  /// Exact symbolic form of a numeric result, if a "nice" one exists and it
  /// agrees with the numeric value.
  Sym? _exactForm(Node ast, EvalContext ctx, Num numeric) {
    try {
      final sym = cas.SymConverter(
        angleMode: ctx.angleMode,
        values: ctx.variables,
        userFunctions: {for (final e in ctx.functions.entries) e.key: (e.value.params, e.value.body)},
      ).convert(ast);
      if (symVariables(sym).isNotEmpty) return null;
      final s = cas.simplify(sym);
      if (!_isNice(s) || cas.symSize(s) > 30) return null;
      if (s is SNum) return null; // Rational: the numeric result is already exact.
      final check = cas.symEval(s, ctx.arith.withComplex(true));
      final diff = ctx.arith.withComplex(true).abs(ctx.arith.withComplex(true).sub(check, numeric)).toDouble();
      final mag = ctx.arith.withComplex(true).abs(numeric).toDouble().abs();
      if (!(diff <= 1e-12 * math.max(1.0, mag))) return null;
      return s;
    } on MathError {
      return null;
    } on StackOverflowError {
      return null;
    }
  }

  bool _isNice(Sym s) => switch (s) {
        SNum() || SConst() => true,
        SVar() => false,
        SAdd(:final terms) => terms.every(_isNice),
        SMul(:final factors) => factors.every(_isNice),
        SPow(:final base, :final exp) => (base is SNum || base is SConst || base is SAdd) && _isNice(base) && _isNice(exp),
        SFn(:final name, :final args) => name == 'ln' && args.first is SNum,
      };

  // ---------------------------------------------------------------- symbolic

  Sym _sym(String input, CalcSettings settings, Environment env, {bool radians = true}) {
    final ast = Parser.parseExpression(input, scope: _scope(env));
    final ctx = _ctx(settings, env);
    return cas.SymConverter(
      angleMode: radians ? AngleMode.rad : settings.angleMode,
      values: const {},
      userFunctions: {for (final e in ctx.functions.entries) e.key: (e.value.params, e.value.body)},
    ).convert(ast);
  }

  @override
  EngineResult<SymbolicResult> simplify(String input, CalcSettings settings, Environment env) =>
      guard(() => SymbolicResult(simplifySym(_sym(input, settings, env))));

  static Sym simplifySym(Sym s) => cas.simplify(s);

  @override
  EngineResult<SymbolicResult> expand(String input, CalcSettings settings, Environment env) =>
      guard(() => SymbolicResult(expandSym(_sym(input, settings, env))));

  static Sym expandSym(Sym s) => cas.expand(s);

  @override
  EngineResult<SymbolicResult> factor(String input, CalcSettings settings, Environment env) =>
      guard(() => SymbolicResult(cas.factorSym(_sym(input, settings, env))));

  @override
  EngineResult<SymbolicResult> collect(String input, String variable, CalcSettings settings, Environment env) =>
      guard(() => SymbolicResult(collectSym(_sym(input, settings, env), variable)));

  static Sym collectSym(Sym s, String v) => cas.collect(s, v);

  @override
  EngineResult<SymbolicResult> substitute(
          String input, String variable, String value, CalcSettings settings, Environment env) =>
      guard(() {
        final s = _sym(input, settings, env);
        final v = _sym(value, settings, env);
        return SymbolicResult(cas.simplify(substituteSym(s, variable, v)));
      });

  static Sym substituteSym(Sym s, String variable, Sym value) => cas.rebuild(s, (x) => x.name == variable ? value : x);

  // ------------------------------------------------------------------- solve

  @override
  EngineResult<EquationSolution> solve(String equation, String variable, CalcSettings settings, Environment env,
      {double? lower, double? upper}) {
    return guard(() {
      final env2 = env.copy()..variables.remove(variable);
      var ast = Parser.parse(equation, scope: _scope(env2, bound: {variable}));
      // "y = 2x + 1" parses as an assignment; for solving it is an equation.
      if (ast is AssignmentNode) ast = EquationNode(VariableNode(ast.name), ast.value);
      if (ast is! EquationNode && (ast is AssignmentNode || ast is FunctionDefNode)) {
        throw const MathError(MathErrorCode.invalidExpression, {'detail': 'enter an equation such as x^2 − 4 = 0'});
      }
      final ctx = _ctx(settings, env2, complex: true);
      return EquationSolver(ctx).solve(ast, variable, lo: lower, hi: upper);
    });
  }

  Num _num(String s, EvalContext ctx) {
    final ast = Parser.parseExpression(s, scope: ParseScope(variables: ctx.variables.keys.toSet()));
    return Evaluator(ctx).evalNumber(ast, 'A coefficient');
  }

  @override
  EngineResult<PolynomialSolution> solvePolynomial(
      List<String> coefficientsHighToLow, CalcSettings settings, Environment env) {
    return guard(() {
      final ctx = _ctx(settings, env, complex: true);
      final coeffs = [for (final c in coefficientsHighToLow.reversed) _num(c.trim().isEmpty ? '0' : c, ctx)];
      while (coeffs.length > 1 && coeffs.last.isZero) {
        coeffs.removeLast();
      }
      final degree = coeffs.length - 1;
      if (degree < 1) {
        if (coeffs.first.isZero) throw const MathError(MathErrorCode.infiniteSolutions);
        throw const MathError(MathErrorCode.noSolution);
      }
      final roots = PolynomialSolver(ctx.arith.withComplex(true), ctx.budget).roots(coeffs);
      var steps = <SolutionStep>[];
      Num? disc;
      if (degree <= 2 && coeffs.every((c) => c is Rat)) {
        final sol = EquationSolver(ctx).solve(
            EquationNode(_polyNode(coeffs.cast<Rat>()), NumberNode(Rat.zero)), 'x');
        steps = sol.steps;
        disc = sol.discriminant;
      } else if (degree == 2) {
        final a = ctx.arith;
        disc = a.sub(a.mul(coeffs[1], coeffs[1]), a.mul(Rat.int(4), a.mul(coeffs[2], coeffs[0])));
      }
      return PolynomialSolution(roots, steps, disc, degree);
    });
  }

  Node _polyNode(List<Rat> c) {
    Node? acc;
    for (var k = c.length - 1; k >= 0; k--) {
      if (c[k].isZero) continue;
      final term = k == 0
          ? NumberNode(c[k]) as Node
          : BinaryNode(BinaryOp.mul, NumberNode(c[k]),
              k == 1 ? const VariableNode('x') : BinaryNode(BinaryOp.pow, const VariableNode('x'), NumberNode(Rat.int(k))),
              mulStyle: MulStyle.implicit);
      acc = acc == null ? term : BinaryNode(BinaryOp.add, acc, term);
    }
    return acc ?? NumberNode(Rat.zero);
  }

  @override
  EngineResult<LinearSystemSolution> solveLinearSystem(List<List<String>> coefficients, List<String> constants,
      List<String> variables, CalcSettings settings, Environment env) {
    return guard(() {
      final ctx = _ctx(settings, env);
      final a = [for (final r in coefficients) [for (final c in r) _num(c.trim().isEmpty ? '0' : c, ctx)]];
      final b = [for (final c in constants) _num(c.trim().isEmpty ? '0' : c, ctx)];
      return LinearSystemSolver(ctx.arith).solve(a, b, variables);
    });
  }

  // ---------------------------------------------------------------- calculus

  @override
  EngineResult<DerivativeResult> differentiate(
      String input, String variable, int order, CalcSettings settings, Environment env,
      {String? at}) {
    return guard(() {
      if (order < 1 || order > 20) {
        throw const MathError(MathErrorCode.domainError, {'function': 'derivative', 'value': 'orders outside 1–20'});
      }
      final env2 = env.copy()..variables.remove(variable);
      var d = _sym(input, settings, env2);
      for (var k = 0; k < order; k++) {
        d = cas.differentiate(d, variable);
      }
      d = cas.simplify(d);
      Num? value;
      if (at != null && at.trim().isNotEmpty) {
        final ctx = _ctx(settings, env2);
        final point = _num(at, ctx);
        final sub = point is Rat ? cas.rebuild(d, (x) => x.name == variable ? S.n(point) : x) : null;
        if (sub is SNum) {
          value = sub.v;
        } else {
          final vars = <String, Num>{variable: point};
          for (final e in env2.variables.entries) {
            final val = e.value;
            if (val is NumberValue) vars[e.key] = val.n;
          }
          value = cas.symEval(d, ctx.arith, vars);
        }
      }
      return DerivativeResult(derivative: d, valueAt: value, variable: variable, order: order);
    });
  }

  @override
  EngineResult<IntegralInfo> integrate(String input, String variable, CalcSettings settings, Environment env,
      {String? lower, String? upper}) {
    return guard(() {
      final env2 = env.copy()..variables.remove(variable);
      Sym? anti;
      try {
        final f = _sym(input, settings, env2);
        anti = integrateSym(f, variable);
        if (anti != null) anti = cas.simplify(anti);
      } on MathError catch (e) {
        if (e.code != MathErrorCode.notSupported) rethrow;
      }
      IntegralResult? definite;
      if (lower != null && upper != null && lower.trim().isNotEmpty && upper.trim().isNotEmpty) {
        final settingsRad = settings.copyWith(angleMode: AngleMode.rad);
        final ctx = _ctx(settingsRad, env2);
        final scope = _scope(env2, bound: {variable});
        final body = Parser.parseExpression(input, scope: scope);
        final calc = NumericCalculus(Evaluator(ctx));
        final lo = calc.boundValue(Parser.parseExpression(lower, scope: _scope(env2)));
        final hi = calc.boundValue(Parser.parseExpression(upper, scope: _scope(env2)));
        definite = calc.integrate(body, variable, lo, hi);
      }
      if (anti == null && definite == null) {
        throw const MathError(MathErrorCode.notSupported, {
          'detail': 'No closed-form antiderivative was found. Enter limits to compute the definite integral numerically.'
        });
      }
      return IntegralInfo(antiderivative: anti, definite: definite);
    });
  }

  @override
  EngineResult<Value> limit(String input, String variable, String point, int side, CalcSettings settings, Environment env) {
    return guard(() {
      final env2 = env.copy()..variables.remove(variable);
      final settingsRad = settings.copyWith(angleMode: AngleMode.rad);
      final ctx = _ctx(settingsRad, env2);
      final body = Parser.parseExpression(input, scope: _scope(env2, bound: {variable}));
      final calc = NumericCalculus(Evaluator(ctx));
      final pointNode = Parser.parseExpression(point, scope: _scope(env2));
      final to = calc.boundValue(pointNode);
      return calc.limit(body, variable, to, side, pointNode: pointNode);
    });
  }

  // ------------------------------------------------------------------ matrix

  @override
  EngineResult<List<EigenPair>> eigen(MatrixValue matrix, CalcSettings settings) {
    return guard(() {
      final a = Arith(precision: settings.precision, allowComplex: true);
      final ops = MatrixOps(a);
      final coeffs = ops.characteristicPolynomial(matrix);
      final roots = PolynomialSolver(a).roots(coeffs);
      final out = <EigenPair>[];
      final n = matrix.rowCount;
      for (final r in roots) {
        final shifted = MatrixValue([
          for (var i = 0; i < n; i++)
            [for (var j = 0; j < n; j++) i == j ? a.sub(matrix.rows[i][j], r.value) : matrix.rows[i][j]]
        ]);
        List<VectorValue> vecs;
        try {
          vecs = ops.nullSpace(shifted);
        } on MathError {
          vecs = const [];
        }
        out.add(EigenPair(r.value, r.multiplicity, vecs));
      }
      return out;
    });
  }
}
