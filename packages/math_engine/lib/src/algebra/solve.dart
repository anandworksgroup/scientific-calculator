import 'dart:math' as math;

import '../ast/ast.dart';
import '../cas/cas.dart';
import '../cas/sym.dart';
import '../core/errors.dart';
import '../eval/double_eval.dart';
import '../eval/evaluator.dart';
import '../eval/values.dart';
import '../format/printers.dart';
import '../numbers/num.dart';
import 'polynomial.dart';

/// One step of a worked explanation, generated from the algorithm itself.
class SolutionStep {
  const SolutionStep(this.description, [this.latex]);
  final String description;
  final String? latex;
}

class SolvedRoot {
  const SolvedRoot(this.value, {this.exact, this.surd, this.multiplicity = 1, this.isExact = false});

  final Num value;

  /// Exact symbolic form when not a plain rational.
  final Sym? exact;
  final SurdForm? surd;
  final int multiplicity;
  final bool isExact;

  bool get isReal => value is! Cpx;
}

enum SolveMethod { polynomial, isolation, numeric, symbolic, identity }

class EquationSolution {
  EquationSolution({
    required this.variable,
    required this.roots,
    required this.method,
    this.symbolic = const [],
    this.steps = const [],
    this.searchInterval,
    this.periodic = false,
    this.degree,
    this.discriminant,
    this.alwaysTrue = false,
  });

  final String variable;
  final List<SolvedRoot> roots;

  /// Solutions containing other symbols (e.g. x = −b/a).
  final List<Sym> symbolic;
  final SolveMethod method;
  final List<SolutionStep> steps;

  /// For numerical searches: the interval that was scanned.
  final (double, double)? searchInterval;

  /// The equation involves periodic functions, so more solutions exist.
  final bool periodic;
  final int? degree;
  final Num? discriminant;

  /// The equation holds for every value (e.g. x = x).
  final bool alwaysTrue;
}

/// Solves single equations in one unknown.
class EquationSolver {
  EquationSolver(this.ctx);
  final EvalContext ctx;
  Arith get a => ctx.arith;

  static const _latex = LatexPrinter();
  String _tex(Sym s) => _latex.print(symToNode(s));

  EquationSolution solve(Node equation, String v, {double? lo, double? hi}) {
    Node lhs, rhs;
    if (equation is EquationNode) {
      if (equation.op != RelOp.eq) {
        throw const MathError(MathErrorCode.notSupported, {'detail': 'Only equations (=) can be solved.'});
      }
      lhs = equation.left;
      rhs = equation.right;
    } else {
      lhs = equation;
      rhs = NumberNode(Rat.zero);
    }
    final diff = BinaryNode(BinaryOp.sub, lhs, rhs);
    Sym? f;
    try {
      f = SymConverter(
        angleMode: ctx.angleMode,
        values: Map.of(ctx.variables)..remove(v),
        userFunctions: {for (final e in ctx.functions.entries) e.key: (e.value.params, e.value.body)},
      ).convert(diff);
    } on MathError {
      f = null;
    }
    if (f != null) {
      final others = symVariables(f)..remove(v);
      if (!dependsOn(f, v)) {
        final zero = others.isEmpty && _isZero(f);
        if (zero) {
          return EquationSolution(variable: v, roots: const [], method: SolveMethod.identity, alwaysTrue: true);
        }
        if (others.isEmpty) throw const MathError(MathErrorCode.noSolution);
        throw MathError(MathErrorCode.invalidExpression, {'detail': 'the equation does not contain $v'});
      }
      if (others.isNotEmpty) return _symbolic(f, v);
      final poly = _polynomial(f, v);
      if (poly != null) return poly;
      final iso = _isolation(f, v);
      if (iso != null && iso.roots.isNotEmpty) return iso;
    }
    return _numeric(diff, v, lo: lo, hi: hi, periodic: f != null && _hasPeriodic(f));
  }

  bool _isZero(Sym f) {
    try {
      return symEval(f, a).isZero;
    } on MathError {
      return false;
    }
  }

