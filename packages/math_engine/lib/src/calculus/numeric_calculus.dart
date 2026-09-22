import 'dart:math' as math;

import '../algebra/polynomial.dart';
import '../ast/ast.dart';
import '../cas/cas.dart';
import '../cas/integrate.dart';
import '../cas/sym.dart';
import '../core/errors.dart';
import '../eval/double_eval.dart';
import '../eval/evaluator.dart';
import '../eval/values.dart';
import '../linalg/matrix_ops.dart';
import '../numbers/num.dart';

/// A real number or ±∞ (integration bounds, limit points).
class ExtNum {
  const ExtNum.finite(Num this.value) : infinity = 0;
  const ExtNum.infinite(this.infinity) : value = null;

  final Num? value;

  /// +1 or −1 for ±∞, 0 when finite.
  final int infinity;

  bool get isFinite => infinity == 0;
  double toDouble() => isFinite ? value!.toDouble() : infinity * double.infinity;
}

class IntegralResult {
  const IntegralResult(this.value, {required this.exact, this.errorEstimate, this.antiderivative});
  final Num value;
  final bool exact;

  /// Absolute error estimate for numerical results.
  final double? errorEstimate;
  final Sym? antiderivative;
}

/// Calculus operations used inside expressions (deriv, integral, sum,
/// prod, lim) and by the calculus screens. Exact symbolic methods are
/// tried first; numerical methods are the fallback.
class NumericCalculus {
  NumericCalculus(this.ev);

  final Evaluator ev;
  Arith get a => ev.a;
  EvalContext get ctx => ev.ctx;

  // -------------------------------------------------------------- helpers

  ExtNum boundValue(Node n) {
    if (n is ConstantNode && n.name == 'inf') return const ExtNum.infinite(1);
    if (n is UnaryNode && n.op == UnaryOp.negate && n.operand is ConstantNode &&
        (n.operand as ConstantNode).name == 'inf') {
      return const ExtNum.infinite(-1);
    }
    if (n is UnaryNode && n.op == UnaryOp.plus) return boundValue(n.operand);
    final v = ev.evalNumber(n, 'A bound');
    if (v is Cpx) {
      throw const MathError(MathErrorCode.typeMismatch, {'detail': 'Bounds must be real numbers.'});
    }
    return ExtNum.finite(v);
  }

  Map<String, Value> _varsWithout(String v) => Map.of(ctx.variables)..remove(v);

  SymConverter _converter(String v) => SymConverter(
        angleMode: ctx.angleMode,
        values: _varsWithout(v),
        userFunctions: {
          for (final e in ctx.functions.entries) e.key: (e.value.params, e.value.body),
        },
      );

  Sym? _toSym(Node body, String v) {
    try {
      return _converter(v).convert(body);
    } on MathError {
      return null;
    }
  }

  /// Evaluates [body] with [v] = [x] using the exact/high-precision evaluator.
  Num evalAt(Node body, String v, Num x, {Arith? arith}) {
    final vars = Map<String, Value>.of(ctx.variables)..[v] = NumberValue(x);
    final e = Evaluator(ctx.copyWith(arith: arith ?? a, variables: vars));
    return e.evalNumber(body, 'The expression');
  }

  DoubleFn? _compile(Node body, String v) {
    try {
      return DoubleCompiler(
        parameters: [v],
        angleMode: ctx.angleMode,
        variables: _varsWithout(v),
        functions: ctx.functions,
      ).compile(body);
    } on MathError {
      return null;
    }
  }

  // ---------------------------------------------------------- derivative

  Num derivative(Node body, String v, Num at, int order) {
    final f = _toSym(body, v);
    if (f != null) {
      try {
        var d = f;
        for (var k = 0; k < order; k++) {
          d = differentiate(d, v);
        }
        final atSym = at is Rat ? S.n(at) : null;
        if (atSym != null) {
          final r = substitute(d, v, atSym);
          if (r is SNum) return r.v;
          return symEval(r, a);
        }
        return symEval(d, a, {v: at});
      } on MathError catch (e) {
        if (e.code == MathErrorCode.divisionByZero || e.code == MathErrorCode.domainError) {
          throw const MathError(MathErrorCode.undefinedResult,
              {'detail': 'the derivative does not exist at this point'});
        }
        if (e.code != MathErrorCode.notSupported) rethrow;
      }
    }
    if (order > 2) {
      throw const MathError(MathErrorCode.notSupported,
          {'detail': 'Higher-order derivatives of this function need a symbolic form.'});
    }
    return _numericDerivative(body, v, at, order);
  }

