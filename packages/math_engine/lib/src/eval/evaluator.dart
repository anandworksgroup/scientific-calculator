import 'dart:math' as math;

import '../ast/ast.dart';
import '../calculus/numeric_calculus.dart';
import '../constants/constants.dart';
import '../core/budget.dart';
import '../core/errors.dart';
import '../functions/catalog.dart';
import '../linalg/matrix_ops.dart';
import '../number_theory/number_theory.dart';
import '../numbers/num.dart';
import '../stats/probability.dart';
import '../stats/statistics.dart';
import 'values.dart';

enum AngleMode { deg, rad, grad }

class UserFunction {
  const UserFunction(this.params, this.body, {this.source = ''});
  final List<String> params;
  final Node body;
  final String source;
}

/// Everything evaluation depends on: arithmetic precision, angle unit,
/// variables, user functions, randomness and computation limits.
class EvalContext {
  EvalContext({
    required this.arith,
    this.angleMode = AngleMode.deg,
    Map<String, Value>? variables,
    Map<String, UserFunction>? functions,
    math.Random? random,
    Budget? budget,
  })  : variables = variables ?? {},
        functions = functions ?? {},
        random = random ?? math.Random(),
        budget = budget ?? Budget(timeLimit: const Duration(seconds: 20));

  Arith arith;
  final AngleMode angleMode;
  final Map<String, Value> variables;
  final Map<String, UserFunction> functions;
  final math.Random random;
  final Budget budget;

  EvalContext copyWith({Arith? arith, Map<String, Value>? variables}) => EvalContext(
        arith: arith ?? this.arith,
        angleMode: angleMode,
        variables: variables ?? this.variables,
        functions: functions,
        random: random,
        budget: budget,
      );
}

/// Tree-walking numeric evaluator.
class Evaluator {
  Evaluator(this.ctx);

  final EvalContext ctx;

  /// Set when evaluation used something inherently decimal (random numbers,
  /// percentages, approximations), so the result is shown as a decimal in
  /// "auto" format.
  bool preferDecimal = false;

  Arith get a => ctx.arith;
  MatrixOps get _m => MatrixOps(a, ctx.budget);

  Value eval(Node node) => ctx.budget.nest(() => _eval(node));

  Num evalNumber(Node node, String context) => eval(node).asNumber(context);

  Value _eval(Node node) {
    ctx.budget.tick();
    switch (node) {
      case NumberNode(:final value):
        return NumberValue(value);
      case ConstantNode(:final name):
        return NumberValue(_constant(name));
      case VariableNode(:final name):
        final v = ctx.variables[name];
        if (v == null) {
          if (name == 'Ans' || name == 'PreAns') {
            return NumberValue(Rat.zero);
          }
          throw MathError(MathErrorCode.undefinedVariable, {'name': name});
        }
        return v;
      case UnaryNode(:final op, :final operand):
        return _unary(op, operand);
      case BinaryNode():
        return _binary(node);
      case FunctionNode(:final name, :final args):
        return _call(name, args);
      case MatrixNode(:final rows):
        MatrixOps.checkSize(rows.length, rows.first.length);
        return MatrixValue([
          for (final r in rows) [for (final c in r) evalNumber(c, 'A matrix entry')]
        ]);
      case VectorNode(:final items):
        if (items.length > maxMatrixDimension) {
          throw const MathError(MathErrorCode.tooLarge, {'function': 'vectors', 'limit': '$maxMatrixDimension components'});
        }
        return VectorValue([for (final c in items) evalNumber(c, 'A vector component')]);
      case EquationNode(:final left, :final right, :final op):
        final l = eval(left), r = eval(right);
        return BoolValue(_compare(l, r, op));
      case AssignmentNode(:final name, :final value):
        final v = eval(value);
        ctx.variables[name] = v;
        return v;
      case FunctionDefNode(:final name, :final params, :final body):
        ctx.functions[name] = UserFunction(params, body);
        return const BoolValue(true);
    }
  }

  bool _compare(Value l, Value r, RelOp op) {
    if (op == RelOp.eq || op == RelOp.ne) {
      bool eq;
      if (l is NumberValue && r is NumberValue) {
        eq = _numEquals(l.n, r.n);
      } else {
        eq = l == r;
      }
      return op == RelOp.eq ? eq : !eq;
    }
    final c = a.compare(l.asNumber('A comparison'), r.asNumber('A comparison'));
    return switch (op) {
      RelOp.lt => c < 0,
      RelOp.gt => c > 0,
      RelOp.le => c <= 0,
      RelOp.ge => c >= 0,
      _ => false,
    };
  }