  bool _hasPeriodic(Sym s) => switch (s) {
        SFn(:final name, :final args) =>
          const {'sin', 'cos', 'tan'}.contains(name) || args.any(_hasPeriodic),
        SAdd(:final terms) => terms.any(_hasPeriodic),
        SMul(:final factors) => factors.any(_hasPeriodic),
        SPow(:final base, :final exp) => _hasPeriodic(base) || _hasPeriodic(exp),
        _ => false,
      };

  // ---------------------------------------------------------- polynomial

  EquationSolution? _polynomial(Sym f, String v) {
    final (num, den) = numDen(f);
    final coeffs = polyCoefficients(num, v);
    if (coeffs == null) return null;
    final rat = <Rat>[];
    for (final c in coeffs) {
      final r = c.asRat;
      if (r == null) return null;
      rat.add(r);
    }
    final deg = rat.length - 1;
    if (deg < 1) {
      if (rat.isEmpty || rat.first.isZero) {
        return EquationSolution(variable: v, roots: const [], method: SolveMethod.identity, alwaysTrue: true);
      }
      throw const MathError(MathErrorCode.noSolution);
    }
    final solver = PolynomialSolver(a.withComplex(true), ctx.budget);
    final roots = solver.roots(rat);
    final out = <SolvedRoot>[];
    for (final r in roots) {
      // Exclude roots of the denominator (not in the domain).
      if (den != S.one) {
        try {
          final dv = r.value is Rat ? symEval(substitute(den, v, S.n(r.value as Rat)), a) : symEval(den, a.withComplex(true), {v: r.value});
          if (dv.isZero || a.abs(dv).toDouble().abs() < 1e-30) continue;
        } on MathError {
          continue;
        }
      }
      if (!r.isReal && !a.allowComplex && !_complexWanted) {
        out.add(SolvedRoot(r.value, surd: r.surd, multiplicity: r.multiplicity, isExact: r.exact));
        continue;
      }
      out.add(SolvedRoot(r.value, surd: r.surd, multiplicity: r.multiplicity, isExact: r.exact));
    }
    final steps = <SolutionStep>[];
    Num? disc;
    if (deg == 1 && den == S.one) {
      steps.addAll(_linearSteps(rat, v));
    } else if (deg == 2 && den == S.one) {
      final (s, d) = _quadraticSteps(rat, v);
      steps.addAll(s);
      disc = d;
    }
    return EquationSolution(
      variable: v,
      roots: out,
      method: SolveMethod.polynomial,
      steps: steps,
      degree: deg,
      discriminant: disc,
    );
  }

  /// Complex roots of polynomials are always reported (flagged as complex).
  bool get _complexWanted => true;

  String _r(Rat x) => _latex.print(symToNode(S.n(x)));

  List<SolutionStep> _linearSteps(List<Rat> c, String v) {
    final aa = c[1], b = c[0];
    return [
      SolutionStep('Write the equation in the form a·$v + b = 0.', '${_r(aa)}$v${b.isNegative ? '' : '+'}${_r(b)}=0'),
      SolutionStep('Subtract b from both sides.', '${_r(aa)}$v=${_r(-b)}'),
      SolutionStep('Divide both sides by a.', '$v=\\frac{${_r(-b)}}{${_r(aa)}}=${_r(-b / aa)}'),
    ];
  }