  /// Central differences with Richardson extrapolation in high precision.
  Num _numericDerivative(Node body, String v, Num at, int order) {
    final hp = Arith(precision: a.precision + 25, allowComplex: a.allowComplex);
    final scale = math.max(1.0, at.toDouble().abs());
    Num step(int k) => hp.mul(Dec.fromDouble(scale), Rat(BigInt.one, pow10(k)));
    Num estimate(Num h) {
      final fp = evalAt(body, v, hp.add(at, h), arith: hp);
      final fm = evalAt(body, v, hp.sub(at, h), arith: hp);
      if (order == 1) return hp.div(hp.sub(fp, fm), hp.mul(Rat.two, h));
      final f0 = evalAt(body, v, at, arith: hp);
      return hp.div(hp.add(hp.sub(fp, hp.mul(Rat.two, f0)), fm), hp.mul(h, h));
    }

    // A jump (floor, sign, round…) makes the symmetric difference stay
    // large as h shrinks; a differentiable function's difference scales
    // with h.
    final jumpNear = hp.abs(hp.sub(evalAt(body, v, hp.add(at, step(6)), arith: hp), evalAt(body, v, hp.sub(at, step(6)), arith: hp)));
    final jumpFar = hp.abs(hp.sub(evalAt(body, v, hp.add(at, step(3)), arith: hp), evalAt(body, v, hp.sub(at, step(3)), arith: hp)));
    if (!jumpFar.isZero && hp.compare(jumpNear, hp.mul(jumpFar, Rat.frac(1, 10))) > 0) {
      throw const MathError(MathErrorCode.undefinedResult,
          {'detail': 'the function is not differentiable at this point (it jumps or has a corner)'});
    }
    final k0 = (a.precision + 25) ~/ (order == 1 ? 3 : 4);
    final d1 = estimate(step(k0));
    final d2 = estimate(hp.div(step(k0), Rat.two));
    // Richardson: error ∝ h², so D ≈ (4·D(h/2) − D(h)) / 3.
    final r = hp.div(hp.sub(hp.mul(Rat.int(4), d2), d1), Rat.int(3));
    final res = a.normalize(r);
    return res is Dec ? res.round(a.wp).withSig(a.precision) : res;
  }

  // ------------------------------------------------------------ integral

  IntegralResult integrate(Node body, String v, ExtNum lo, ExtNum hi) {
    var sign = 1;
    if (lo.isFinite && hi.isFinite) {
      final c = a.compare(lo.value!, hi.value!);
      if (c == 0) return IntegralResult(Rat.zero, exact: true);
      if (c > 0) {
        sign = -1;
        final t = lo;
        lo = hi;
        hi = t;
      }
    } else if (!lo.isFinite && !hi.isFinite && lo.infinity == hi.infinity) {
      return IntegralResult(Rat.zero, exact: true);
    } else if ((!lo.isFinite && lo.infinity > 0) || (!hi.isFinite && hi.infinity < 0)) {
      sign = -1;
      final t = lo;
      lo = hi;
      hi = t;
    }
    final r = _integrateOrdered(body, v, lo, hi);
    if (sign < 0) {
      return IntegralResult(a.neg(r.value),
          exact: r.exact, errorEstimate: r.errorEstimate, antiderivative: r.antiderivative);
    }
    return r;
  }

