part of 'num.dart';

/// Exact rational number `n/d` with `d > 0` and `gcd(n, d) == 1`.
final class Rat extends Num implements Comparable<Rat> {
  Rat._(this.n, this.d);

  factory Rat(BigInt n, [BigInt? d]) {
    d ??= BigInt.one;
    if (d == BigInt.zero) throw const MathError(MathErrorCode.divisionByZero);
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    if (d == BigInt.one) return Rat._(n, d);
    final g = n.gcd(d);
    if (g != BigInt.one && g != BigInt.zero) {
      n = n ~/ g;
      d = d ~/ g;
    }
    return Rat._(n, d);
  }

  factory Rat.int(int v) => Rat._(BigInt.from(v), BigInt.one);

  factory Rat.frac(int n, int d) => Rat(BigInt.from(n), BigInt.from(d));

  /// Parses a decimal literal such as `12`, `1.25`, `.5`, `1.2E-3` exactly.
  factory Rat.parseDecimal(String s) {
    var str = s.trim();
    var exp = 0;
    final eIdx = str.indexOf(RegExp('[eE]'));
    if (eIdx >= 0) {
      exp = int.parse(str.substring(eIdx + 1));
      str = str.substring(0, eIdx);
    }
    var neg = false;
    if (str.startsWith('-')) {
      neg = true;
      str = str.substring(1);
    } else if (str.startsWith('+')) {
      str = str.substring(1);
    }
    final dot = str.indexOf('.');
    String digits;
    if (dot >= 0) {
      final frac = str.substring(dot + 1);
      digits = str.substring(0, dot) + frac;
      exp -= frac.length;
    } else {
      digits = str;
    }
    if (digits.isEmpty) digits = '0';
    var m = BigInt.parse(digits);
    if (neg) m = -m;
    if (exp >= 0) return Rat(m * _pow10(exp));
    return Rat(m, _pow10(-exp));
  }

  static final zero = Rat._(BigInt.zero, BigInt.one);
  static final one = Rat._(BigInt.one, BigInt.one);
  static final two = Rat._(BigInt.two, BigInt.one);
  static final minusOne = Rat._(-BigInt.one, BigInt.one);
  static final half = Rat._(BigInt.one, BigInt.two);

  final BigInt n;
  final BigInt d;

  bool get isInteger => d == BigInt.one;
  @override
  bool get isZero => n == BigInt.zero;
  bool get isNegative => n.isNegative;
  bool get isOne => n == BigInt.one && d == BigInt.one;
  int get sign => n.sign;

  /// Total size in bits, used to cap runaway exact growth.
  int get bitSize => n.bitLength + d.bitLength;

  Rat operator +(Rat o) =>
      d == o.d ? Rat(n + o.n, d) : Rat(n * o.d + o.n * d, d * o.d);
  Rat operator -(Rat o) =>
      d == o.d ? Rat(n - o.n, d) : Rat(n * o.d - o.n * d, d * o.d);
  Rat operator *(Rat o) => Rat(n * o.n, d * o.d);
  Rat operator /(Rat o) {
    if (o.isZero) throw const MathError(MathErrorCode.divisionByZero);
    return Rat(n * o.d, d * o.n);
  }

  Rat operator -() => Rat._(-n, d);
  Rat abs() => n.isNegative ? Rat._(-n, d) : this;
  Rat reciprocal() {
    if (isZero) throw const MathError(MathErrorCode.divisionByZero);
    return Rat(d, n);
  }

  /// Exact integer power (negative exponents allowed for non-zero bases).
  Rat powInt(int e) {
    if (e == 0) return Rat.one;
    if (e < 0) return reciprocal().powInt(-e);
    return Rat._(n.pow(e), d.pow(e));
  }

  BigInt floor() {
    if (isInteger) return n;
    final q = n ~/ d; // truncates toward zero
    return n.isNegative ? q - BigInt.one : q;
  }

  BigInt ceil() => isInteger ? n : floor() + BigInt.one;

  BigInt truncate() => n ~/ d;

  /// Rounds half away from zero.
  BigInt round() {
    final twice = Rat(n * BigInt.two + (n.isNegative ? -d : d), d * BigInt.two);
    return twice.truncate();
  }

  @override
  int compareTo(Rat o) => (n * o.d).compareTo(o.n * d);

  bool operator <(Rat o) => compareTo(o) < 0;
  bool operator >(Rat o) => compareTo(o) > 0;
  bool operator <=(Rat o) => compareTo(o) <= 0;
  bool operator >=(Rat o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object other) => other is Rat && other.n == n && other.d == d;

  @override
  int get hashCode => Object.hash(n, d);

  @override
  double toDouble() {
    final v = n / d;
    if (v.isFinite) return v;
    // Very large numerator/denominator: scale down first.
    return Dec.fromRat(this, 20).toDouble();
  }

  int? toIntOrNull() {
    if (!isInteger) return null;
    if (n.bitLength > 62) return null;
    return n.toInt();
  }

  @override
  String toString() => isInteger ? '$n' : '$n/$d';
}

final _pow10Cache = <int, BigInt>{};

BigInt _pow10(int e) {
  if (e < 64) {
    return _pow10Cache.putIfAbsent(e, () => BigInt.from(10).pow(e));
  }
  return BigInt.from(10).pow(e);
}

/// 10^e as a BigInt (e >= 0).
BigInt pow10(int e) => _pow10(e);
