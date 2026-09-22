import 'dart:math' as math;

import '../ast/ast.dart';
import '../constants/constants.dart';
import '../core/errors.dart';
import '../numbers/num.dart';
import 'evaluator.dart';
import 'values.dart';

typedef DoubleFn = double Function(List<double> args);

/// Compiles an AST into a closure over IEEE doubles for fast repeated
/// evaluation (graph sampling, numerical integration, root scanning).
///
/// Invalid points (domain errors, poles) evaluate to NaN instead of
/// throwing. Only scalar real functions are supported; anything else
/// throws [MathError] at compile time so callers can fall back to the
/// exact evaluator.
class DoubleCompiler {
  DoubleCompiler({
    required this.parameters,
    this.angleMode = AngleMode.rad,
    this.variables = const {},
    this.functions = const {},
  });

  /// Names bound to positions of the argument list.
  final List<String> parameters;
  final AngleMode angleMode;
  final Map<String, Value> variables;
  final Map<String, UserFunction> functions;
  int _inline = 0;

  static const _unsupported = MathError(MathErrorCode.notSupported,
      {'detail': 'This expression cannot be evaluated numerically.'});

  DoubleFn compile(Node node) => _c(node);

  double get _toRad => switch (angleMode) {
        AngleMode.rad => 1.0,
        AngleMode.deg => math.pi / 180,
        AngleMode.grad => math.pi / 200,
      };

  DoubleFn _c(Node node) {
    switch (node) {
      case NumberNode(:final value):
        final v = value.toDouble();
        return (_) => v;
      case ConstantNode(:final name):
        final v = _constant(name);
        return (_) => v;
      case VariableNode(:final name):
        final idx = parameters.indexOf(name);
        if (idx >= 0) return (a) => a[idx];
        final val = variables[name];
        if (val is NumberValue && val.n is! Cpx) {
          final v = val.n.toDouble();
          return (_) => v;
        }
        if (name == 'Ans' || name == 'PreAns') return (_) => 0;
        throw MathError(MathErrorCode.undefinedVariable, {'name': name});
      case UnaryNode(:final op, :final operand):
        final f = _c(operand);
        switch (op) {
          case UnaryOp.negate:
            return (a) => -f(a);
          case UnaryOp.plus:
            return f;
          case UnaryOp.factorial:
            return (a) => _factorial(f(a));
          case UnaryOp.percent:
            return (a) => f(a) / 100;
          case UnaryOp.degrees:
            final k = math.pi / 180 / _toRad;
            return (a) => f(a) * k;
          case UnaryOp.radians:
            final k = 1 / _toRad;
            return (a) => f(a) * k;
          case UnaryOp.gradians:
            final k = math.pi / 200 / _toRad;
            return (a) => f(a) * k;
        }
      case BinaryNode(:final op, :final left, :final right):
        if ((op == BinaryOp.add || op == BinaryOp.sub) && right is UnaryNode && right.op == UnaryOp.percent) {
          final l = _c(left), p = _c(right.operand);
          return op == BinaryOp.add ? (a) => l(a) * (1 + p(a) / 100) : (a) => l(a) * (1 - p(a) / 100);
        }
        final l = _c(left), r = _c(right);
        switch (op) {
          case BinaryOp.add:
            return (a) => l(a) + r(a);
          case BinaryOp.sub:
            return (a) => l(a) - r(a);
          case BinaryOp.mul:
            return (a) => l(a) * r(a);
          case BinaryOp.div:
            return (a) => l(a) / r(a);
          case BinaryOp.pow:
            // Integer/odd-root exponent constants allow negative bases.
            if (right is NumberNode) {
              final e = right.value;
              final ed = e.toDouble();
              if (e.isInteger) {
                final n = ed;
                return (a) => math.pow(l(a), n).toDouble();
              }
              if (e.d.isOdd) {
                return (a) {
                  final b = l(a);
                  if (b >= 0) return math.pow(b, ed).toDouble();
                  final m = math.pow(-b, ed).toDouble();
                  return e.n.isOdd ? -m : m;
                };
              }
            }
            return (a) => _pow(l(a), r(a));
          case BinaryOp.nCr:
            return (a) => _nCr(l(a), r(a));
          case BinaryOp.nPr:
            return (a) => _nPr(l(a), r(a));
          case BinaryOp.polar:
            throw _unsupported;
        }
      case FunctionNode(:final name, :final args):
        return _function(name, args);
      default:
        throw _unsupported;
    }
  }