  IntegralResult _integrateOrdered(Node body, String v, ExtNum lo, ExtNum hi) {
    final f = _compile(body, v);
    double Function(double) fn;
    if (f != null) {
      fn = (x) => f([x]);
    } else {
      fn = (x) {
        try {
          return evalAt(body, v, Dec.fromDouble(x), arith: Arith(precision: 17)).toDouble();
        } on MathError {
          return double.nan;
        }
      };
    }
    final (g, ta, tb) = _transform(fn, lo.toDouble(), hi.toDouble());
    // Interior singularities: split at integrable ones, reject divergent ones.
    final sing = _singularities(g, ta, tb);
    if (sing.any((s) => !s.$2)) {
      throw const MathError(MathErrorCode.noConvergence,
          {'detail': 'the integrand has a non-integrable singularity inside the interval, so the integral diverges'});
    }
    if (_endpointDivergent(g, ta, tb, 1) || _endpointDivergent(g, tb, ta, -1)) {
      throw const MathError(MathErrorCode.noConvergence,
          {'detail': 'the integrand grows too fast at an end of the interval, so the integral diverges'});
    }
    final cuts = [ta, for (final s in sing) s.$1, tb];
    final singularAt = <bool>[
      _endpointGrows(g, ta, tb, 1),
      for (final _ in sing) true,
      _endpointGrows(g, tb, ta, -1),
    ];
    var total = 0.0, totalErr = 0.0;
    for (var k = 0; k + 1 < cuts.length; k++) {
      final (val, e) = _piece(g, cuts[k], cuts[k + 1], singularAt[k], singularAt[k + 1]);
      total += val;
      totalErr += e;
    }
    final numeric = (total, totalErr);
    // Exact attempt via antiderivative (finite bounds, continuous integrand).
    final sym = _toSym(body, v);
    if (sym != null && lo.isFinite && hi.isFinite && sing.isEmpty) {
      final anti = integrateSym(sym, v);
      if (anti != null && _continuousOn(fn, lo.toDouble(), hi.toDouble())) {
        try {
          final lv = lo.value!, hv = hi.value!;
          Num evalAnti(Num x) {
            if (x is Rat) {
              final s = substitute(anti, v, S.n(x));
              if (s is SNum) return s.v;
              return symEval(s, a);
            }
            return symEval(anti, a, {v: x});
          }

          final exactVal = a.sub(evalAnti(hv), evalAnti(lv));
          final ev = exactVal.toDouble();
          final nv = numeric.$1;
          if (ev.isFinite && (ev - nv).abs() <= 1e-7 * math.max(1.0, nv.abs()) + 10 * numeric.$2) {
            return IntegralResult(exactVal, exact: exactVal is Rat, antiderivative: anti);
          }
        } on MathError {
          // Fall through to the numeric result.
        }
      }
    }
    final (value, err) = numeric;
    if (!value.isFinite || err.isNaN) {
      throw const MathError(MathErrorCode.noConvergence,
          {'detail': 'the integral appears to diverge or the integrand is undefined on the interval'});
    }
    final rel = err / math.max(1e-300, value.abs());
    if (err > 1e-6 * math.max(1.0, value.abs()) && rel > 1e-4) {
      throw MathError(MathErrorCode.noConvergence,
          {'detail': 'the integral appears to diverge (estimated error ${err.toStringAsExponential(2)})'});
    }
    final digits = rel <= 0 ? 15 : math.max(3, math.min(15, (-math.log(rel) / math.ln10).floor()));
    return IntegralResult(Dec.fromDouble(value).withSig(digits), exact: false, errorEstimate: err);
  }

  bool _continuousOn(double Function(double) f, double lo, double hi) {
    const n = 400;
    for (var k = 0; k <= n; k++) {
      final x = lo + (hi - lo) * k / n;
      final y = f(x);
      if (!y.isFinite) return false;
    }
    return true;
  }

  static const _gkNodes = [
    0.991455371120812639206854697526329, 0.949107912342758524526189684047851,
    0.864864423359769072789712788640926, 0.741531185599394439863864773280788,
    0.586087235467691130294144845693013, 0.405845151377397166906606412076961,
    0.207784955007898467600689403773245, 0.000000000000000000000000000000000,
  ];
  static const _gkWeightsK = [
    0.022935322010529224963732008058970, 0.063092092629978553290700663189204,
    0.104790010322250183839876322541518, 0.140653259715525918745189590510238,
    0.169004726639267902826583426598550, 0.190350578064785409913256402421014,
    0.204432940075298892414161999234649, 0.209482141084727828012999174891714,
  ];
  static const _gkWeightsG = [
    0.129484966168869693270611432679082, 0.279705391489276667901467771423780,
    0.381830050505118944950369775488975, 0.417959183673469387755102040816327,
  ];

