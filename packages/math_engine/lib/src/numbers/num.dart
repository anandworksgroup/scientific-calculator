/// Number tower used by the engine: exact rationals ([Rat]), arbitrary
/// precision decimals ([Dec]) and complex numbers ([Cpx]), with [Arith]
/// providing precision-aware arithmetic and elementary functions.
library;

import 'dart:math' as math;

import '../core/errors.dart';

part 'rational.dart';
part 'decimal.dart';
part 'complex.dart';
part 'dec_math.dart';
part 'special.dart';

sealed class Num {
  const Num();
  bool get isZero;
  double toDouble();
}

/// Precision-aware arithmetic over [Num].
///
/// [precision] is the number of significant digits the user asked for;
/// internal work uses a few guard digits more ([wp]).
class Arith {
  Arith({this.precision = 15, this.allowComplex = false});

  final int precision;
  final bool allowComplex;

  int get wp => precision + 6;

  /// Exact integers may grow to ~120k digits (large factorials); exact
  /// non-integer fractions are capped far lower to keep results readable.
  static const intBitLimit = 400000;
  static const ratBitLimit = 8192;

  Arith withComplex(bool allow) =>
      allow == allowComplex ? this : Arith(precision: precision, allowComplex: allow);

  // ------------------------------------------------------------ conversion

  Num normalize(Num x) {
    switch (x) {
      case Rat r:
        if (r.isInteger) {
          if (r.n.bitLength > intBitLimit) return Dec.fromRat(r, wp);
        } else if (r.bitSize > ratBitLimit) {
          return Dec.fromRat(r, wp);
        }
        return r;
      case Dec():
        return x;
      case Cpx(:final re, :final im):
        return Cpx.of(normalize(re), normalize(im));
    }
  }

  Dec toDec(Num x) => switch (x) {
        Rat r => Dec.fromRat(r, wp),
        Dec d => d,
        Cpx() => throw const MathError(MathErrorCode.typeMismatch,
            {'detail': 'A real number is required here, but a complex number was given.'}),
      };

  static bool isReal(Num x) => x is! Cpx;

  static bool isIntegerValue(Num x) => switch (x) {
        Rat r => r.isInteger,
        Dec d => d.isInteger,
        Cpx() => false,
      };

  /// Exact integer value of [x], or null.
  static BigInt? asBigInt(Num x) => switch (x) {
        Rat r when r.isInteger => r.n,
        Dec d when d.isInteger && d.magnitude < 400 => d.toBigIntIfInteger(),
        _ => null,
      };

  static int? asInt(Num x) {
    final b = asBigInt(x);
    if (b == null || b.bitLength > 52) return null;
    return b.toInt();
  }

  Num fromDouble(double v) => Dec.fromDouble(v);

  static Num reOf(Num x) => x is Cpx ? x.re : x;
  static Num imOf(Num x) => x is Cpx ? x.im : Rat.zero;

  // ------------------------------------------------------------ arithmetic

  Num neg(Num a) => switch (a) {
        Rat r => -r,
        Dec d => -d,
        Cpx(:final re, :final im) => Cpx.of(neg(re), neg(im)),
      };

  Num add(Num a, Num b) {
    if (a is Rat && b is Rat) return normalize(a + b);
    if (a is Cpx || b is Cpx) {
      return Cpx.of(add(reOf(a), reOf(b)), add(imOf(a), imOf(b)));
    }
    if (a is Rat && a.isZero) return b;
    if (b is Rat && b.isZero) return a;
    return toDec(a).add(toDec(b), wp);
  }

  Num sub(Num a, Num b) => add(a, neg(b));

  Num mul(Num a, Num b) {
    if (a is Rat && b is Rat) return normalize(a * b);
    if (a is Cpx || b is Cpx) {
      final ar = reOf(a), ai = imOf(a), br = reOf(b), bi = imOf(b);
      return Cpx.of(sub(mul(ar, br), mul(ai, bi)), add(mul(ar, bi), mul(ai, br)));
    }
    // Exact zero annihilates.
    if ((a is Rat && a.isZero) || (b is Rat && b.isZero)) return Rat.zero;
    if (a is Rat && a.isOne) return b;
    if (b is Rat && b.isOne) return a;
    return toDec(a).mul(toDec(b), wp);
  }