  double _constant(String name) {
    switch (name) {
      case 'pi':
        return math.pi;
      case 'e':
        return math.e;
      case 'phi':
        return (1 + math.sqrt(5)) / 2;
      case 'inf':
        return double.infinity;
    }
    if (name.startsWith('@')) {
      final c = constantIndex[name.substring(1)];
      if (c != null) return c.numericValue(Arith(precision: 17)).toDouble();
    }
    throw _unsupported;
  }

  DoubleFn _function(String name, List<Node> args) {
    final uf = functions[name];
    if (uf != null) {
      if (++_inline > 50) throw const MathError(MathErrorCode.recursionLimit);
      try {
        if (uf.params.length != args.length) {
          throw MathError(MathErrorCode.wrongArgumentCount,
              {'name': name, 'expected': '${uf.params.length}', 'got': args.length});
        }
        return _c(substituteNodes(uf.body, {for (var k = 0; k < args.length; k++) uf.params[k]: args[k]}));
      } finally {
        _inline--;
      }
    }
    final f = [for (final n in args) _c(n)];
    final k = _toRad;
    final inv = 1 / _toRad;
    DoubleFn u(double Function(double) g) {
      final a0 = f[0];
      return (a) => g(a0(a));
    }

    switch (name) {
      case 'sqrt':
        return u(math.sqrt);
      case 'cbrt':
        return u(_cbrt);
      case 'nroot':
        return (a) => _nroot(f[1](a), f[0](a));
      case 'exp':
        return u(math.exp);
      case 'pow':
        return (a) => _pow(f[0](a), f[1](a));
      case 'ln':
        return u(math.log);
      case 'log':
        if (f.length == 2) return (a) => math.log(f[1](a)) / math.log(f[0](a));
        return u((v) => math.log(v) / math.ln10);
      case 'log2':
        return u((v) => math.log(v) / math.ln2);
      case 'sin':
        return u((v) => math.sin(v * k));
      case 'cos':
        return u((v) => math.cos(v * k));
      case 'tan':
        return u((v) => math.tan(v * k));
      case 'sec':
        return u((v) => 1 / math.cos(v * k));
      case 'csc':
        return u((v) => 1 / math.sin(v * k));
      case 'cot':
        return u((v) => 1 / math.tan(v * k));
      case 'asin':
        return u((v) => math.asin(v) * inv);
      case 'acos':
        return u((v) => math.acos(v) * inv);
      case 'atan':
        return u((v) => math.atan(v) * inv);
      case 'atan2':
        return (a) => math.atan2(f[0](a), f[1](a)) * inv;
      case 'sinh':
        return u((v) => (math.exp(v) - math.exp(-v)) / 2);
      case 'cosh':
        return u((v) => (math.exp(v) + math.exp(-v)) / 2);
      case 'tanh':
        return u(_tanh);
      case 'asinh':
        return u((v) => v < 0 ? -math.log(-v + math.sqrt(v * v + 1)) : math.log(v + math.sqrt(v * v + 1)));
      case 'acosh':
        return u((v) => math.log(v + math.sqrt(v * v - 1)));
      case 'atanh':
        return u((v) => 0.5 * math.log((1 + v) / (1 - v)));
      case 'abs':
        return u((v) => v.abs());
      case 'floor':
        return u((v) => v.floorToDouble());
      case 'ceil':
        return u((v) => v.ceilToDouble());
      case 'round':
        if (f.length == 2) {
          return (a) {
            final m = math.pow(10, f[1](a).round()).toDouble();
            return (f[0](a) * m).roundToDouble() / m;
          };
        }
        return u((v) => v.roundToDouble());
      case 'trunc':
        return u((v) => v.truncateToDouble());
      case 'fpart':
        return u((v) => v - v.truncateToDouble());
      case 'sign':
        return u((v) => v.sign);
      case 'factorial':
        return u(_factorial);
      case 'gamma':
        return u(gammaDouble);
      case 'nCr':
        return (a) => _nCr(f[0](a), f[1](a));
      case 'nPr':
        return (a) => _nPr(f[0](a), f[1](a));
      case 'mod':
        return (a) {
          final x = f[0](a), m = f[1](a);
          return x - m * (x / m).floorToDouble();
        };
      case 'rem':
        return (a) => f[0](a).remainder(f[1](a));
      case 'min':
        return (a) => f.map((g) => g(a)).reduce(math.min);
      case 'max':
        return (a) => f.map((g) => g(a)).reduce(math.max);
    }
    throw _unsupported;
  }

