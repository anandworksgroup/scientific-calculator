/// Symbolic expressions in canonical form.
///
/// All construction goes through [S] which performs automatic
/// simplification (like SymPy's automatic evaluation): sums are flattened
/// and like terms combined, products group equal bases, numeric powers are
/// evaluated exactly (√8 → 2√2, 1/√2 → √2/2), and functions of special
/// arguments evaluate (sin(π/6) → 1/2, ln(e) → 1).
library;

import '../core/errors.dart';
import '../number_theory/number_theory.dart';
import '../numbers/num.dart';

/// Size limit for expressions produced by expansion.
const int maxSymTerms = 5000;

sealed class Sym {
  const Sym();

  String get key;

  @override
  bool operator ==(Object other) => other is Sym && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;

  bool get isNumber => this is SNum;
  Rat? get asRat => this is SNum ? (this as SNum).v : null;
}

final class SNum extends Sym {
  SNum(this.v);
  final Rat v;
  @override
  late final String key = 'n:$v';
}

final class SConst extends Sym {
  SConst(this.name);

  /// `pi`, `e`, `i`
  final String name;
  @override
  late final String key = 'c:$name';
}

final class SVar extends Sym {
  SVar(this.name);
  final String name;
  @override
  late final String key = 'v:$name';
}

final class SAdd extends Sym {
  SAdd(this.terms);
  final List<Sym> terms;
  @override
  late final String key = '+(${terms.map((t) => t.key).join(',')})';
}

final class SMul extends Sym {
  SMul(this.factors);
  final List<Sym> factors;
  @override
  late final String key = '*(${factors.map((t) => t.key).join(',')})';

  Rat get coefficient => factors.first is SNum ? (factors.first as SNum).v : Rat.one;

  /// Product without the numeric coefficient.
  Sym get rest {
    if (factors.first is! SNum) return this;
    final r = factors.sublist(1);
    return r.length == 1 ? r.first : SMul(r);
  }
}

final class SPow extends Sym {
  SPow(this.base, this.exp);
  final Sym base;
  final Sym exp;
  @override
  late final String key = '^(${base.key},${exp.key})';
}

final class SFn extends Sym {
  SFn(this.name, this.args);
  final String name;
  final List<Sym> args;
  @override
  late final String key = 'f:$name(${args.map((t) => t.key).join(',')})';
}

// ------------------------------------------------------------ utilities

bool dependsOn(Sym s, String v) => switch (s) {
      SNum() || SConst() => false,
      SVar(:final name) => name == v,
      SAdd(:final terms) => terms.any((t) => dependsOn(t, v)),
      SMul(:final factors) => factors.any((t) => dependsOn(t, v)),
      SPow(:final base, :final exp) => dependsOn(base, v) || dependsOn(exp, v),
      SFn(:final args) => args.any((t) => dependsOn(t, v)),
    };

Set<String> symVariables(Sym s) {
  final out = <String>{};
  void walk(Sym x) {
    switch (x) {
      case SVar(:final name):
        out.add(name);
      case SAdd(:final terms):
        terms.forEach(walk);
      case SMul(:final factors):
        factors.forEach(walk);
      case SPow(:final base, :final exp):
        walk(base);
        walk(exp);
      case SFn(:final args):
        args.forEach(walk);
      default:
        break;
    }
  }

  walk(s);
  return out;
}

/// Polynomial degree of a term in all variables (0 for non-polynomial).
Rat _degree(Sym s) {
  switch (s) {
    case SVar():
      return Rat.one;
    case SPow(:final base, :final exp) when base is SVar && exp is SNum:
      return exp.v;
    case SMul(:final factors):
      return factors.fold(Rat.zero, (d, f) => d + _degree(f));
    default:
      return Rat.zero;
  }
}