  Num div(Num a, Num b) {
    if (isZeroValue(b)) throw const MathError(MathErrorCode.divisionByZero);
    if (a is Rat && b is Rat) return normalize(a / b);
    if (a is Cpx || b is Cpx) {
      final br = reOf(b), bi = imOf(b);
      final den = add(mul(br, br), mul(bi, bi));
      final ar = reOf(a), ai = imOf(a);
      final re = div(add(mul(ar, br), mul(ai, bi)), den);
      final im = div(sub(mul(ai, br), mul(ar, bi)), den);
      return Cpx.of(re, im);
    }
    if (a is Rat && a.isZero) return Rat.zero;
    if (b is Rat && b.isOne) return a;
    return toDec(a).div(toDec(b), wp);
  }

  static bool isZeroValue(Num x) => x.isZero;

  int compare(Num a, Num b) {
    if (a is Cpx || b is Cpx) {
      throw const MathError(MathErrorCode.typeMismatch,
          {'detail': 'Complex numbers cannot be compared.'});
    }
    if (a is Rat && b is Rat) return a.compareTo(b);
    // Compare exactly: Dec values convert to rationals exactly.
    final ra = a is Rat ? a : (a as Dec).toRat();
    final rb = b is Rat ? b : (b as Dec).toRat();
    return ra.compareTo(rb);
  }

  int signOf(Num a) => switch (a) {
        Rat r => r.sign,
        Dec d => d.sign,
        Cpx() => throw const MathError(MathErrorCode.typeMismatch,
            {'detail': 'The sign of a complex number is not defined.'}),
      };

  Num abs(Num a) => switch (a) {
        Rat r => r.abs(),
        Dec d => d.abs(),
        Cpx(:final re, :final im) => sqrt(add(mul(re, re), mul(im, im))),
      };

  // ---------------------------------------------------------------- powers

  Num pow(Num a, Num b) {
    // Integer exponent.
    final bi = b is Rat && b.isInteger ? b.n : null;
    if (bi != null) {
      if (bi == BigInt.zero) return Rat.one; // policy: 0^0 = 1
      if (isZeroValue(a)) {
        if (bi.isNegative) throw const MathError(MathErrorCode.divisionByZero);
        return Rat.zero;
      }
      if (a is Rat) {
        if (a.isOne) return Rat.one;
        if (a == Rat.minusOne) return bi.isEven ? Rat.one : Rat.minusOne;
        final bits = a.bitSize.toDouble() * bi.abs().toDouble();
        final limit = a.isInteger && !bi.isNegative ? intBitLimit : ratBitLimit;
        if (bits <= limit && bi.bitLength < 31) return normalize(a.powInt(bi.toInt()));
        return DecMath.powInt(toDec(a), bi, wp);
      }
      if (a is Dec) return DecMath.powInt(a, bi, wp);
      return _cpxPowInt(a as Cpx, bi);
    }
    if (a is Cpx || b is Cpx) return _cpxPow(a, b);
    // Real base, non-integer real exponent.
    final sa = signOf(a);
    if (sa == 0) {
      if (signOf(b) > 0) return Rat.zero;
      throw const MathError(MathErrorCode.divisionByZero);
    }
    if (b is Rat) {
      // Rational exponent p/q.
      final q = b.d;
      final p = b.n;
      if (sa < 0) {
        if (q.isOdd) {
          final r = pow(neg(a), b);
          return p.isOdd ? neg(r) : r;
        }
        if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
        return _cpxPow(a, b);
      }
      if (a is Rat && q.bitLength < 20) {
        final root = exactRoot(a, q.toInt());
        if (root != null) return pow(root, Rat(p));
      }
    } else if (sa < 0) {
      if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
      return _cpxPow(a, b);
    }
    return DecMath.pow(toDec(a), toDec(b), wp);
  }