  /// Maps infinite ranges to finite ones: returns (g, a, b) with
  /// ∫ f over [lo, hi] = ∫ g over [a, b].
  (double Function(double), double, double) _transform(double Function(double) f, double lo, double hi) {
    double Function(double) g;
    double a0, b0;
    if (lo.isFinite && hi.isFinite) {
      g = f;
      a0 = lo;
      b0 = hi;
    } else if (lo.isFinite) {
      // x = lo + t/(1−t), t ∈ [0, 1)
      g = (t) {
        final d = 1 - t;
        return f(lo + t / d) / (d * d);
      };
      a0 = 0;
      b0 = 1;
    } else if (hi.isFinite) {
      g = (t) {
        final d = 1 - t;
        return f(hi - t / d) / (d * d);
      };
      a0 = 0;
      b0 = 1;
    } else {
      // x = t/(1 − t²), t ∈ (−1, 1)
      g = (t) {
        final d = 1 - t * t;
        return f(t / d) * (1 + t * t) / (d * d);
      };
      a0 = -1;
      b0 = 1;
    }
    return (g, a0, b0);
  }

  /// Integrates one piece; an (integrable) singular endpoint is removed by
  /// the substitution x = end ± (r − l)·u², which turns |x − end|^(−½)
  /// into a smooth integrand and tames logarithmic singularities.
  (double, double) _piece(double Function(double) g, double l, double r, bool singL, bool singR) {
    if (singL && singR) {
      final m = (l + r) / 2;
      final p = _piece(g, l, m, true, false), q = _piece(g, m, r, false, true);
      return (p.$1 + q.$1, p.$2 + q.$2);
    }
    final w = r - l;
    // The located singular point may be off by an ulp; if a node lands on
    // the true pole, re-evaluate a hair further inside.
    // Below minU the offset w·u² is lost to rounding next to `end`; the
    // transformed integrand is smooth there, so its value at minU is used.
    double sub(double end, double sign, double u) {
      final minU = math.sqrt(16 * math.max(end.abs(), 1e-300) * 2.220446049250313e-16 / w);
      final uu = u < minU ? minU : u;
      var y = g(end + sign * w * uu * uu) * 2 * w * uu;
      if (!y.isFinite) {
        final u2 = uu * 1.01;
        y = g(end + sign * w * u2 * u2) * 2 * w * u2;
      }
      return y;
    }

    if (singL) return _gaussKronrod((u) => sub(l, 1, u), 0, 1);
    if (singR) return _gaussKronrod((u) => sub(r, -1, u), 0, 1);
    return _gaussKronrod(g, l, r);
  }

  /// True when |g| grows noticeably towards [end] (from inside).
  bool _endpointGrows(double Function(double) g, double end, double other, int dir) {
    final w = (other - end).abs();
    final near = g(end + dir * w * 1e-10), far = g(end + dir * w * 1e-2);
    return near.isFinite && far.isFinite && near.abs() > 10 * math.max(far.abs(), 1e-300);
  }

  /// True when g blows up at [end] (approached from inside, direction
  /// [dir]) at least as fast as 1/distance — a non-integrable singularity.
  bool _endpointDivergent(double Function(double) g, double end, double other, int dir) {
    final w = (other - end).abs();
    final v = <double>[];
    for (var j = 2; j <= 12; j++) {
      final y = g(end + dir * w * math.pow(10, -j));
      if (!y.isFinite) return false; // undefined there: handled elsewhere
      v.add(y.abs());
    }
    if (!(v.last > 1e3 * math.max(v.first, 1e-300))) return false;
    // |g|·distance not shrinking ⇒ divergent (1/x, 1/x², …).
    final r2 = v.first * w * 1e-2, r12 = v.last * w * 1e-12;
    return r12 >= 0.05 * r2;
  }