int _rank(Sym s) => switch (s) {
      SNum() => 0,
      SConst() => 1,
      SVar() => 2,
      SPow(:final base) => base is SNum ? 1 : (base is SConst ? 1 : _rank(base) == 2 ? 2 : 3),
      SFn() => 4,
      SAdd() => 5,
      SMul() => 6,
    };

Sym _baseOf(Sym s) => s is SPow ? s.base : s;

int _compareFactors(Sym x, Sym y) {
  final r = _rank(x).compareTo(_rank(y));
  if (r != 0) return r;
  final b = _baseOf(x).key.compareTo(_baseOf(y).key);
  if (b != 0) return b;
  return x.key.compareTo(y.key);
}

int _compareTerms(Sym x, Sym y) {
  final xn = x is SNum, yn = y is SNum;
  if (xn != yn) return xn ? 1 : -1;
  final d = _degree(y).compareTo(_degree(x));
  if (d != 0) return d;
  // Terms with variables before pure constants (π, √2).
  final xv = symVariables(x).isNotEmpty, yv = symVariables(y).isNotEmpty;
  if (xv != yv) return xv ? -1 : 1;
  return _stripCoeff(x).key.compareTo(_stripCoeff(y).key);
}

Sym _stripCoeff(Sym s) => s is SMul ? s.rest : s;

Rat _coeffOf(Sym s) => s is SMul ? s.coefficient : (s is SNum ? s.v : Rat.one);

// ------------------------------------------------------------ constructors

/// Canonicalizing constructors.
abstract final class S {
  static final zero = SNum(Rat.zero);
  static final one = SNum(Rat.one);
  static final two = SNum(Rat.two);
  static final minusOne = SNum(Rat.minusOne);
  static final half = SNum(Rat.half);
  static final pi = SConst('pi');
  static final e = SConst('e');
  static final i = SConst('i');

  static Sym n(Rat v) => SNum(v);
  static Sym integer(int v) => SNum(Rat.int(v));
  static Sym v(String name) => SVar(name);

  static Sym neg(Sym x) => mul([minusOne, x]);
  static Sym sub(Sym x, Sym y) => add([x, neg(y)]);
  static Sym div(Sym x, Sym y) {
    if (y is SNum && y.v.isZero) throw const MathError(MathErrorCode.divisionByZero);
    return mul([x, pow(y, minusOne)]);
  }

  static Sym sqrt(Sym x) => pow(x, half);

  // ------------------------------------------------------------------ add