  /// Exact k-th root of a non-negative rational, or null if irrational.
  static Rat? exactRoot(Rat a, int k) {
    if (a.isNegative) return null;
    if (a.n.bitLength > 20000 || a.d.bitLength > 20000) return null;
    final rn = DecMath.iroot(a.n, k);
    if (rn.pow(k) != a.n) return null;
    final rd = DecMath.iroot(a.d, k);
    if (rd.pow(k) != a.d) return null;
    return Rat(rn, rd);
  }

  Num _cpxPowInt(Cpx a, BigInt n) {
    if (n.isNegative) return div(Rat.one, _cpxPowInt(a, -n));
    if (n.bitLength > 20) return _cpxPow(a, Rat(n));
    Num result = Rat.one;
    Num base = a;
    var e = n;
    while (e > BigInt.zero) {
      if (e.isOdd) result = mul(result, base);
      e = e >> 1;
      if (e > BigInt.zero) base = mul(base, base);
    }
    return result;
  }

  Num _cpxPow(Num a, Num b) {
    if (isZeroValue(a)) {
      if (signOf(reOf(b)) > 0) return Rat.zero;
      throw const MathError(MathErrorCode.divisionByZero);
    }
    final c = withComplex(true);
    return c.exp(c.mul(b, c.ln(a)));
  }

  Num sqrt(Num a) {
    switch (a) {
      case Rat r:
        if (r.isNegative) {
          if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
          return Cpx.of(Rat.zero, sqrt(-r));
        }
        final ex = exactRoot(r, 2);
        if (ex != null) return ex;
        return DecMath.sqrt(Dec.fromRat(r, wp + 2), wp);
      case Dec d:
        if (d.isNegative) {
          if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
          return Cpx.of(Rat.zero, DecMath.sqrt(-d, wp));
        }
        return DecMath.sqrt(d, wp);
      case Cpx(:final re, :final im):
        final r = abs(a);
        final x = sqrt(div(add(r, re), Rat.two));
        var y = sqrt(div(sub(r, re), Rat.two));
        if (signOf(im) < 0) y = neg(y);
        return Cpx.of(x, y);
    }
  }

  /// Real cube root (negative inputs give negative roots).
  Num cbrt(Num a) => nthRoot(a, Rat.int(3));

  /// x^(1/n); odd integer n gives real roots of negative numbers.
  Num nthRoot(Num x, Num n) {
    if (isZeroValue(n)) {
      throw const MathError(MathErrorCode.domainError, {'function': 'root', 'value': 'index 0'});
    }
    if (n is Rat && n.isInteger && x is! Cpx) {
      final k = n.n;
      if (signOf(x) < 0) {
        if (k.isOdd) return neg(nthRoot(neg(x), n));
        if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
      } else if (x is Rat && k.bitLength < 20 && !k.isNegative) {
        final ex = exactRoot(x, k.toInt());
        if (ex != null) return ex;
      }
    }
    return pow(x, div(Rat.one, n));
  }

  // ---------------------------------------------------------- exp and logs

  Num exp(Num a) {
    switch (a) {
      case Rat r when r.isZero:
        return Rat.one;
      case Cpx(:final re, :final im):
        final m = exp(re);
        final sc = _sinCosReal(im);
        return Cpx.of(mul(m, sc.cos), mul(m, sc.sin));
      default:
        return DecMath.exp(toDec(a), wp);
    }
  }

  Num ln(Num a) {
    switch (a) {
      case Rat r when r.isOne:
        return Rat.zero;
      case Cpx(:final re, :final im):
        // ln|z| = ½·ln(re² + im²): exact for rational parts, which keeps
        // tiny real parts when |z| is very close to 1.
        final m2 = add(mul(re, re), mul(im, im));
        return Cpx.of(div(withComplex(false).ln(m2), Rat.two), arg(a));
      default:
        final s = signOf(a);
        if (s == 0) {
          throw const MathError(MathErrorCode.domainError, {'function': 'ln', 'value': '0'});
        }
        if (s < 0) {
          if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
          return Cpx.of(ln(neg(a)), pi());
        }
        return DecMath.ln(toDec(a), wp);
    }
  }