  /// Finds interior points of [a, b] where g blows up. Returns
  /// (location, integrable) pairs, sorted.
  List<(double, bool)> _singularities(double Function(double) g, double a, double b) {
    const n = 1000;
    final w = b - a;
    final xs = List<double>.generate(n, (k) => a + w * (k + 0.5) / n);
    final ys = [for (final x in xs) g(x)];
    final finite = [for (final y in ys) if (y.isFinite) y.abs()]..sort();
    if (finite.isEmpty) return const [];
    final median = math.max(finite[finite.length ~/ 2], 1e-300);
    final candidates = <double>[];
    for (var k = 0; k < n && candidates.length < 20; k++) {
      final y = ys[k];
      final prevOk = k > 0 && ys[k - 1].isFinite, nextOk = k + 1 < n && ys[k + 1].isFinite;
      if (!y.isFinite) {
        // Isolated undefined point between defined neighbours.
        if (prevOk && nextOk) candidates.add(xs[k]);
        continue;
      }
      if (nextOk) {
        final y1 = ys[k + 1];
        if ((y < 0) != (y1 < 0) && math.min(y.abs(), y1.abs()) > 50 * median) {
          // Sign change through a pole: locate by bisection on the sign.
          var l = xs[k], r = xs[k + 1];
          final sl = y < 0;
          for (var it = 0; it < 80; it++) {
            final m = (l + r) / 2;
            final ym = g(m);
            if (!ym.isFinite) {
              l = m;
              r = m;
              break;
            }
            if ((ym < 0) == sl) {
              l = m;
            } else {
              r = m;
            }
          }
          candidates.add((l + r) / 2);
          continue;
        }
      }
      if (prevOk && nextOk && y.abs() > 5 * median && y.abs() >= ys[k - 1].abs() && y.abs() >= ys[k + 1].abs()) {
        // Local peak of |g|: find the maximum precisely.
        var l = xs[k - 1], r = xs[k + 1];
        const gr = 0.6180339887498949;
        for (var it = 0; it < 90; it++) {
          final c = r - gr * (r - l), d = l + gr * (r - l);
          final fc = g(c).abs(), fd = g(d).abs();
          final vc = fc.isFinite ? fc : double.infinity, vd = fd.isFinite ? fd : double.infinity;
          if (vc > vd) {
            r = d;
          } else {
            l = c;
          }
        }
        candidates.add((l + r) / 2);
      }
    }
    final out = <(double, bool)>[];
    for (final rough in candidates) {
      // Snap to the neighbouring double where |g| is largest (the exact
      // pole when it is representable) so pieces end exactly on it.
      var x0 = rough;
      var best = g(rough).abs();
      final ulp = math.max(rough.abs(), 1e-300) * 2.220446049250313e-16;
      for (var k = -4; k <= 4; k++) {
        final x = rough + k * ulp;
        final y = g(x);
        final m = y.isFinite ? y.abs() : double.infinity;
        if (m > best) {
          best = m;
          x0 = x;
        }
      }
      if (x0 <= a || x0 >= b) continue;
      if (out.any((s) => (s.$1 - x0).abs() <= 1e-9 * w)) continue;
      final v = <double>[];
      for (var j = 2; j <= 9; j++) {
        final h = w * math.pow(10, -j);
        var m = 0.0;
        for (final x in [x0 - h, x0 + h]) {
          final y = g(x);
          if (y.isFinite && y.abs() > m) m = y.abs();
          if (!y.isFinite) m = double.infinity;
        }
        v.add(m);
      }
      if (v.any((e) => e.isInfinite)) {
        out.add((x0, false));
        continue;
      }
      final growth = v.last / math.max(v.first, 1e-300);
      if (growth <= 3 || v.last < 5 * median) continue;
      // |g|·h shrinking means an integrable singularity (|x|^−½, ln|x|).
      final r2 = v.first * w * 1e-2, r9 = v.last * w * 1e-9;
      out.add((x0, r9 < 0.05 * r2));
    }
    out.sort((p, q) => p.$1.compareTo(q.$1));
    return out;
  }