  (List<SolutionStep>, Num) _quadraticSteps(List<Rat> c, String v) {
    final qa = c[2], qb = c[1], qc = c[0];
    final disc = qb * qb - Rat.int(4) * qa * qc;
    final steps = <SolutionStep>[
      SolutionStep('Identify the coefficients of a·$v² + b·$v + c = 0.',
          'a=${_r(qa)},\\quad b=${_r(qb)},\\quad c=${_r(qc)}'),
      const SolutionStep('Compute the discriminant.', r'\Delta=b^{2}-4ac'),
      SolutionStep('Substitute the coefficients.',
          '\\Delta=\\left(${_r(qb)}\\right)^{2}-4\\cdot${_wrapNeg(qa)}\\cdot${_wrapNeg(qc)}=${_r(disc)}'),
    ];
    if (disc.isNegative) {
      steps.add(const SolutionStep('Δ < 0, so there are two complex conjugate roots.'));
    } else if (disc.isZero) {
      steps.add(const SolutionStep('Δ = 0, so there is one repeated real root.'));
    } else {
      steps.add(const SolutionStep('Δ > 0, so there are two distinct real roots.'));
    }
    steps.add(SolutionStep('Apply the quadratic formula.', '$v=\\frac{-b\\pm\\sqrt{\\Delta}}{2a}'));
    final sqrtD = _tex(S.sqrt(S.n(disc)));
    steps.add(SolutionStep('Substitute.', '$v=\\frac{${_r(-qb)}\\pm$sqrtD}{${_r(Rat.two * qa)}}'));
    return (steps, disc);
  }

  String _wrapNeg(Rat r) => r.isNegative ? '\\left(${_r(r)}\\right)' : _r(r);

  // ------------------------------------------------------------ symbolic

  EquationSolution _symbolic(Sym f, String v) {
    final (num, _) = numDen(f);
    final c = polyCoefficients(num, v);
    if (c == null || c.length < 2 || c.length > 3) {
      throw MathError(MathErrorCode.notSupported, {
        'detail': 'The equation contains other unknowns (${(symVariables(f)..remove(v)).join(', ')}). '
            'Give them values first, or use an equation that is linear or quadratic in $v.'
      });
    }
    if (c.length == 2) {
      final sol = S.neg(S.div(c[0], c[1]));
      return EquationSolution(variable: v, roots: const [], symbolic: [simplify(sol)], method: SolveMethod.symbolic);
    }
    final qa = c[2], qb = c[1], qc = c[0];
    final disc = S.sub(S.pow(qb, S.two), S.mul([S.integer(4), qa, qc]));
    final root = S.sqrt(disc);
    final den = S.mul([S.two, qa]);
    return EquationSolution(
      variable: v,
      roots: const [],
      symbolic: [
        S.div(S.sub(S.neg(qb), root), den),
        S.div(S.add([S.neg(qb), root]), den),
      ],
      method: SolveMethod.symbolic,
    );
  }

  // ----------------------------------------------------------- isolation

  EquationSolution? _isolation(Sym f, String v) {
    List<Sym>? sols;
    try {
      sols = _isolate(f, S.zero, v, 0);
    } on MathError {
      sols = null;
    }
    if (sols == null) return null;
    final out = <SolvedRoot>[];
    final seen = <String>{};
    for (final s in sols) {
      try {
        final val = symEval(s, a);
        if (val is Cpx && !a.allowComplex) continue;
        // Verify: f(val) ≈ 0 (drops extraneous roots such as √x = −2).
        final check = symEval(f, a.withComplex(true), {v: val});
        final mag = a.abs(check).toDouble().abs();
        if (!(mag <= 1e-9 * math.max(1.0, a.abs(val).toDouble().abs()))) continue;
        if (!seen.add(val.toString())) continue;
        final exactSym = s is SNum ? null : s;
        out.add(SolvedRoot(s is SNum ? s.v : val, exact: exactSym, isExact: true));
      } on MathError {
        continue;
      }
    }
    out.sort((p, q) => p.value.toDouble().compareTo(q.value.toDouble()));
    return EquationSolution(variable: v, roots: out, method: SolveMethod.isolation);
  }