  Num log10(Num a) {
    if (a is Rat && !a.isNegative && !a.isZero) {
      // Exact for powers of ten (including 1/10^k).
      final r = _exactLog(a, BigInt.from(10));
      if (r != null) return r;
    }
    if (a is! Cpx && signOf(a) > 0) return DecMath.log10(toDec(a), wp);
    try {
      return div(ln(a), ln(Rat.int(10)));
    } on MathError catch (e) {
      if (e.code == MathErrorCode.domainError) {
        throw const MathError(MathErrorCode.domainError, {'function': 'log', 'value': '0'});
      }
      rethrow;
    }
  }

  Num logBase(Num base, Num a) {
    if (base is Rat && a is Rat && !a.isNegative && !a.isZero && base.isInteger && base.n > BigInt.one) {
      final r = _exactLog(a, base.n);
      if (r != null) return r;
    }
    if (base is! Cpx && (signOf(base) <= 0 || (base is Rat && base.isOne))) {
      throw MathError(MathErrorCode.domainError, {'function': 'log', 'value': 'base ${_short(base)}'});
    }
    return div(ln(a), ln(base));
  }

  /// log_b(a) when it is an integer (a = b^k or 1/b^k).
  static Num? _exactLog(Rat a, BigInt b) {
    BigInt v;
    var sign = 1;
    if (a.d == BigInt.one) {
      v = a.n;
    } else if (a.n == BigInt.one) {
      v = a.d;
      sign = -1;
    } else {
      return null;
    }
    var k = 0;
    while (v > BigInt.one) {
      if (v % b != BigInt.zero) return null;
      v = v ~/ b;
      k++;
    }
    return Rat.int(sign * k);
  }

  // --------------------------------------------------------- trigonometry

  Num pi() => DecMath.pi(wp);
  Num e() => DecMath.exp(Dec.one, wp);

  ({Num sin, Num cos}) _sinCosReal(Num x) {
    if (x is Rat && x.isZero) return (sin: Rat.zero, cos: Rat.one);
    // An exact rational argument is never "almost" a multiple of π/2.
    final r = x is Rat ? DecMath.sinCos(Dec.fromRat(x, wp + 10 + digitCount(x.n) + digitCount(x.d)), wp, allowSnap: false) : DecMath.sinCos(toDec(x), wp);
    Num s = r.sin, c = r.cos;
    if (r.exact) {
      s = r.sin.isZero ? Rat.zero : (r.sin.isNegative ? Rat.minusOne : Rat.one);
      c = r.cos.isZero ? Rat.zero : (r.cos.isNegative ? Rat.minusOne : Rat.one);
    }
    return (sin: s, cos: c);
  }

  Num sin(Num x) {
    if (x is Cpx) {
      final sc = _sinCosReal(x.re);
      return Cpx.of(mul(sc.sin, cosh(x.im)), mul(sc.cos, sinh(x.im)));
    }
    return _sinCosReal(x).sin;
  }

  Num cos(Num x) {
    if (x is Cpx) {
      final sc = _sinCosReal(x.re);
      return Cpx.of(mul(sc.cos, cosh(x.im)), neg(mul(sc.sin, sinh(x.im))));
    }
    return _sinCosReal(x).cos;
  }

  Num tan(Num x) {
    if (x is Cpx) return div(sin(x), cos(x));
    final sc = _sinCosReal(x);
    if (sc.cos.isZero) {
      throw const MathError(MathErrorCode.undefinedResult,
          {'detail': 'tan is undefined at odd multiples of 90° (π/2)'});
    }
    return div(sc.sin, sc.cos);
  }