  /// Adaptive Gauss–Kronrod (7/15) on a finite interval of the
  /// (transformed) integrand. Returns (value, absolute error estimate).
  (double, double) _gaussKronrod(double Function(double) g0, double a0, double b0) {
    // A node landing exactly on an integrable singularity is nudged
    // towards the middle of the interval instead of poisoning the sum.
    final mid = (a0 + b0) / 2, span = (b0 - a0).abs();
    double g(double x) {
      final y = g0(x);
      if (y.isFinite) return y;
      return g0(x + (mid - x).sign * span * 1e-13);
    }

    (double, double) segment(double l, double r) {
      final c = (l + r) / 2, h = (r - l) / 2;
      final fc = g(c);
      var k = fc * _gkWeightsK[7];
      var gs = fc * _gkWeightsG[3];
      for (var j = 0; j < 7; j++) {
        final dx = h * _gkNodes[j];
        final f1 = g(c - dx), f2 = g(c + dx);
        k += _gkWeightsK[j] * (f1 + f2);
        if (j.isOdd) gs += _gkWeightsG[j ~/ 2] * (f1 + f2);
      }
      return (k * h, ((k - gs) * h).abs());
    }

    final intervals = <(double, double, double, double)>[];
    final first = segment(a0, b0);
    intervals.add((a0, b0, first.$1, first.$2));
    var total = first.$1, err = first.$2;
    for (var it = 0; it < 2000; it++) {
      ctx.budget.tick(15);
      if (err <= math.max(1e-14 * total.abs(), 1e-300) || err.isNaN) break;
      // Split the interval with the largest error.
      var worst = 0;
      for (var k = 1; k < intervals.length; k++) {
        if (intervals[k].$4 > intervals[worst].$4) worst = k;
      }
      final (l, r, v, e) = intervals.removeAt(worst);
      final m = (l + r) / 2;
      if (m == l || m == r) {
        intervals.add((l, r, v, e));
        break;
      }
      final s1 = segment(l, m), s2 = segment(m, r);
      intervals.add((l, m, s1.$1, s1.$2));
      intervals.add((m, r, s2.$1, s2.$2));
      total += s1.$1 + s2.$1 - v;
      err += s1.$2 + s2.$2 - e;
    }
    // Recompute totals to avoid accumulated rounding.
    total = intervals.fold(0.0, (s, i) => s + i.$3);
    err = intervals.fold(0.0, (s, i) => s + i.$4);
    return (total, err);
  }

  // ------------------------------------------------------ sum / product

  static const maxSeriesTerms = 1000000;

