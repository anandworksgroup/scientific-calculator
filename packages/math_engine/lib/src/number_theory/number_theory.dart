import 'dart:math' as math;

import '../core/budget.dart';
import '../core/errors.dart';

/// Integer number theory: primality, factorization, divisors, gcd/lcm.
abstract final class NumberTheory {
  static final _small = _sieve(1000);

  static List<int> _sieve(int n) {
    final comp = List<bool>.filled(n + 1, false);
    final out = <int>[];
    for (var i = 2; i <= n; i++) {
      if (comp[i]) continue;
      out.add(i);
      for (var j = i * i; j <= n; j += i) {
        comp[j] = true;
      }
    }
    return out;
  }

  /// Largest integer accepted by the factorization routines (~10^40).
  static final BigInt factorLimit = BigInt.from(10).pow(40);

  static BigInt _modPow(BigInt b, BigInt e, BigInt m) => b.modPow(e, m);

  /// Miller–Rabin. Deterministic for n < 3.3·10^24 with the first 13 prime
  /// bases; for larger n the same bases give an error probability below
  /// 4^−13 per composite, and a further 12 bases are used.
  static bool isPrime(BigInt n) {
    if (n < BigInt.two) return false;
    for (final p in _small.take(40)) {
      final bp = BigInt.from(p);
      if (n == bp) return true;
      if (n % bp == BigInt.zero) return false;
    }
    var d = n - BigInt.one;
    var s = 0;
    while (d.isEven) {
      d >>= 1;
      s++;
    }
    final bases = _small.take(n.bitLength > 82 ? 25 : 13);
    outer:
    for (final base in bases) {
      final a = BigInt.from(base);
      if (a >= n) continue;
      var x = _modPow(a, d, n);
      if (x == BigInt.one || x == n - BigInt.one) continue;
      for (var r = 1; r < s; r++) {
        x = (x * x) % n;
        if (x == n - BigInt.one) continue outer;
      }
      return false;
    }
    return true;
  }

  static BigInt _pollardRho(BigInt n, Budget budget) {
    if (n.isEven) return BigInt.two;
    final rnd = math.Random(n.hashCode);
    while (true) {
      final c = BigInt.from(rnd.nextInt(1 << 30) + 1);
      var y = BigInt.from(rnd.nextInt(1 << 30) + 2) % n;
      const m = 64;
      var g = BigInt.one;
      var r = 1;
      var q = BigInt.one;
      BigInt x = y, ys = y;
      while (g == BigInt.one) {
        x = y;
        for (var i = 0; i < r; i++) {
          y = (y * y + c) % n;
        }
        var k = 0;
        while (k < r && g == BigInt.one) {
          ys = y;
          final lim = math.min(m, r - k);
          for (var i = 0; i < lim; i++) {
            y = (y * y + c) % n;
            q = (q * (x - y).abs()) % n;
          }
          g = q.gcd(n);
          k += m;
          budget.tick(m);
        }
        r *= 2;
      }
      if (g == n) {
        do {
          ys = (ys * ys + c) % n;
          g = (x - ys).abs().gcd(n);
        } while (g == BigInt.one);
      }
      if (g != n) return g;
    }
  }

