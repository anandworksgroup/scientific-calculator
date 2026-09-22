import '../numbers/num.dart';

/// Abstract syntax tree shared by evaluation, formatting, simplification
/// and symbolic manipulation.
sealed class Node {
  const Node();
}

/// Numeric literal. [isDecimal] records whether it was written with a
/// decimal point / exponent (used to pick fraction vs decimal display).
final class NumberNode extends Node {
  const NumberNode(this.value, {this.isDecimal = false});
  final Rat value;
  final bool isDecimal;
}

/// Built-in constant: `pi`, `e`, `phi`, `i`, or a physical constant `@name`.
final class ConstantNode extends Node {
  const ConstantNode(this.name);
  final String name;
}

final class VariableNode extends Node {
  const VariableNode(this.name);
  final String name;
}

enum UnaryOp {
  negate,
  plus,
  factorial,
  percent,

  /// Postfix `°`: the operand is in degrees.
  degrees,

  /// Postfix `ʳ`: the operand is in radians.
  radians,

  /// Postfix `ᵍ`: the operand is in gradians.
  gradians,
}

final class UnaryNode extends Node {
  const UnaryNode(this.op, this.operand);
  final UnaryOp op;
  final Node operand;
}

enum BinaryOp { add, sub, mul, div, pow, nCr, nPr, polar }

/// How a multiplication was written; matters for vectors (`·` is the dot
/// product, `×` the cross product) and for faithful re-display.
enum MulStyle { star, times, dot, implicit }

final class BinaryNode extends Node {
  const BinaryNode(this.op, this.left, this.right, {this.mulStyle = MulStyle.star});
  final BinaryOp op;
  final Node left;
  final Node right;
  final MulStyle mulStyle;
}

final class FunctionNode extends Node {
  const FunctionNode(this.name, this.args);
  final String name;
  final List<Node> args;
}

final class MatrixNode extends Node {
  const MatrixNode(this.rows);
  final List<List<Node>> rows;
}

final class VectorNode extends Node {
  const VectorNode(this.items);
  final List<Node> items;
}

enum RelOp { eq, lt, gt, le, ge, ne }

final class EquationNode extends Node {
  const EquationNode(this.left, this.right, [this.op = RelOp.eq]);
  final Node left;
  final Node right;
  final RelOp op;
}

/// `name = expr` or `expr → name`.
final class AssignmentNode extends Node {
  const AssignmentNode(this.name, this.value);
  final String name;
  final Node value;
}

/// `f(x, y) = body`.
final class FunctionDefNode extends Node {
  const FunctionDefNode(this.name, this.params, this.body);
  final String name;
  final List<String> params;
  final Node body;
}

// ------------------------------------------------------------ utilities

/// Collects all free variable names used in [node].
Set<String> freeVariables(Node node, [Set<String> bound = const {}]) {
  final out = <String>{};
  void walk(Node n, Set<String> b) {
    switch (n) {
      case VariableNode(:final name):
        if (!b.contains(name)) out.add(name);
      case NumberNode() || ConstantNode():
        break;
      case UnaryNode(:final operand):
        walk(operand, b);
      case BinaryNode(:final left, :final right):
        walk(left, b);
        walk(right, b);
      case FunctionNode(:final name, :final args):
        final lazy = lazyBindingFunctions[name];
        if (lazy != null && args.length > lazy) {
          final v = args[lazy];
          final nb = v is VariableNode ? {...b, v.name} : b;
          for (var k = 0; k < args.length; k++) {
            if (k == lazy) continue;
            walk(args[k], k == 0 ? nb : b);
          }
        } else {
          for (final a in args) {
            walk(a, b);
          }
        }
      case MatrixNode(:final rows):
        for (final r in rows) {
          for (final c in r) {
            walk(c, b);
          }
        }
      case VectorNode(:final items):
        for (final c in items) {
          walk(c, b);
        }
      case EquationNode(:final left, :final right):
        walk(left, b);
        walk(right, b);
      case AssignmentNode(:final value):
        walk(value, b);
      case FunctionDefNode(:final params, :final body):
        walk(body, {...b, ...params});
    }
  }

  walk(node, bound);
  return out;
}

/// Higher-order functions whose argument at the given index names a bound
/// variable (e.g. `integral(f, x, a, b)` binds `x` in `f`).
const Map<String, int> lazyBindingFunctions = {
  'integral': 1,
  'deriv': 1,
  'sum': 1,
  'prod': 1,
  'lim': 1,
  'limleft': 1,
  'limright': 1,
  'solve': 1,
  'table': 1,
};

/// True if [node] contains any decimal literal (drives auto result format).
bool containsDecimalLiteral(Node node) {
  var found = false;
  void walk(Node n) {
    if (found) return;
    switch (n) {
      case NumberNode(:final isDecimal):
        if (isDecimal) found = true;
      case ConstantNode() || VariableNode():
        break;
      case UnaryNode(:final operand, :final op):
        if (op == UnaryOp.percent) found = true;
        walk(operand);
      case BinaryNode(:final left, :final right):
        walk(left);
        walk(right);
      case FunctionNode(:final args):
        args.forEach(walk);
      case MatrixNode(:final rows):
        for (final r in rows) {
          r.forEach(walk);
        }
      case VectorNode(:final items):
        items.forEach(walk);
      case EquationNode(:final left, :final right):
        walk(left);
        walk(right);
      case AssignmentNode(:final value):
        walk(value);
      case FunctionDefNode(:final body):
        walk(body);
    }
  }

  walk(node);
  return found;
}

/// True if [node] references the imaginary unit.
bool containsImaginaryUnit(Node node) {
  var found = false;
  void walk(Node n) {
    if (found) return;
    switch (n) {
      case ConstantNode(:final name):
        if (name == 'i') found = true;
      case NumberNode() || VariableNode():
        break;
      case UnaryNode(:final operand):
        walk(operand);
      case BinaryNode(:final left, :final right, :final op):
        if (op == BinaryOp.polar) found = true;
        walk(left);
        walk(right);
      case FunctionNode(:final args):
        args.forEach(walk);
      case MatrixNode(:final rows):
        for (final r in rows) {
          r.forEach(walk);
        }
      case VectorNode(:final items):
        items.forEach(walk);
      case EquationNode(:final left, :final right):
        walk(left);
        walk(right);
      case AssignmentNode(:final value):
        walk(value);
      case FunctionDefNode(:final body):
        walk(body);
    }
  }

  walk(node);
  return found;
}

/// Replaces variables by nodes (used for user-function expansion).
Node substituteNodes(Node node, Map<String, Node> map) {
  Node s(Node n) => substituteNodes(n, map);
  return switch (node) {
    VariableNode(:final name) => map[name] ?? node,
    NumberNode() || ConstantNode() => node,
    UnaryNode(:final op, :final operand) => UnaryNode(op, s(operand)),
    BinaryNode(:final op, :final left, :final right, :final mulStyle) =>
      BinaryNode(op, s(left), s(right), mulStyle: mulStyle),
    FunctionNode(:final name, :final args) => FunctionNode(name, args.map(s).toList()),
    MatrixNode(:final rows) => MatrixNode(rows.map((r) => r.map(s).toList()).toList()),
    VectorNode(:final items) => VectorNode(items.map(s).toList()),
    EquationNode(:final left, :final right, :final op) => EquationNode(s(left), s(right), op),
    AssignmentNode(:final name, :final value) => AssignmentNode(name, s(value)),
    FunctionDefNode(:final name, :final params, :final body) =>
      FunctionDefNode(name, params, substituteNodes(body, {...map}..removeWhere((k, _) => params.contains(k)))),
  };
}