  bool _numEquals(Num x, Num y) {
    final d = a.sub(x, y);
    if (d.isZero) return true;
    if (d is Rat) return false;
    // Approximate values: equal within working precision.
    final mag = math.max(a.abs(x).toDouble().abs(), a.abs(y).toDouble().abs());
    return a.abs(d).toDouble().abs() <= mag * math.pow(10, -(a.precision + 2));
  }

  Num _constant(String name) {
    switch (name) {
      case 'pi':
        return a.pi();
      case 'e':
        return a.e();
      case 'phi':
        return a.div(a.add(Rat.one, a.sqrt(Rat.int(5))), Rat.two);
      case 'i':
        if (!a.allowComplex) ctx.arith = a.withComplex(true);
        return Cpx.i;
      case 'inf':
        throw const MathError(MathErrorCode.notSupported,
            {'detail': '∞ can only be used as a limit, integral bound or summation bound.'});
    }
    if (name.startsWith('@')) {
      final c = constantIndex[name.substring(1)];
      if (c == null) throw MathError(MathErrorCode.unknownIdentifier, {'name': name});
      return c.numericValue(a);
    }
    throw MathError(MathErrorCode.unknownIdentifier, {'name': name});
  }

  // ---------------------------------------------------------------- angles

  /// Converts an angle in the current unit to radians.
  Num toRadians(Num x) => switch (ctx.angleMode) {
        AngleMode.rad => x,
        AngleMode.deg => a.div(a.mul(x, a.pi()), Rat.int(180)),
        AngleMode.grad => a.div(a.mul(x, a.pi()), Rat.int(200)),
      };

  /// Converts radians to the current angle unit.
  Num fromRadians(Num r) => switch (ctx.angleMode) {
        AngleMode.rad => r,
        AngleMode.deg => a.div(a.mul(r, Rat.int(180)), a.pi()),
        AngleMode.grad => a.div(a.mul(r, Rat.int(200)), a.pi()),
      };

  /// Angle in exact degrees when the input is a rational number of degrees
  /// or gradians (enables exact trig values such as sin 30° = 1/2).
  Rat? _exactDegrees(Num x) {
    if (x is! Rat) return null;
    switch (ctx.angleMode) {
      case AngleMode.deg:
        return _mod(x, Rat.int(360));
      case AngleMode.grad:
        return _mod(x * Rat.frac(9, 10), Rat.int(360));
      case AngleMode.rad:
        return x.isZero ? Rat.zero : null;
    }
  }

  Rat _mod(Rat x, Rat m) => x - m * Rat(( x / m).floor());

  static final _sinTable = <int, Rat>{
    0: Rat.zero, 30: Rat.half, 90: Rat.one, 150: Rat.half, 180: Rat.zero,
    210: -Rat.half, 270: Rat.minusOne, 330: -Rat.half,
  };

  /// sin and cos of an exact angle in degrees, reduced exactly to
  /// [−45°, 45°] before converting to radians. This keeps full relative
  /// accuracy near zeros (sin 180.0000000001°) and for huge angles.
  ({Num sin, Num cos}) _degTrig(Rat d) {
    final q = (d / Rat.int(90)).round();
    final r = d - Rat.int(90) * Rat(q);
    final rad = r.isZero ? Rat.zero : a.div(a.mul(r, a.pi()), Rat.int(180));
    final s = a.sin(rad), c = a.cos(rad);
    return switch ((q % BigInt.from(4)).toInt()) {
      0 => (sin: s, cos: c),
      1 => (sin: c, cos: a.neg(s)),
      2 => (sin: a.neg(s), cos: a.neg(c)),
      _ => (sin: a.neg(c), cos: s),
    };
  }

  Num _sin(Num x) {
    final d = _exactDegrees(x);
    if (d != null) {
      if (d.isInteger) {
        final v = _sinTable[d.n.toInt()];
        if (v != null) return v;
      }
      if (ctx.angleMode != AngleMode.rad) return _degTrig(d).sin;
    }
    return a.sin(x is Cpx ? x : toRadians(x));
  }

  Num _cos(Num x) {
    final d = _exactDegrees(x);
    if (d != null) {
      final shifted = _mod(d + Rat.int(90), Rat.int(360));
      if (shifted.isInteger) {
        final v = _sinTable[shifted.n.toInt()];
        if (v != null) return v;
      }
      if (ctx.angleMode != AngleMode.rad) return _degTrig(d).cos;
    }
    return a.cos(x is Cpx ? x : toRadians(x));
  }

  Num _tan(Num x) {
    final d = _exactDegrees(x);
    if (d != null && d.isInteger) {
      switch (d.n.toInt() % 180) {
        case 0:
          return Rat.zero;
        case 45:
          return Rat.one;
        case 135:
          return Rat.minusOne;
        case 90:
          throw const MathError(MathErrorCode.undefinedResult,
              {'detail': 'tan is undefined at odd multiples of 90°'});
      }
    }
    if (d != null && ctx.angleMode != AngleMode.rad) {
      final sc = _degTrig(d);
      if (sc.cos.isZero) {
        throw const MathError(MathErrorCode.undefinedResult, {'detail': 'tan is undefined at odd multiples of 90°'});
      }
      return a.div(sc.sin, sc.cos);
    }
    return a.tan(x is Cpx ? x : toRadians(x));
  }

