import '../core/errors.dart';
import '../numbers/num.dart';

/// Runtime value produced by evaluation.
sealed class Value {
  const Value();

  String get typeName;
}

final class NumberValue extends Value {
  const NumberValue(this.n);
  final Num n;

  @override
  String get typeName => n is Cpx ? 'complex number' : 'number';

  @override
  bool operator ==(Object other) => other is NumberValue && other.n == n;

  @override
  int get hashCode => n.hashCode;

  @override
  String toString() => 'NumberValue($n)';
}

final class MatrixValue extends Value {
  MatrixValue(this.rows) {
    if (rows.isEmpty || rows.first.isEmpty) throw const MathError(MathErrorCode.emptyMatrix);
  }

  final List<List<Num>> rows;

  int get rowCount => rows.length;
  int get colCount => rows.first.length;
  bool get isSquare => rowCount == colCount;

  Num at(int r, int c) => rows[r][c];

  @override
  String get typeName => 'matrix';

  @override
  bool operator ==(Object other) {
    if (other is! MatrixValue || other.rowCount != rowCount || other.colCount != colCount) return false;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        if (other.rows[r][c] != rows[r][c]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(rows.expand((r) => r));

  @override
  String toString() => 'Matrix$rows';
}

final class VectorValue extends Value {
  VectorValue(this.items) {
    if (items.isEmpty) throw const MathError(MathErrorCode.emptyMatrix);
  }

  final List<Num> items;
  int get length => items.length;

  @override
  String get typeName => 'vector';

  @override
  bool operator ==(Object other) {
    if (other is! VectorValue || other.length != length) return false;
    for (var k = 0; k < length; k++) {
      if (other.items[k] != items[k]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);

  @override
  String toString() => 'Vector$items';
}

/// A plain list of values (random lists, divisors, eigenvalues…).
final class ListValue extends Value {
  const ListValue(this.items);
  final List<Value> items;

  @override
  String get typeName => 'list';

  @override
  String toString() => 'List$items';
}

final class BoolValue extends Value {
  const BoolValue(this.value);
  final bool value;

  @override
  String get typeName => 'truth value';

  @override
  bool operator ==(Object other) => other is BoolValue && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Signed infinity (results of limits and divergent integrals/sums).
final class InfinityValue extends Value {
  const InfinityValue(this.sign);
  final int sign;

  @override
  String get typeName => 'infinity';

  @override
  bool operator ==(Object other) => other is InfinityValue && other.sign == sign;

  @override
  int get hashCode => sign.hashCode;
}

/// Prime factorization `sign × Π p^k`.
final class FactorizationValue extends Value {
  const FactorizationValue(this.sign, this.factors, this.number);
  final int sign;
  final List<(BigInt prime, int exponent)> factors;
  final BigInt number;

  @override
  String get typeName => 'factorization';
}

/// Solutions of an equation for one variable.
final class SolutionsValue extends Value {
  const SolutionsValue(this.variable, this.solutions, {this.numeric = false, this.note});
  final String variable;
  final List<Num> solutions;

  /// True when found numerically (approximate).
  final bool numeric;
  final String? note;

  @override
  String get typeName => 'solutions';
}

extension ValueCasts on Value {
  Num asNumber(String context) {
    final v = this;
    if (v is NumberValue) return v.n;
    if (v is BoolValue) return v.value ? Rat.one : Rat.zero;
    throw MathError(MathErrorCode.typeMismatch,
        {'detail': '$context expects a number, but got a $typeName.'});
  }
}