  /// Prime factorization as sorted (prime, exponent) pairs; n >= 2.
  static List<(BigInt, int)> factorize(BigInt n, [Budget? budget]) {
    budget ??= Budget(timeLimit: const Duration(seconds: 5));
    if (n.isNegative) n = -n;
    if (n > factorLimit) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'factorization', 'limit': '10^40'});
    }
    final counts = <BigInt, int>{};
    void add(BigInt p) => counts[p] = (counts[p] ?? 0) + 1;
    for (final p in _small) {
      final bp = BigInt.from(p);
      if (bp * bp > n) break;
      while (n % bp == BigInt.zero) {
        add(bp);
        n = n ~/ bp;
      }
    }
    final stack = <BigInt>[if (n > BigInt.one) n];
    while (stack.isNotEmpty) {
      final m = stack.removeLast();
      if (m == BigInt.one) continue;
      if (isPrime(m)) {
        add(m);
        continue;
      }
      // Perfect-square shortcut helps rho on squares of primes.
      final r = _isqrt(m);
      if (r * r == m) {
        stack
          ..add(r)
          ..add(r);
        continue;
      }
      final f = _pollardRho(m, budget);
      stack
        ..add(f)
        ..add(m ~/ f);
    }
    final keys = counts.keys.toList()..sort();
    return [for (final k in keys) (k, counts[k]!)];
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

  static const maxDivisorCount = 100000;

  static List<BigInt> divisors(BigInt n) {
    n = n.abs();
    if (n == BigInt.zero) {
      throw const MathError(MathErrorCode.domainError, {'function': 'divisors', 'value': '0'});
    }
    if (n == BigInt.one) return [BigInt.one];
    final f = factorize(n);
    var count = 1;
    for (final (_, e) in f) {
      count *= e + 1;
    }
    if (count > maxDivisorCount) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'divisors', 'limit': '$maxDivisorCount divisors'});
    }
    var divs = [BigInt.one];
    for (final (p, e) in f) {
      final next = <BigInt>[];
      for (final d in divs) {
        var pk = BigInt.one;
        for (var k = 0; k <= e; k++) {
          next.add(d * pk);
          pk *= p;
        }
      }
      divs = next;
    }
    divs.sort();
    return divs;
  }

  static BigInt totient(BigInt n) {
    if (n < BigInt.one) {
      throw const MathError(MathErrorCode.domainError, {'function': 'totient', 'value': 'n < 1'});
    }
    if (n == BigInt.one) return BigInt.one;
    var r = n;
    for (final (p, _) in factorize(n)) {
      r = r ~/ p * (p - BigInt.one);
    }
    return r;
  }

  static BigInt nextPrime(BigInt n) {
    if (n < BigInt.two) return BigInt.two;
    var c = n + BigInt.one;
    if (c.isEven && c != BigInt.two) c += BigInt.one;
    final budget = Budget(timeLimit: const Duration(seconds: 5));
    while (!isPrime(c)) {
      c += BigInt.two;
      budget.tick();
    }
    return c;
  }

  static BigInt? prevPrime(BigInt n) {
    if (n <= BigInt.two) return null;
    if (n == BigInt.from(3)) return BigInt.two;
    var c = n - BigInt.one;
    if (c.isEven) c -= BigInt.one;
    final budget = Budget(timeLimit: const Duration(seconds: 5));
    while (c > BigInt.two && !isPrime(c)) {
      c -= BigInt.two;
      budget.tick();
    }
    return c < BigInt.two ? null : c;
  }

  static BigInt lcm(BigInt a, BigInt b) {
    if (a == BigInt.zero || b == BigInt.zero) return BigInt.zero;
    return (a ~/ a.gcd(b) * b).abs();
  }

  /// nCr for integers (exact).
  static BigInt combinations(BigInt n, BigInt r) {
    if (r.isNegative || n.isNegative || r > n) {
      if (r.isNegative || n.isNegative) {
        throw MathError(MathErrorCode.domainError, {'function': 'nCr', 'value': 'negative arguments'});
      }
      return BigInt.zero;
    }
    if (r > n - r) r = n - r;
    if (r > BigInt.from(100000)) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'nCr', 'limit': 'r ≤ 100000'});
    }
    var result = BigInt.one;
    final rr = r.toInt();
    for (var k = 1; k <= rr; k++) {
      result = result * (n - BigInt.from(rr - k)) ~/ BigInt.from(k);
    }
    return result;
  }

  static BigInt permutations(BigInt n, BigInt r) {
    if (r.isNegative || n.isNegative) {
      throw MathError(MathErrorCode.domainError, {'function': 'nPr', 'value': 'negative arguments'});
    }
    if (r > n) return BigInt.zero;
    if (r > BigInt.from(100000)) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'nPr', 'limit': 'r ≤ 100000'});
    }
    var result = BigInt.one;
    for (var k = n - r + BigInt.one; k <= n; k += BigInt.one) {
      result *= k;
    }
    return result;
  }
}