  Num? _exactInverse(String fn, Num x) {
    if (x is! Rat || ctx.angleMode == AngleMode.rad) {
      if (x is Rat && x.isZero && (fn == 'asin' || fn == 'atan')) return Rat.zero;
      if (x is Rat && x.isOne && fn == 'acos') return Rat.zero;
      return null;
    }
    Rat? deg;
    if (fn == 'asin') {
      deg = {Rat.zero: Rat.zero, Rat.half: Rat.int(30), Rat.one: Rat.int(90), -Rat.half: Rat.int(-30), Rat.minusOne: Rat.int(-90)}[x];
    } else if (fn == 'acos') {
      deg = {Rat.one: Rat.zero, Rat.half: Rat.int(60), Rat.zero: Rat.int(90), -Rat.half: Rat.int(120), Rat.minusOne: Rat.int(180)}[x];
    } else if (fn == 'atan') {
      deg = {Rat.zero: Rat.zero, Rat.one: Rat.int(45), Rat.minusOne: Rat.int(-45)}[x];
    }
    if (deg == null) return null;
    return ctx.angleMode == AngleMode.deg ? deg : deg * Rat.frac(10, 9);
  }

  // ----------------------------------------------------------------- unary

  Value _unary(UnaryOp op, Node operand) {
    final v = eval(operand);
    switch (op) {
      case UnaryOp.negate:
        return _mapNum(v, a.neg, 'Negation');
      case UnaryOp.plus:
        return v;
      case UnaryOp.factorial:
        return _mapNum(v, (n) {
          if (n is! Cpx && !Arith.isIntegerValue(n) && a.signOf(n) < 0) {
            // Γ has poles only at non-positive integers; negative
            // non-integers are fine.
          }
          return a.factorial(n);
        }, 'Factorial');
      case UnaryOp.percent:
        preferDecimal = true;
        return _mapNum(v, (n) => a.div(n, Rat.int(100)), 'Percent');
      case UnaryOp.degrees:
        return _mapNum(v, (n) => switch (ctx.angleMode) {
              AngleMode.deg => n,
              AngleMode.rad => a.div(a.mul(n, a.pi()), Rat.int(180)),
              AngleMode.grad => a.mul(n, Rat.frac(10, 9)),
            }, 'Degrees');
      case UnaryOp.radians:
        return _mapNum(v, fromRadians, 'Radians');
      case UnaryOp.gradians:
        return _mapNum(v, (n) => switch (ctx.angleMode) {
              AngleMode.grad => n,
              AngleMode.deg => a.mul(n, Rat.frac(9, 10)),
              AngleMode.rad => a.div(a.mul(n, a.pi()), Rat.int(200)),
            }, 'Gradians');
    }
  }

  Value _mapNum(Value v, Num Function(Num) f, String what) {
    switch (v) {
      case NumberValue(:final n):
        return NumberValue(f(n));
      case MatrixValue(:final rows) when what == 'Negation':
        return MatrixValue([for (final r in rows) [for (final c in r) f(c)]]);
      case VectorValue(:final items):
        return VectorValue([for (final c in items) f(c)]);
      case ListValue(:final items):
        return ListValue([for (final c in items) _mapNum(c, f, what)]);
      case BoolValue(:final value):
        return NumberValue(f(value ? Rat.one : Rat.zero));
      default:
        throw MathError(MathErrorCode.typeMismatch, {'detail': '$what cannot be applied to a ${v.typeName}.'});
    }
  }

  // ---------------------------------------------------------------- binary

  Value _binary(BinaryNode node) {
    final op = node.op;
    // a ± b%  means a ± (a·b/100)
    if ((op == BinaryOp.add || op == BinaryOp.sub) &&
        node.right is UnaryNode &&
        (node.right as UnaryNode).op == UnaryOp.percent) {
      final base = eval(node.left);
      final pct = eval((node.right as UnaryNode).operand);
      preferDecimal = true;
      if (base is NumberValue && pct is NumberValue) {
        final delta = a.div(a.mul(base.n, pct.n), Rat.int(100));
        return NumberValue(op == BinaryOp.add ? a.add(base.n, delta) : a.sub(base.n, delta));
      }
    }
    final l = eval(node.left);
    final r = eval(node.right);
    switch (op) {
      case BinaryOp.add:
        return _add(l, r, false);
      case BinaryOp.sub:
        return _add(l, r, true);
      case BinaryOp.mul:
        return _mul(l, r, node.mulStyle);
      case BinaryOp.div:
        return _div(l, r);
      case BinaryOp.pow:
        return _pow(l, r);
      case BinaryOp.nCr:
      case BinaryOp.nPr:
        final n = _int(l.asNumber('nCr'), op == BinaryOp.nCr ? 'nCr' : 'nPr');
        final k = _int(r.asNumber('nCr'), op == BinaryOp.nCr ? 'nCr' : 'nPr');
        return NumberValue(Rat(op == BinaryOp.nCr
            ? NumberTheory.combinations(n, k)
            : NumberTheory.permutations(n, k)));
      case BinaryOp.polar:
        final m = l.asNumber('Polar form');
        final t = toRadians(r.asNumber('Polar form'));
        ctx.arith = a.withComplex(true);
        return NumberValue(a.mul(m, Cpx.of(a.cos(t), a.sin(t))));
    }
  }

