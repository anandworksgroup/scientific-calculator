part of 'num.dart';

/// High-precision elementary functions on [Dec] values.
///
/// All routines work in fixed-point [BigInt] arithmetic at a working scale
/// of `10^W` where `W` exceeds the requested precision by guard digits, and
/// return results rounded to the requested number of significant digits.
abstract final class DecMath {
  static final _piCache = <int, BigInt>{};
  static final _ln2Cache = <int, BigInt>{};
  static final _ln10Cache = <int, BigInt>{};

  // ---------------------------------------------------------------- helpers

  static BigInt _one(int w) => pow10(w);

  /// round(x × 10^w) as a BigInt.
  static BigInt toFixed(Dec x, int w) {
    final shift = x.e + w;
    if (shift >= 0) return x.m * pow10(shift);
    final div = pow10(-shift);
    final q = x.m ~/ div;
    final r = (x.m - q * div).abs() * BigInt.two;
    if (r >= div) return q + (x.m.isNegative ? -BigInt.one : BigInt.one);
    return q;
  }

  static Dec fromFixed(BigInt v, int w, int p) => Dec(v, -w).round(p);

  static BigInt floorDiv(BigInt a, BigInt b) {
    final q = a ~/ b;
    if ((a.isNegative != b.isNegative) && q * b != a) return q - BigInt.one;
    return q;
  }

  static BigInt isqrt(BigInt n) {
    if (n.isNegative) throw ArgumentError('isqrt of negative');
    if (n < BigInt.two) return n;
    var x = BigInt.one << ((n.bitLength + 1) >> 1);
    while (true) {
      final y = (x + n ~/ x) >> 1;
      if (y >= x) return x;
      x = y;
    }
  }

  /// Integer n-th root: floor(v^(1/k)) for v >= 0.
  static BigInt iroot(BigInt v, int k) {
    if (v < BigInt.two || k == 1) return v;
    final kk = BigInt.from(k);
    var x = BigInt.one << ((v.bitLength ~/ k) + 1);
    while (true) {
      final y = ((kk - BigInt.one) * x + v ~/ x.pow(k - 1)) ~/ kk;
      if (y >= x) break;
      x = y;
    }
    while (x.pow(k) > v) {
      x -= BigInt.one;
    }
    while ((x + BigInt.one).pow(k) <= v) {
      x += BigInt.one;
    }
    return x;
  }

  // -------------------------------------------------------------- constants

  static BigInt _atanInv(int n, BigInt one) {
    final nn = BigInt.from(n);
    final n2 = BigInt.from(n * n);
    var x = one ~/ nn;
    var sum = x;
    var k = 1;
    var neg = true;
    while (x != BigInt.zero) {
      x = x ~/ n2;
      final term = x ~/ BigInt.from(2 * k + 1);
      sum = neg ? sum - term : sum + term;
      neg = !neg;
      k++;
    }
    return sum;
  }

  static BigInt _atanhInv(int n, BigInt one) {
    final nn = BigInt.from(n);
    final n2 = BigInt.from(n * n);
    var x = one ~/ nn;
    var sum = x;
    var k = 1;
    while (x != BigInt.zero) {
      x = x ~/ n2;
      sum += x ~/ BigInt.from(2 * k + 1);
      k++;
    }
    return sum;
  }

  /// π at scale 10^w.
  static BigInt piFixed(int w) {
    final cached = _piCache[w];
    if (cached != null) return cached;
    final g = w + 10;
    final one = _one(g);
    final v = (BigInt.from(16) * _atanInv(5, one) - BigInt.from(4) * _atanInv(239, one)) ~/ pow10(10);
    if (_piCache.length > 16) _piCache.clear();
    return _piCache[w] = v;
  }

  static BigInt ln2Fixed(int w) {
    final cached = _ln2Cache[w];
    if (cached != null) return cached;
    final g = w + 10;
    final v = (BigInt.two * _atanhInv(3, _one(g))) ~/ pow10(10);
    if (_ln2Cache.length > 16) _ln2Cache.clear();
    return _ln2Cache[w] = v;
  }

