import '../core/budget.dart';
import '../core/errors.dart';
import '../eval/values.dart';
import '../numbers/num.dart';

/// Maximum matrix dimension accepted anywhere in the engine.
const int maxMatrixDimension = 20;

/// Matrix and vector operations over [Num]. Exact for rational entries
/// (fraction-free Bareiss determinant, exact Gauss–Jordan), numerically
/// pivoted for approximate entries.
class MatrixOps {
  MatrixOps(this.a, [Budget? budget]) : budget = budget ?? Budget.unlimited();

  final Arith a;
  final Budget budget;

  static void checkSize(int r, int c) {
    if (r < 1 || c < 1) throw const MathError(MathErrorCode.emptyMatrix);
    if (r > maxMatrixDimension || c > maxMatrixDimension) {
      throw const MathError(MathErrorCode.tooLarge,
          {'function': 'matrices', 'limit': '$maxMatrixDimension×$maxMatrixDimension'});
    }
  }

  List<List<Num>> _copy(List<List<Num>> m) => [for (final r in m) List<Num>.of(r)];

  MatrixValue identity(int n) {
    checkSize(n, n);
    return MatrixValue([
      for (var r = 0; r < n; r++) [for (var c = 0; c < n; c++) r == c ? Rat.one : Rat.zero]
    ]);
  }

  MatrixValue zeros(int r, int c) {
    checkSize(r, c);
    return MatrixValue([for (var i = 0; i < r; i++) List<Num>.filled(c, Rat.zero)]);
  }

  MatrixValue add(MatrixValue x, MatrixValue y, {bool subtract = false}) {
    if (x.rowCount != y.rowCount || x.colCount != y.colCount) {
      throw MathError(MathErrorCode.dimensionMismatch, {
        'detail': 'cannot ${subtract ? 'subtract' : 'add'} a ${x.rowCount}×${x.colCount} and a ${y.rowCount}×${y.colCount} matrix'
      });
    }
    return MatrixValue([
      for (var r = 0; r < x.rowCount; r++)
        [
          for (var c = 0; c < x.colCount; c++)
            subtract ? a.sub(x.rows[r][c], y.rows[r][c]) : a.add(x.rows[r][c], y.rows[r][c])
        ]
    ]);
  }

  MatrixValue scale(MatrixValue x, Num k) =>
      MatrixValue([for (final row in x.rows) [for (final v in row) a.mul(v, k)]]);

  MatrixValue mul(MatrixValue x, MatrixValue y) {
    if (x.colCount != y.rowCount) {
      throw MathError(MathErrorCode.dimensionMismatch, {
        'detail': 'a ${x.rowCount}×${x.colCount} matrix can only multiply a matrix with ${x.colCount} rows (got ${y.rowCount}×${y.colCount})'
      });
    }
    final out = <List<Num>>[];
    for (var r = 0; r < x.rowCount; r++) {
      final row = <Num>[];
      for (var c = 0; c < y.colCount; c++) {
        Num s = Rat.zero;
        for (var k = 0; k < x.colCount; k++) {
          s = a.add(s, a.mul(x.rows[r][k], y.rows[k][c]));
        }
        budget.tick(x.colCount);
        row.add(s);
      }
      out.add(row);
    }
    return MatrixValue(out);
  }

  VectorValue mulVec(MatrixValue x, VectorValue v) {
    if (x.colCount != v.length) {
      throw MathError(MathErrorCode.dimensionMismatch, {
        'detail': 'a ${x.rowCount}×${x.colCount} matrix needs a vector of length ${x.colCount} (got ${v.length})'
      });
    }
    return VectorValue([
      for (var r = 0; r < x.rowCount; r++)
        [for (var k = 0; k < x.colCount; k++) a.mul(x.rows[r][k], v.items[k])].fold<Num>(Rat.zero, a.add)
    ]);
  }

  MatrixValue transpose(MatrixValue x) => MatrixValue([
        for (var c = 0; c < x.colCount; c++) [for (var r = 0; r < x.rowCount; r++) x.rows[r][c]]
      ]);