  Value _add(Value l, Value r, bool subtract) {
    if (l is BoolValue) l = NumberValue(l.value ? Rat.one : Rat.zero);
    if (r is BoolValue) r = NumberValue(r.value ? Rat.one : Rat.zero);
    if (l is NumberValue && r is NumberValue) {
      return NumberValue(subtract ? a.sub(l.n, r.n) : a.add(l.n, r.n));
    }
    if (l is MatrixValue && r is MatrixValue) return _m.add(l, r, subtract: subtract);
    if (l is VectorValue && r is VectorValue) return _m.vadd(l, r, subtract: subtract);
    if (l is ListValue || r is ListValue) {
      return _zipList(l, r, (x, y) => _add(x, y, subtract));
    }
    throw MathError(MathErrorCode.typeMismatch,
        {'detail': 'Cannot ${subtract ? 'subtract' : 'add'} a ${r.typeName} ${subtract ? 'from' : 'and'} a ${l.typeName}.'});
  }

  Value _zipList(Value l, Value r, Value Function(Value, Value) f) {
    if (l is ListValue && r is ListValue) {
      if (l.items.length != r.items.length) {
        throw const MathError(MathErrorCode.dimensionMismatch, {'detail': 'lists must have the same length'});
      }
      return ListValue([for (var k = 0; k < l.items.length; k++) f(l.items[k], r.items[k])]);
    }
    if (l is ListValue) return ListValue([for (final x in l.items) f(x, r)]);
    final rl = r as ListValue;
    return ListValue([for (final y in rl.items) f(l, y)]);
  }

  Value _mul(Value l, Value r, MulStyle style) {
    if (l is BoolValue) l = NumberValue(l.value ? Rat.one : Rat.zero);
    if (r is BoolValue) r = NumberValue(r.value ? Rat.one : Rat.zero);
    switch ((l, r)) {
      case (NumberValue x, NumberValue y):
        return NumberValue(a.mul(x.n, y.n));
      case (NumberValue x, MatrixValue y):
        return _m.scale(y, x.n);
      case (MatrixValue x, NumberValue y):
        return _m.scale(x, y.n);
      case (MatrixValue x, MatrixValue y):
        return _m.mul(x, y);
      case (MatrixValue x, VectorValue y):
        return _m.mulVec(x, y);
      case (VectorValue x, MatrixValue y):
        // Row vector times matrix.
        final row = MatrixValue([x.items]);
        return VectorValue(_m.mul(row, y).rows.first);
      case (NumberValue x, VectorValue y):
        return _m.vscale(y, x.n);
      case (VectorValue x, NumberValue y):
        return _m.vscale(x, y.n);
      case (VectorValue x, VectorValue y):
        if (style == MulStyle.dot) return NumberValue(_m.dot(x, y));
        if (style == MulStyle.times) return _m.cross(x, y);
        throw const MathError(MathErrorCode.typeMismatch,
            {'detail': 'Use · (dot product) or × (cross product) between two vectors.'});
      default:
        if (l is ListValue || r is ListValue) return _zipList(l, r, (x, y) => _mul(x, y, style));
        throw MathError(MathErrorCode.typeMismatch,
            {'detail': 'Cannot multiply a ${l.typeName} by a ${r.typeName}.'});
    }
  }

  Value _div(Value l, Value r) {
    if (l is BoolValue) l = NumberValue(l.value ? Rat.one : Rat.zero);
    switch ((l, r)) {
      case (NumberValue x, NumberValue y):
        return NumberValue(a.div(x.n, y.n));
      case (MatrixValue x, NumberValue y):
        return _m.scale(x, a.div(Rat.one, y.n));
      case (VectorValue x, NumberValue y):
        return _m.vscale(x, a.div(Rat.one, y.n));
      case (MatrixValue x, MatrixValue y):
        return _m.mul(x, _m.inverse(y));
      case (NumberValue x, MatrixValue y):
        return _m.scale(_m.inverse(y), x.n);
      default:
        if (l is ListValue || r is ListValue) return _zipList(l, r, _div);
        throw MathError(MathErrorCode.typeMismatch,
            {'detail': 'Cannot divide a ${l.typeName} by a ${r.typeName}.'});
    }
  }