  List<Sym>? _isolate(Sym lhs, Sym rhs, String v, int depth) {
    if (depth > 12) return null;
    if (lhs is SVar && lhs.name == v) return [rhs];
    switch (lhs) {
      case SAdd(:final terms):
        final withV = terms.where((t) => dependsOn(t, v)).toList();
        if (withV.length != 1) return null;
        final others = terms.where((t) => !dependsOn(t, v)).toList();
        return _isolate(withV.first, S.sub(rhs, S.add(others)), v, depth + 1);
      case SMul(:final factors):
        final withV = factors.where((t) => dependsOn(t, v)).toList();
        if (withV.length != 1) return null;
        final others = S.mul(factors.where((t) => !dependsOn(t, v)).toList());
        return _isolate(withV.first, S.div(rhs, others), v, depth + 1);
      case SPow(:final base, :final exp):
        if (!dependsOn(exp, v)) {
          final e = exp.asRat;
          if (e == null) return null;
          if (e.isInteger && e.n.isEven && !e.isNegative) {
            final r = S.pow(rhs, S.n(e.reciprocal()));
            return [
              ...?_isolate(base, r, v, depth + 1),
              ...?_isolate(base, S.neg(r), v, depth + 1),
            ];
          }
          return _isolate(base, S.pow(rhs, S.n(e.reciprocal())), v, depth + 1);
        }
        if (!dependsOn(base, v)) {
          // b^u = r  →  u = ln r / ln b
          return _isolate(exp, S.div(S.ln(rhs), S.ln(base)), v, depth + 1);
        }
        return null;
      case SFn(:final name, :final args):
        final u = args.first;
        switch (name) {
          case 'ln':
            return _isolate(u, S.pow(S.e, rhs), v, depth + 1);
          case 'abs':
            return [...?_isolate(u, rhs, v, depth + 1), ...?_isolate(u, S.neg(rhs), v, depth + 1)];
          case 'asin':
            return _isolate(u, S.fn('sin', [rhs]), v, depth + 1);
          case 'acos':
            return _isolate(u, S.fn('cos', [rhs]), v, depth + 1);
          case 'atan':
            return _isolate(u, S.fn('tan', [rhs]), v, depth + 1);
          case 'sinh':
            return _isolate(u, S.fn('asinh', [rhs]), v, depth + 1);
          case 'tanh':
            return _isolate(u, S.fn('atanh', [rhs]), v, depth + 1);
        }
        return null;
      default:
        return null;
    }
  }

  // ------------------------------------------------------------- numeric

  EquationSolution _numeric(Node diff, String v, {double? lo, double? hi, bool periodic = false}) {
    DoubleFn? f;
    try {
      f = DoubleCompiler(
        parameters: [v],
        angleMode: ctx.angleMode,
        variables: Map.of(ctx.variables)..remove(v),
        functions: ctx.functions,
      ).compile(diff);
    } on MathError catch (e) {
      if (e.code == MathErrorCode.undefinedVariable) rethrow;
      throw const MathError(MathErrorCode.notSupported,
          {'detail': 'This equation cannot be solved numerically.'});
    }
    double g(double x) => f!([x]);
    final lower = lo ?? -1000.0, upper = hi ?? 1000.0;
    if (!(lower < upper)) {
      throw const MathError(MathErrorCode.invalidExpression, {'detail': 'the search interval is empty'});
    }
    final found = <double>[];
    void scan(double l, double r, int n) {
      var px = l, py = g(l);
      for (var k = 1; k <= n; k++) {
        ctx.budget.tick();
        final x = l + (r - l) * k / n;
        final y = g(x);
        if (py.isFinite && y.isFinite) {
          if (py == 0) {
            found.add(px);
          } else if ((py < 0) != (y < 0) && y != 0) {
            final root = _brent(g, px, x);
            if (root != null) found.add(root);
          } else if (k > 1) {
            // Possible tangential root: local minimum of |g| near zero.
            final mid = (px + x) / 2;
            final ym = g(mid);
            if (ym.isFinite && ym.abs() < py.abs() && ym.abs() < y.abs() && ym.abs() < 1e-3) {
              final m = _minimizeAbs(g, px, x);
              if (m != null && g(m).abs() < 1e-10) found.add(m);
            }
          }
        }
        px = x;
        py = y;
      }
    }

    if (lo == null && hi == null) {
      scan(-10, 10, 4000);
      scan(-1000, -10, 4000);
      scan(10, 1000, 4000);
    } else {
      scan(lower, upper, 20000);
    }
    // Polish in high precision and deduplicate.
    found.sort();
    final roots = <SolvedRoot>[];
    double? last;
    for (final r in found) {
      if (last != null && (r - last).abs() <= 1e-9 * math.max(1.0, r.abs())) continue;
      last = r;
      final polished = _polish(diff, v, r);
      if (polished == null) continue;
      roots.add(polished);
    }
    if (roots.isEmpty && !periodic && lo == null) {
      throw const MathError(MathErrorCode.noRealSolution);
    }
    return EquationSolution(
      variable: v,
      roots: roots,
      method: SolveMethod.numeric,
      searchInterval: lo == null && hi == null ? (-1000, 1000) : (lower, upper),
      periodic: periodic,
    );
  }