  static Sym add(List<Sym> input) {
    final flat = <Sym>[];
    for (final t in input) {
      if (t is SAdd) {
        flat.addAll(t.terms);
      } else {
        flat.add(t);
      }
    }
    if (flat.length > maxSymTerms) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'symbolic expressions', 'limit': '$maxSymTerms terms'});
    }
    var constant = Rat.zero;
    final groups = <String, (Sym, Rat)>{};
    final order = <String>[];
    for (final t in flat) {
      if (t is SNum) {
        constant += t.v;
        continue;
      }
      final rest = _stripCoeff(t);
      final c = _coeffOf(t);
      final k = rest.key;
      final g = groups[k];
      if (g == null) {
        groups[k] = (rest, c);
        order.add(k);
      } else {
        groups[k] = (rest, g.$2 + c);
      }
    }
    final terms = <Sym>[];
    for (final k in order) {
      final (rest, c) = groups[k]!;
      if (c.isZero) continue;
      terms.add(c.isOne ? rest : _mulRaw(c, rest));
    }
    if (!constant.isZero) terms.add(SNum(constant));
    if (terms.isEmpty) return zero;
    if (terms.length == 1) return terms.first;
    terms.sort(_compareTerms);
    return SAdd(terms);
  }

  /// coefficient × product (no re-simplification needed).
  static Sym _mulRaw(Rat c, Sym rest) {
    if (rest is SMul) return SMul([SNum(c), ...rest.factors]);
    return SMul([SNum(c), rest]);
  }

  // ------------------------------------------------------------------ mul

  static Sym mul(List<Sym> input) {
    final flat = <Sym>[];
    for (final f in input) {
      if (f is SMul) {
        flat.addAll(f.factors);
      } else {
        flat.add(f);
      }
    }
    var coeff = Rat.one;
    var iCount = 0;
    final bases = <String, (Sym, List<Sym>)>{};
    final order = <String>[];
    // Numeric radicals n^(p/q), grouped by exponent: √2·√3 → √6.
    final numericByExp = <String, (Rat, Rat)>{};
    final numOrder = <String>[];
    void addRadical(Rat base, Rat exp) {
      final ek = exp.toString();
      final g = numericByExp[ek];
      if (g == null) {
        numericByExp[ek] = (exp, base);
        numOrder.add(ek);
      } else {
        numericByExp[ek] = (exp, g.$2 * base);
      }
    }

    for (final f in flat) {
      if (f is SNum) {
        coeff = coeff * f.v;
        if (coeff.isZero) return zero;
        continue;
      }
      if (f is SConst && f.name == 'i') {
        iCount++;
        continue;
      }
      if (f is SPow && f.base is SConst && (f.base as SConst).name == 'i' && f.exp is SNum &&
          (f.exp as SNum).v.isInteger) {
        iCount += ((f.exp as SNum).v.n % BigInt.from(4)).toInt();
        continue;
      }
      if (f is SPow && f.base is SNum && f.exp is SNum) {
        addRadical((f.base as SNum).v, (f.exp as SNum).v);
        continue;
      }
      final base = _baseOf(f);
      final exp = f is SPow ? f.exp : one;
      final k = base.key;
      final g = bases[k];
      if (g == null) {
        bases[k] = (base, [exp]);
        order.add(k);
      } else {
        g.$2.add(exp);
      }
    }
    final factors = <Sym>[];
    void absorb(Sym p) {
      final parts = p is SMul ? p.factors : [p];
      for (final part in parts) {
        if (part is SNum) {
          coeff = coeff * part.v;
        } else if (part is SConst && part.name == 'i') {
          iCount++;
        } else {
          factors.add(part);
        }
      }
    }

    for (final k in order) {
      final (base, exps) = bases[k]!;
      if (exps.length == 1) {
        factors.add(exps.first == one ? base : SPow(base, exps.first));
        continue;
      }
      final p = pow(base, add(exps));
      if (p is SPow && p.base is SNum && p.exp is SNum) {
        addRadical((p.base as SNum).v, (p.exp as SNum).v);
      } else {
        absorb(p);
      }
    }
    // Combine radicals sharing an exponent (at most two passes: the
    // combined result can only produce fresh radicals of reduced index).
    for (var pass = 0; pass < 2 && numOrder.isNotEmpty; pass++) {
      final entries = [for (final k in numOrder) numericByExp[k]!];
      numericByExp.clear();
      numOrder.clear();
      for (final (exp, base) in entries) {
        final (c, rads, imag) = _numPowParts(base, exp);
        coeff = coeff * c;
        if (imag) iCount++;
        for (final r in rads) {
          if (pass == 0) {
            addRadical((r.base as SNum).v, (r.exp as SNum).v);
          } else {
            factors.add(r);
          }
        }
      }
    }
    for (final k in numOrder) {
      final (exp, base) = numericByExp[k]!;
      factors.add(SPow(SNum(base), SNum(exp)));
    }
    switch (iCount % 4) {
      case 1:
        factors.add(i);
      case 2:
        coeff = -coeff;
      case 3:
        coeff = -coeff;
        factors.add(i);
    }
    if (coeff.isZero) return zero;
    if (factors.isEmpty) return SNum(coeff);
    factors.sort(_compareFactors);
    if (coeff.isOne && factors.length == 1) return factors.first;
    return SMul([if (!coeff.isOne) SNum(coeff), ...factors]);
  }

  // ------------------------------------------------------------------ pow

  static Sym pow(Sym base, Sym exp) {
    if (exp is SNum) {
      final ev = exp.v;
      if (ev.isZero) return one;
      if (ev.isOne) return base;
    }
    if (base is SNum) {
      final bv = base.v;
      if (bv.isOne) return one;
      if (bv.isZero) {
        if (exp is SNum && exp.v.isNegative) throw const MathError(MathErrorCode.divisionByZero);
        if (exp is SNum) return zero;
      }
      if (exp is SNum) return _numPow(bv, exp.v);
    }
    if (base is SConst && base.name == 'i' && exp is SNum && exp.v.isInteger) {
      final k = (exp.v.n % BigInt.from(4)).toInt();
      return [one, i, minusOne, SMul([minusOne, i])][k];
    }
    if (base is SConst && base.name == 'e') {
      if (exp is SFn && exp.name == 'ln') return exp.args.first;
      if (exp is SMul && exp.factors.length == 2 && exp.factors.first is SNum && exp.factors[1] is SFn &&
          (exp.factors[1] as SFn).name == 'ln' && (exp.factors.first as SNum).v.isInteger) {
        // e^(k ln x) = x^k
        return pow((exp.factors[1] as SFn).args.first, exp.factors.first);
      }
    }
    if (base is SPow && exp is SNum && exp.v.isInteger) {
      return pow(base.base, mul([base.exp, exp]));
    }
    if (base is SPow && exp is SNum && base.exp is SNum && (base.exp as SNum).v.isInteger &&
        (base.exp as SNum).v.n.isOdd) {
      // (x^odd)^(p/q) = x^(odd·p/q) holds for real principal roots when q
      // is odd.
      if (exp.v.d.isOdd) return pow(base.base, mul([base.exp, exp]));
    }
    if (base is SMul) {
      if (exp is SNum && exp.v.isInteger) {
        return mul([for (final f in base.factors) pow(f, exp)]);
      }
      // A positive numeric coefficient can be split off for any exponent.
      final c = base.coefficient;
      if (!c.isOne && !c.isNegative) {
        final cp = exp is SNum ? _numPow(c, exp.v) : SPow(SNum(c), exp);
        return mul([cp, pow(base.rest, exp)]);
      }
    }
    return SPow(base, exp);
  }

  /// Exact rational power of a rational number, extracting perfect powers
  /// and rationalizing denominators. Never calls [mul] (no recursion).
  static Sym _numPow(Rat b, Rat e) {
    final (c, rads, imag) = _numPowParts(b, e);
    final factors = <Sym>[if (imag) i, ...rads]..sort(_compareFactors);
    if (c.isZero) return zero;
    if (factors.isEmpty) return SNum(c);
    if (c.isOne && factors.length == 1) return factors.first;
    return SMul([if (!c.isOne) SNum(c), ...factors]);
  }

  /// b^e as coefficient × radicals × (i if imaginary).
  static (Rat, List<SPow>, bool) _numPowParts(Rat b, Rat e) {
    SPow raw() => SPow(SNum(b), SNum(e));
    if (e.isInteger) {
      if (b.bitSize * e.n.abs().toDouble() > 20000) return (Rat.one, [raw()], false);
      return (b.powInt(e.n.toInt()), const [], false);
    }
    final k = e.floor();
    final f = e - Rat(k);
    final r = f.n, q = f.d;
    if (q.bitLength > 16 || b.bitSize * (r.toDouble() + k.abs().toDouble()) > 4000) {
      return (Rat.one, [raw()], false);
    }
    var coeff = k == BigInt.zero ? Rat.one : b.powInt(k.toInt());
    final neg = b.isNegative;
    var imag = false;
    if (neg) {
      if (q.isOdd) {
        if (r.isOdd) coeff = -coeff;
      } else if (q == BigInt.two) {
        imag = true; // (−n)^(1/2) = i·√n (r is odd here)
      } else {
        return (Rat.one, [raw()], false);
      }
    }
    final a = b.abs();
    // a^(r/q) = (n^r · d^(q−r))^(1/q) / d
    final qi = q.toInt();
    final c = a.n.pow(r.toInt()) * a.d.pow(qi - r.toInt());
    final (outside, inside, index) = _extractRoot(c, qi);
    coeff = coeff * Rat(outside, a.d);
    if (inside == BigInt.one) return (coeff, const [], imag);
    return (coeff, [SPow(SNum(Rat(inside)), SNum(Rat.frac(1, index)))], imag);
  }

  /// c^(1/q) = outside · inside^(1/index) with the smallest index.
  static (BigInt, BigInt, int) _extractRoot(BigInt c, int q) {
    var outside = BigInt.one;
    var inside = BigInt.one;
    var m = c;
    if (c.bitLength <= 60) {
      if (c > BigInt.one) {
        for (final (p, e) in NumberTheory.factorize(c)) {
          outside *= p.pow(e ~/ q);
          inside *= p.pow(e % q);
        }
      }
      m = BigInt.one;
    } else {
      // Bounded trial division; a remaining cofactor that is itself a
      // perfect q-th power is still extracted.
      for (var p = 2; p < 20000 && m > BigInt.one; p++) {
        final bp = BigInt.from(p);
        var e = 0;
        while (m % bp == BigInt.zero) {
          m = m ~/ bp;
          e++;
        }
        if (e > 0) {
          outside *= bp.pow(e ~/ q);
          inside *= bp.pow(e % q);
        }
      }
      final rt = _iroot(m, q);
      if (rt.pow(q) == m) {
        outside *= rt;
        m = BigInt.one;
      }
    }
    inside *= m;
    if (inside == BigInt.one) return (outside, inside, 1);
    // Reduce the index when inside is a perfect g-th power (4^(1/4) = √2).
    for (var g = q; g >= 2; g--) {
      if (q % g != 0) continue;
      final rt = _iroot(inside, g);
      if (rt.pow(g) == inside) return (outside, rt, q ~/ g);
    }
    return (outside, inside, q);
  }

  static BigInt _iroot(BigInt v, int k) {
    if (v < BigInt.two) return v;
    var lo = BigInt.one, hi = BigInt.one << (v.bitLength ~/ k + 1);
    while (lo < hi) {
      final mid = (lo + hi + BigInt.one) >> 1;
      if (mid.pow(k) <= v) {
        lo = mid;
      } else {
        hi = mid - BigInt.one;
      }
    }
    return lo;
  }

  // ------------------------------------------------------------ functions

  static Sym fn(String name, List<Sym> args) {
    switch (name) {
      case 'sqrt':
        return pow(args[0], half);
      case 'cbrt':
        return pow(args[0], SNum(Rat.frac(1, 3)));
      case 'nroot':
        return pow(args[1], div(one, args[0]));
      case 'exp':
        return pow(e, args[0]);
      case 'pow':
        return pow(args[0], args[1]);
      case 'log':
        if (args.length == 2) return div(ln(args[1]), ln(args[0]));
        return div(ln(args[0]), ln(SNum(Rat.int(10))));
      case 'log2':
        return div(ln(args[0]), ln(two));
      case 'ln':
        return ln(args[0]);
      case 'sin':
        return _trig('sin', args[0]);
      case 'cos':
        return _trig('cos', args[0]);
      case 'tan':
        return _trig('tan', args[0]);
      case 'sec':
        return div(one, _trig('cos', args[0]));
      case 'csc':
        return div(one, _trig('sin', args[0]));
      case 'cot':
        return div(_trig('cos', args[0]), _trig('sin', args[0]));
      case 'asin' || 'acos' || 'atan':
        return _invTrig(name, args[0]);
      case 'abs':
        final a0 = args[0];
        if (a0 is SNum) return SNum(a0.v.abs());
        if (a0 is SConst && (a0.name == 'pi' || a0.name == 'e')) return a0;
        if (a0 is SMul && a0.coefficient.isNegative) return fn('abs', [neg(a0)]);
        if (isNonNegative(a0)) return a0;
        return SFn('abs', args);
      case 'sinh' || 'tanh' || 'asinh' || 'atanh':
        if (args[0] is SNum && (args[0] as SNum).v.isZero) return zero;
        return SFn(name, args);
      case 'cosh':
        if (args[0] is SNum && (args[0] as SNum).v.isZero) return one;
        return SFn(name, args);
      case 'acosh':
        if (args[0] is SNum && (args[0] as SNum).v.isOne) return zero;
        return SFn(name, args);
      case 'factorial':
        final a0 = args[0];
        if (a0 is SNum && a0.v.isInteger && !a0.v.isNegative && a0.v.n <= BigInt.from(1000)) {
          return SNum(Rat(Arith.productRange(BigInt.one, a0.v.n)));
        }
        return SFn(name, args);
      case 'floor' || 'ceil' || 'round' || 'trunc' || 'sign':
        final a0 = args[0];
        if (a0 is SNum && args.length == 1) {
          final v = a0.v;
          return SNum(Rat(switch (name) {
            'floor' => v.floor(),
            'ceil' => v.ceil(),
            'round' => v.round(),
            'trunc' => v.truncate(),
            _ => BigInt.from(v.sign),
          }));
        }
        return SFn(name, args);
    }
    return SFn(name, args);
  }

  /// Conservative test: true only when [s] is provably ≥ 0 for all real
  /// values of its variables.
  static bool isNonNegative(Sym s) => switch (s) {
        SNum(:final v) => !v.isNegative,
        SConst(:final name) => name == 'pi' || name == 'e',
        SVar() => false,
        SPow(:final base, :final exp) => (exp is SNum && exp.v.isInteger && exp.v.n.isEven) ||
            (base is SConst && base.name == 'e') ||
            (base is SNum && !base.v.isNegative) ||
            (isNonNegative(base) && exp is SNum),
        SMul(:final factors) => factors.every(isNonNegative),
        SAdd(:final terms) => terms.every(isNonNegative),
        SFn(:final name) => name == 'abs' || name == 'cosh',
      };

  static Sym ln(Sym x) {
    if (x is SNum) {
      final v = x.v;
      if (v.isOne) return zero;
      if (v.isZero || v.isNegative) return SFn('ln', [x]);
      // ln(n/d) = ln n − ln d, and ln(b^k) = k·ln b
      if (!v.isInteger) {
        if (v.n == BigInt.one) return neg(ln(SNum(Rat(v.d))));
        return SFn('ln', [x]);
      }
      final (base, k) = _perfectPower(v.n);
      if (k > 1) return mul([SNum(Rat.int(k)), SFn('ln', [SNum(Rat(base))])]);
      return SFn('ln', [x]);
    }
    if (x is SConst && x.name == 'e') return one;
    if (x is SPow && x.base is SConst && (x.base as SConst).name == 'e') return x.exp;
    if (x is SPow && x.base is SNum && !(x.base as SNum).v.isNegative && x.exp is SNum) {
      // ln(√2) = ½·ln 2
      return mul([x.exp, ln(x.base)]);
    }
    return SFn('ln', [x]);
  }

  static (BigInt, int) _perfectPower(BigInt n) {
    if (n < BigInt.from(4)) return (n, 1);
    for (var k = n.bitLength; k >= 2; k--) {
      final r = _iroot(n, k);
      if (r > BigInt.one && r.pow(k) == n) {
        final (b2, k2) = _perfectPower(r);
        return (b2, k * k2);
      }
    }
    return (n, 1);
  }

  /// If x = q·π for rational q, returns q.
  static Rat? piMultiple(Sym x) {
    if (x is SNum && x.v.isZero) return Rat.zero;
    if (x is SConst && x.name == 'pi') return Rat.one;
    if (x is SMul && x.factors.length == 2 && x.factors[0] is SNum && x.factors[1] is SConst &&
        (x.factors[1] as SConst).name == 'pi') {
      return (x.factors[0] as SNum).v;
    }
    return null;
  }

  static Sym _sinOfTwelfths(int k) {
    // sin(kπ/12) for k in 0..23
    k %= 24;
    if (k >= 12) return neg(_sinOfTwelfths(k - 12));
    if (k > 6) return _sinOfTwelfths(12 - k);
    final s2 = sqrt(two), s3 = sqrt(SNum(Rat.int(3))), s6 = sqrt(SNum(Rat.int(6)));
    return switch (k) {
      0 => zero,
      1 => div(sub(s6, s2), SNum(Rat.int(4))),
      2 => half,
      3 => div(s2, two),
      4 => div(s3, two),
      5 => div(add([s6, s2]), SNum(Rat.int(4))),
      _ => one,
    };
  }

  static Sym _trig(String name, Sym x) {
    final q = piMultiple(x);
    if (q != null) {
      final twelve = q * Rat.int(12);
      if (twelve.isInteger) {
        final k = (twelve.n % BigInt.from(24)).toInt();
        switch (name) {
          case 'sin':
            return _sinOfTwelfths(k);
          case 'cos':
            return _sinOfTwelfths(k + 6);
          case 'tan':
            final c = _sinOfTwelfths(k + 6);
            if (c is SNum && c.v.isZero) {
              throw const MathError(MathErrorCode.undefinedResult,
                  {'detail': 'tan is undefined at odd multiples of π/2'});
            }
            return div(_sinOfTwelfths(k), c);
        }
      }
    }
    // Odd/even symmetry: pull out a negative coefficient.
    if (x is SMul && x.coefficient.isNegative) {
      final pos = neg(x);
      return name == 'cos' ? _trig('cos', pos) : neg(_trig(name, pos));
    }
    if (x is SNum && x.v.isNegative) {
      final pos = SNum(-x.v);
      return name == 'cos' ? _trig('cos', pos) : neg(_trig(name, pos));
    }
    // Inverse functions: sin(asin(x)) = x.
    if (x is SFn && x.name == 'a$name') return x.args.first;
    return SFn(name, [x]);
  }

  static Sym _invTrig(String name, Sym x) {
    // Match against the exact special values.
    final table = <(Sym, Rat)>[
      (zero, Rat.zero),
      (half, Rat.frac(1, 6)),
      (div(sqrt(two), two), Rat.frac(1, 4)),
      (div(sqrt(SNum(Rat.int(3))), two), Rat.frac(1, 3)),
      (one, Rat.frac(1, 2)),
    ];
    Sym piTimes(Rat q) => mul([SNum(q), pi]);
    if (name == 'atan') {
      final t = <(Sym, Rat)>[
        (zero, Rat.zero),
        (div(sqrt(SNum(Rat.int(3))), SNum(Rat.int(3))), Rat.frac(1, 6)),
        (one, Rat.frac(1, 4)),
        (sqrt(SNum(Rat.int(3))), Rat.frac(1, 3)),
      ];
      for (final (v, q) in t) {
        if (x == v) return piTimes(q);
        if (x == neg(v)) return piTimes(-q);
      }
    } else {
      for (final (v, q) in table) {
        if (x == v) return name == 'asin' ? piTimes(q) : piTimes(Rat.half - q);
        if (x == neg(v)) return name == 'asin' ? piTimes(-q) : piTimes(Rat.half + q);
      }
    }
    if (name != 'acos' && x is SMul && x.coefficient.isNegative) return neg(_invTrig(name, neg(x)));
    return SFn(name, [x]);
  }
}