  Value _pow(Value l, Value r) {
    if (l is BoolValue) l = NumberValue(l.value ? Rat.one : Rat.zero);
    if (l is NumberValue && r is NumberValue) return NumberValue(a.pow(l.n, r.n));
    if (l is MatrixValue && r is NumberValue) {
      final k = Arith.asBigInt(r.n);
      if (k == null) {
        throw const MathError(MathErrorCode.nonIntegerArgument, {'function': 'Matrix powers'});
      }
      return _m.power(l, k);
    }
    if (l is VectorValue && r is NumberValue && r.n == Rat.two) {
      return NumberValue(_m.dot(l, l));
    }
    if (l is ListValue && r is NumberValue) return _zipList(l, r, _pow);
    throw MathError(MathErrorCode.typeMismatch,
        {'detail': 'Cannot raise a ${l.typeName} to a power of type ${r.typeName}.'});
  }

  BigInt _int(Num x, String fn) {
    final b = Arith.asBigInt(x);
    if (b == null) {
      throw MathError(MathErrorCode.nonIntegerArgument, {'function': fn});
    }
    return b;
  }

  // ------------------------------------------------------------- functions

  List<Num> _dataArgs(List<Value> vals, String fn) {
    if (vals.length == 1) {
      final v = vals.first;
      if (v is ListValue) return [for (final i in v.items) i.asNumber(fn)];
      if (v is VectorValue) return v.items;
      if (v is MatrixValue) return [for (final r in v.rows) ...r];
    }
    return [for (final v in vals) v.asNumber(fn)];
  }

  Value _call(String name, List<Node> argNodes) {
    final user = ctx.functions[name];
    if (user != null && !functionIndex.containsKey(name)) {
      return _callUser(name, user, argNodes);
    }
    final spec = functionIndex[name];
    if (spec == null) throw MathError(MathErrorCode.unknownIdentifier, {'name': name});
    if (spec.lazy) return _callLazy(name, argNodes);
    final args = [for (final n in argNodes) eval(n)];
    return _callBuiltin(name, args);
  }

  Value _callUser(String name, UserFunction f, List<Node> argNodes) {
    if (argNodes.length != f.params.length) {
      throw MathError(MathErrorCode.wrongArgumentCount,
          {'name': name, 'expected': '${f.params.length}', 'got': argNodes.length});
    }
    final vals = [for (final n in argNodes) eval(n)];
    final scoped = Map<String, Value>.of(ctx.variables);
    for (var k = 0; k < f.params.length; k++) {
      scoped[f.params[k]] = vals[k];
    }
    final inner = Evaluator(ctx.copyWith(variables: scoped));
    final v = inner.eval(f.body);
    ctx.arith = inner.ctx.arith;
    preferDecimal |= inner.preferDecimal;
    return v;
  }

  Value _callLazy(String name, List<Node> args) {
    final varNode = args[1];
    if (varNode is! VariableNode) {
      throw MathError(MathErrorCode.invalidExpression,
          {'detail': 'the second argument of $name() must be a variable name'});
    }
    final v = varNode.name;
    final calc = NumericCalculus(this);
    switch (name) {
      case 'deriv':
        final at = evalNumber(args[2], 'deriv');
        final order = args.length > 3 ? Arith.asInt(evalNumber(args[3], 'deriv')) : 1;
        if (order == null || order < 1 || order > 10) {
          throw const MathError(MathErrorCode.domainError, {'function': 'deriv', 'value': 'orders outside 1–10'});
        }
        return NumberValue(calc.derivative(args[0], v, at, order));
      case 'integral':
        final lo = calc.boundValue(args[2]);
        final hi = calc.boundValue(args[3]);
        return NumberValue(calc.integrate(args[0], v, lo, hi).value);
      case 'sum':
      case 'prod':
        final lo = evalNumber(args[2], name);
        final hi = evalNumber(args[3], name);
        return NumberValue(calc.sumOrProduct(args[0], v, lo, hi, product: name == 'prod'));
      case 'lim':
      case 'limleft':
      case 'limright':
        final to = calc.boundValue(args[2]);
        final side = name == 'lim' ? 0 : (name == 'limleft' ? -1 : 1);
        return calc.limit(args[0], v, to, side, pointNode: args[2]);
    }
    throw MathError(MathErrorCode.unknownIdentifier, {'name': name});
  }

