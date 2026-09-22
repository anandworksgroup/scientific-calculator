part of 'num.dart';

/// Largest decimal exponent magnitude the engine will represent. Results
/// beyond this raise an overflow error instead of consuming unbounded memory.
const int maxDecimalExponent = 1000000;

/// Arbitrary-precision approximate real number: `m × 10^e`.
///
/// [sig] records how many significant digits are trustworthy. Values from
/// the native high-precision routines carry the working precision; values
/// derived from IEEE doubles (e.g. special functions) carry 15, so the
/// formatter never displays digits that were never computed.
final class Dec extends Num {
  Dec._(this.m, this.e, this.sig);

  /// Creates and normalizes (strips trailing zeros of the mantissa).
  factory Dec(BigInt m, int e, [int sig = 1 << 20]) {
    if (m == BigInt.zero) return Dec._(BigInt.zero, 0, sig);
    // Strip trailing zeros cheaply.
    var mm = m;
    var ee = e;
    final ten = BigInt.from(10);
    while (mm % ten == BigInt.zero) {
      mm = mm ~/ ten;
      ee++;
    }
    return Dec._(mm, ee, sig);
  }

  static final zero = Dec._(BigInt.zero, 0, 1 << 20);
  static final one = Dec._(BigInt.one, 0, 1 << 20);

  factory Dec.fromInt(int v) => Dec(BigInt.from(v), 0);

  /// Converts a double; the result is marked as having 15 reliable digits.
  factory Dec.fromDouble(double v) {
    if (v.isNaN) throw const MathError(MathErrorCode.undefinedResult);
    if (v.isInfinite) throw const MathError(MathErrorCode.overflow);
    if (v == 0) return Dec._(BigInt.zero, 0, 15);
    final s = v.toStringAsExponential(16); // e.g. 1.2345678901234567e-7
    final r = Rat.parseDecimal(s);
    return Dec.fromRat(r, 17).withSig(15);
  }

  /// Rounds a rational to [digits] significant digits.
  factory Dec.fromRat(Rat r, int digits) {
    if (r.isZero) return Dec.zero;
    if (r.isInteger) return Dec(r.n, 0).round(digits);
    // Scale so the integer quotient has at least `digits + 2` digits.
    final nd = _digitCount(r.n.abs());
    final dd = _digitCount(r.d);
    final shift = digits + 2 - (nd - dd);
    BigInt q;
    if (shift >= 0) {
      q = (r.n * pow10(shift)) ~/ r.d;
    } else {
      q = r.n ~/ (r.d * pow10(-shift));
    }
    return Dec(q, -shift).round(digits);
  }

  final BigInt m;
  final int e;
  final int sig;

  @override
  bool get isZero => m == BigInt.zero;
  bool get isNegative => m.isNegative;
  int get sign => m.sign;

  Dec withSig(int s) => Dec._(m, e, s);

  /// Number of digits in the mantissa.
  int get digits => _digitCount(m.abs());

  /// Decimal exponent of the leading digit: value in [10^mag, 10^(mag+1)).
  int get magnitude => isZero ? 0 : e + digits - 1;

  Dec operator -() => Dec._(-m, e, sig);
  Dec abs() => m.isNegative ? Dec._(-m, e, sig) : this;

  /// Rounds to [p] significant digits (half-even).
  Dec round(int p) {
    if (isZero) return this;
    final nd = digits;
    if (nd <= p) return _checked(this);
    final drop = nd - p;
    final div = pow10(drop);
    var q = m ~/ div; // trunc toward zero
    final r = (m - q * div).abs();
    final half = div ~/ BigInt.two;
    final c = r.compareTo(half);
    if (c > 0 || (c == 0 && q.isOdd)) {
      q += m.isNegative ? -BigInt.one : BigInt.one;
    }
    return _checked(Dec(q, e + drop, sig));
  }

