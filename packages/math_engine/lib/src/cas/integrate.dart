import 'dart:math' as math;

import '../algebra/polynomial.dart';
import '../core/errors.dart';
import '../numbers/num.dart';
import 'cas.dart';
import 'sym.dart';

/// Symbolic antiderivative of [f] with respect to [x], or null when no
/// closed form is found. Every candidate is verified by differentiating it
/// and comparing with [f] numerically, so a wrong antiderivative is never
/// returned.
Sym? integrateSym(Sym f, String x) {
  try {
    final r = _Integrator(x).integrate(f, 0);
    if (r == null) return null;
    return verifyAntiderivative(r, f, x) ? r : null;
  } on MathError {
    return null;
  }
}

/// Checks d/dx F == f at several sample points.
bool verifyAntiderivative(Sym antiderivative, Sym f, String x) {
  Sym dF;
  try {
    dF = differentiate(antiderivative, x);
  } on MathError {
    return false;
  }
  final a = Arith(precision: 20);
  const points = [0.371, 1.137, -0.713, 2.291, 0.05, -1.9, 3.7];
  var ok = 0;
  final others = symVariables(f)..remove(x);
  final otherVals = {for (final (k, v) in others.indexed) v: Dec.fromDouble(1.3 + 0.7 * k)};
  for (final p in points) {
    try {
      final vars = {...otherVals, x: Dec.fromDouble(p) as Num};
      final lhs = symEval(dF, a, vars);
      final rhs = symEval(f, a, vars);
      if (lhs is Cpx || rhs is Cpx) continue;
      final l = lhs.toDouble(), r = rhs.toDouble();
      if (!l.isFinite || !r.isFinite) continue;
      if ((l - r).abs() > 1e-9 * math.max(1.0, r.abs())) return false;
      ok++;
    } on MathError {
      continue;
    }
  }
  return ok >= 2;
}

class _Integrator {
  _Integrator(this.x);
  final String x;
  static const _maxDepth = 8;

  Sym get xs => S.v(x);
  bool _dep(Sym s) => dependsOn(s, x);

  /// (a, b) such that s = a·x + b with a ≠ 0 constant.
  (Sym, Sym)? _linear(Sym s) {
    final c = polyCoefficients(s, x, maxDegree: 1);
    if (c == null || c.length != 2) return null;
    if (_dep(c[1]) || _dep(c[0]) || c[1] == S.zero) return null;
    return (c[1], c[0]);
  }

  Sym? integrate(Sym f, int depth) {
    if (depth > _maxDepth) return null;
    if (!_dep(f)) return S.mul([f, xs]);
    switch (f) {
      case SVar():
        return S.div(S.pow(xs, S.two), S.two);
      case SAdd(:final terms):
        final parts = <Sym>[];
        for (final t in terms) {
          final r = integrate(t, depth + 1);
          if (r == null) return _rational(f) ?? _expandedRetry(f, depth);
          parts.add(r);
        }
        return S.add(parts);
      case SMul():
        return _product(f, depth);
      case SPow():
        return _power(f, depth);
      case SFn():
        return _function(f, depth);
      default:
        return null;
    }
  }

  Sym? _expandedRetry(Sym f, int depth) {
    final e = expand(f);
    if (e == f) return null;
    return integrate(e, depth + 1);
  }

  // ---------------------------------------------------------------- powers