  static BigInt ln10Fixed(int w) {
    final cached = _ln10Cache[w];
    if (cached != null) return cached;
    final g = w + 10;
    final one = _one(g);
    final v = (BigInt.from(3) * ((BigInt.two * _atanhInv(3, one))) + BigInt.two * _atanhInv(9, one)) ~/ pow10(10);
    if (_ln10Cache.length > 16) _ln10Cache.clear();
    return _ln10Cache[w] = v;
  }

  static Dec pi(int p) => fromFixed(piFixed(p + 5), p + 5, p);

  // ------------------------------------------------------------ sqrt / root

  /// Square root; exact when the argument is a perfect square.
  static Dec sqrt(Dec x, int p) {
    if (x.isNegative) throw const MathError(MathErrorCode.complexResult);
    if (x.isZero) return x;
    final w = p + 2;
    var s = 2 * w + 2 - x.digits;
    if (s < 0) s = 0;
    if ((x.e - s).isOdd) s++;
    final n = x.m * pow10(s);
    final r = isqrt(n);
    return Dec(r, (x.e - s) ~/ 2, x.sig).round(p);
  }

  // ------------------------------------------------------------- exp / ln

  static Dec exp(Dec x, int p) {
    if (x.isZero) return Dec.one;
    // e^x overflows the representable exponent range beyond ~2.3e6.
    if (x.magnitude >= 7) {
      if (x.isNegative) return Dec.zero;
      throw const MathError(MathErrorCode.overflow);
    }
    final intDigits = x.magnitude < 0 ? 1 : x.magnitude + 1;
    final w = p + 12 + intDigits;
    final one = _one(w);
    final xf = toFixed(x, w);
    final l10 = ln10Fixed(w);
    final k = floorDiv(xf, l10);
    var r = xf - k * l10; // 0 <= r < ln 10
    const halvings = 12;
    r = r >> halvings;
    var sum = one;
    var term = one;
    var n = 1;
    while (true) {
      term = (term * r) ~/ (one * BigInt.from(n));
      if (term == BigInt.zero) break;
      sum += term;
      n++;
    }
    for (var i = 0; i < halvings; i++) {
      sum = (sum * sum) ~/ one;
    }
    final kk = k.toInt();
    if (kk.abs() > maxDecimalExponent) {
      if (kk < 0) return Dec.zero;
      throw const MathError(MathErrorCode.overflow);
    }
    return Dec(sum, -w + kk, x.sig).round(p);
  }

  static Dec ln(Dec x, int p) {
    if (x.isZero || x.isNegative) {
      throw MathError(MathErrorCode.domainError, {'function': 'ln', 'value': x.isZero ? '0' : 'negative numbers'});
    }
    // Extra digits when x is close to 1 (the result is then small).
    var guard = 0;
    if (x.magnitude == 0 || x.magnitude == -1) {
      final diff = x.add(Dec(BigInt.from(-1), 0), p + 40);
      if (diff.isZero) return Dec.zero;
      if (diff.magnitude < 0) guard = -diff.magnitude;
    }
    final t = x.magnitude;
    final tDigits = t == 0 ? 1 : t.abs().toString().length;
    final w = p + 12 + guard + tDigits;
    final one = _one(w);
    // y = x / 10^t in [1, 10)
    final y = toFixed(Dec(x.m, x.e - t), w);
    final yd = y / one;
    var k = (math.log(yd) / math.ln2).round();
    if (k < 0) k = 0;
    final z = y >> k; // y / 2^k in ~[0.7, 1.42]
    final u = ((z - one) * one) ~/ (z + one);
    final u2 = (u * u) ~/ one;
    var sum = u;
    var term = u;
    var n = 1;
    while (true) {
      term = (term * u2) ~/ one;
      if (term == BigInt.zero) break;
      sum += term ~/ BigInt.from(2 * n + 1);
      n++;
    }
    var res = BigInt.two * sum + BigInt.from(k) * ln2Fixed(w);
    if (t != 0) res += BigInt.from(t) * ln10Fixed(w);
    return Dec(res, -w, x.sig).round(p);
  }

  static Dec log10(Dec x, int p) {
    // Exact for powers of ten.
    if (!x.isNegative && x.m == BigInt.one) return Dec.fromInt(x.e);
    final w = p + 5;
    return ln(x, w).div(fromFixed(ln10Fixed(w), w, w), p);
  }

