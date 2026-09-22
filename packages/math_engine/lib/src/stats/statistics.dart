import 'dart:math' as math;

import '../core/errors.dart';
import '../numbers/num.dart';

/// Maximum number of data points accepted by statistics routines.
const int maxDataPoints = 100000;

class OneVarStats {
  OneVarStats({
    required this.count,
    required this.sum,
    required this.sumSquares,
    required this.mean,
    required this.median,
    required this.modes,
    required this.min,
    required this.max,
    required this.range,
    required this.sampleVariance,
    required this.populationVariance,
    required this.sampleStdDev,
    required this.populationStdDev,
    required this.q1,
    required this.q3,
    required this.iqr,
  });

  final int count;
  final Num sum;
  final Num sumSquares;
  final Num mean;
  final Num median;

  /// All values sharing the highest frequency; empty when every value
  /// occurs equally often (no mode).
  final List<Num> modes;
  final Num min;
  final Num max;
  final Num range;

  /// Null when count < 2.
  final Num? sampleVariance;
  final Num populationVariance;
  final Num? sampleStdDev;
  final Num populationStdDev;
  final Num q1;
  final Num q3;
  final Num iqr;
}

enum RegressionType { linear, quadratic, exponential, logarithmic, power }

class RegressionResult {
  RegressionResult(this.type, this.coefficients, this.r2, this.r);
  final RegressionType type;

  /// linear: [a, b] for y = a + b·x
  /// quadratic: [a, b, c] for y = a + b·x + c·x²
  /// exponential: [a, b] for y = a·e^(b·x)
  /// logarithmic: [a, b] for y = a + b·ln x
  /// power: [a, b] for y = a·x^b
  final List<Num> coefficients;

  /// Coefficient of determination.
  final Num r2;

  /// Correlation coefficient of the (transformed) linear fit, when defined.
  final Num? r;

  String get equationTemplate => switch (type) {
        RegressionType.linear => 'y = a + b·x',
        RegressionType.quadratic => 'y = a + b·x + c·x²',
        RegressionType.exponential => 'y = a·e^(b·x)',
        RegressionType.logarithmic => 'y = a + b·ln(x)',
        RegressionType.power => 'y = a·x^b',
      };

  double predict(double x) {
    final c = coefficients.map((e) => e.toDouble()).toList();
    return switch (type) {
      RegressionType.linear => c[0] + c[1] * x,
      RegressionType.quadratic => c[0] + c[1] * x + c[2] * x * x,
      RegressionType.exponential => c[0] * math.exp(c[1] * x),
      RegressionType.logarithmic => c[0] + c[1] * math.log(x),
      RegressionType.power => c[0] * math.pow(x, c[1]).toDouble(),
    };
  }
}

class TwoVarStats {
  TwoVarStats({
    required this.count,
    required this.meanX,
    required this.meanY,
    required this.sumX,
    required this.sumY,
    required this.sumXY,
    required this.sumX2,
    required this.sumY2,
    required this.sampleCovariance,
    required this.populationCovariance,
    required this.correlation,
  });

  final int count;
  final Num meanX, meanY, sumX, sumY, sumXY, sumX2, sumY2;
  final Num? sampleCovariance;
  final Num populationCovariance;

  /// Pearson r; null if either variable has zero variance.
  final Num? correlation;
}

/// Descriptive statistics and regression. Sums, means, variances and
/// linear/quadratic fits are exact for rational data.
class Statistics {
  Statistics(this.a);
  final Arith a;

