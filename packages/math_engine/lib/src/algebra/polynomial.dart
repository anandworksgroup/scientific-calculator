import 'dart:math' as math;

import '../core/budget.dart';
import '../core/errors.dart';
import '../numbers/num.dart';

/// Maximum polynomial degree accepted by the root finder.
const int maxPolynomialDegree = 40;

/// Exact quadratic-surd form `p + q·√d` (d square-free, d ≠ 1). When d < 0
/// the value is complex: `p + q·i·√|d|`.
class SurdForm {
  const SurdForm(this.p, this.q, this.d);
  final Rat p;
  final Rat q;
  final BigInt d;
}

class PolyRoot {
  const PolyRoot(this.value, this.multiplicity, {this.exact = false, this.surd});

  /// Root value: [Rat] when exactly rational, otherwise [Dec] or [Cpx].
  final Num value;
  final int multiplicity;

  /// True when [value] is exact (rational) or [surd] gives the exact form.
  final bool exact;
  final SurdForm? surd;

  bool get isReal => value is! Cpx;
}

/// Dense polynomial operations over exact rationals (ascending coefficients).
abstract final class RatPoly {
  static List<Rat> trim(List<Rat> p) {
    var n = p.length;
    while (n > 0 && p[n - 1].isZero) {
      n--;
    }
    return p.sublist(0, n);
  }

  static int degree(List<Rat> p) => trim(p).length - 1;

  static Rat eval(List<Rat> p, Rat x) {
    var r = Rat.zero;
    for (var k = p.length - 1; k >= 0; k--) {
      r = r * x + p[k];
    }
    return r;
  }

  static List<Rat> derivative(List<Rat> p) =>
      [for (var k = 1; k < p.length; k++) p[k] * Rat.int(k)];

  static List<Rat> mul(List<Rat> x, List<Rat> y) {
    if (x.isEmpty || y.isEmpty) return [];
    final out = List<Rat>.filled(x.length + y.length - 1, Rat.zero);
    for (var i = 0; i < x.length; i++) {
      for (var j = 0; j < y.length; j++) {
        out[i + j] = out[i + j] + x[i] * y[j];
      }
    }
    return trim(out);
  }

  /// Polynomial long division: returns (quotient, remainder).
  static (List<Rat>, List<Rat>) divmod(List<Rat> n, List<Rat> d) {
    d = trim(d);
    if (d.isEmpty) throw const MathError(MathErrorCode.divisionByZero);
    var r = List<Rat>.of(trim(n));
    final dd = d.length - 1;
    if (r.length - 1 < dd) return ([], r);
    final q = List<Rat>.filled(r.length - dd, Rat.zero);
    final lead = d.last;
    for (var k = r.length - 1; k >= dd; k--) {
      final c = r[k] / lead;
      q[k - dd] = c;
      if (c.isZero) continue;
      for (var j = 0; j <= dd; j++) {
        r[k - dd + j] = r[k - dd + j] - c * d[j];
      }
    }
    r = trim(r.sublist(0, dd));
    return (trim(q), r);
  }

  static List<Rat> monic(List<Rat> p) {
    p = trim(p);
    if (p.isEmpty) return p;
    final l = p.last;
    return [for (final c in p) c / l];
  }

  static List<Rat> gcd(List<Rat> a, List<Rat> b) {
    a = trim(a);
    b = trim(b);
    while (b.isNotEmpty) {
      final (_, r) = divmod(a, b);
      a = b;
      b = monic(r);
    }
    return monic(a);
  }

  /// Scales to a primitive integer polynomial with positive leading term.
  static List<BigInt> primitive(List<Rat> p) {
    p = trim(p);
    var lcm = BigInt.one;
    for (final c in p) {
      lcm = lcm ~/ lcm.gcd(c.d) * c.d;
    }
    final ints = [for (final c in p) (c * Rat(lcm)).n];
    var g = BigInt.zero;
    for (final c in ints) {
      g = g.gcd(c);
    }
    if (g == BigInt.zero) return ints;
    var out = [for (final c in ints) c ~/ g];
    if (out.last.isNegative) out = [for (final c in out) -c];
    return out;
  }