  Value _mapUnary(Value v, Num Function(Num) f, String fn) {
    switch (v) {
      case NumberValue(:final n):
        return NumberValue(f(n));
      case VectorValue(:final items):
        return VectorValue([for (final c in items) f(c)]);
      case ListValue(:final items):
        return ListValue([for (final c in items) _mapUnary(c, f, fn)]);
      case BoolValue(:final value):
        return NumberValue(f(value ? Rat.one : Rat.zero));
      default:
        throw MathError(MathErrorCode.typeMismatch, {'detail': '$fn() cannot be applied to a ${v.typeName}.'});
    }
  }

  Num _n(List<Value> args, int k, String fn) => args[k].asNumber('$fn()');

  MatrixValue _mat(Value v, String fn) {
    if (v is MatrixValue) return v;
    if (v is NumberValue) return MatrixValue([[v.n]]);
    throw MathError(MathErrorCode.typeMismatch, {'detail': '$fn() expects a matrix, but got a ${v.typeName}.'});
  }

  VectorValue _vec(Value v, String fn) {
    if (v is VectorValue) return v;
    if (v is MatrixValue && (v.rowCount == 1 || v.colCount == 1)) {
      return VectorValue([for (final r in v.rows) ...r]);
    }
    throw MathError(MathErrorCode.typeMismatch, {'detail': '$fn() expects a vector, but got a ${v.typeName}.'});
  }