  void _check(List<Num> data) {
    if (data.isEmpty) {
      throw const MathError(MathErrorCode.invalidExpression, {'detail': 'the data set is empty'});
    }
    if (data.length > maxDataPoints) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'statistics', 'limit': '$maxDataPoints values'});
    }
    for (final v in data) {
      if (v is Cpx) {
        throw const MathError(MathErrorCode.typeMismatch, {'detail': 'Statistics require real numbers.'});
      }
    }
  }

  List<Num> _expand(List<Num> data, List<Num>? freq) {
    if (freq == null) return data;
    if (freq.length != data.length) {
      throw const MathError(MathErrorCode.dimensionMismatch, {'detail': 'each value needs one frequency'});
    }
    final out = <Num>[];
    for (var k = 0; k < data.length; k++) {
      final f = Arith.asInt(freq[k]);
      if (f == null || f < 0) {
        throw const MathError(MathErrorCode.nonIntegerArgument, {'function': 'Frequencies'});
      }
      for (var j = 0; j < f; j++) {
        out.add(data[k]);
      }
      if (out.length > maxDataPoints) {
        throw const MathError(MathErrorCode.tooLarge, {'function': 'statistics', 'limit': '$maxDataPoints values'});
      }
    }
    return out;
  }

  Num sum(List<Num> data) => data.fold<Num>(Rat.zero, a.add);

  Num mean(List<Num> data) {
    _check(data);
    return a.div(sum(data), Rat.int(data.length));
  }

  List<Num> sorted(List<Num> data) => [...data]..sort(a.compare);

  Num median(List<Num> data) {
    _check(data);
    return _medianSorted(sorted(data));
  }

  Num _medianSorted(List<Num> s) {
    final n = s.length;
    if (n.isOdd) return s[n ~/ 2];
    return a.div(a.add(s[n ~/ 2 - 1], s[n ~/ 2]), Rat.two);
  }

  List<Num> modes(List<Num> data) {
    _check(data);
    final counts = <Num, int>{};
    for (final v in data) {
      // Normalize approximate values so equal numbers group together.
      counts[v] = (counts[v] ?? 0) + 1;
    }
    final best = counts.values.reduce(math.max);
    if (best == 1 && counts.length > 1) return const [];
    if (counts.values.every((c) => c == best) && counts.length > 1) return const [];
    final out = [for (final e in counts.entries) if (e.value == best) e.key];
    out.sort(a.compare);
    return out;
  }

  Num variance(List<Num> data, {required bool sample}) {
    _check(data);
    final n = data.length;
    if (sample && n < 2) {
      throw const MathError(MathErrorCode.invalidExpression,
          {'detail': 'the sample variance needs at least two values'});
    }
    final m = mean(data);
    Num ss = Rat.zero;
    for (final v in data) {
      final d = a.sub(v, m);
      ss = a.add(ss, a.mul(d, d));
    }
    return a.div(ss, Rat.int(sample ? n - 1 : n));
  }

  Num stdDev(List<Num> data, {required bool sample}) => a.sqrt(variance(data, sample: sample));

  /// Quartiles using the median-of-halves method (the median itself is
  /// excluded from both halves when n is odd), as on most handheld
  /// scientific calculators.
  (Num, Num) quartiles(List<Num> data) {
    _check(data);
    final s = sorted(data);
    final n = s.length;
    if (n == 1) return (s[0], s[0]);
    final lower = s.sublist(0, n ~/ 2);
    final upper = s.sublist(n.isOdd ? n ~/ 2 + 1 : n ~/ 2);
    return (_medianSorted(lower), _medianSorted(upper));
  }

  /// Percentile with linear interpolation between closest ranks
  /// (Hyndman–Fan type 7; the default in most spreadsheets).
  Num percentile(List<Num> data, Num p) {
    _check(data);
    if (a.compare(p, Rat.zero) < 0 || a.compare(p, Rat.int(100)) > 0) {
      throw const MathError(MathErrorCode.domainError, {'function': 'percentile', 'value': 'p outside 0–100'});
    }
    final s = sorted(data);
    final n = s.length;
    final h = a.mul(a.div(p, Rat.int(100)), Rat.int(n - 1));
    final lo = Arith.asInt(a.floor(h))!;
    if (lo >= n - 1) return s[n - 1];
    final frac = a.sub(h, Rat.int(lo));
    return a.add(s[lo], a.mul(frac, a.sub(s[lo + 1], s[lo])));
  }

  OneVarStats oneVar(List<Num> values, {List<Num>? frequencies}) {
    final data = _expand(values, frequencies);
    _check(data);
    final s = sorted(data);
    final n = s.length;
    final sm = sum(s);
    final m = a.div(sm, Rat.int(n));
    Num ss = Rat.zero, sq = Rat.zero;
    for (final v in s) {
      final d = a.sub(v, m);
      ss = a.add(ss, a.mul(d, d));
      sq = a.add(sq, a.mul(v, v));
    }
    final pv = a.div(ss, Rat.int(n));
    final sv = n > 1 ? a.div(ss, Rat.int(n - 1)) : null;
    final (q1, q3) = quartiles(s);
    return OneVarStats(
      count: n,
      sum: sm,
      sumSquares: sq,
      mean: m,
      median: _medianSorted(s),
      modes: modes(s),
      min: s.first,
      max: s.last,
      range: a.sub(s.last, s.first),
      sampleVariance: sv,
      populationVariance: pv,
      sampleStdDev: sv == null ? null : a.sqrt(sv),
      populationStdDev: a.sqrt(pv),
      q1: q1,
      q3: q3,
      iqr: a.sub(q3, q1),
    );
  }

  void _checkPairs(List<Num> x, List<Num> y) {
    if (x.length != y.length) {
      throw const MathError(MathErrorCode.dimensionMismatch, {'detail': 'X and Y need the same number of values'});
    }
    _check(x);
    _check(y);
  }

  TwoVarStats twoVar(List<Num> x, List<Num> y) {
    _checkPairs(x, y);
    final n = x.length;
    final nn = Rat.int(n);
    final sx = sum(x), sy = sum(y);
    Num sxy = Rat.zero, sx2 = Rat.zero, sy2 = Rat.zero;
    for (var k = 0; k < n; k++) {
      sxy = a.add(sxy, a.mul(x[k], y[k]));
      sx2 = a.add(sx2, a.mul(x[k], x[k]));
      sy2 = a.add(sy2, a.mul(y[k], y[k]));
    }
    final mx = a.div(sx, nn), my = a.div(sy, nn);
    final sxxC = a.sub(sx2, a.mul(nn, a.mul(mx, mx)));
    final syyC = a.sub(sy2, a.mul(nn, a.mul(my, my)));
    final sxyC = a.sub(sxy, a.mul(nn, a.mul(mx, my)));
    Num? r;
    if (!sxxC.isZero && !syyC.isZero && a.signOf(sxxC) > 0 && a.signOf(syyC) > 0) {
      r = a.div(sxyC, a.sqrt(a.mul(sxxC, syyC)));
    }
    return TwoVarStats(
      count: n,
      meanX: mx,
      meanY: my,
      sumX: sx,
      sumY: sy,
      sumXY: sxy,
      sumX2: sx2,
      sumY2: sy2,
      sampleCovariance: n > 1 ? a.div(sxyC, Rat.int(n - 1)) : null,
      populationCovariance: a.div(sxyC, nn),
      correlation: r,
    );
  }

  /// Least-squares fit of y = c0 + c1·x.
  (Num, Num, Num?) _linearFit(List<Num> x, List<Num> y) {
    final t = twoVar(x, y);
    final nn = Rat.int(t.count);
    final sxx = a.sub(t.sumX2, a.mul(nn, a.mul(t.meanX, t.meanX)));
    if (sxx.isZero) {
      throw const MathError(MathErrorCode.undefinedResult, {'detail': 'all X values are equal, so no line can be fitted'});
    }
    final sxy = a.sub(t.sumXY, a.mul(nn, a.mul(t.meanX, t.meanY)));
    final b = a.div(sxy, sxx);
    final c0 = a.sub(t.meanY, a.mul(b, t.meanX));
    return (c0, b, t.correlation);
  }

  Num _r2(List<Num> x, List<Num> y, Num Function(Num) f) {
    final my = mean(y);
    Num ssRes = Rat.zero, ssTot = Rat.zero;
    for (var k = 0; k < x.length; k++) {
      final e = a.sub(y[k], f(x[k]));
      ssRes = a.add(ssRes, a.mul(e, e));
      final d = a.sub(y[k], my);
      ssTot = a.add(ssTot, a.mul(d, d));
    }
    if (ssTot.isZero) return Rat.one;
    return a.sub(Rat.one, a.div(ssRes, ssTot));
  }

  RegressionResult regression(RegressionType type, List<Num> x, List<Num> y) {
    _checkPairs(x, y);
    final minPoints = type == RegressionType.quadratic ? 3 : 2;
    if (x.length < minPoints) {
      throw MathError(MathErrorCode.invalidExpression,
          {'detail': 'this regression needs at least $minPoints data points'});
    }
    switch (type) {
      case RegressionType.linear:
        final (c0, c1, r) = _linearFit(x, y);
        return RegressionResult(type, [c0, c1], _r2(x, y, (v) => a.add(c0, a.mul(c1, v))), r);
      case RegressionType.quadratic:
        // Normal equations, solved exactly.
        final n = Rat.int(x.length);
        Num s1 = Rat.zero, s2 = Rat.zero, s3 = Rat.zero, s4 = Rat.zero;
        Num t0 = Rat.zero, t1 = Rat.zero, t2 = Rat.zero;
        for (var k = 0; k < x.length; k++) {
          final xv = x[k], x2 = a.mul(xv, xv);
          s1 = a.add(s1, xv);
          s2 = a.add(s2, x2);
          s3 = a.add(s3, a.mul(x2, xv));
          s4 = a.add(s4, a.mul(x2, x2));
          t0 = a.add(t0, y[k]);
          t1 = a.add(t1, a.mul(xv, y[k]));
          t2 = a.add(t2, a.mul(x2, y[k]));
        }
        final sol = _solve3([
          [n, s1, s2, t0],
          [s1, s2, s3, t1],
          [s2, s3, s4, t2],
        ]);
        Num f(Num v) => a.add(sol[0], a.add(a.mul(sol[1], v), a.mul(sol[2], a.mul(v, v))));
        return RegressionResult(type, sol, _r2(x, y, f), null);
      case RegressionType.exponential:
        for (final v in y) {
          if (a.signOf(v) <= 0) {
            throw const MathError(MathErrorCode.domainError,
                {'function': 'Exponential regression', 'value': 'Y ≤ 0'});
          }
        }
        final ly = [for (final v in y) a.ln(v)];
        final (c0, c1, r) = _linearFit(x, ly);
        final aa = a.exp(c0);
        return RegressionResult(type, [aa, c1], _r2(x, y, (v) => a.mul(aa, a.exp(a.mul(c1, v)))), r);
      case RegressionType.logarithmic:
        for (final v in x) {
          if (a.signOf(v) <= 0) {
            throw const MathError(MathErrorCode.domainError,
                {'function': 'Logarithmic regression', 'value': 'X ≤ 0'});
          }
        }
        final lx = [for (final v in x) a.ln(v)];
        final (c0, c1, r) = _linearFit(lx, y);
        return RegressionResult(type, [c0, c1], _r2(x, y, (v) => a.add(c0, a.mul(c1, a.ln(v)))), r);
      case RegressionType.power:
        for (var k = 0; k < x.length; k++) {
          if (a.signOf(x[k]) <= 0 || a.signOf(y[k]) <= 0) {
            throw const MathError(MathErrorCode.domainError,
                {'function': 'Power regression', 'value': 'X ≤ 0 or Y ≤ 0'});
          }
        }
        final lx = [for (final v in x) a.ln(v)];
        final ly = [for (final v in y) a.ln(v)];
        final (c0, c1, r) = _linearFit(lx, ly);
        final aa = a.exp(c0);
        return RegressionResult(type, [aa, c1], _r2(x, y, (v) => a.mul(aa, a.pow(v, c1))), r);
    }
  }

  List<Num> _solve3(List<List<Num>> m) {
    const n = 3;
    for (var c = 0; c < n; c++) {
      var p = c;
      while (p < n && m[p][c].isZero) {
        p++;
      }
      if (p == n) {
        throw const MathError(MathErrorCode.undefinedResult,
            {'detail': 'the X values do not determine a unique parabola'});
      }
      final t = m[p];
      m[p] = m[c];
      m[c] = t;
      for (var r = 0; r < n; r++) {
        if (r == c) continue;
        final f = a.div(m[r][c], m[c][c]);
        for (var k = c; k <= n; k++) {
          m[r][k] = a.sub(m[r][k], a.mul(f, m[c][k]));
        }
      }
    }
    return [for (var r = 0; r < n; r++) a.div(m[r][n], m[r][r])];
  }
}
