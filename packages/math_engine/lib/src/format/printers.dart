import '../ast/ast.dart';
import '../constants/constants.dart';
import '../numbers/num.dart';

/// Operator precedence used by printers to decide parenthesization.
int _prec(Node n) => switch (n) {
      EquationNode() || AssignmentNode() || FunctionDefNode() => 0,
      BinaryNode(:final op) => switch (op) {
          BinaryOp.add || BinaryOp.sub => 1,
          BinaryOp.mul || BinaryOp.div => 2,
          BinaryOp.nCr || BinaryOp.nPr || BinaryOp.polar => 3,
          BinaryOp.pow => 5,
        },
      UnaryNode(:final op) => op == UnaryOp.negate || op == UnaryOp.plus ? 4 : 6,
      NumberNode(:final value) => value.isNegative ? 4 : 7,
      _ => 7,
    };

const _greek = {
  'alpha': r'\alpha', 'beta': r'\beta', 'gamma': r'\gamma', 'delta': r'\delta',
  'theta': r'\theta', 'lambda': r'\lambda', 'mu': r'\mu', 'sigma': r'\sigma',
  'omega': r'\omega', 'tau': r'\tau', 'rho': r'\rho', 'epsilon': r'\varepsilon',
  'θ': r'\theta', 'λ': r'\lambda', 'μ': r'\mu', 'σ': r'\sigma', 'ω': r'\omega',
  'α': r'\alpha', 'β': r'\beta', 'τ': r'\tau', 'ρ': r'\rho', 'δ': r'\delta',
};

const _latexFunctionNames = {
  'sin': r'\sin', 'cos': r'\cos', 'tan': r'\tan', 'sec': r'\sec', 'csc': r'\csc', 'cot': r'\cot',
  'asin': r'\sin^{-1}', 'acos': r'\cos^{-1}', 'atan': r'\tan^{-1}',
  'sinh': r'\sinh', 'cosh': r'\cosh', 'tanh': r'\tanh',
  'asinh': r'\sinh^{-1}', 'acosh': r'\cosh^{-1}', 'atanh': r'\tanh^{-1}',
  'ln': r'\ln', 'log': r'\log', 'log2': r'\log_{2}', 'det': r'\det', 'gcd': r'\gcd',
  'min': r'\min', 'max': r'\max', 'arg': r'\arg', 'exp': r'\exp',
};

/// Renders an AST as LaTeX in textbook notation.
class LatexPrinter {
  const LatexPrinter();

  String print(Node n) => _p(n);

  String _var(String name) {
    final g = _greek[name];
    if (g != null) return g;
    if (name == 'Ans' || name == 'PreAns') return '\\mathrm{$name}';
    if (name.length == 1) return name;
    // x1 → x_{1}
    final m = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(name);
    if (m != null && m.group(1)!.length == 1) return '${m.group(1)}_{${m.group(2)}}';
    return '\\mathrm{${name.replaceAll('_', r'\_')}}';
  }

  String _num(NumberNode n) {
    final v = n.value;
    if (v.isInteger) return v.n.toString();
    // Decimal literal: print positionally.
    final s = _decimalString(v);
    if (s != null) return s;
    return '\\frac{${v.n}}{${v.d}}';
  }

  /// Exact decimal expansion if the denominator is 2^a·5^b.
  static String? _decimalString(Rat v) {
    var d = v.d;
    var k = 0;
    while (d % BigInt.from(10) == BigInt.zero) {
      d = d ~/ BigInt.from(10);
      k++;
    }
    var n = v.n.abs();
    while (d % BigInt.two == BigInt.zero) {
      d = d ~/ BigInt.two;
      n *= BigInt.from(5);
      k++;
    }
    while (d % BigInt.from(5) == BigInt.zero) {
      d = d ~/ BigInt.from(5);
      n *= BigInt.two;
      k++;
    }
    if (d != BigInt.one || k > 40) return null;
    final s = n.toString().padLeft(k + 1, '0');
    final r = '${s.substring(0, s.length - k)}.${s.substring(s.length - k)}';
    return v.isNegative ? '-$r' : r;
  }