  Value _callBuiltin(String name, List<Value> args) {
    Value unary(Num Function(Num) f) => _mapUnary(args[0], f, name);
    Num n0() => _n(args, 0, name);
    Num n1() => _n(args, 1, name);

    switch (name) {
      // Powers and roots
      case 'sqrt':
        return unary(a.sqrt);
      case 'cbrt':
        return unary(a.cbrt);
      case 'nroot':
        return NumberValue(a.nthRoot(n1(), n0()));
      case 'exp':
        return unary(a.exp);
      case 'pow':
        return _pow(args[0], args[1]);
      // Logarithms
      case 'ln':
        return unary(a.ln);
      case 'log':
        if (args.length == 2) return NumberValue(a.logBase(n0(), n1()));
        return unary(a.log10);
      case 'log2':
        return unary((x) => a.logBase(Rat.two, x));
      // Trigonometry
      case 'sin':
        return unary(_sin);
      case 'cos':
        return unary(_cos);
      case 'tan':
        return unary(_tan);
      case 'sec':
        return unary((x) => _reciprocal(_cos(x), 'sec'));
      case 'csc':
        return unary((x) => _reciprocal(_sin(x), 'csc'));
      case 'cot':
        return unary((x) {
          final t = _tanOrInf(x);
          return t == null ? Rat.zero : _reciprocal(t, 'cot');
        });
      case 'asin':
        return unary((x) => _exactInverse('asin', x) ?? _inverseTrig(a.asin(x), x));
      case 'acos':
        return unary((x) => _exactInverse('acos', x) ?? _inverseTrig(a.acos(x), x));
      case 'atan':
        return unary((x) => _exactInverse('atan', x) ?? _inverseTrig(a.atan(x), x));
      case 'atan2':
        return NumberValue(fromRadians(a.atan2(n0(), n1())));
      // Hyperbolic
      case 'sinh':
        return unary(a.sinh);
      case 'cosh':
        return unary(a.cosh);
      case 'tanh':
        return unary(a.tanh);
      case 'asinh':
        return unary(a.asinh);
      case 'acosh':
        return unary(a.acosh);
      case 'atanh':
        return unary(a.atanh);
      // Rounding
      case 'abs':
        final v = args[0];
        if (v is VectorValue) return NumberValue(_m.norm(v));
        if (v is MatrixValue) return NumberValue(_m.det(v));
        return unary(a.abs);
      case 'floor':
        return unary(a.floor);
      case 'ceil':
        return unary(a.ceil);
      case 'round':
        if (args.length == 2) {
          final d = Arith.asInt(n1());
          if (d == null || d.abs() > 1000) {
            throw const MathError(MathErrorCode.nonIntegerArgument, {'function': 'round (digits)'});
          }
          return unary((x) => a.round(x, d));
        }
        return unary(a.round);
      case 'trunc':
        return unary(a.trunc);
      case 'fpart':
        return unary(a.fracPart);
      case 'sign':
        return unary(a.sign);
      case 'factorial':
        return unary(a.factorial);
      case 'gamma':
        return unary(a.gamma);
      // Number theory
      case 'nCr':
        return NumberValue(Rat(NumberTheory.combinations(_int(n0(), 'nCr'), _int(n1(), 'nCr'))));
      case 'nPr':
        return NumberValue(Rat(NumberTheory.permutations(_int(n0(), 'nPr'), _int(n1(), 'nPr'))));
      case 'gcd':
      case 'lcm':
        final nums = _dataArgs(args, name).map((x) => _int(x, name)).toList();
        var acc = nums.first.abs();
        for (final v in nums.skip(1)) {
          acc = name == 'gcd' ? acc.gcd(v) : NumberTheory.lcm(acc, v);
        }
        return NumberValue(Rat(acc));
      case 'mod':
        final d = n1();
        if (d.isZero) throw const MathError(MathErrorCode.divisionByZero);
        return NumberValue(a.sub(n0(), a.mul(d, a.floor(a.div(n0(), d)))));
      case 'rem':
        final d = n1();
        if (d.isZero) throw const MathError(MathErrorCode.divisionByZero);
        return NumberValue(a.sub(n0(), a.mul(d, a.trunc(a.div(n0(), d)))));
      case 'quot':
        final d = n1();
        if (d.isZero) throw const MathError(MathErrorCode.divisionByZero);
        return NumberValue(a.trunc(a.div(n0(), d)));
      case 'isprime':
        return BoolValue(NumberTheory.isPrime(_int(n0(), 'isprime')));
      case 'factor':
        final n = _int(n0(), 'factor');
        if (n.abs() < BigInt.two) {
          return FactorizationValue(n.sign, const [], n);
        }
        return FactorizationValue(n.sign, NumberTheory.factorize(n, ctx.budget), n);
      case 'divisors':
        return ListValue([for (final d in NumberTheory.divisors(_int(n0(), 'divisors'))) NumberValue(Rat(d))]);
      case 'nextprime':
        return NumberValue(Rat(NumberTheory.nextPrime(_int(a.floor(n0()), 'nextprime'))));
      case 'prevprime':
        final p = NumberTheory.prevPrime(_int(a.ceil(n0()), 'prevprime'));
        if (p == null) {
          throw const MathError(MathErrorCode.domainError, {'function': 'prevprime', 'value': 'n ≤ 2'});
        }
        return NumberValue(Rat(p));
      case 'totient':
        return NumberValue(Rat(NumberTheory.totient(_int(n0(), 'totient'))));
      // Random
      case 'rand':
        preferDecimal = true;
        return NumberValue(_randomUnit());
      case 'randint':
        final lo = _int(a.ceil(n0()), 'randint'), hi = _int(a.floor(n1()), 'randint');
        return NumberValue(Rat(_randomInt(lo, hi)));
      case 'randreal':
        preferDecimal = true;
        return NumberValue(a.add(n0(), a.mul(_randomUnit(), a.sub(n1(), n0()))));
      case 'randlist':
        final count = Arith.asInt(n0());
        if (count == null || count < 1 || count > 10000) {
          throw const MathError(MathErrorCode.domainError, {'function': 'randlist', 'value': 'counts outside 1–10000'});
        }
        final lo = _int(a.ceil(n1()), 'randlist'), hi = _int(a.floor(_n(args, 2, name)), 'randlist');
        return ListValue([for (var k = 0; k < count; k++) NumberValue(Rat(_randomInt(lo, hi)))]);
      case 'randperm':
        final count = Arith.asInt(n0());
        if (count == null || count < 1 || count > 10000) {
          throw const MathError(MathErrorCode.domainError, {'function': 'randperm', 'value': 'n outside 1–10000'});
        }
        final list = [for (var k = 1; k <= count; k++) k]..shuffle(ctx.random);
        return ListValue([for (final k in list) NumberValue(Rat.int(k))]);
      // Complex
      case 're':
        return unary(Arith.reOf);
      case 'im':
        return unary(Arith.imOf);
      case 'conj':
        return unary(a.conj);
      case 'arg':
        return unary((x) => fromRadians(a.arg(x)));
      case 'cis':
        ctx.arith = a.withComplex(true);
        return unary((t) {
          final r = x2rad(t);
          return Cpx.of(a.cos(r), a.sin(r));
        });
      // Matrix
      case 'det':
        return NumberValue(_m.det(_mat(args[0], name)));
      case 'inv':
        final v = args[0];
        if (v is NumberValue) return NumberValue(a.div(Rat.one, v.n));
        return _m.inverse(_mat(v, name));
      case 'trn':
        final v = args[0];
        if (v is VectorValue) return MatrixValue([for (final c in v.items) [c]]);
        return _m.transpose(_mat(v, name));
      case 'rank':
        return NumberValue(Rat.int(_m.rank(_mat(args[0], name))));
      case 'trace':
        return NumberValue(_m.trace(_mat(args[0], name)));
      case 'identity':
        final k = Arith.asInt(n0());
        if (k == null) throw const MathError(MathErrorCode.nonIntegerArgument, {'function': 'identity'});
        return _m.identity(k);
      case 'zeros':
        final r = Arith.asInt(n0());
        final c = args.length > 1 ? Arith.asInt(n1()) : r;
        if (r == null || c == null) throw const MathError(MathErrorCode.nonIntegerArgument, {'function': 'zeros'});
        return _m.zeros(r, c);
      case 'ref':
        return _m.echelon(_mat(args[0], name)).matrix;
      case 'rref':
        return _m.echelon(_mat(args[0], name), reduced: true).matrix;
      case 'eigvals':
        return ListValue([
          for (final r in NumericCalculus(this).eigenvalues(_mat(args[0], name))) NumberValue(r)
        ]);
      // Vector
      case 'dot':
        return NumberValue(_m.dot(_vec(args[0], name), _vec(args[1], name)));
      case 'cross':
        return _m.cross(_vec(args[0], name), _vec(args[1], name));
      case 'norm':
        return NumberValue(_m.norm(_vec(args[0], name)));
      case 'unit':
        return _m.unit(_vec(args[0], name));
      case 'angle':
        return NumberValue(fromRadians(_m.angle(_vec(args[0], name), _vec(args[1], name))));
      case 'proj':
        return _m.project(_vec(args[0], name), _vec(args[1], name));
      case 'dist':
        return NumberValue(_m.distance(_vec(args[0], name), _vec(args[1], name)));
      // Statistics
      case 'mean':
      case 'median':
      case 'total':
      case 'min':
      case 'max':
      case 'var':
      case 'pvar':
      case 'stdev':
      case 'pstdev':
        final data = _dataArgs(args, name);
        final s = Statistics(a);
        return NumberValue(switch (name) {
          'mean' => s.mean(data),
          'median' => s.median(data),
          'total' => s.sum(data),
          'min' => s.sorted(data).first,
          'max' => s.sorted(data).last,
          'var' => s.variance(data, sample: true),
          'pvar' => s.variance(data, sample: false),
          'stdev' => s.stdDev(data, sample: true),
          _ => s.stdDev(data, sample: false),
        });
      // Probability
      case 'normpdf':
      case 'normcdf':
      case 'invnorm':
        preferDecimal = true;
        final p = Probability(a);
        final mu = args.length > 1 ? n1() : Rat.zero;
        final sigma = args.length > 2 ? _n(args, 2, name) : Rat.one;
        if (args.length == 2) {
          throw MathError(MathErrorCode.wrongArgumentCount, {'name': name, 'expected': '1 or 3', 'got': 2});
        }
        return NumberValue(switch (name) {
          'normpdf' => p.normalPdf(n0(), mu, sigma),
          'normcdf' => p.normalCdf(n0(), mu, sigma),
          _ => p.inverseNormal(n0(), mu, sigma),
        });
      case 'binompdf':
        return NumberValue(Probability(a).binomialPdf(n0(), n1(), _n(args, 2, name)));
      case 'binomcdf':
        return NumberValue(Probability(a).binomialCdf(n0(), n1(), _n(args, 2, name)));
      case 'poissonpdf':
        preferDecimal = true;
        return NumberValue(Probability(a).poissonPdf(n0(), n1()));
      case 'poissoncdf':
        preferDecimal = true;
        return NumberValue(Probability(a).poissonCdf(n0(), n1()));
    }
    throw MathError(MathErrorCode.unknownIdentifier, {'name': name});
  }