  /// Square-free factorization (Yun): list of (factor, multiplicity).
  static List<(List<Rat>, int)> squareFree(List<Rat> f) {
    f = monic(f);
    final out = <(List<Rat>, int)>[];
    if (f.length <= 2) return [(f, 1)];
    var c = gcd(f, derivative(f));
    var w = divmod(f, c).$1;
    var i = 1;
    while (c.length > 1) {
      final y = gcd(w, c);
      final z = divmod(w, y).$1;
      if (z.length > 1) out.add((monic(z), i));
      i++;
      w = y;
      c = divmod(c, y).$1;
    }
    if (w.length > 1) out.add((monic(w), i));
    return out;
  }
}

/// Polynomial root finding.
class PolynomialSolver {
  PolynomialSolver(this.a, [Budget? budget]) : budget = budget ?? Budget.unlimited();
  final Arith a;
  final Budget budget;

  /// All roots of Σ coeffs[k]·x^k (ascending order).
  List<PolyRoot> roots(List<Num> coeffs) {
    final c = List<Num>.of(coeffs);
    while (c.isNotEmpty && c.last.isZero) {
      c.removeLast();
    }
    if (c.isEmpty) throw const MathError(MathErrorCode.infiniteSolutions);
    final deg = c.length - 1;
    if (deg == 0) throw const MathError(MathErrorCode.noSolution);
    if (deg > maxPolynomialDegree) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'polynomial solving', 'limit': 'degree $maxPolynomialDegree'});
    }
    final out = <PolyRoot>[];
    // Zero roots.
    var zeros = 0;
    while (c.first.isZero) {
      c.removeAt(0);
      zeros++;
    }
    if (zeros > 0) out.add(PolyRoot(Rat.zero, zeros, exact: true));
    if (c.length > 1) {
      if (c.every((v) => v is Rat)) {
        out.addAll(_exactRoots(c.cast<Rat>()));
      } else {
        for (final r in _numericRoots(c)) {
          out.add(PolyRoot(r, 1));
        }
      }
    }
    _sort(out);
    return out;
  }

  void _sort(List<PolyRoot> roots) {
    int cmp(PolyRoot x, PolyRoot y) {
      if (x.isReal != y.isReal) return x.isReal ? -1 : 1;
      final rx = Arith.reOf(x.value).toDouble(), ry = Arith.reOf(y.value).toDouble();
      if (rx != ry) return rx.compareTo(ry);
      return Arith.imOf(x.value).toDouble().compareTo(Arith.imOf(y.value).toDouble());
    }

    roots.sort(cmp);
  }

  List<PolyRoot> _exactRoots(List<Rat> p) {
    final out = <PolyRoot>[];
    for (final (factor, mult) in RatPoly.squareFree(p)) {
      budget.check();
      var f = factor;
      // Rational roots by numeric search + exact verification.
      if (f.length > 2) {
        final prim = RatPoly.primitive(f);
        final lead = prim.last.abs();
        final approx = _numericRoots(f);
        for (final r in approx) {
          if (r is Cpx) continue;
          final cand = _rationalNear(a.toDec(r), lead);
          if (cand == null) continue;
          if (RatPoly.eval(f, cand).isZero) {
            out.add(PolyRoot(cand, mult, exact: true));
            f = RatPoly.divmod(f, [-cand, Rat.one]).$1;
            if (f.length <= 1) break;
          }
        }
      }
      final deg = f.length - 1;
      if (deg == 1) {
        out.add(PolyRoot(-f[0] / f[1], mult, exact: true));
      } else if (deg == 2) {
        out.addAll(_quadratic(f[2], f[1], f[0], mult));
      } else if (deg > 2) {
        for (final r in _numericRoots(f)) {
          out.add(PolyRoot(r, mult));
        }
      }
    }
    return out;
  }

  /// Exact roots of ax² + bx + c with rational coefficients.
  List<PolyRoot> _quadratic(Rat qa, Rat qb, Rat qc, int mult) {
    final disc = qb * qb - Rat.int(4) * qa * qc;
    final p = -qb / (Rat.two * qa);
    if (disc.isZero) return [PolyRoot(p, mult * 2, exact: true)];
    // √disc = s·√d with d square-free integer.
    final (s, d) = _surd(disc);
    final q = s / (Rat.two * qa).abs();
    if (d == BigInt.one) {
      return [
        PolyRoot(p - q, mult, exact: true),
        PolyRoot(p + q, mult, exact: true),
      ];
    }
    final root = a.sqrt(Rat(d.abs()));
    final qv = a.mul(q, root);
    if (d.isNegative) {
      final c = a.withComplex(true);
      return [
        PolyRoot(Cpx.of(p, c.neg(qv)), mult, exact: true, surd: SurdForm(p, -q, d)),
        PolyRoot(Cpx.of(p, qv), mult, exact: true, surd: SurdForm(p, q, d)),
      ];
    }
    return [
      PolyRoot(a.sub(p, qv), mult, exact: true, surd: SurdForm(p, -q, d)),
      PolyRoot(a.add(p, qv), mult, exact: true, surd: SurdForm(p, q, d)),
    ];
  }

  /// Writes √r = s·√d with s rational and d a square-free integer
  /// (negative when r < 0).
  static (Rat, BigInt) _surd(Rat r) {
    final sign = r.isNegative ? -1 : 1;
    final v = r.abs();
    // √(n/m) = √(n·m)/m
    final nm = v.n * v.d;
    final (outside, inside) = extractSquare(nm);
    return (Rat(outside, v.d), inside * BigInt.from(sign));
  }

  /// n = outside² · inside with inside square-free (trial division up to
  /// 10^5; larger cofactors are kept inside).
  static (BigInt, BigInt) extractSquare(BigInt n) {
    var outside = BigInt.one;
    var inside = BigInt.one;
    var m = n;
    for (var p = 2; p < 100000; p++) {
      final bp = BigInt.from(p);
      if (bp * bp > m) break;
      var e = 0;
      while (m % bp == BigInt.zero) {
        m = m ~/ bp;
        e++;
      }
      if (e > 0) {
        outside *= bp.pow(e ~/ 2);
        if (e.isOdd) inside *= bp;
      }
    }
    // Remaining m: check if it is a perfect square.
    final r = _isqrt(m);
    if (r * r == m) {
      outside *= r;
    } else {
      inside *= m;
    }
    return (outside, inside);
  }

  static BigInt _isqrt(BigInt n) {
    if (n < BigInt.two) return n;
    var x = BigInt.one << ((n.bitLength + 1) >> 1);
    while (true) {
      final y = (x + n ~/ x) >> 1;
      if (y >= x) return x;
      x = y;
    }
  }

  /// Best rational approximation with denominator ≤ maxDen (continued
  /// fractions), or null if none is close.
  static Rat? _rationalNear(Dec x, BigInt maxDen) {
    final exact = x.toRat();
    var h0 = BigInt.zero, h1 = BigInt.one;
    var k0 = BigInt.one, k1 = BigInt.zero;
    var r = exact;
    Rat? best;
    for (var i = 0; i < 64; i++) {
      final ai = r.floor();
      final h2 = ai * h1 + h0;
      final k2 = ai * k1 + k0;
      if (k2 > maxDen) break;
      best = Rat(h2, k2);
      h0 = h1;
      h1 = h2;
      k0 = k1;
      k1 = k2;
      final frac = r - Rat(ai);
      if (frac.isZero) break;
      r = frac.reciprocal();
    }
    return best;
  }

  // ------------------------------------------------------ numeric (Aberth)

  List<Num> _numericRoots(List<Num> coeffs) {
    final n = coeffs.length - 1;
    // Complex double coefficients.
    final cr = <double>[], ci = <double>[];
    for (final c in coeffs) {
      cr.add(Arith.reOf(c).toDouble());
      ci.add(Arith.imOf(c).toDouble());
    }
    // Normalize by the leading coefficient.
    final lr = cr[n], li = ci[n];
    final ld = lr * lr + li * li;
    for (var k = 0; k <= n; k++) {
      final r = (cr[k] * lr + ci[k] * li) / ld;
      final i = (ci[k] * lr - cr[k] * li) / ld;
      cr[k] = r;
      ci[k] = i;
    }
    // Cauchy bound for the initial circle.
    var bound = 0.0;
    for (var k = 0; k < n; k++) {
      bound = math.max(bound, math.sqrt(cr[k] * cr[k] + ci[k] * ci[k]));
    }
    final radius = 1 + bound;
    final zr = List<double>.generate(n, (k) => radius * 0.5 * math.cos(2 * math.pi * k / n + 0.4));
    final zi = List<double>.generate(n, (k) => radius * 0.5 * math.sin(2 * math.pi * k / n + 0.4));
    for (var iter = 0; iter < 500; iter++) {
      budget.tick(n);
      var maxStep = 0.0;
      for (var k = 0; k < n; k++) {
        // p(z) and p'(z) by Horner.
        var pr = cr[n], pi = ci[n], dr = 0.0, di = 0.0;
        for (var j = n - 1; j >= 0; j--) {
          final ndr = dr * zr[k] - di * zi[k] + pr;
          final ndi = dr * zi[k] + di * zr[k] + pi;
          dr = ndr;
          di = ndi;
          final npr = pr * zr[k] - pi * zi[k] + cr[j];
          final npi = pr * zi[k] + pi * zr[k] + ci[j];
          pr = npr;
          pi = npi;
        }
        // ratio = p/p'
        final dd = dr * dr + di * di;
        if (dd == 0) continue;
        final rr = (pr * dr + pi * di) / dd;
        final ri = (pi * dr - pr * di) / dd;
        // sum 1/(z_k − z_j)
        var sr = 0.0, si = 0.0;
        for (var j = 0; j < n; j++) {
          if (j == k) continue;
          final xr = zr[k] - zr[j], xi = zi[k] - zi[j];
          final xd = xr * xr + xi * xi;
          if (xd == 0) continue;
          sr += xr / xd;
          si += -xi / xd;
        }
        // w = ratio / (1 − ratio·sum)
        final denr = 1 - (rr * sr - ri * si);
        final deni = -(rr * si + ri * sr);
        final den = denr * denr + deni * deni;
        if (den == 0) continue;
        final wr = (rr * denr + ri * deni) / den;
        final wi = (ri * denr - rr * deni) / den;
        zr[k] -= wr;
        zi[k] -= wi;
        final step = math.sqrt(wr * wr + wi * wi) / (1 + math.sqrt(zr[k] * zr[k] + zi[k] * zi[k]));
        if (step > maxStep) maxStep = step;
      }
      if (maxStep < 1e-15) break;
    }
    // Polish in high precision with Newton's method.
    final c = a.withComplex(true);
    final realCoeffs = coeffs.every((v) => v is! Cpx);
    final out = <Num>[];
    for (var k = 0; k < n; k++) {
      Num z = zi[k].abs() < 1e-300
          ? Dec.fromDouble(zr[k])
          : Cpx.of(Dec.fromDouble(zr[k]), Dec.fromDouble(zi[k]));
      z = _polish(c, coeffs, z);
      if (realCoeffs && z is Cpx) {
        final im = z.im.toDouble().abs();
        final mag = c.abs(z).toDouble().abs();
        if (im <= 1e-12 * (1 + mag)) {
          // Nearly real: re-polish as a real root.
          z = _polish(c, coeffs, z.re);
          if (z is Cpx) z = z.re;
        }
      }
      out.add(_clean(z));
    }
    return out;
  }

  Num _clean(Num z) {
    if (z is Dec) return z.withSig(math.min(z.sig, a.wp));
    return z;
  }

  Num _polish(Arith c, List<Num> coeffs, Num z) {
    for (var it = 0; it < 60; it++) {
      Num p = coeffs.last, d = Rat.zero;
      for (var j = coeffs.length - 2; j >= 0; j--) {
        d = c.add(c.mul(d, z), p);
        p = c.add(c.mul(p, z), coeffs[j]);
      }
      if (d.isZero) break;
      final step = c.div(p, d);
      z = c.sub(z, step);
      if (step.isZero) break;
      final s = c.abs(step).toDouble().abs();
      final m = c.abs(z).toDouble().abs();
      if (s <= (m == 0 ? 1 : m) * math.pow(10, -(a.wp + 2))) break;
    }
    return z;
  }
}