  String _wrap(Node n, int minPrec) {
    final s = _p(n);
    return _prec(n) < minPrec ? '\\left($s\\right)' : s;
  }

  String _args(List<Node> args) => args.map(_p).join(', ');

  String _p(Node n) {
    switch (n) {
      case NumberNode():
        return _num(n);
      case ConstantNode(:final name):
        switch (name) {
          case 'pi':
            return r'\pi';
          case 'e':
            return 'e';
          case 'phi':
            return r'\varphi';
          case 'i':
            return 'i';
          case 'inf':
            return r'\infty';
        }
        final c = constantIndex[name.startsWith('@') ? name.substring(1) : name];
        return c != null ? '{${c.latex}}' : '\\mathrm{$name}';
      case VariableNode(:final name):
        return _var(name);
      case UnaryNode(:final op, :final operand):
        switch (op) {
          case UnaryOp.negate:
            return '-${_wrap(operand, 2)}';
          case UnaryOp.plus:
            return '+${_wrap(operand, 5)}';
          case UnaryOp.factorial:
            return '${_wrap(operand, 7)}!';
          case UnaryOp.percent:
            return '${_wrap(operand, 7)}\\%';
          case UnaryOp.degrees:
            return '${_wrap(operand, 7)}^{\\circ}';
          case UnaryOp.radians:
            return '${_wrap(operand, 7)}^{r}';
          case UnaryOp.gradians:
            return '${_wrap(operand, 7)}^{g}';
        }
      case BinaryNode(:final op, :final left, :final right, :final mulStyle):
        switch (op) {
          case BinaryOp.add:
            return '${_wrap(left, 1)}+${_wrap(right, 2)}';
          case BinaryOp.sub:
            return '${_wrap(left, 1)}-${_wrap(right, 2)}';
          case BinaryOp.mul:
            final l = _wrap(left, 2), r = _wrap(right, 3);
            final sep = switch (mulStyle) {
              MulStyle.dot => r'\cdot ',
              MulStyle.times => r'\times ',
              MulStyle.star => r'\times ',
              MulStyle.implicit => _implicitSep(left, right),
            };
            return '$l$sep$r';
          case BinaryOp.div:
            return '\\frac{${_p(left)}}{${_p(right)}}';
          case BinaryOp.pow:
            if (left is FunctionNode && _latexFunctionNames.containsKey(left.name) &&
                right is NumberNode && right.value.isInteger && !right.value.isNegative &&
                !left.name.startsWith('a')) {
              // sin²(x)
              return '${_latexFunctionNames[left.name]}^{${_p(right)}}\\left(${_args(left.args)}\\right)';
            }
            return '{${_wrap(left, 6)}}^{${_p(right)}}';
          case BinaryOp.nCr:
            return '{}_{${_p(left)}}\\mathrm{C}_{${_p(right)}}';
          case BinaryOp.nPr:
            return '{}_{${_p(left)}}\\mathrm{P}_{${_p(right)}}';
          case BinaryOp.polar:
            return '${_wrap(left, 4)}\\angle ${_wrap(right, 4)}';
        }
      case FunctionNode(:final name, :final args):
        return _fn(name, args);
      case MatrixNode(:final rows):
        final body = rows.map((r) => r.map(_p).join(' & ')).join(r' \\ ');
        return '\\begin{bmatrix}$body\\end{bmatrix}';
      case VectorNode(:final items):
        return '\\left(${items.map(_p).join(', ')}\\right)';
      case EquationNode(:final left, :final right, :final op):
        final sym = switch (op) {
          RelOp.eq => '=',
          RelOp.lt => '<',
          RelOp.gt => '>',
          RelOp.le => r'\le ',
          RelOp.ge => r'\ge ',
          RelOp.ne => r'\ne ',
        };
        return '${_p(left)}$sym${_p(right)}';
      case AssignmentNode(:final name, :final value):
        return '${_var(name)}=${_p(value)}';
      case FunctionDefNode(:final name, :final params, :final body):
        return '${_var(name)}\\left(${params.map(_var).join(', ')}\\right)=${_p(body)}';
    }
  }