  Num trace(MatrixValue x) {
    _requireSquare(x, 'Trace');
    Num s = Rat.zero;
    for (var i = 0; i < x.rowCount; i++) {
      s = a.add(s, x.rows[i][i]);
    }
    return s;
  }

  void _requireSquare(MatrixValue x, String op) {
    if (!x.isSquare) throw MathError(MathErrorCode.notSquare, {'operation': op});
  }

  bool _allExact(List<List<Num>> m) => m.every((r) => r.every((v) => v is Rat));

  /// Magnitude used for relative zero tests on approximate matrices.
  double _scale(List<List<Num>> m) {
    var s = 0.0;
    for (final r in m) {
      for (final v in r) {
        final d = v is Cpx ? a.abs(v).toDouble() : v.toDouble().abs();
        if (d > s) s = d;
      }
    }
    return s == 0 ? 1 : s;
  }

  bool _negligible(Num v, double scale) {
    if (v is Rat) return v.isZero;
    if (v.isZero) return true;
    final mag = v is Cpx ? a.abs(v) : v;
    final d = mag.toDouble().abs();
    return d <= scale * _tolerance;
  }

  double get _tolerance => 1e-12 > _pow10neg(a.precision) ? _pow10neg(a.precision - 2) : 1e-12;
  static double _pow10neg(int p) => double.parse('1e-$p');

  int _pivotRow(List<List<Num>> m, int col, int from, bool exact) {
    if (exact) {
      for (var r = from; r < m.length; r++) {
        if (!m[r][col].isZero) return r;
      }
      return -1;
    }
    var best = -1;
    var bestMag = -1.0;
    for (var r = from; r < m.length; r++) {
      final v = m[r][col];
      final mag = (v is Cpx ? a.abs(v) : v).toDouble().abs();
      if (mag > bestMag) {
        bestMag = mag;
        best = r;
      }
    }
    return best;
  }

  Num det(MatrixValue x) {
    _requireSquare(x, 'The determinant');
    final n = x.rowCount;
    if (n == 1) return x.rows[0][0];
    if (n == 2) {
      return a.sub(a.mul(x.rows[0][0], x.rows[1][1]), a.mul(x.rows[0][1], x.rows[1][0]));
    }
    final m = _copy(x.rows);
    if (_allExact(m)) return _bareiss(m);
    final scale = _scale(m);
    Num d = Rat.one;
    for (var c = 0; c < n; c++) {
      final p = _pivotRow(m, c, c, false);
      if (p < 0 || _negligible(m[p][c], scale)) return Rat.zero;
      if (p != c) {
        final t = m[p];
        m[p] = m[c];
        m[c] = t;
        d = a.neg(d);
      }
      d = a.mul(d, m[c][c]);
      for (var r = c + 1; r < n; r++) {
        final f = a.div(m[r][c], m[c][c]);
        for (var k = c; k < n; k++) {
          m[r][k] = a.sub(m[r][k], a.mul(f, m[c][k]));
        }
        budget.tick(n);
      }
    }
    return d;
  }

  /// Fraction-free exact determinant (Bareiss algorithm).
  Num _bareiss(List<List<Num>> m) {
    final n = m.length;
    var sign = 1;
    Num prev = Rat.one;
    for (var k = 0; k < n - 1; k++) {
      if (m[k][k].isZero) {
        final p = _pivotRow(m, k, k + 1, true);
        if (p < 0) return Rat.zero;
        final t = m[p];
        m[p] = m[k];
        m[k] = t;
        sign = -sign;
      }
      for (var i = k + 1; i < n; i++) {
        for (var j = k + 1; j < n; j++) {
          m[i][j] = a.div(a.sub(a.mul(m[i][j], m[k][k]), a.mul(m[i][k], m[k][j])), prev);
        }
        budget.tick(n);
      }
      prev = m[k][k];
    }
    final d = m[n - 1][n - 1];
    return sign < 0 ? a.neg(d) : d;
  }