  Num sumOrProduct(Node body, String v, Num lo, Num hi, {required bool product}) {
    final l = Arith.asBigInt(lo), h = Arith.asBigInt(hi);
    if (l == null || h == null) {
      throw MathError(MathErrorCode.nonIntegerArgument, {'function': product ? 'Π bounds' : 'Σ bounds'});
    }
    Num acc = product ? Rat.one : Rat.zero;
    if (h < l) return acc;
    if (h - l >= BigInt.from(maxSeriesTerms)) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'Σ/Π', 'limit': '$maxSeriesTerms terms'});
    }
    final vars = Map<String, Value>.of(ctx.variables);
    final e = Evaluator(ctx.copyWith(variables: vars));
    for (var k = l; k <= h; k += BigInt.one) {
      ctx.budget.tick(4);
      vars[v] = NumberValue(Rat(k));
      final t = e.evalNumber(body, product ? 'Π' : 'Σ');
      acc = product ? a.mul(acc, t) : a.add(acc, t);
      if (product && acc.isZero) break;
    }
    ev.preferDecimal |= e.preferDecimal;
    return acc;
  }

  // --------------------------------------------------------------- limits

  /// [pointNode], when given, lets irrational points (π/2) be recomputed
  /// with enough digits for the tiny offsets used numerically.
  Value limit(Node body, String v, ExtNum to, int side, {Node? pointNode}) {
    final sym = _toSym(body, v);
    if (sym != null) {
      final exact = _symbolicLimit(sym, v, to, side, 0);
      if (exact != null) return exact;
    }
    if (!to.isFinite) return _agree(_numericLimitInfinity(body, v, to.infinity, 1), _numericLimitInfinity(body, v, to.infinity, 2));
    var point = to.value!;
    if (point is! Rat && pointNode != null) {
      point = Evaluator(ctx.copyWith(arith: Arith(precision: a.precision + 160))).evalNumber(pointNode, 'The limit point');
    }
    Value oneSide(int s) => _agree(_numericLimitSide(body, v, point, s, 1), _numericLimitSide(body, v, point, s, 2));
    if (side != 0) return oneSide(side);
    final left = oneSide(-1);
    final right = oneSide(1);
    if (_sameLimit(left, right)) return right;
    throw MathError(MathErrorCode.undefinedResult, {
      'detail': 'the limit does not exist because the left limit (${_describe(left)}) '
          'differs from the right limit (${_describe(right)})'
    });
  }

  String _describe(Value v) => switch (v) {
        InfinityValue(:final sign) => sign > 0 ? '+∞' : '−∞',
        NumberValue(:final n) => n is Dec ? n.round(8).toString() : n.toString(),
        _ => '?',
      };

  bool _sameLimit(Value l, Value r) {
    if (l is InfinityValue && r is InfinityValue) return l.sign == r.sign;
    if (l is NumberValue && r is NumberValue) {
      final d = a.abs(a.sub(l.n, r.n)).toDouble();
      final m = math.max(1.0, a.abs(l.n).toDouble());
      return d <= 1e-9 * m;
    }
    return false;
  }

  Value? _symbolicLimit(Sym f, String v, ExtNum to, int side, int depth) {
    if (depth > 6) return null;
    if (!to.isFinite) return _rationalAtInfinity(f, v, to.infinity);
    final point = to.value!;
    if (point is! Rat) return null;
    try {
      final val = substitute(f, v, S.n(point));
      if (symVariables(val).isEmpty) {
        final n = symEval(val, a);
        if (n is Cpx) return null;
        // Guard against removable discontinuities / jumps (floor etc.):
        // the function must be close to the value on the approach side(s).
        final ok = _nearbyAgrees(f, v, point, n, side);
        if (ok) return NumberValue(val is SNum ? val.v : n);
        return null;
      }
      return null;
    } on MathError {
      // 0/0 or similar: try L'Hôpital on a quotient.
    }
    final (num, den) = numDen(f);
    if (den == S.one) return null;
    try {
      final n0 = symEval(substitute(num, v, S.n(point)), a);
      final d0 = symEval(substitute(den, v, S.n(point)), a);
      if (n0.isZero && d0.isZero) {
        final q = S.div(differentiate(num, v), differentiate(den, v));
        return _symbolicLimit(q, v, to, side, depth + 1);
      }
    } on MathError {
      return null;
    }
    return null;
  }

  bool _nearbyAgrees(Sym f, String v, Rat point, Num value, int side) {
    final hp = Arith(precision: 30);
    final target = value.toDouble();
    final sides = side == 0 ? [-1, 1] : [side];
    for (final s in sides) {
      try {
        final x = hp.add(point, Rat(BigInt.from(s), pow10(18)));
        final y = symEval(f, hp, {v: x}).toDouble();
        if (!((y - target).abs() <= 1e-9 * math.max(1.0, target.abs()))) return false;
      } on MathError {
        return false;
      }
    }
    return true;
  }

  Value? _rationalAtInfinity(Sym f, String v, int dir) {
    final (n, d) = numDen(f);
    final pn = polyCoefficients(n, v), pd = polyCoefficients(d, v);
    if (pn == null || pd == null) return null;
    final ln = pn.last.asRat, ld = pd.last.asRat;
    if (ln == null || ld == null) return null;
    if (symVariables(S.add(pn)).isNotEmpty || symVariables(S.add(pd)).isNotEmpty) return null;
    final dn = pn.length - 1, dd = pd.length - 1;
    if (dn < dd) return NumberValue(Rat.zero);
    if (dn == dd) return NumberValue(ln / ld);
    var sign = (ln / ld).sign;
    if (dir < 0 && (dn - dd).isOdd) sign = -sign;
    return InfinityValue(sign);
  }

  /// Two sample sequences (offsets h and 1.7h) must agree; this exposes
  /// oscillation such as x·sin(x) that one sequence could hide.
  Value _agree(Value p, Value q) {
    if (_sameLimit(p, q)) return p;
    throw const MathError(MathErrorCode.noConvergence,
        {'detail': 'the function oscillates, so the limit does not exist'});
  }

  /// Working precision for a sample at offset/size 10^±k: enough digits
  /// that cancellations like √(x²+1) − x at x = 10^k are resolved.
  Arith _limitArith(int k) => Arith(precision: a.precision + 20 + 3 * k);

  Value _numericLimitSide(Node body, String v, Num point, int side, int sequence) {
    final vals = <double>[];
    final exactVals = <Num>[];
    final factor = sequence == 1 ? Rat.one : Rat.frac(17, 10);
    for (var k = 4; k <= 36; k += 4) {
      final hp = _limitArith(k);
      final h = Rat(BigInt.from(side), pow10(k)) * factor;
      try {
        final y = evalAt(body, v, hp.add(point, h), arith: hp);
        if (y is Cpx) {
          throw const MathError(MathErrorCode.complexResult);
        }
        vals.add(y.toDouble());
        exactVals.add(y);
      } on MathError catch (e) {
        if (e.code == MathErrorCode.complexResult || e.code == MathErrorCode.domainError) {
          throw MathError(MathErrorCode.undefinedResult,
              {'detail': 'the function is not defined on the ${side < 0 ? 'left' : 'right'} of the point'});
        }
        rethrow;
      }
    }
    return _classify(vals, exactVals);
  }

  Value _numericLimitInfinity(Node body, String v, int dir, int sequence) {
    final vals = <double>[];
    final exactVals = <Num>[];
    final factor = sequence == 1 ? Rat.one : Rat.frac(17, 10);
    for (var k = 4; k <= 36; k += 4) {
      final hp = _limitArith(k);
      final x = Rat(pow10(k) * BigInt.from(dir)) * factor;
      final y = evalAt(body, v, x, arith: hp);
      if (y is Cpx) {
        throw const MathError(MathErrorCode.undefinedResult, {'detail': 'the function is not real there'});
      }
      vals.add(y.toDouble());
      exactVals.add(y);
    }
    return _classify(vals, exactVals);
  }

  Value _classify(List<double> vals, List<Num> exact) {
    final n = vals.length;
    final last = vals[n - 1], prev = vals[n - 2], prev2 = vals[n - 3];
    // Divergence to ±∞: magnitudes growing steadily with one sign over the
    // whole tail (a sign change means oscillation, e.g. x·sin x).
    final tail = vals.sublist(math.max(0, n - 6));
    final oneSign = tail.every((v) => v.sign == last.sign && v != 0);
    var growing = true;
    for (var k = 1; k < tail.length; k++) {
      if (!(tail[k].abs() > 2 * tail[k - 1].abs())) growing = false;
    }
    if (last.abs() > 1e8 && oneSign && growing) {
      return InfinityValue(last.sign.toInt());
    }
    if (last.abs() > 1e8 && prev.abs() > 1e6 && !oneSign) {
      throw const MathError(MathErrorCode.noConvergence,
          {'detail': 'the function oscillates with growing amplitude, so the limit does not exist'});
    }
    if (!last.isFinite) return InfinityValue(last.sign.toInt());
    final d1 = (last - prev).abs(), d2 = (prev - prev2).abs();
    final scale = math.max(1.0, last.abs());
    if (d1 <= 1e-10 * scale || (d1 <= d2 * 0.5 && d1 <= 1e-6 * scale)) {
      final best = exact.last;
      final res = a.normalize(best);
      // Snap to a simple rational when extremely close.
      if (res is Dec) {
        final r = _snapRational(res);
        if (r != null) return NumberValue(r);
        final digits = d1 == 0 ? a.precision : math.max(4, math.min(a.precision, (-math.log(d1 / scale) / math.ln10).floor() - 1));
        return NumberValue(res.round(a.wp).withSig(digits));
      }
      return NumberValue(res);
    }
    throw const MathError(MathErrorCode.noConvergence,
        {'detail': 'the function oscillates or converges too slowly to determine the limit'});
  }

  Rat? _snapRational(Dec x) {
    final exact = x.toRat();
    var h0 = BigInt.zero, h1 = BigInt.one, k0 = BigInt.one, k1 = BigInt.zero;
    var r = exact;
    for (var i = 0; i < 30; i++) {
      final ai = r.floor();
      final h2 = ai * h1 + h0, k2 = ai * k1 + k0;
      if (k2 > BigInt.from(10000)) return null;
      final cand = Rat(h2, k2);
      final diff = (cand - exact).abs();
      if (diff.toDouble() <= 1e-25 * math.max(1.0, exact.toDouble().abs())) return cand;
      h0 = h1;
      h1 = h2;
      k0 = k1;
      k1 = k2;
      final frac = r - Rat(ai);
      if (frac.isZero) return cand;
      r = frac.reciprocal();
    }
    return null;
  }

  // ---------------------------------------------------------- eigenvalues

  List<Num> eigenvalues(MatrixValue m) {
    final ops = MatrixOps(a, ctx.budget);
    final coeffs = ops.characteristicPolynomial(m);
    final solver = PolynomialSolver(a.withComplex(true), ctx.budget);
    final out = <Num>[];
    for (final r in solver.roots(coeffs)) {
      for (var k = 0; k < r.multiplicity; k++) {
        out.add(r.value);
      }
    }
    return out;
  }
}