  String _implicitSep(Node l, Node r) {
    // Two numbers side by side need an explicit sign.
    if (_endsWithNumber(l) && _startsWithNumber(r)) return r'\times ';
    return r'\,';
  }

  bool _endsWithNumber(Node n) => switch (n) {
        NumberNode() => true,
        BinaryNode(:final right, :final op) => op != BinaryOp.div && op != BinaryOp.pow && _endsWithNumber(right),
        UnaryNode(:final op, :final operand) => op == UnaryOp.negate && _endsWithNumber(operand),
        _ => false,
      };

  bool _startsWithNumber(Node n) => switch (n) {
        NumberNode() => true,
        BinaryNode(:final left, :final op) => op != BinaryOp.div && _startsWithNumber(left),
        UnaryNode(:final op) => op == UnaryOp.negate,
        _ => false,
      };

  String _fn(String name, List<Node> args) {
    String a(int k) => _p(args[k]);
    switch (name) {
      case 'sqrt':
        return '\\sqrt{${a(0)}}';
      case 'cbrt':
        return '\\sqrt[3]{${a(0)}}';
      case 'nroot':
        return '\\sqrt[${a(0)}]{${a(1)}}';
      case 'abs':
        return '\\left|${a(0)}\\right|';
      case 'floor':
        return '\\left\\lfloor ${a(0)}\\right\\rfloor';
      case 'ceil':
        return '\\left\\lceil ${a(0)}\\right\\rceil';
      case 'exp':
        return 'e^{${a(0)}}';
      case 'log':
        if (args.length == 2) return '\\log_{${a(0)}}\\left(${a(1)}\\right)';
        return '\\log\\left(${a(0)}\\right)';
      case 'factorial':
        return '${_wrap(args[0], 7)}!';
      case 'conj':
        return '\\overline{${a(0)}}';
      case 'trn':
        return '{${_wrap(args[0], 7)}}^{\\mathsf{T}}';
      case 'inv':
        return '{${_wrap(args[0], 7)}}^{-1}';
      case 'norm':
        return '\\left\\|${a(0)}\\right\\|';
      case 'nCr':
        return '{}_{${a(0)}}\\mathrm{C}_{${a(1)}}';
      case 'nPr':
        return '{}_{${a(0)}}\\mathrm{P}_{${a(1)}}';
      case 'deriv':
        final v = a(1);
        final order = args.length > 3 ? a(3) : '1';
        final d = order == '1' ? '\\frac{d}{d$v}' : '\\frac{d^{$order}}{d$v^{$order}}';
        return '$d\\left(${a(0)}\\right)\\Big|_{$v=${a(2)}}';
      case 'integral':
        return '\\int_{${a(2)}}^{${a(3)}}${a(0)}\\,d${a(1)}';
      case 'sum':
        return '\\sum_{${a(1)}=${a(2)}}^{${a(3)}}\\left(${a(0)}\\right)';
      case 'prod':
        return '\\prod_{${a(1)}=${a(2)}}^{${a(3)}}\\left(${a(0)}\\right)';
      case 'lim':
        return '\\lim_{${a(1)}\\to ${a(2)}}\\left(${a(0)}\\right)';
      case 'limleft':
        return '\\lim_{${a(1)}\\to ${a(2)}^{-}}\\left(${a(0)}\\right)';
      case 'limright':
        return '\\lim_{${a(1)}\\to ${a(2)}^{+}}\\left(${a(0)}\\right)';
    }
    final known = _latexFunctionNames[name];
    final head = known ?? '\\mathrm{${name.replaceAll('_', r'\_')}}';
    return '$head\\left(${_args(args)}\\right)';
  }
}