  Sym? _power(SPow f, int depth) {
    final base = f.base, exp = f.exp;
    if (!_dep(exp)) {
      final lin = _linear(base);
      if (lin != null) {
        final (a, _) = lin;
        if (exp == S.minusOne) {
          return S.div(S.ln(S.fn('abs', [base])), a);
        }
        final e1 = S.add([exp, S.one]);
        return S.div(S.pow(base, e1), S.mul([e1, a]));
      }
      final er = exp.asRat;
      // Trig powers.
      if (base is SFn && er != null && er.isInteger) {
        final r = _trigPower(base, er.n.toInt(), depth);
        if (r != null) return r;
      }
      // Polynomial to a positive integer power: expand.
      if (er != null && er.isInteger && !er.isNegative) {
        return _expandedRetry(f, depth);
      }
      // (c − k·x²)^(−1/2) → asin, (x² + c)^(−1/2) → ln|x + √(x²+c)|
      if (er == Rat.frac(-1, 2)) {
        final c = polyCoefficients(base, x, maxDegree: 2);
        if (c != null && c.length == 3 && c[1] == S.zero) {
          final k = c[2].asRat, c0 = c[0].asRat;
          if (k != null && c0 != null) {
            if (k.isNegative && !c0.isNegative && !c0.isZero) {
              final sk = S.sqrt(S.n(-k)), sc = S.sqrt(S.n(c0));
              return S.div(S.fn('asin', [S.mul([sk, xs, S.pow(sc, S.minusOne)])]), sk);
            }
            if (!k.isNegative && !c0.isZero) {
              final sk = S.sqrt(S.n(k));
              return S.div(
                  S.ln(S.fn('abs', [S.add([S.mul([sk, xs]), S.sqrt(base)])])), sk);
            }
          }
        }
      }
      if (er != null && er.isInteger && er.isNegative) return _rational(f);
      return null;
    }
    if (!_dep(base)) {
      final lin = _linear(exp);
      if (lin != null) {
        final (a, _) = lin;
        if (base == S.e) return S.div(f, a);
        return S.div(f, S.mul([a, S.ln(base)]));
      }
      return _substitution(f, depth);
    }
    return null;
  }

  Sym? _trigPower(SFn g, int n, int depth) {
    final lin = _linear(g.args.first);
    if (lin == null) return null;
    final u = g.args.first;
    final (a, _) = lin;
    switch (g.name) {
      case 'sin' when n >= 2:
        // ∫sinⁿu = −sinⁿ⁻¹u·cos u/(n a) + (n−1)/n ∫sinⁿ⁻²u
        final rest = n == 2 ? S.div(xs, S.one) : integrate(S.pow(g, S.integer(n - 2)), depth + 1);
        if (rest == null) return null;
        return S.add([
          S.neg(S.div(S.mul([S.pow(g, S.integer(n - 1)), S.fn('cos', [u])]), S.mul([S.integer(n), a]))),
          S.mul([S.n(Rat.frac(n - 1, n)), rest]),
        ]);
      case 'cos' when n >= 2:
        final rest = n == 2 ? xs : integrate(S.pow(g, S.integer(n - 2)), depth + 1);
        if (rest == null) return null;
        return S.add([
          S.div(S.mul([S.pow(g, S.integer(n - 1)), S.fn('sin', [u])]), S.mul([S.integer(n), a])),
          S.mul([S.n(Rat.frac(n - 1, n)), rest]),
        ]);
      case 'cos' when n == -2:
        return S.div(S.fn('tan', [u]), a);
      case 'sin' when n == -2:
        return S.neg(S.div(S.div(S.fn('cos', [u]), S.fn('sin', [u])), a));
      case 'cos' when n == -1:
        return S.div(
            S.ln(S.fn('abs', [S.div(S.add([S.one, S.fn('sin', [u])]), S.fn('cos', [u]))])), a);
      case 'sin' when n == -1:
        return S.div(
            S.ln(S.fn('abs', [S.div(S.sub(S.one, S.fn('cos', [u])), S.fn('sin', [u]))])), a);
      case 'tan' when n == 2:
        return S.sub(S.div(S.fn('tan', [u]), a), xs);
      case 'cosh' when n == -2:
        return S.div(S.fn('tanh', [u]), a);
    }
    return null;
  }

  // ------------------------------------------------------------- functions

  Sym? _function(SFn f, int depth) {
    final u = f.args.first;
    final lin = _linear(u);
    if (lin == null) return _substitution(f, depth);
    final (a, _) = lin;
    Sym? g;
    switch (f.name) {
      case 'sin':
        g = S.neg(S.fn('cos', [u]));
      case 'cos':
        g = S.fn('sin', [u]);
      case 'tan':
        g = S.neg(S.ln(S.fn('abs', [S.fn('cos', [u])])));
      case 'sinh':
        g = S.fn('cosh', [u]);
      case 'cosh':
        g = S.fn('sinh', [u]);
      case 'tanh':
        g = S.ln(S.fn('cosh', [u]));
      case 'ln':
        g = S.sub(S.mul([u, S.ln(u)]), u);
      case 'asin':
        g = S.add([S.mul([u, S.fn('asin', [u])]), S.sqrt(S.sub(S.one, S.pow(u, S.two)))]);
      case 'acos':
        g = S.sub(S.mul([u, S.fn('acos', [u])]), S.sqrt(S.sub(S.one, S.pow(u, S.two))));
      case 'atan':
        g = S.sub(S.mul([u, S.fn('atan', [u])]),
            S.div(S.ln(S.add([S.one, S.pow(u, S.two)])), S.two));
      case 'asinh':
        g = S.sub(S.mul([u, S.fn('asinh', [u])]), S.sqrt(S.add([S.pow(u, S.two), S.one])));
      case 'atanh':
        g = S.add([S.mul([u, S.fn('atanh', [u])]),
          S.div(S.ln(S.sub(S.one, S.pow(u, S.two))), S.two)]);
      case 'abs':
        g = S.div(S.mul([u, S.fn('abs', [u])]), S.two);
    }
    if (g == null) return null;
    return S.div(g, a);
  }