  /// x^y for real x > 0 (or x == 0).
  static Dec pow(Dec x, Dec y, int p) {
    if (y.isZero) return Dec.one;
    if (x.isZero) {
      if (y.isNegative) throw const MathError(MathErrorCode.divisionByZero);
      return Dec.zero;
    }
    if (x.isNegative) throw const MathError(MathErrorCode.complexResult);
    final lx = ln(x, p + 10);
    final prod = lx.mul(y, p + 10);
    final extra = prod.magnitude > 0 ? prod.magnitude + 1 : 0;
    final lx2 = extra > 0 ? ln(x, p + 10 + extra) : lx;
    return exp(lx2.mul(y, p + 10 + extra), p);
  }

  /// Integer power by repeated squaring.
  static Dec powInt(Dec x, BigInt n, int p) {
    if (n == BigInt.zero) return Dec.one;
    if (n.isNegative) return Dec.one.div(powInt(x, -n, p + 5), p);
    if (n.bitLength > 40) {
      return pow(x.abs(), Dec(n, 0), p).let((r) => (x.isNegative && n.isOdd) ? -r : r);
    }
    final w = p + 5 + n.bitLength;
    var result = Dec.one;
    var base = x;
    var e = n;
    while (e > BigInt.zero) {
      if (e.isOdd) result = result.mul(base, w);
      e = e >> 1;
      if (e > BigInt.zero) base = base.mul(base, w);
    }
    return result.round(p);
  }

  // ----------------------------------------------------------- trigonometry