  Num asin(Num x) {
    if (x is Cpx || compare(abs(x), Rat.one) > 0) {
      if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
      final c = withComplex(true);
      final iz = c.mul(Cpx.i, x);
      final root = c.sqrt(c.sub(Rat.one, c.mul(x, x)));
      return c.mul(Cpx.of(Rat.zero, Rat.minusOne), c.ln(c.add(iz, root)));
    }
    return DecMath.asin(toDec(x), wp);
  }

  Num acos(Num x) {
    if (x is Cpx || compare(abs(x), Rat.one) > 0) {
      if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
      return sub(div(pi(), Rat.two), withComplex(true).asin(x));
    }
    if (x is Rat && x.isOne) return Rat.zero;
    return DecMath.acos(toDec(x), wp);
  }

  Num atan(Num x) {
    if (x is Cpx) {
      final c = withComplex(true);
      final iz = c.mul(Cpx.i, x);
      if (c.sub(Rat.one, iz).isZero || c.add(Rat.one, iz).isZero) {
        throw const MathError(MathErrorCode.domainError, {'function': 'atan', 'value': '±i'});
      }
      final l = c.sub(c.ln(c.sub(Rat.one, iz)), c.ln(c.add(Rat.one, iz)));
      return c.mul(Cpx.of(Rat.zero, Rat.half), l);
    }
    return DecMath.atan(toDec(x), wp);
  }

  /// atan2(y, x) in radians, range (−π, π].
  Num atan2(Num y, Num x) {
    final sx = signOf(x), sy = signOf(y);
    if (sx == 0 && sy == 0) {
      throw const MathError(MathErrorCode.undefinedResult, {'detail': 'the angle of 0 is not defined'});
    }
    if (sx == 0) return sy > 0 ? div(pi(), Rat.two) : neg(div(pi(), Rat.two));
    if (sy == 0) return sx > 0 ? Rat.zero : pi();
    final base = atan(div(y, x));
    if (sx > 0) return base;
    return sy >= 0 ? add(base, pi()) : sub(base, pi());
  }

  Num sinh(Num x) {
    if (x is Cpx) {
      // sinh(a+bi) = sinh a cos b + i cosh a sin b
      final sc = _sinCosReal(x.im);
      return Cpx.of(mul(sinh(x.re), sc.cos), mul(cosh(x.re), sc.sin));
    }
    if (x.isZero) return Rat.zero;
    return DecMath.sinh(toDec(x), wp);
  }

  Num cosh(Num x) {
    if (x is Cpx) {
      final sc = _sinCosReal(x.im);
      return Cpx.of(mul(cosh(x.re), sc.cos), mul(sinh(x.re), sc.sin));
    }
    if (x.isZero) return Rat.one;
    return DecMath.cosh(toDec(x), wp);
  }

  Num tanh(Num x) {
    if (x is Cpx) return div(sinh(x), cosh(x));
    if (x.isZero) return Rat.zero;
    return DecMath.tanh(toDec(x), wp);
  }

  Num asinh(Num x) {
    if (x is Cpx) {
      final c = withComplex(true);
      return c.ln(c.add(x, c.sqrt(c.add(c.mul(x, x), Rat.one))));
    }
    if (x.isZero) return Rat.zero;
    return DecMath.asinh(toDec(x), wp);
  }

  Num acosh(Num x) {
    if (x is Cpx || compare(x, Rat.one) < 0) {
      if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
      final c = withComplex(true);
      return c.ln(c.add(x, c.mul(c.sqrt(c.add(x, Rat.one)), c.sqrt(c.sub(x, Rat.one)))));
    }
    if (x is Rat && x.isOne) return Rat.zero;
    return DecMath.acosh(toDec(x), wp);
  }

  Num atanh(Num x) {
    if (x is! Cpx) {
      final c = compare(abs(x), Rat.one);
      if (c == 0) {
        throw MathError(MathErrorCode.domainError, {'function': 'atanh', 'value': _short(x)});
      }
      if (c < 0) return x.isZero ? Rat.zero : DecMath.atanh(toDec(x), wp);
      if (!allowComplex) throw const MathError(MathErrorCode.complexResult);
    }
    final c = withComplex(true);
    return c.div(c.sub(c.ln(c.add(Rat.one, x)), c.ln(c.sub(Rat.one, x))), Rat.two);
  }