  // -------------------------------------------------------------- products

  Sym? _product(SMul f, int depth) {
    final consts = <Sym>[], vars = <Sym>[];
    for (final fac in f.factors) {
      (_dep(fac) ? vars : consts).add(fac);
    }
    if (consts.isNotEmpty) {
      final inner = integrate(S.mul(vars), depth + 1);
      return inner == null ? null : S.mul([...consts, inner]);
    }
    // Polynomial products: expand.
    final poly = polyCoefficients(f, x);
    if (poly != null) return integrate(polyFromCoefficients(poly, x), depth + 1);
    return _expSinCos(vars) ??
        _substitution(f, depth) ??
        _byParts(vars, depth) ??
        _rational(f) ??
        _trigProduct(vars, depth) ??
        _expandedRetry(f, depth);
  }

  /// e^(ax+b)·sin(cx+d) and e^(ax+b)·cos(cx+d).
  Sym? _expSinCos(List<Sym> vars) {
    if (vars.length != 2) return null;
    SPow? ex;
    SFn? tr;
    for (final v in vars) {
      if (v is SPow && v.base == S.e) ex = v;
      if (v is SFn && (v.name == 'sin' || v.name == 'cos')) tr = v;
    }
    if (ex == null || tr == null) return null;
    final le = _linear(ex.exp), lt = _linear(tr.args.first);
    if (le == null || lt == null) return null;
    final a = le.$1, b = lt.$1;
    final u = tr.args.first;
    final den = S.add([S.pow(a, S.two), S.pow(b, S.two)]);
    final s = S.fn('sin', [u]), c = S.fn('cos', [u]);
    final inner = tr.name == 'sin'
        ? S.sub(S.mul([a, s]), S.mul([b, c]))
        : S.add([S.mul([a, c]), S.mul([b, s])]);
    return S.div(S.mul([ex, inner]), den);
  }

  /// sin·cos products via product-to-sum identities.
  Sym? _trigProduct(List<Sym> vars, int depth) {
    if (vars.length != 2) return null;
    final p = vars[0], q = vars[1];
    if (p is! SFn || q is! SFn) return null;
    final u = p.args.first, v = q.args.first;
    if (_linear(u) == null || _linear(v) == null) return null;
    Sym? sum;
    final plus = S.add([u, v]), minus = S.sub(u, v);
    if (p.name == 'sin' && q.name == 'cos') {
      sum = S.div(S.add([S.fn('sin', [plus]), S.fn('sin', [minus])]), S.two);
    } else if (p.name == 'cos' && q.name == 'sin') {
      sum = S.div(S.sub(S.fn('sin', [plus]), S.fn('sin', [minus])), S.two);
    } else if (p.name == 'sin' && q.name == 'sin') {
      sum = S.div(S.sub(S.fn('cos', [minus]), S.fn('cos', [plus])), S.two);
    } else if (p.name == 'cos' && q.name == 'cos') {
      sum = S.div(S.add([S.fn('cos', [minus]), S.fn('cos', [plus])]), S.two);
    }
    return sum == null ? null : integrate(expand(sum), depth + 1);
  }

  bool _isPolynomial(Sym s) => polyCoefficients(s, x) != null;