  /// Returns (sin x, cos x) for x in radians. The record's `exact` flag is
  /// set when x was recognized as an exact multiple of π/2 (so the results
  /// are exactly 0 or ±1 rather than tiny rounding residues).
  static ({Dec sin, Dec cos, bool exact}) sinCos(Dec x, int p, {bool allowSnap = true}) {
    if (x.isZero) return (sin: Dec.zero, cos: Dec.one, exact: true);
    if (x.magnitude > 5000) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'trigonometric functions', 'limit': '1E5000'});
    }
    final small = x.magnitude < 0 ? -x.magnitude : 0;
    final big = x.magnitude > 0 ? x.magnitude + 1 : 0;
    final w = p + 12 + small + big;
    final one = _one(w);
    final xf = toFixed(x, w);
    final halfPi = piFixed(w) >> 1;
    final q = floorDiv(xf * BigInt.two + halfPi, halfPi * BigInt.two);
    var r = xf - q * halfPi;
    var exact = false;
    // Snapping only applies to approximate inputs (e.g. a computed π);
    // exact inputs are reduced exactly using enough digits of π.
    if (q != BigInt.zero && allowSnap) {
      final ref = xf.abs() > one ? xf.abs() : one;
      // The argument itself carries ~p digits, so a residue this small is
      // indistinguishable from an exact multiple of π/2.
      if (r.abs() * pow10(p - 3) < ref) {
        r = BigInt.zero;
        exact = true;
      }
    }
    BigInt s, c;
    if (r == BigInt.zero) {
      s = BigInt.zero;
      c = one;
    } else {
      final r2 = (r * r) ~/ one;
      s = r;
      var term = r;
      var n = 1;
      while (true) {
        term = -(term * r2) ~/ (one * BigInt.from((2 * n) * (2 * n + 1)));
        if (term == BigInt.zero) break;
        s += term;
        n++;
      }
      c = one;
      term = one;
      n = 1;
      while (true) {
        term = -(term * r2) ~/ (one * BigInt.from((2 * n - 1) * (2 * n)));
        if (term == BigInt.zero) break;
        c += term;
        n++;
      }
    }
    final quad = (q % BigInt.from(4)).toInt();
    BigInt sv, cv;
    switch (quad) {
      case 0:
        sv = s;
        cv = c;
      case 1:
        sv = c;
        cv = -s;
      case 2:
        sv = -s;
        cv = -c;
      default:
        sv = -c;
        cv = s;
    }
    return (sin: Dec(sv, -w, x.sig).round(p), cos: Dec(cv, -w, x.sig).round(p), exact: exact);
  }

  static Dec atan(Dec x, int p) {
    if (x.isZero) return Dec.zero;
    final small = x.magnitude < 0 ? -x.magnitude : 0;
    final w = p + 12 + small;
    final one = _one(w);
    var xf = toFixed(x, w);
    final neg = xf.isNegative;
    if (neg) xf = -xf;
    var invert = false;
    if (xf > one) {
      // atan(x) = π/2 − atan(1/x)
      xf = (one * one) ~/ xf;
      invert = true;
    }
    for (var i = 0; i < 3; i++) {
      xf = (xf * one) ~/ (one + isqrt(one * one + xf * xf));
    }
    final x2 = (xf * xf) ~/ one;
    var sum = xf;
    var term = xf;
    var n = 1;
    while (true) {
      term = -(term * x2) ~/ one;
      if (term == BigInt.zero) break;
      sum += term ~/ BigInt.from(2 * n + 1);
      n++;
    }
    var res = sum * BigInt.from(8);
    if (invert) res = (piFixed(w) >> 1) - res;
    if (neg) res = -res;
    return Dec(res, -w, x.sig).round(p);
  }

  static Dec asin(Dec x, int p) {
    final c = x.abs().compareTo(Dec.one);
    if (c > 0) throw const MathError(MathErrorCode.complexResult);
    if (c == 0) {
      final hp = fromFixed(piFixed(p + 5) >> 1, p + 5, p);
      return x.isNegative ? -hp : hp;
    }
    if (x.isZero) return Dec.zero;
    final w = p + 10;
    final one = Dec.one;
    final den = sqrt(one.sub(x.mul(x, w * 2), w * 2), w);
    return atan(x.div(den, w), p);
  }

  static Dec acos(Dec x, int p) {
    final c = x.abs().compareTo(Dec.one);
    if (c > 0) throw const MathError(MathErrorCode.complexResult);
    final w = p + 10;
    if (x.compareTo(Dec(BigInt.from(5), -1)) > 0) {
      // acos x = 2 asin(sqrt((1 − x)/2)) avoids cancellation near 1.
      final t = sqrt(Dec.one.sub(x, w).div(Dec.fromInt(2), w), w);
      return asin(t, w).mul(Dec.fromInt(2), p);
    }
    final hp = fromFixed(piFixed(w) >> 1, w, w);
    return hp.sub(asin(x, w), p);
  }

  // ------------------------------------------------------------- hyperbolic

  static int _smallGuard(Dec x) => x.magnitude < 0 ? -x.magnitude : 0;

  static Dec sinh(Dec x, int p) {
    if (x.isZero) return x;
    final w = p + 5 + _smallGuard(x);
    final ex = exp(x, w);
    return ex.sub(Dec.one.div(ex, w), w).div(Dec.fromInt(2), p);
  }

  static Dec cosh(Dec x, int p) {
    final w = p + 5;
    final ex = exp(x, w);
    return ex.add(Dec.one.div(ex, w), w).div(Dec.fromInt(2), p);
  }

  static Dec tanh(Dec x, int p) {
    if (x.isZero) return x;
    if (x.magnitude >= 4) return x.isNegative ? -Dec.one : Dec.one;
    final w = p + 5 + _smallGuard(x);
    final e2 = exp(x.mul(Dec.fromInt(2), w), w);
    return e2.sub(Dec.one, w).div(e2.add(Dec.one, w), p);
  }

  static Dec asinh(Dec x, int p) {
    if (x.isZero) return x;
    if (x.isNegative) return -asinh(-x, p);
    final w = p + 5 + _smallGuard(x);
    final s = sqrt(x.mul(x, w * 2).add(Dec.one, w * 2), w);
    return ln(x.add(s, w), p);
  }

  static Dec acosh(Dec x, int p) {
    if (x.compareTo(Dec.one) < 0) throw const MathError(MathErrorCode.complexResult);
    final w = p + 8;
    final s = sqrt(x.mul(x, w * 2).sub(Dec.one, w * 2), w);
    return ln(x.add(s, w), p);
  }

  static Dec atanh(Dec x, int p) {
    final c = x.abs().compareTo(Dec.one);
    if (c == 0) {
      throw MathError(MathErrorCode.domainError, {'function': 'atanh', 'value': x.isNegative ? '−1' : '1'});
    }
    if (c > 0) throw const MathError(MathErrorCode.complexResult);
    if (x.isZero) return x;
    final w = p + 5 + _smallGuard(x);
    final r = Dec.one.add(x, w).div(Dec.one.sub(x, w), w);
    return ln(r, w).div(Dec.fromInt(2), p);
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