  // ---------------------------------------------------------- complex parts

  Num arg(Num x) {
    if (x is Cpx) return atan2(x.im, x.re);
    final s = signOf(x);
    if (s == 0) {
      throw const MathError(MathErrorCode.undefinedResult, {'detail': 'the argument of 0 is not defined'});
    }
    return s > 0 ? Rat.zero : pi();
  }

  Num conj(Num x) => x is Cpx ? Cpx.of(x.re, neg(x.im)) : x;

  // --------------------------------------------------------- integer parts

  Num floor(Num x) => switch (x) {
        Rat r => Rat(r.floor()),
        Dec d => Rat(_decFloor(d)),
        Cpx() => throw _realRequired('floor'),
      };

  Num ceil(Num x) => switch (x) {
        Rat r => Rat(r.ceil()),
        Dec d => Rat(-_decFloor(-d)),
        Cpx() => throw _realRequired('ceil'),
      };

  Num trunc(Num x) => signOf(x) >= 0 ? floor(x) : ceil(x);

  /// Round half away from zero to [digits] decimal places.
  Num round(Num x, [int digits = 0]) {
    if (x is Cpx) throw _realRequired('round');
    final scale = Rat(pow10(digits.abs()));
    final r = x is Rat ? x : (x as Dec).toRat();
    final scaled = digits >= 0 ? r * scale : r / scale;
    final rounded = Rat(scaled.round());
    return digits >= 0 ? rounded / scale : rounded * scale;
  }

  Num fracPart(Num x) => sub(x, trunc(x));

  Num sign(Num x) => x is Cpx
      ? (x.isZero ? Rat.zero : div(x, abs(x)))
      : Rat.int(signOf(x));

  static BigInt _decFloor(Dec d) {
    if (d.e >= 0) return d.m * pow10(d.e);
    final div = pow10(-d.e);
    return DecMath.floorDiv(d.m, div);
  }

  static MathError _realRequired(String fn) => MathError(MathErrorCode.typeMismatch,
      {'detail': '$fn() requires a real number.'});

  static String _short(Num x) {
    if (x is Rat) return x.toString();
    if (x is Dec) return x.round(8).toString();
    return 'a complex number';
  }

  // ------------------------------------------------------------- factorial

  static const exactFactorialLimit = 25000;

  Num factorial(Num x) {
    if (x is Cpx) throw _realRequired('factorial');
    final n = asBigInt(x);
    if (n != null) {
      if (n.isNegative) {
        throw MathError(MathErrorCode.domainError,
            {'function': 'factorial', 'value': 'negative integers ($n)'});
      }
      if (n <= BigInt.from(exactFactorialLimit)) {
        return Rat(productRange(BigInt.one, n));
      }
      if (n > BigInt.from(205000)) throw const MathError(MathErrorCode.overflow);
      return Special.gamma(toDec(add(x, Rat.one)), wp);
    }
    return gamma(add(x, Rat.one));
  }

  Num gamma(Num x) {
    if (x is Cpx) throw _realRequired('gamma');
    final n = asBigInt(x);
    if (n != null) {
      if (n <= BigInt.zero) {
        throw MathError(MathErrorCode.domainError,
            {'function': 'gamma', 'value': 'zero and negative integers'});
      }
      return factorial(Rat(n - BigInt.one));
    }
    return Special.gamma(toDec(x), wp);
  }

  /// Product lo·(lo+1)···hi using a balanced product tree.
  static BigInt productRange(BigInt lo, BigInt hi) {
    if (lo > hi) return BigInt.one;
    if (hi - lo < BigInt.from(16)) {
      var r = BigInt.one;
      for (var i = lo; i <= hi; i += BigInt.one) {
        r *= i;
      }
      return r;
    }
    final mid = (lo + hi) >> 1;
    return productRange(lo, mid) * productRange(mid + BigInt.one, hi);
  }
}
