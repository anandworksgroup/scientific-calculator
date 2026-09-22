import 'dart:math' as math;

import '../core/errors.dart';
import '../number_theory/number_theory.dart';
import '../numbers/num.dart';

/// Probability distributions. The binomial distribution is computed
/// exactly (rational arithmetic) for moderate n; normal and Poisson use
/// double precision special functions accurate to ~15 digits.
class Probability {
  Probability(this.a);
  final Arith a;

  // ---------------------------------------------------------------- normal

  static double erf(double x) => x < 0 ? -_erfPos(-x) : _erfPos(x);

  /// erfc(x) accurate to ~1e-15 relative (Chebyshev fit by W. J. Cody).
  static double erfc(double x) {
    if (x < 0) return 2 - erfc(-x);
    if (x < 0.5) return 1 - _erfPos(x);
    return _erfcLarge(x);
  }

  static double _erfPos(double x) {
    if (x >= 0.5) return 1 - _erfcLarge(x);
    // Maclaurin series converges fast for small x.
    final x2 = x * x;
    var term = x;
    var sum = x;
    for (var n = 1; n < 60; n++) {
      term *= -x2 / n;
      final t = term / (2 * n + 1);
      sum += t;
      if (t.abs() < 1e-17 * sum.abs()) break;
    }
    return 2 / math.sqrt(math.pi) * sum;
  }

  static double _erfcLarge(double x) {
    if (x > 27) return 0;
    // Continued fraction (Lentz) for erfc, accurate for x >= 0.5.
    const tiny = 1e-300;
    var f = x;
    var c = x;
    var d = 0.0;
    for (var n = 1; n < 500; n++) {
      final an = n / 2.0;
      d = x + an * d;
      d = d == 0 ? tiny : d;
      c = x + an / c;
      c = c == 0 ? tiny : c;
      d = 1 / d;
      final delta = c * d;
      f *= delta;
      if ((delta - 1).abs() < 1e-16) break;
    }
    return math.exp(-x * x) / (f * math.sqrt(math.pi));
  }

  static double normPdf(double x, double mu, double sigma) {
    final z = (x - mu) / sigma;
    return math.exp(-0.5 * z * z) / (sigma * math.sqrt(2 * math.pi));
  }

  static double normCdf(double x, double mu, double sigma) {
    final z = (x - mu) / (sigma * math.sqrt2);
    return 0.5 * erfc(-z);
  }