  SolvedRoot? _polish(Node diff, String v, double x0) {
    final hp = Arith(precision: a.precision + 10);
    Num evalAt(Num x) {
      final vars = Map<String, Value>.of(ctx.variables)..[v] = NumberValue(x);
      return Evaluator(ctx.copyWith(arith: hp, variables: vars)).evalNumber(diff, 'The equation');
    }

    // Rational snap first: exact roots stay exact.
    final r = _nearRational(x0);
    if (r != null) {
      try {
        if (evalAt(r).isZero) return SolvedRoot(r, isExact: true);
      } on MathError {
        // continue
      }
    }
    try {
      // Secant iterations in high precision.
      Num x1 = Dec.fromDouble(x0);
      Num x2 = hp.add(x1, Dec.fromDouble(math.max(1e-7, x0.abs() * 1e-7)));
      var f1 = evalAt(x1), f2 = evalAt(x2);
      for (var k = 0; k < 60; k++) {
        if (f2.isZero) break;
        final den = hp.sub(f2, f1);
        if (den.isZero) break;
        final x3 = hp.sub(x2, hp.div(hp.mul(f2, hp.sub(x2, x1)), den));
        x1 = x2;
        f1 = f2;
        x2 = x3;
        f2 = evalAt(x2);
        final step = hp.abs(hp.sub(x2, x1)).toDouble();
        if (step <= math.pow(10, -(a.precision + 6)) * math.max(1.0, x2.toDouble().abs())) break;
      }
      if (x2 is Cpx) return null;
      final res = hp.abs(f2).toDouble();
      if (!(res < 1e-8)) return null;
      final out = a.normalize(x2 is Dec ? x2.round(a.wp) : x2);
      return SolvedRoot(out);
    } on MathError {
      return null;
    }
  }

  static Rat? _nearRational(double x) {
    if (!x.isFinite) return null;
    for (var d = 1; d <= 64; d++) {
      final n = (x * d).roundToDouble();
      if ((n / d - x).abs() <= 1e-9 * math.max(1.0, x.abs())) return Rat.frac(n.toInt(), d);
    }
    return null;
  }

  static double? _brent(double Function(double) f, double lo, double hi) {
    var a = lo, b = hi, fa = f(a), fb = f(b);
    if (fa.isNaN || fb.isNaN || (fa < 0) == (fb < 0)) return null;
    var c = a, fc = fa, d = b - a, e = d;
    for (var it = 0; it < 200; it++) {
      if ((fb < 0) == (fc < 0)) {
        c = a;
        fc = fa;
        d = b - a;
        e = d;
      }
      if (fc.abs() < fb.abs()) {
        a = b;
        b = c;
        c = a;
        fa = fb;
        fb = fc;
        fc = fa;
      }
      final tol = 2e-16 * b.abs() + 1e-300;
      final m = (c - b) / 2;
      if (m.abs() <= tol || fb == 0) {
        // Reject poles: a genuine root has a small residual.
        final scale = math.max(1.0, math.max(f(lo).abs(), f(hi).abs()));
        return fb.abs() <= 1e-6 * scale ? b : null;
      }
      if (e.abs() >= tol && fa.abs() > fb.abs()) {
        final s = fb / fa;
        double p, q;
        if (a == c) {
          p = 2 * m * s;
          q = 1 - s;
        } else {
          final q0 = fa / fc, r = fb / fc;
          p = s * (2 * m * q0 * (q0 - r) - (b - a) * (r - 1));
          q = (q0 - 1) * (r - 1) * (s - 1);
        }
        if (p > 0) {
          q = -q;
        } else {
          p = -p;
        }
        if (2 * p < math.min(3 * m * q - (tol * q).abs(), (e * q).abs())) {
          e = d;
          d = p / q;
        } else {
          d = m;
          e = m;
        }
      } else {
        d = m;
        e = m;
      }
      a = b;
      fa = fb;
      b += d.abs() > tol ? d : (m > 0 ? tol : -tol);
      fb = f(b);
      if (fb.isNaN) return null;
    }
    return b;
  }