  static double _pow(double b, double e) {
    if (b < 0 && e != e.roundToDouble()) return double.nan;
    return math.pow(b, e).toDouble();
  }

  static double _cbrt(double v) => v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

  static double _nroot(double x, double n) {
    if (x < 0 && n == n.roundToDouble() && n.round().isOdd) return -math.pow(-x, 1 / n).toDouble();
    return _pow(x, 1 / n);
  }

  static double _tanh(double v) {
    if (v > 20) return 1;
    if (v < -20) return -1;
    final e2 = math.exp(2 * v);
    return (e2 - 1) / (e2 + 1);
  }

  static double _factorial(double v) {
    if (v == v.roundToDouble() && v < 0) return double.nan;
    return gammaDouble(v + 1);
  }

  static double _nCr(double n, double r) {
    if (n != n.roundToDouble() || r != r.roundToDouble() || r < 0 || n < 0) return double.nan;
    if (r > n) return 0;
    return math.exp(lgammaDouble(n + 1) - lgammaDouble(r + 1) - lgammaDouble(n - r + 1)).roundToDouble();
  }

  static double _nPr(double n, double r) {
    if (n != n.roundToDouble() || r != r.roundToDouble() || r < 0 || n < 0) return double.nan;
    if (r > n) return 0;
    return math.exp(lgammaDouble(n + 1) - lgammaDouble(n - r + 1)).roundToDouble();
  }

  static const _lanczos = [
    0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
    -176.61503916999185, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];

  static double lgammaDouble(double x) {
    if (x < 0.5) return math.log(math.pi / math.sin(math.pi * x).abs()) - lgammaDouble(1 - x);
    x -= 1;
    var s = _lanczos[0];
    for (var i = 1; i < 9; i++) {
      s += _lanczos[i] / (x + i);
    }
    final t = x + 7.5;
    return 0.5 * math.log(2 * math.pi) + (x + 0.5) * math.log(t) - t + math.log(s);
  }

  static double gammaDouble(double x) {
    if (x == x.roundToDouble() && x <= 0) return double.nan;
    if (x == x.roundToDouble() && x <= 171) {
      var r = 1.0;
      for (var k = 2; k < x; k++) {
        r *= k;
      }
      return r;
    }
    if (x < 0.5) return math.pi / (math.sin(math.pi * x) * gammaDouble(1 - x));
    if (x > 171.7) return double.infinity;
    x -= 1;
    var s = _lanczos[0];
    for (var i = 1; i < 9; i++) {
      s += _lanczos[i] / (x + i);
    }
    final t = x + 7.5;
    return math.sqrt(2 * math.pi) * math.pow(t, x + 0.5) * math.exp(-t) * s;
  }
}