  /// Integration by parts for polynomial × transcendental.
  Sym? _byParts(List<Sym> vars, int depth) {
    final polyPart = <Sym>[], other = <Sym>[];
    for (final v in vars) {
      (_isPolynomial(v) ? polyPart : other).add(v);
    }
    if (polyPart.isEmpty || other.length != 1) return null;
    final p = S.mul(polyPart);
    final t = other.first;
    final isLogLike = t is SFn && const {'ln', 'atan', 'asin', 'acos', 'asinh', 'atanh'}.contains(t.name);
    if (isLogLike) {
      // u = t, dv = p
      final pInt = integrate(p, depth + 1);
      if (pInt == null) return null;
      final rest = integrate(S.mul([pInt, differentiate(t, x)]), depth + 1);
      if (rest == null) return null;
      return S.sub(S.mul([t, pInt]), rest);
    }
    // u = p, dv = t
    final tInt = integrate(t, depth + 1);
    if (tInt == null) return null;
    final dp = differentiate(p, x);
    final rest = dp == S.zero ? S.zero : integrate(S.mul([dp, tInt]), depth + 1);
    if (rest == null) return null;
    return S.sub(S.mul([p, tInt]), rest);
  }

  // ---------------------------------------------------------- substitution

  /// ∫ g(u(x))·u'(x) dx = G(u(x)).
  Sym? _substitution(Sym f, int depth) {
    final factors = f is SMul ? f.factors : [f];
    final candidates = <Sym>{};
    void addCandidate(Sym s) {
      if (_dep(s) && _linear(s) == null && s is! SVar) candidates.add(s);
    }

    for (final g in factors) {
      if (g is SFn) addCandidate(g.args.first);
      if (g is SPow) {
        addCandidate(g.base);
        if (_dep(g.exp)) addCandidate(g.exp);
        if (g.base is SFn) addCandidate((g.base as SFn).args.first);
      }
      addCandidate(g);
    }
    const t = 'τ_sub';
    for (final u in candidates) {
      final du = differentiate(u, x);
      if (du == S.zero) continue;
      final replaced = _replace(f, u, S.v(t));
      if (replaced == f) continue;
      final ratio = simplify(S.div(replaced, du));
      if (_dep(ratio)) continue;
      final inner = _Integrator(t).integrate(ratio, depth + 1);
      if (inner == null) continue;
      return substitute(inner, t, u);
    }
    return null;
  }

  Sym _replace(Sym s, Sym target, Sym by) {
    if (s == target) return by;
    switch (s) {
      case SAdd(:final terms):
        return S.add([for (final q in terms) _replace(q, target, by)]);
      case SMul(:final factors):
        return S.mul([for (final q in factors) _replace(q, target, by)]);
      case SPow(:final base, :final exp):
        // x^4 with target x² → t²
        if (target is SPow && base == target.base && exp.asRat != null && target.exp.asRat != null) {
          final k = exp.asRat! / target.exp.asRat!;
          if (k.isInteger && !k.isZero) return S.pow(by, S.n(k));
        }
        return S.pow(_replace(base, target, by), _replace(exp, target, by));
      case SFn(:final name, :final args):
        return S.fn(name, [for (final q in args) _replace(q, target, by)]);
      default:
        return s;
    }
  }

  // ------------------------------------------------------ rational functions

  Sym? _rational(Sym f) {
    final (n, d) = numDen(f);
    if (d == S.one) return null;
    final pn = _ratPolyOf(n), pd = _ratPolyOf(d);
    if (pn == null || pd == null || pd.length < 2) return null;
    // Make the denominator monic.
    final lead = pd.last;
    var num = [for (final c in pn) c / lead];
    final den = [for (final c in pd) c / lead];
    final (q, r) = RatPoly.divmod(num, den);
    final parts = <Sym>[];
    if (q.isNotEmpty) {
      final qi = integrate(_polySym(q), 0);
      if (qi == null) return null;
      parts.add(qi);
    }
    num = r;
    if (num.isEmpty) return S.add(parts);
    final pf = _partialFractions(num, den);
    if (pf == null) return null;
    parts.add(pf);
    return S.add(parts);
  }

  List<Rat>? _ratPolyOf(Sym s) {
    final c = polyCoefficients(s, x);
    if (c == null) return null;
    final out = <Rat>[];
    for (final k in c) {
      final r = k.asRat;
      if (r == null) return null;
      out.add(r);
    }
    return RatPoly.trim(out);
  }

  Sym _polySym(List<Rat> p) =>
      S.add([for (var k = 0; k < p.length; k++) S.mul([S.n(p[k]), S.pow(xs, S.integer(k))])]);