  /// Row echelon form; when [reduced] is true, reduced row echelon form.
  /// Returns the matrix and its rank.
  ({MatrixValue matrix, int rank, List<int> pivotCols}) echelon(MatrixValue x, {bool reduced = false}) {
    final m = _copy(x.rows);
    final exact = _allExact(m);
    final scale = _scale(m);
    final rows = m.length, cols = m.first.length;
    var r = 0;
    final pivots = <int>[];
    for (var c = 0; c < cols && r < rows; c++) {
      final p = _pivotRow(m, c, r, exact);
      if (p < 0 || _negligible(m[p][c], scale)) {
        if (!exact) {
          for (var rr = r; rr < rows; rr++) {
            m[rr][c] = Rat.zero;
          }
        }
        continue;
      }
      if (p != r) {
        final t = m[p];
        m[p] = m[r];
        m[r] = t;
      }
      final pv = m[r][c];
      if (reduced) {
        for (var k = c; k < cols; k++) {
          m[r][k] = a.div(m[r][k], pv);
        }
        m[r][c] = Rat.one;
      }
      final start = reduced ? 0 : r + 1;
      for (var i = start; i < rows; i++) {
        if (i == r || m[i][c].isZero) continue;
        final f = a.div(m[i][c], m[r][c]);
        for (var k = c; k < cols; k++) {
          m[i][k] = a.sub(m[i][k], a.mul(f, m[r][k]));
        }
        m[i][c] = Rat.zero;
        budget.tick(cols);
      }
      pivots.add(c);
      r++;
    }
    return (matrix: MatrixValue(m), rank: r, pivotCols: pivots);
  }

  int rank(MatrixValue x) => echelon(x).rank;

  MatrixValue inverse(MatrixValue x) {
    _requireSquare(x, 'The inverse');
    final n = x.rowCount;
    final aug = MatrixValue([
      for (var r = 0; r < n; r++)
        [...x.rows[r], for (var c = 0; c < n; c++) r == c ? Rat.one : Rat.zero]
    ]);
    final e = echelon(aug, reduced: true);
    if (e.pivotCols.length < n || e.pivotCols[n - 1] != n - 1) {
      throw const MathError(MathErrorCode.singularMatrix);
    }
    return MatrixValue([for (final row in e.matrix.rows) row.sublist(n)]);
  }

  MatrixValue power(MatrixValue x, BigInt n) {
    _requireSquare(x, 'Matrix powers');
    if (n.isNegative) return power(inverse(x), -n);
    if (n.bitLength > 16) {
      throw const MathError(MathErrorCode.tooLarge, {'function': 'matrix powers', 'limit': '65535'});
    }
    var result = identity(x.rowCount);
    var base = x;
    var e = n;
    while (e > BigInt.zero) {
      if (e.isOdd) result = mul(result, base);
      e = e >> 1;
      if (e > BigInt.zero) base = mul(base, base);
    }
    return result;
  }

  /// Coefficients (ascending) of det(λI − A), computed exactly with the
  /// Faddeev–LeVerrier recurrence.
  List<Num> characteristicPolynomial(MatrixValue x) {
    _requireSquare(x, 'Eigenvalues');
    final n = x.rowCount;
    final coeffs = List<Num>.filled(n + 1, Rat.zero);
    coeffs[n] = Rat.one;
    var mk = zeros(n, n); // M_0 = 0
    final id = identity(n);
    for (var k = 1; k <= n; k++) {
      // M_k = A·M_{k−1} + c_{n−k+1}·I
      mk = add(mul(x, mk), scale(id, coeffs[n - k + 1]));
      final am = mul(x, mk);
      coeffs[n - k] = a.div(a.neg(trace(am)), Rat.int(k));
      budget.check();
    }
    return coeffs;
  }