  /// Inverse standard normal CDF (Acklam's algorithm + Newton refinement).
  static double invNormStd(double p) {
    if (p <= 0 || p >= 1) throw ArgumentError('p must be in (0, 1)');
    const aa = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00];
    const bb = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01];
    const cc = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00];
    const dd = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00];
    const plow = 0.02425;
    double x;
    if (p < plow) {
      final q = math.sqrt(-2 * math.log(p));
      x = (((((cc[0] * q + cc[1]) * q + cc[2]) * q + cc[3]) * q + cc[4]) * q + cc[5]) /
          ((((dd[0] * q + dd[1]) * q + dd[2]) * q + dd[3]) * q + 1);
    } else if (p <= 1 - plow) {
      final q = p - 0.5;
      final r = q * q;
      x = (((((aa[0] * r + aa[1]) * r + aa[2]) * r + aa[3]) * r + aa[4]) * r + aa[5]) * q /
          (((((bb[0] * r + bb[1]) * r + bb[2]) * r + bb[3]) * r + bb[4]) * r + 1);
    } else {
      final q = math.sqrt(-2 * math.log(1 - p));
      x = -(((((cc[0] * q + cc[1]) * q + cc[2]) * q + cc[3]) * q + cc[4]) * q + cc[5]) /
          ((((dd[0] * q + dd[1]) * q + dd[2]) * q + dd[3]) * q + 1);
    }
    // Newton/Halley refinement.
    for (var k = 0; k < 2; k++) {
      final e = 0.5 * erfc(-x / math.sqrt2) - p;
      final u = e * math.sqrt(2 * math.pi) * math.exp(x * x / 2);
      x = x - u / (1 + x * u / 2);
    }
    return x;
  }

  Num _d(double v) => Dec.fromDouble(v);

  void _checkSigma(double sigma) {
    if (!(sigma > 0)) {
      throw const MathError(MathErrorCode.domainError, {'function': 'the normal distribution', 'value': 'σ ≤ 0'});
    }
  }

  Num normalPdf(Num x, Num mu, Num sigma) {
    final s = sigma.toDouble();
    _checkSigma(s);
    return _d(normPdf(x.toDouble(), mu.toDouble(), s));
  }

  Num normalCdf(Num x, Num mu, Num sigma) {
    final s = sigma.toDouble();
    _checkSigma(s);
    final z = (x.toDouble() - mu.toDouble()) / s;
    if (z < -26) return _lowerTail(-z / math.sqrt2);
    return _d(normCdf(x.toDouble(), mu.toDouble(), s));
  }

  /// ½·erfc(u) for large u without underflow: e^(−u²) is computed with
  /// the arbitrary-precision exponential (exponent range ±10⁶).
  Num _lowerTail(double u) {
    const tiny = 1e-300;
    var f = u, c = u, d = 0.0;
    for (var n = 1; n < 500; n++) {
      final an = n / 2.0;
      d = u + an * d;
      d = d == 0 ? tiny : d;
      c = u + an / c;
      c = c == 0 ? tiny : c;
      d = 1 / d;
      final delta = c * d;
      f *= delta;
      if ((delta - 1).abs() < 1e-16) break;
    }
    final e = a.exp(Dec.fromDouble(-u * u));
    return a.toDec(a.div(e, Dec.fromDouble(2 * f * math.sqrt(math.pi)))).withSig(14);
  }

  /// P(lower ≤ X ≤ upper).
  Num normalBetween(Num lower, Num upper, Num mu, Num sigma) {
    final s = sigma.toDouble();
    _checkSigma(s);
    final m = mu.toDouble();
    final lo = lower.toDouble(), hi = upper.toDouble();
    // Use the upper tail for accuracy when both bounds are far right.
    final zl = (lo - m) / s, zh = (hi - m) / s;
    double p;
    if (zl > 0) {
      p = 0.5 * (erfc(zl / math.sqrt2) - erfc(zh / math.sqrt2));
    } else {
      p = normCdf(hi, m, s) - normCdf(lo, m, s);
    }
    return _d(p < 0 ? 0 : p);
  }

  Num inverseNormal(Num p, Num mu, Num sigma) {
    final s = sigma.toDouble();
    _checkSigma(s);
    final pv = p.toDouble();
    if (!(pv > 0 && pv < 1)) {
      throw const MathError(MathErrorCode.domainError, {'function': 'invnorm', 'value': 'p outside (0, 1)'});
    }
    return _d(mu.toDouble() + s * invNormStd(pv));
  }

  // -------------------------------------------------------------- binomial

  (BigInt, Num) _binomArgs(Num n, Num p) {
    final nn = Arith.asBigInt(n);
    if (nn == null || nn.isNegative) {
      throw const MathError(MathErrorCode.nonIntegerArgument, {'function': 'The binomial distribution (n)'});
    }
    if (nn > BigInt.from(1000000)) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'the binomial distribution', 'limit': 'n ≤ 1000000'});
    }
    if (p is Cpx || a.compare(p, Rat.zero) < 0 || a.compare(p, Rat.one) > 0) {
      throw const MathError(MathErrorCode.domainError, {'function': 'the binomial distribution', 'value': 'p outside [0, 1]'});
    }
    return (nn, p);
  }

  static double _logChoose(int n, int k) => _lgamma(n + 1.0) - _lgamma(k + 1.0) - _lgamma(n - k + 1.0);

  /// ln Γ(x) for x > 0 (Lanczos, g = 7).
  static double _lgamma(double x) {
    const g = 7.0;
    const c = [
      0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
      -176.61503916999185, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
      1.5056327351493116e-7,
    ];
    if (x < 0.5) return math.log(math.pi / math.sin(math.pi * x).abs()) - _lgamma(1 - x);
    x -= 1;
    var s = c[0];
    for (var i = 1; i < 9; i++) {
      s += c[i] / (x + i);
    }
    final t = x + g + 0.5;
    return 0.5 * math.log(2 * math.pi) + (x + 0.5) * math.log(t) - t + math.log(s);
  }

  Num binomialPdf(Num n, Num p, Num k) {
    final (nn, pp) = _binomArgs(n, p);
    final kk = Arith.asBigInt(k);
    if (kk == null) return Rat.zero;
    if (kk.isNegative || kk > nn) return Rat.zero;
    if (pp is Rat && nn <= BigInt.from(1000)) {
      final c = Rat(NumberTheory.combinations(nn, kk));
      return a.mul(c, a.mul(pp.powInt(kk.toInt()), (Rat.one - pp).powInt((nn - kk).toInt())));
    }
    final pd = pp.toDouble();
    final ni = nn.toInt(), ki = kk.toInt();
    if (pd == 0) return ki == 0 ? Rat.one : Rat.zero;
    if (pd == 1) return ki == ni ? Rat.one : Rat.zero;
    final lp = _logChoose(ni, ki) + ki * math.log(pd) + (ni - ki) * math.log(1 - pd);
    return _d(math.exp(lp));
  }

  Num binomialCdf(Num n, Num p, Num k) {
    final (nn, pp) = _binomArgs(n, p);
    final kk = Arith.asBigInt(a.floor(k));
    if (kk == null || kk.isNegative) return Rat.zero;
    if (kk >= nn) return Rat.one;
    if (pp is Rat && nn <= BigInt.from(1000)) {
      Num s = Rat.zero;
      for (var j = BigInt.zero; j <= kk; j += BigInt.one) {
        s = a.add(s, binomialPdf(n, p, Rat(j)));
      }
      return s;
    }
    var s = 0.0;
    for (var j = 0; j <= kk.toInt(); j++) {
      s += binomialPdf(n, p, Rat.int(j)).toDouble();
    }
    return _d(math.min(1.0, s));
  }

  /// Smallest k with P(X ≤ k) ≥ q.
  Num inverseBinomial(Num n, Num p, Num q) {
    final (nn, _) = _binomArgs(n, p);
    final qv = q.toDouble();
    if (!(qv >= 0 && qv <= 1)) {
      throw const MathError(MathErrorCode.domainError, {'function': 'the inverse binomial', 'value': 'probability outside [0, 1]'});
    }
    var s = 0.0;
    for (var k = 0; k <= nn.toInt(); k++) {
      s += binomialPdf(n, p, Rat.int(k)).toDouble();
      if (s >= qv - 1e-15) return Rat.int(k);
    }
    return Rat(nn);
  }

  // --------------------------------------------------------------- poisson

  double _lambda(Num l) {
    final v = l.toDouble();
    if (!(v > 0) || l is Cpx) {
      throw const MathError(MathErrorCode.domainError, {'function': 'the Poisson distribution', 'value': 'λ ≤ 0'});
    }
    if (v > 1e7) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'the Poisson distribution', 'limit': 'λ ≤ 10^7'});
    }
    return v;
  }

  Num poissonPdf(Num lambda, Num k) {
    final l = _lambda(lambda);
    final kk = Arith.asInt(k);
    if (kk == null || kk < 0) return Rat.zero;
    if (kk <= 5000 && l <= 10000) {
      // Full precision: e^−λ · λ^k / k!
      return a.div(a.mul(a.exp(a.neg(lambda)), a.pow(lambda, Rat.int(kk))), a.factorial(Rat.int(kk)));
    }
    return _d(math.exp(kk * math.log(l) - l - _lgamma(kk + 1.0)));
  }

  Num poissonCdf(Num lambda, Num k) {
    final l = _lambda(lambda);
    final kk = Arith.asInt(a.floor(k));
    if (kk == null || kk < 0) return Rat.zero;
    if (kk <= 2000 && l <= 10000) {
      // Σ λ^j/j! in high precision (decimal terms keep this fast), times e^−λ.
      final lam = lambda is Rat && lambda.isInteger && lambda.n.bitLength < 8 ? lambda : a.toDec(lambda);
      Num term = Rat.one, sum = Rat.one;
      for (var j = 1; j <= kk; j++) {
        term = a.div(a.mul(term, lam), Rat.int(j));
        if (term is Rat && term.bitSize > 256) term = a.toDec(term);
        sum = a.add(sum, term);
      }
      final p = a.mul(a.exp(a.neg(lambda)), sum);
      return a.compare(p, Rat.one) > 0 ? Rat.one : p;
    }
    var s = 0.0;
    for (var j = 0; j <= kk; j++) {
      s += math.exp(j * math.log(l) - l - _lgamma(j + 1.0));
      if (j > l && s >= 1) break;
    }
    return _d(math.min(1.0, s));
  }

  Num inversePoisson(Num lambda, Num q) {
    final l = _lambda(lambda);
    final qv = q.toDouble();
    if (!(qv >= 0 && qv < 1)) {
      throw const MathError(MathErrorCode.domainError, {'function': 'the inverse Poisson', 'value': 'probability outside [0, 1)'});
    }
    var s = 0.0;
    for (var k = 0; k < 100000000; k++) {
      s += math.exp(k * math.log(l) - l - _lgamma(k + 1.0));
      if (s >= qv - 1e-15) return Rat.int(k);
    }
    throw const MathError(MathErrorCode.noConvergence);
  }
}