  static double? _minimizeAbs(double Function(double) f, double lo, double hi) {
    const gr = 0.6180339887498949;
    var a = lo, b = hi;
    var c = b - gr * (b - a), d = a + gr * (b - a);
    for (var k = 0; k < 100; k++) {
      if (f(c).abs() < f(d).abs()) {
        b = d;
      } else {
        a = c;
      }
      c = b - gr * (b - a);
      d = a + gr * (b - a);
    }
    final m = (a + b) / 2;
    return f(m).isFinite ? m : null;
  }
}

// ------------------------------------------------------------ linear systems

enum SystemKind { unique, none, infinite }

class LinearSystemSolution {
  LinearSystemSolution({
    required this.kind,
    required this.values,
    required this.parametric,
    required this.steps,
    required this.variables,
  });

  final SystemKind kind;

  /// Solution values (unique systems).
  final List<Num> values;

  /// LaTeX expression per variable in terms of parameters t₁, t₂…
  final List<String> parametric;
  final List<SolutionStep> steps;
  final List<String> variables;
}

/// Solves A·x = b exactly by Gauss–Jordan elimination, recording each row
/// operation as a step.
class LinearSystemSolver {
  LinearSystemSolver(this.a);
  final Arith a;

  static const _latex = LatexPrinter();