  /// Basis of the null space of [x] (as vectors).
  List<VectorValue> nullSpace(MatrixValue x) {
    final e = echelon(x, reduced: true);
    final cols = x.colCount;
    final free = [for (var c = 0; c < cols; c++) if (!e.pivotCols.contains(c)) c];
    final basis = <VectorValue>[];
    for (final f in free) {
      final v = List<Num>.filled(cols, Rat.zero);
      v[f] = Rat.one;
      for (var i = 0; i < e.pivotCols.length; i++) {
        v[e.pivotCols[i]] = a.neg(e.matrix.rows[i][f]);
      }
      basis.add(VectorValue(v));
    }
    return basis;
  }

  // ---------------------------------------------------------------- vectors

  void _sameLength(VectorValue x, VectorValue y, String op) {
    if (x.length != y.length) {
      throw MathError(MathErrorCode.dimensionMismatch,
          {'detail': '$op needs vectors of the same length (${x.length} and ${y.length})'});
    }
  }

  VectorValue vadd(VectorValue x, VectorValue y, {bool subtract = false}) {
    _sameLength(x, y, subtract ? 'Subtraction' : 'Addition');
    return VectorValue([
      for (var k = 0; k < x.length; k++) subtract ? a.sub(x.items[k], y.items[k]) : a.add(x.items[k], y.items[k])
    ]);
  }

  VectorValue vscale(VectorValue x, Num k) => VectorValue([for (final v in x.items) a.mul(v, k)]);

  Num dot(VectorValue x, VectorValue y) {
    _sameLength(x, y, 'The dot product');
    Num s = Rat.zero;
    for (var k = 0; k < x.length; k++) {
      s = a.add(s, a.mul(x.items[k], a.conj(y.items[k])));
    }
    return s;
  }

  VectorValue cross(VectorValue x, VectorValue y) {
    if (x.length != 3 || y.length != 3) {
      if (x.length == 2 && y.length == 2) {
        return cross(VectorValue([...x.items, Rat.zero]), VectorValue([...y.items, Rat.zero]));
      }
      throw const MathError(MathErrorCode.dimensionMismatch, {'detail': 'the cross product needs two 3D vectors'});
    }
    final u = x.items, v = y.items;
    return VectorValue([
      a.sub(a.mul(u[1], v[2]), a.mul(u[2], v[1])),
      a.sub(a.mul(u[2], v[0]), a.mul(u[0], v[2])),
      a.sub(a.mul(u[0], v[1]), a.mul(u[1], v[0])),
    ]);
  }

  Num norm(VectorValue x) {
    Num s = Rat.zero;
    for (final v in x.items) {
      final m = a.abs(v);
      s = a.add(s, a.mul(m, m));
    }
    return a.sqrt(s);
  }

  VectorValue unit(VectorValue x) {
    final n = norm(x);
    if (n.isZero) {
      throw const MathError(MathErrorCode.undefinedResult, {'detail': 'the zero vector has no direction'});
    }
    return VectorValue([for (final v in x.items) a.div(v, n)]);
  }

  /// Angle between vectors in radians.
  Num angle(VectorValue x, VectorValue y) {
    final nx = norm(x), ny = norm(y);
    if (nx.isZero || ny.isZero) {
      throw const MathError(MathErrorCode.undefinedResult, {'detail': 'the angle with a zero vector is not defined'});
    }
    var c = a.div(dot(x, y), a.mul(nx, ny));
    // Clamp rounding noise into [−1, 1].
    if (a.compare(c, Rat.one) > 0) c = Rat.one;
    if (a.compare(c, Rat.minusOne) < 0) c = Rat.minusOne;
    if (c is Rat) {
      if (c.isOne) return Rat.zero;
      if (c == Rat.minusOne) return a.pi();
      if (c.isZero) return a.div(a.pi(), Rat.two);
    }
    return a.acos(c);
  }

  VectorValue project(VectorValue x, VectorValue onto) {
    final d = dot(onto, onto);
    if (d.isZero) {
      throw const MathError(MathErrorCode.undefinedResult, {'detail': 'cannot project onto the zero vector'});
    }
    return vscale(onto, a.div(dot(x, onto), d));
  }

  Num distance(VectorValue x, VectorValue y) => norm(vadd(x, y, subtract: true));
}