/// Renders an AST as re-parseable plain text in engine syntax.
class TextPrinter {
  const TextPrinter({this.pretty = false});

  /// Pretty mode uses ×, −, √ and π symbols (still parseable).
  final bool pretty;

  String print(Node n) => _p(n);

  String _wrap(Node n, int minPrec) {
    final s = _p(n);
    return _prec(n) < minPrec ? '($s)' : s;
  }

  String _num(Rat v) {
    if (v.isInteger) return v.n.toString();
    final s = LatexPrinter._decimalString(v);
    if (s != null) return s;
    return '(${v.n}/${v.d})';
  }

  String _p(Node n) {
    switch (n) {
      case NumberNode(:final value):
        return _num(value);
      case ConstantNode(:final name):
        if (name == 'pi') return pretty ? 'π' : 'pi';
        if (name == 'phi') return pretty ? 'φ' : 'phi';
        if (name == 'inf') return pretty ? '∞' : 'inf';
        return name;
      case VariableNode(:final name):
        return name;
      case UnaryNode(:final op, :final operand):
        return switch (op) {
          UnaryOp.negate => '${pretty ? '−' : '-'}${_wrap(operand, 2)}',
          UnaryOp.plus => '+${_wrap(operand, 5)}',
          UnaryOp.factorial => '${_wrap(operand, 7)}!',
          UnaryOp.percent => '${_wrap(operand, 7)}%',
          UnaryOp.degrees => '${_wrap(operand, 7)}°',
          UnaryOp.radians => '${_wrap(operand, 7)}ʳ',
          UnaryOp.gradians => '${_wrap(operand, 7)}ᵍ',
        };
      case BinaryNode(:final op, :final left, :final right, :final mulStyle):
        final minus = pretty ? '−' : '-';
        return switch (op) {
          BinaryOp.add => '${_wrap(left, 1)}+${_wrap(right, 2)}',
          BinaryOp.sub => '${_wrap(left, 1)}$minus${_wrap(right, 2)}',
          BinaryOp.mul => '${_wrap(left, 2)}${switch (mulStyle) {
              MulStyle.dot => '·',
              MulStyle.times => '×',
              MulStyle.star => pretty ? '×' : '*',
              MulStyle.implicit => _implicit(left, right),
            }}${_wrap(right, 3)}',
          BinaryOp.div => '${_wrap(left, 2)}${pretty ? '÷' : '/'}${_wrap(right, 3)}',
          BinaryOp.pow => '${_wrap(left, 6)}^${_wrap(right, 6)}',
          BinaryOp.nCr => '${_wrap(left, 4)}nCr${_wrap(right, 4)}',
          BinaryOp.nPr => '${_wrap(left, 4)}nPr${_wrap(right, 4)}',
          BinaryOp.polar => '${_wrap(left, 4)}∠${_wrap(right, 4)}',
        };
      case FunctionNode(:final name, :final args):
        if (pretty && name == 'sqrt') return '√(${_p(args[0])})';
        return '$name(${args.map(_p).join(', ')})';
      case MatrixNode(:final rows):
        return '[${rows.map((r) => '[${r.map(_p).join(', ')}]').join(', ')}]';
      case VectorNode(:final items):
        return '[${items.map(_p).join(', ')}]';
      case EquationNode(:final left, :final right, :final op):
        final sym = switch (op) {
          RelOp.eq => '=',
          RelOp.lt => '<',
          RelOp.gt => '>',
          RelOp.le => '≤',
          RelOp.ge => '≥',
          RelOp.ne => '≠',
        };
        return '${_p(left)}$sym${_p(right)}';
      case AssignmentNode(:final name, :final value):
        return '$name=${_p(value)}';
      case FunctionDefNode(:final name, :final params, :final body):
        return '$name(${params.join(', ')})=${_p(body)}';
    }
  }

  String _implicit(Node l, Node r) {
    if (l is NumberNode && (r is VariableNode || r is ConstantNode || r is FunctionNode)) return '';
    return pretty ? '·' : '*';
  }
}
