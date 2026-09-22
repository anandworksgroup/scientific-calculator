part of 'num.dart';

/// Arbitrary-precision special functions (Gamma via Stirling's series).
abstract final class Special {
  static List<Rat>? _bern;

  /// Even-index Bernoulli numbers B_0, B_2, …, B_120 (index k → B_{2k}).
  static List<Rat> get _bernoulliEven {
    final cached = _bern;
    if (cached != null) return cached;
    const n = 120;
    final a = List<Rat>.filled(n + 1, Rat.zero);
    final out = <Rat>[];
    for (var m = 0; m <= n; m++) {
      a[m] = Rat.frac(1, m + 1);
      for (var j = m; j >= 1; j--) {
        a[j - 1] = Rat.int(j) * (a[j - 1] - a[j]);
      }
      if (m.isEven) out.add(a[0]);
    }
    return _bern = out;
  }

  /// ln Γ(z) for z >= threshold via the asymptotic Stirling series.
  static Dec _lnGammaLarge(Dec z, int w) {
    final lnz = DecMath.ln(z, w);
    final half = Dec(BigInt.from(5), -1);
    final twoPi = DecMath.pi(w).mul(Dec.fromInt(2), w);
    var res = z.sub(half, w).mul(lnz, w).sub(z, w).add(DecMath.ln(twoPi, w).mul(half, w), w);
    final bern = _bernoulliEven;
    final z2 = z.mul(z, w);
    var zpow = z; // z^(2k−1)
    for (var k = 1; k < bern.length; k++) {
      final b = bern[k];
      final coeff = Dec.fromRat(b / Rat.int(2 * k * (2 * k - 1)), w);
      final term = coeff.div(zpow, w);
      if (term.isZero || term.magnitude < res.magnitude - w - 2) break;
      res = res.add(term, w);
      zpow = zpow.mul(z2, w);
    }
    return res;
  }

  static Dec lnGamma(Dec x, int p) {
    if (x.sign <= 0) throw ArgumentError('lnGamma requires x > 0');
    final threshold = p + 15;
    final extra = x.magnitude > 0 ? x.magnitude + 2 : 2;
    final w = p + 8 + extra;
    var z = x;
    var prod = Dec.one;
    final th = Dec.fromInt(threshold);
    while (z.compareTo(th) < 0) {
      prod = prod.mul(z, w);
      z = z.add(Dec.one, w);
    }
    var r = _lnGammaLarge(z, w);
    if (!(prod.m == BigInt.one && prod.e == 0)) r = r.sub(DecMath.ln(prod, w), w);
    return r.round(p);
  }

  static Dec gamma(Dec x, int p) {
    if (x.sign <= 0) {
      // Reflection: Γ(x) = π / (sin(πx) Γ(1 − x)).
      final w = p + 8;
      final pi = DecMath.pi(w);
      final s = DecMath.sinCos(pi.mul(x, w), w).sin;
      if (s.isZero) {
        throw const MathError(MathErrorCode.domainError,
            {'function': 'gamma', 'value': 'zero and negative integers'});
      }
      return pi.div(s.mul(gamma(Dec.one.sub(x, w), w), w), p);
    }
    final lg = lnGamma(x, p + 10 + (x.magnitude > 0 ? x.magnitude + 1 : 0));
    return DecMath.exp(lg, p);
  }
}