  Sym? _partialFractions(List<Rat> num, List<Rat> den) {
    // Factor den (monic) into (x − r)^m and irreducible quadratics.
    final linear = <(Rat, int)>[];
    final quads = <List<Rat>>[];
    for (final (sf, mult) in RatPoly.squareFree(den)) {
      var f = sf;
      if (f.length > 2) {
        for (final root in PolynomialSolver(Arith(precision: 30)).roots(f)) {
          final v = root.value;
          if (v is Rat && RatPoly.eval(f, v).isZero) {
            linear.add((v, mult));
            f = RatPoly.divmod(f, [-v, Rat.one]).$1;
            if (f.length <= 1) break;
          }
        }
      }
      final deg = f.length - 1;
      if (deg == 1) {
        linear.add((-f[0] / f[1], mult));
      } else if (deg == 2) {
        if (mult != 1) return null;
        quads.add(RatPoly.monic(f));
      } else if (deg > 2) {
        return null;
      }
    }
    // Basis polynomials: den / (x − r)^j and x·den/q, den/q.
    final basis = <List<Rat>>[];
    final labels = <(String, Object, int)>[];
    for (final (r, m) in linear) {
      for (var j = 1; j <= m; j++) {
        var divisor = <Rat>[Rat.one];
        for (var k = 0; k < j; k++) {
          divisor = RatPoly.mul(divisor, [-r, Rat.one]);
        }
        basis.add(RatPoly.divmod(den, divisor).$1);
        labels.add(('lin', r, j));
      }
    }
    for (final q in quads) {
      final base = RatPoly.divmod(den, q).$1;
      basis.add(RatPoly.mul(base, [Rat.zero, Rat.one]));
      labels.add(('quadB', q, 1));
      basis.add(base);
      labels.add(('quadC', q, 1));
    }
    final n = den.length - 1;
    if (basis.length != n) return null;
    // Solve Σ c_k·basis_k = num (coefficient matching).
    final m = List.generate(n, (row) => [
          for (var k = 0; k < n; k++) row < basis[k].length ? basis[k][row] : Rat.zero,
          row < num.length ? num[row] : Rat.zero,
        ]);
    for (var c = 0; c < n; c++) {
      var p = c;
      while (p < n && m[p][c].isZero) {
        p++;
      }
      if (p == n) return null;
      final tmp = m[p];
      m[p] = m[c];
      m[c] = tmp;
      for (var r = 0; r < n; r++) {
        if (r == c || m[r][c].isZero) continue;
        final fct = m[r][c] / m[c][c];
        for (var k = c; k <= n; k++) {
          m[r][k] = m[r][k] - fct * m[c][k];
        }
      }
    }
    final coef = [for (var r = 0; r < n; r++) m[r][n] / m[r][r]];
    final parts = <Sym>[];
    final quadB = <List<Rat>, Rat>{};
    for (var k = 0; k < n; k++) {
      final (kind, data, j) = labels[k];
      final c = coef[k];
      if (kind == 'lin') {
        if (c.isZero) continue;
        final xr = S.sub(xs, S.n(data as Rat));
        if (j == 1) {
          parts.add(S.mul([S.n(c), S.ln(S.fn('abs', [xr]))]));
        } else {
          parts.add(S.mul([S.n(-c / Rat.int(j - 1)), S.pow(xr, S.integer(1 - j))]));
        }
      } else if (kind == 'quadB') {
        quadB[data as List<Rat>] = c;
      } else {
        final q = data as List<Rat>;
        final bb = quadB[q] ?? Rat.zero;
        final cc = c;
        // (B x + C)/(x² + p x + s)
        final p = q[1], s = q[0];
        final qs = _polySym(q);
        if (!bb.isZero) parts.add(S.mul([S.n(bb / Rat.two), S.ln(qs)]));
        final rem = cc - bb * p / Rat.two;
        if (!rem.isZero) {
          final disc = Rat.int(4) * s - p * p; // > 0 for irreducible
          final root = S.sqrt(S.n(disc));
          parts.add(S.mul([
            S.n(rem * Rat.two),
            S.pow(root, S.minusOne),
            S.fn('atan', [S.mul([S.add([S.mul([S.two, xs]), S.n(p)]), S.pow(root, S.minusOne)])]),
          ]));
        }
      }
    }
    return S.add(parts);
  }
}