  LinearSystemSolution solve(List<List<Num>> coeffs, List<Num> rhs, List<String> vars) {
    final n = coeffs.length;
    if (n == 0) throw const MathError(MathErrorCode.emptyMatrix);
    final m = coeffs.first.length;
    if (m > 20 || n > 20) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'linear systems', 'limit': '20 unknowns'});
    }
    for (final r in coeffs) {
      if (r.length != m) {
        throw const MathError(MathErrorCode.dimensionMismatch, {'detail': 'every equation needs the same number of coefficients'});
      }
    }
    final aug = [for (var r = 0; r < n; r++) [...coeffs[r], rhs[r]]];
    final steps = <SolutionStep>[
      SolutionStep('Write the augmented matrix [A | b].', _matrixTex(aug, m)),
    ];
    var row = 0;
    final pivots = <int>[];
    final exact = aug.every((r) => r.every((v) => v is Rat));
    for (var c = 0; c < m && row < n; c++) {
      var p = -1;
      var best = -1.0;
      for (var r = row; r < n; r++) {
        final v = aug[r][c];
        if (v.isZero) continue;
        if (exact) {
          p = r;
          break;
        }
        final mag = a.abs(v).toDouble().abs();
        if (mag > best + 1e-300) {
          best = mag;
          p = r;
        }
      }
      if (p < 0 || (!exact && best < 1e-13)) continue;
      if (p != row) {
        final t = aug[p];
        aug[p] = aug[row];
        aug[row] = t;
        _addStep(steps, 'Swap rows R${row + 1} and R${p + 1}.', aug, m);
      }
      final pv = aug[row][c];
      if (!(pv is Rat && pv.isOne)) {
        for (var k = c; k <= m; k++) {
          aug[row][k] = a.div(aug[row][k], pv);
        }
        _addStep(steps, 'Divide R${row + 1} by ${_numText(pv)} to make the pivot 1.', aug, m);
      }
      for (var r = 0; r < n; r++) {
        if (r == row || aug[r][c].isZero) continue;
        final f = aug[r][c];
        for (var k = c; k <= m; k++) {
          aug[r][k] = a.sub(aug[r][k], a.mul(f, aug[row][k]));
        }
        _addStep(steps, 'R${r + 1} → R${r + 1} − (${_numText(f)})·R${row + 1}', aug, m);
      }
      pivots.add(c);
      row++;
    }
    // Inconsistency: 0 = nonzero.
    for (var r = row; r < n; r++) {
      final allZero = [for (var k = 0; k < m; k++) aug[r][k]].every((v) => v.isZero || (!exact && a.abs(v).toDouble() < 1e-12));
      if (allZero && !(aug[r][m].isZero || (!exact && a.abs(aug[r][m]).toDouble() < 1e-12))) {
        steps.add(SolutionStep('Row ${r + 1} reads 0 = ${_numText(aug[r][m])}, which is impossible.'));
        return LinearSystemSolution(kind: SystemKind.none, values: const [], parametric: const [], steps: steps, variables: vars);
      }
    }
    if (pivots.length == m) {
      final values = List<Num>.filled(m, Rat.zero);
      for (var i = 0; i < pivots.length; i++) {
        values[pivots[i]] = aug[i][m];
      }
      steps.add(SolutionStep('Read off the solution.',
          [for (var k = 0; k < m; k++) '${_varTex(vars[k])}=${_numTex(values[k])}'].join(r',\quad ')));
      return LinearSystemSolution(kind: SystemKind.unique, values: values, parametric: const [], steps: steps, variables: vars);
    }
    // Infinitely many: express pivot variables via free parameters.
    final free = [for (var c = 0; c < m; c++) if (!pivots.contains(c)) c];
    final param = {for (var k = 0; k < free.length; k++) free[k]: 't_{${k + 1}}'};
    final exprs = List<String>.filled(m, '');
    for (final f in free) {
      exprs[f] = param[f]!;
    }
    for (var i = 0; i < pivots.length; i++) {
      final pc = pivots[i];
      final sb = StringBuffer(_numTex(aug[i][m]));
      for (final f in free) {
        final coef = aug[i][f];
        if (coef.isZero) continue;
        final negCoef = a.neg(coef);
        final isNeg = negCoef is Rat ? negCoef.isNegative : a.signOf(negCoef) < 0;
        final absC = a.abs(negCoef);
        final cTex = absC is Rat && absC.isOne ? '' : _numTex(absC);
        sb.write('${isNeg ? '-' : '+'}$cTex${param[f]}');
      }
      exprs[pc] = sb.toString();
    }
    steps.add(SolutionStep('There are free variables, so the system has infinitely many solutions.',
        [for (var k = 0; k < m; k++) '${_varTex(vars[k])}=${exprs[k]}'].join(r',\quad ')));
    return LinearSystemSolution(kind: SystemKind.infinite, values: const [], parametric: exprs, steps: steps, variables: vars);
  }

  void _addStep(List<SolutionStep> steps, String text, List<List<Num>> aug, int m) {
    if (steps.length < 60) steps.add(SolutionStep(text, _matrixTex(aug, m)));
  }

  String _varTex(String v) => _latex.print(VariableNode(v));

  /// Plain-text number for step descriptions (LaTeX goes in the formula).
  String _numText(Num x) {
    if (x is Rat) return x.isInteger ? '${x.n}' : '${x.n}/${x.d}';
    if (x is Dec) return x.round(10).toString();
    return x.toString();
  }

  String _numTex(Num x) {
    if (x is Rat) return _latex.print(symToNode(S.n(x)));
    if (x is Dec) return x.round(10).toString().replaceAllMapped(RegExp(r'e(-?\d+)'), (mm) => r'\times10^{' '${mm.group(1)}}');
    return x.toString();
  }

  String _matrixTex(List<List<Num>> aug, int m) {
    final rows = aug.map((r) => [
          for (var k = 0; k < r.length; k++) _numTex(r[k]),
        ]);
    final spec = '${'c' * m}|c';
    return '\\left[\\begin{array}{$spec}${rows.map((r) => r.join(' & ')).join(r' \\ ')}\\end{array}\\right]';
  }
}