  static Dec _checked(Dec d) {
    if (d.isZero) return d;
    final mag = d.magnitude;
    if (mag > maxDecimalExponent) throw const MathError(MathErrorCode.overflow);
    if (mag < -maxDecimalExponent) return Dec.zero;
    return d;
  }

  Dec add(Dec o, int p) {
    if (isZero) return o.round(p).withSig(_minSig(o.sig, sig));
    if (o.isZero) return round(p).withSig(_minSig(o.sig, sig));
    final s = _minSig(sig, o.sig);
    // If magnitudes differ by more than the precision, the smaller one
    // cannot affect the rounded result (beyond a guard digit).
    final gap = magnitude - o.magnitude;
    if (gap > p + 3) return round(p).withSig(s);
    if (gap < -(p + 3)) return o.round(p).withSig(s);
    if (e == o.e) return Dec(m + o.m, e, s).round(p);
    if (e > o.e) return Dec(m * pow10(e - o.e) + o.m, o.e, s).round(p);
    return Dec(m + o.m * pow10(o.e - e), e, s).round(p);
  }

  Dec sub(Dec o, int p) => add(-o, p);

  Dec mul(Dec o, int p) {
    final s = _minSig(sig, o.sig);
    if (isZero || o.isZero) return Dec.zero.withSig(s);
    return Dec(m * o.m, e + o.e, s).round(p);
  }

  Dec div(Dec o, int p) {
    if (o.isZero) throw const MathError(MathErrorCode.divisionByZero);
    final s = _minSig(sig, o.sig);
    if (isZero) return Dec.zero.withSig(s);
    final shift = p + 3 + o.digits - digits;
    final num = shift > 0 ? m * pow10(shift) : m;
    final q = num ~/ o.m;
    return Dec(q, e - o.e - (shift > 0 ? shift : 0), s).round(p);
  }

  int compareTo(Dec o) {
    if (sign != o.sign) return sign.compareTo(o.sign);
    if (isZero) return 0;
    if (e == o.e) return m.compareTo(o.m);
    if (e > o.e) return (m * pow10(e - o.e)).compareTo(o.m);
    return m.compareTo(o.m * pow10(o.e - e));
  }

  /// Exact conversion to a rational.
  Rat toRat() => e >= 0 ? Rat(m * pow10(e)) : Rat(m, pow10(-e));

  bool get isInteger => e >= 0;

  BigInt? toBigIntIfInteger() => e >= 0 ? m * pow10(e) : null;

  @override
  double toDouble() {
    if (isZero) return 0;
    final mag = magnitude;
    if (mag > 400) return m.isNegative ? double.negativeInfinity : double.infinity;
    if (mag < -400) return 0;
    // Use at most 20 digits of the mantissa.
    final nd = digits;
    var mm = m;
    var ee = e;
    if (nd > 20) {
      mm = m ~/ pow10(nd - 20);
      ee += nd - 20;
    }
    return double.parse('${mm}e$ee');
  }

  /// Plain scientific representation for debugging, e.g. `1.2345e-7`.
  @override
  String toString() {
    if (isZero) return '0';
    final s = m.abs().toString();
    final neg = m.isNegative ? '-' : '';
    final exp = magnitude;
    final mant = s.length == 1 ? s : '${s[0]}.${s.substring(1)}';
    return exp == 0 ? '$neg$mant' : '$neg${mant}e$exp';
  }

  @override
  bool operator ==(Object other) =>
      other is Dec && other.m == m && other.e == e;

  @override
  int get hashCode => Object.hash(m, e);
}

int _minSig(int a, int b) => a < b ? a : b;

int _digitCount(BigInt v) {
  if (v == BigInt.zero) return 1;
  // Estimate from the bit length, then correct.
  final bits = v.bitLength;
  var est = ((bits - 1) * 0.30102999566398120).floor() + 1;
  final p = pow10(est - 1);
  if (v < p) {
    est--;
  } else if (v >= p * BigInt.from(10)) {
    est++;
  }
  return est;
}

/// Number of decimal digits of |v| (1 for zero).
int digitCount(BigInt v) => _digitCount(v.abs());