  Num x2rad(Num t) => toRadians(t);

  Num? _tanOrInf(Num x) {
    try {
      return _tan(x);
    } on MathError catch (e) {
      if (e.code == MathErrorCode.undefinedResult) return null;
      rethrow;
    }
  }

  Num _reciprocal(Num v, String fn) {
    if (v.isZero) {
      throw MathError(MathErrorCode.undefinedResult, {'detail': '$fn is undefined here (division by zero)'});
    }
    return a.div(Rat.one, v);
  }

  Num _inverseTrig(Num radians, Num input) => radians is Cpx ? radians : fromRadians(radians);

  Num _randomUnit() {
    // 18 random decimal digits.
    final hi = ctx.random.nextInt(1000000000);
    final lo = ctx.random.nextInt(1000000000);
    return Rat(BigInt.from(hi) * BigInt.from(1000000000) + BigInt.from(lo), pow10(18));
  }

  BigInt _randomInt(BigInt lo, BigInt hi) {
    if (lo > hi) {
      throw const MathError(MathErrorCode.domainError, {'function': 'random integers', 'value': 'a > b'});
    }
    final span = hi - lo + BigInt.one;
    if (span.bitLength <= 31) return lo + BigInt.from(ctx.random.nextInt(span.toInt()));
    // Rejection sampling on 32-bit chunks.
    final bits = span.bitLength;
    while (true) {
      var r = BigInt.zero;
      for (var k = 0; k < bits; k += 30) {
        r = (r << 30) | BigInt.from(ctx.random.nextInt(1 << 30));
      }
      r = r & ((BigInt.one << bits) - BigInt.one);
      if (r < span) return lo + r;
    }
  }
}
