import '../algebra/polynomial.dart';
import '../ast/ast.dart';
import '../constants/constants.dart';
import '../core/errors.dart';
import '../eval/evaluator.dart' show AngleMode;
import '../eval/values.dart';
import '../number_theory/number_theory.dart';
import '../numbers/num.dart';
import 'sym.dart';

/// Converts parsed expressions to symbolic form.
///
/// When [angleMode] is degrees or gradians, trigonometric arguments are
/// converted to radians (and inverse-trig results back), so that exact
/// evaluation matches the calculator (sin 30 = 1/2 in DEG mode).
class SymConverter {
  SymConverter({
    this.angleMode = AngleMode.rad,
    this.values = const {},
    this.userFunctions = const {},
  });

  final AngleMode angleMode;

  /// Known variable values; exact numbers are substituted.
  final Map<String, Value> values;
  final Map<String, (List<String>, Node)> userFunctions;

  int _depth = 0;

  static const _unsupported = MathError(MathErrorCode.notSupported,
      {'detail': 'This expression cannot be handled symbolically.'});

  Sym convert(Node node) {
    if (++_depth > 300) throw const MathError(MathErrorCode.recursionLimit);
    try {
      return _convert(node);
    } finally {
      _depth--;
    }
  }

  Sym _toRad(Sym x) => switch (angleMode) {
        AngleMode.rad => x,
        AngleMode.deg => S.mul([x, S.pi, S.n(Rat.frac(1, 180))]),
        AngleMode.grad => S.mul([x, S.pi, S.n(Rat.frac(1, 200))]),
      };

  Sym _fromRad(Sym x) => switch (angleMode) {
        AngleMode.rad => x,
        AngleMode.deg => S.mul([x, S.integer(180), S.pow(S.pi, S.minusOne)]),
        AngleMode.grad => S.mul([x, S.integer(200), S.pow(S.pi, S.minusOne)]),
      };

  Sym _convert(Node node) {
    switch (node) {
      case NumberNode(:final value):
        return S.n(value);
      case ConstantNode(:final name):
        switch (name) {
          case 'pi' || '@pi':
            return S.pi;
          case 'e' || '@e':
            return S.e;
          case 'i':
            return S.i;
          case 'phi' || '@phi':
            return S.div(S.add([S.one, S.sqrt(S.integer(5))]), S.two);
          case '@hbar':
            return S.div(S.n(Rat.parseDecimal('6.62607015E-34')), S.mul([S.two, S.pi]));
        }
        if (name.startsWith('@')) {
          final c = constantIndex[name.substring(1)];
          if (c != null && c.compute == null) return S.n(Rat.parseDecimal(c.value));
        }
        throw _unsupported;
      case VariableNode(:final name):
        final v = values[name];
        if (v == null) return S.v(name);
        if (v is NumberValue) {
          final n = v.n;
          if (n is Rat) return S.n(n);
          if (n is Cpx && n.re is Rat && n.im is Rat) {
            return S.add([S.n(n.re as Rat), S.mul([S.n(n.im as Rat), S.i])]);
          }
        }
        throw _unsupported;
      case UnaryNode(:final op, :final operand):
        final x = convert(operand);
        return switch (op) {
          UnaryOp.negate => S.neg(x),
          UnaryOp.plus => x,
          UnaryOp.factorial => S.fn('factorial', [x]),
          UnaryOp.percent => S.mul([x, S.n(Rat.frac(1, 100))]),
          UnaryOp.degrees => switch (angleMode) {
              AngleMode.deg => x,
              AngleMode.rad => S.mul([x, S.pi, S.n(Rat.frac(1, 180))]),
              AngleMode.grad => S.mul([x, S.n(Rat.frac(10, 9))]),
            },
          UnaryOp.radians => _fromRad(x),
          UnaryOp.gradians => switch (angleMode) {
              AngleMode.grad => x,
              AngleMode.deg => S.mul([x, S.n(Rat.frac(9, 10))]),
              AngleMode.rad => S.mul([x, S.pi, S.n(Rat.frac(1, 200))]),
            },
        };
      case BinaryNode(:final op, :final left, :final right):
        if ((op == BinaryOp.add || op == BinaryOp.sub) &&
            right is UnaryNode &&
            right.op == UnaryOp.percent) {
          final base = convert(left);
          final pct = S.mul([base, convert(right.operand), S.n(Rat.frac(1, 100))]);
          return op == BinaryOp.add ? S.add([base, pct]) : S.sub(base, pct);
        }
        final l = convert(left), r = convert(right);
        switch (op) {
          case BinaryOp.add:
            return S.add([l, r]);
          case BinaryOp.sub:
            return S.sub(l, r);
          case BinaryOp.mul:
            return S.mul([l, r]);
          case BinaryOp.div:
            return S.div(l, r);
          case BinaryOp.pow:
            return S.pow(l, r);
          case BinaryOp.nCr:
          case BinaryOp.nPr:
            final ln = l.asRat, rn = r.asRat;
            if (ln != null && rn != null && ln.isInteger && rn.isInteger) {
              return S.n(Rat(op == BinaryOp.nCr
                  ? NumberTheory.combinations(ln.n, rn.n)
                  : NumberTheory.permutations(ln.n, rn.n)));
            }
            throw _unsupported;
          case BinaryOp.polar:
            final t = _toRad(r);
            return S.mul([l, S.add([S.fn('cos', [t]), S.mul([S.i, S.fn('sin', [t])])])]);
        }
      case FunctionNode(:final name, :final args):
        final uf = userFunctions[name];
        if (uf != null) {
          final (params, body) = uf;
          if (params.length != args.length) throw _unsupported;
          return convert(substituteNodes(body, {for (var k = 0; k < params.length; k++) params[k]: args[k]}));
        }
        if (!_symbolicFunctions.contains(name)) throw _unsupported;
        final sargs = [for (final a in args) convert(a)];
        switch (name) {
          case 'sin' || 'cos' || 'tan' || 'sec' || 'csc' || 'cot':
            return S.fn(name, [_toRad(sargs[0])]);
          case 'asin' || 'acos' || 'atan':
            return _fromRad(S.fn(name, sargs));
          case 'nCr' || 'nPr':
            final ln = sargs[0].asRat, rn = sargs[1].asRat;
            if (ln != null && rn != null && ln.isInteger && rn.isInteger) {
              return S.n(Rat(name == 'nCr'
                  ? NumberTheory.combinations(ln.n, rn.n)
                  : NumberTheory.permutations(ln.n, rn.n)));
            }
            throw _unsupported;
          case 'gcd' || 'lcm':
            if (sargs.every((s) => s.asRat?.isInteger ?? false)) {
              var acc = sargs.first.asRat!.n.abs();
              for (final s in sargs.skip(1)) {
                acc = name == 'gcd' ? acc.gcd(s.asRat!.n) : NumberTheory.lcm(acc, s.asRat!.n);
              }
              return S.n(Rat(acc));
            }
            throw _unsupported;
        }
        return S.fn(name, sargs);
      default:
        throw _unsupported;
    }
  }

  static const _symbolicFunctions = {
    'sqrt', 'cbrt', 'nroot', 'exp', 'pow', 'ln', 'log', 'log2',
    'sin', 'cos', 'tan', 'sec', 'csc', 'cot', 'asin', 'acos', 'atan',
    'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh',
    'abs', 'floor', 'ceil', 'round', 'trunc', 'sign', 'factorial',
    'nCr', 'nPr', 'gcd', 'lcm',
  };
}

/// Converts a symbolic expression back to an AST for display.
Node symToNode(Sym s) {
  switch (s) {
    case SNum(:final v):
      if (v.isNegative) return UnaryNode(UnaryOp.negate, symToNode(SNum(-v)));
      if (v.isInteger) return NumberNode(v);
      return BinaryNode(BinaryOp.div, NumberNode(Rat(v.n)), NumberNode(Rat(v.d)));
    case SConst(:final name):
      return ConstantNode(name);
    case SVar(:final name):
      return VariableNode(name);
    case SAdd(:final terms):
      Node? acc;
      for (final t in terms) {
        final neg = _isNegativeTerm(t);
        final node = symToNode(neg ? S.neg(t) : t);
        if (acc == null) {
          acc = neg ? UnaryNode(UnaryOp.negate, node) : node;
        } else {
          acc = BinaryNode(neg ? BinaryOp.sub : BinaryOp.add, acc, node);
        }
      }
      return acc!;
    case SMul():
      return _mulToNode(s);
    case SPow(:final base, :final exp):
      final er = exp.asRat;
      if (er != null) {
        if (er.isNegative) {
          return BinaryNode(BinaryOp.div, NumberNode(Rat.one), symToNode(S.pow(base, SNum(-er))));
        }
        if (er == Rat.half) return FunctionNode('sqrt', [symToNode(base)]);
        if (er.n == BigInt.one && er.d > BigInt.two && er.d < BigInt.from(100)) {
          return FunctionNode('nroot', [NumberNode(Rat(er.d)), symToNode(base)]);
        }
      }
      if (base is SConst && base.name == 'e') {
        return BinaryNode(BinaryOp.pow, const ConstantNode('e'), symToNode(exp));
      }
      return BinaryNode(BinaryOp.pow, symToNode(base), symToNode(exp));
    case SFn(:final name, :final args):
      return FunctionNode(name, [for (final a in args) symToNode(a)]);
  }
}

bool _isNegativeTerm(Sym t) =>
    (t is SNum && t.v.isNegative) || (t is SMul && t.coefficient.isNegative);

Node _mulToNode(SMul m) {
  var coeff = m.coefficient;
  final negative = coeff.isNegative;
  if (negative) coeff = -coeff;
  final num = <Node>[];
  final den = <Node>[];
  if (!coeff.isOne) {
    if (coeff.n != BigInt.one) num.add(NumberNode(Rat(coeff.n)));
    if (coeff.d != BigInt.one) den.add(NumberNode(Rat(coeff.d)));
  }
  final factors = m.factors.where((f) => f is! SNum).toList();
  // log_b(x) = ln(x) · ln(b)^−1
  SFn? lnX;
  SFn? lnBase;
  for (final f in factors) {
    if (f is SFn && f.name == 'ln' && lnX == null) lnX = f;
    if (f is SPow && f.exp == S.minusOne && f.base is SFn && (f.base as SFn).name == 'ln') {
      lnBase = f.base as SFn;
    }
  }
  if (lnX != null && lnBase != null) {
    factors.remove(lnX);
    factors.removeWhere((f) => f is SPow && f.base == lnBase && f.exp == S.minusOne);
    final b = lnBase.args.first;
    final x = symToNode(lnX.args.first);
    if (b == S.integer(10)) {
      num.add(FunctionNode('log', [x]));
    } else if (b == S.two) {
      num.add(FunctionNode('log2', [x]));
    } else {
      num.add(FunctionNode('log', [symToNode(b), x]));
    }
  }
  for (final f in factors) {
    if (f is SPow && f.exp.asRat != null && f.exp.asRat!.isNegative) {
      den.add(symToNode(S.pow(f.base, SNum(-f.exp.asRat!))));
    } else {
      num.add(symToNode(f));
    }
  }
  Node product(List<Node> xs) {
    if (xs.isEmpty) return NumberNode(Rat.one);
    var acc = xs.first;
    for (final x in xs.skip(1)) {
      acc = BinaryNode(BinaryOp.mul, acc, x, mulStyle: MulStyle.implicit);
    }
    return acc;
  }

  Node result = den.isEmpty ? product(num) : BinaryNode(BinaryOp.div, product(num), product(den));
  if (negative) result = UnaryNode(UnaryOp.negate, result);
  return result;
}

// ------------------------------------------------------------ evaluation

/// Numeric evaluation of a symbolic expression (angles in radians).
Num symEval(Sym s, Arith a, [Map<String, Num> vars = const {}]) {
  switch (s) {
    case SNum(:final v):
      return v;
    case SConst(:final name):
      return switch (name) {
        'pi' => a.pi(),
        'e' => a.e(),
        'i' => Cpx.i,
        _ => throw MathError(MathErrorCode.unknownIdentifier, {'name': name}),
      };
    case SVar(:final name):
      final v = vars[name];
      if (v == null) throw MathError(MathErrorCode.undefinedVariable, {'name': name});
      return v;
    case SAdd(:final terms):
      return terms.map((t) => symEval(t, a, vars)).reduce(a.add);
    case SMul(:final factors):
      return factors.map((t) => symEval(t, a, vars)).reduce(a.mul);
    case SPow(:final base, :final exp):
      final b = symEval(base, a, vars);
      final e = symEval(exp, a, vars);
      if (b is Rat && b.isNegative && e is Rat && e.d.isOdd) return a.pow(b, e);
      return a.pow(b, e);
    case SFn(:final name, :final args):
      final x = [for (final t in args) symEval(t, a, vars)];
      return switch (name) {
        'ln' => a.ln(x[0]),
        'sin' => a.sin(x[0]),
        'cos' => a.cos(x[0]),
        'tan' => a.tan(x[0]),
        'asin' => a.asin(x[0]),
        'acos' => a.acos(x[0]),
        'atan' => a.atan(x[0]),
        'sinh' => a.sinh(x[0]),
        'cosh' => a.cosh(x[0]),
        'tanh' => a.tanh(x[0]),
        'asinh' => a.asinh(x[0]),
        'acosh' => a.acosh(x[0]),
        'atanh' => a.atanh(x[0]),
        'abs' => a.abs(x[0]),
        'floor' => a.floor(x[0]),
        'ceil' => a.ceil(x[0]),
        'round' => a.round(x[0]),
        'trunc' => a.trunc(x[0]),
        'sign' => a.sign(x[0]),
        'factorial' => a.factorial(x[0]),
        _ => throw MathError(MathErrorCode.unknownIdentifier, {'name': name}),
      };
  }
}

/// Rebuilds [s] bottom-up through the canonical constructors, applying
/// [leaf] to variables.
Sym rebuild(Sym s, Sym Function(SVar) leaf) {
  switch (s) {
    case SNum() || SConst():
      return s;
    case SVar():
      return leaf(s);
    case SAdd(:final terms):
      return S.add([for (final t in terms) rebuild(t, leaf)]);
    case SMul(:final factors):
      return S.mul([for (final t in factors) rebuild(t, leaf)]);
    case SPow(:final base, :final exp):
      return S.pow(rebuild(base, leaf), rebuild(exp, leaf));
    case SFn(:final name, :final args):
      return S.fn(name, [for (final t in args) rebuild(t, leaf)]);
  }
}

Sym substitute(Sym s, String variable, Sym value) =>
    rebuild(s, (v) => v.name == variable ? value : v);

/// Counts nodes (complexity measure for choosing simplest forms).
int symSize(Sym s) => switch (s) {
      SNum(:final v) => v.isInteger ? 1 : 2,
      SConst() || SVar() => 1,
      SAdd(:final terms) => 1 + terms.fold(0, (n, t) => n + symSize(t)),
      SMul(:final factors) => 1 + factors.fold(0, (n, t) => n + symSize(t)),
      SPow(:final base, :final exp) => 1 + symSize(base) + symSize(exp),
      SFn(:final args) => 1 + args.fold(0, (n, t) => n + symSize(t)),
    };

// ------------------------------------------------------------ expansion

Sym expand(Sym s) {
  switch (s) {
    case SNum() || SConst() || SVar():
      return s;
    case SAdd(:final terms):
      return S.add([for (final t in terms) expand(t)]);
    case SMul(:final factors):
      var acc = <Sym>[S.one];
      for (final f in factors) {
        final e = expand(f);
        final parts = e is SAdd ? e.terms : [e];
        if (acc.length * parts.length > maxSymTerms) {
          throw const MathError(MathErrorCode.tooLarge, {'function': 'expansion', 'limit': '$maxSymTerms terms'});
        }
        final next = S.add([for (final x in acc) for (final y in parts) S.mul([x, y])]);
        acc = next is SAdd ? next.terms : [next];
      }
      return S.add(acc);
    case SPow(:final base, :final exp):
      final b = expand(base);
      final er = exp.asRat;
      if (b is SAdd && er != null && er.isInteger && er.n > BigInt.one) {
        if (er.n > BigInt.from(200)) {
          throw const MathError(MathErrorCode.tooLarge, {'function': 'expansion', 'limit': 'power 200'});
        }
        // Multiply term lists directly: S.mul on two equal sums would just
        // regroup them into a power again.
        var acc = b.terms;
        for (var k = 1; k < er.n.toInt(); k++) {
          if (acc.length * b.terms.length > maxSymTerms) {
            throw const MathError(MathErrorCode.tooLarge, {'function': 'expansion', 'limit': '$maxSymTerms terms'});
          }
          final next = S.add([for (final x in acc) for (final y in b.terms) S.mul([x, y])]);
          acc = next is SAdd ? next.terms : [next];
        }
        return S.add(acc);
      }
      return S.pow(b, expand(exp));
    case SFn(:final name, :final args):
      return S.fn(name, [for (final t in args) expand(t)]);
  }
}

/// Polynomial coefficients of [s] in [x] (index = power), or null when [s]
/// is not a polynomial in [x]. Coefficients may contain other symbols.
List<Sym>? polyCoefficients(Sym s, String x, {int maxDegree = 200}) {
  final e = expand(s);
  final terms = e is SAdd ? e.terms : [e];
  final coeffs = <int, List<Sym>>{};
  for (final t in terms) {
    final factors = t is SMul ? t.factors : [t];
    var deg = 0;
    final rest = <Sym>[];
    for (final f in factors) {
      if (f is SVar && f.name == x) {
        deg += 1;
      } else if (f is SPow && f.base is SVar && (f.base as SVar).name == x) {
        final k = f.exp.asRat;
        if (k == null || !k.isInteger || k.isNegative) return null;
        deg += k.n.toInt();
      } else if (dependsOn(f, x)) {
        return null;
      } else {
        rest.add(f);
      }
    }
    if (deg > maxDegree) return null;
    coeffs.putIfAbsent(deg, () => []).add(S.mul(rest));
  }
  if (coeffs.isEmpty) return [S.zero];
  final maxDeg = coeffs.keys.reduce((p, q) => p > q ? p : q);
  final out = [for (var k = 0; k <= maxDeg; k++) S.add(coeffs[k] ?? const [])];
  while (out.length > 1 && out.last == S.zero) {
    out.removeLast();
  }
  return out;
}

Sym polyFromCoefficients(List<Sym> c, String x) =>
    S.add([for (var k = 0; k < c.length; k++) S.mul([c[k], S.pow(S.v(x), S.integer(k))])]);

// ------------------------------------------------------------ calculus

Sym differentiate(Sym s, String x) {
  if (!dependsOn(s, x)) return S.zero;
  switch (s) {
    case SNum() || SConst():
      return S.zero;
    case SVar(:final name):
      return name == x ? S.one : S.zero;
    case SAdd(:final terms):
      return S.add([for (final t in terms) differentiate(t, x)]);
    case SMul(:final factors):
      final parts = <Sym>[];
      for (var k = 0; k < factors.length; k++) {
        if (!dependsOn(factors[k], x)) continue;
        parts.add(S.mul([
          for (var j = 0; j < factors.length; j++) j == k ? differentiate(factors[j], x) : factors[j]
        ]));
      }
      return S.add(parts);
    case SPow(:final base, :final exp):
      final db = differentiate(base, x);
      if (!dependsOn(exp, x)) {
        return S.mul([exp, S.pow(base, S.sub(exp, S.one)), db]);
      }
      final de = differentiate(exp, x);
      if (!dependsOn(base, x)) {
        return S.mul([s, S.ln(base), de]);
      }
      return S.mul([s, S.add([S.mul([de, S.ln(base)]), S.mul([exp, db, S.pow(base, S.minusOne)])])]);
    case SFn(:final name, :final args):
      final u = args.first;
      final du = differentiate(u, x);
      final outer = switch (name) {
        'sin' => S.fn('cos', [u]),
        'cos' => S.neg(S.fn('sin', [u])),
        'tan' => S.pow(S.fn('cos', [u]), S.integer(-2)),
        'asin' => S.pow(S.sub(S.one, S.pow(u, S.two)), S.n(Rat.frac(-1, 2))),
        'acos' => S.neg(S.pow(S.sub(S.one, S.pow(u, S.two)), S.n(Rat.frac(-1, 2)))),
        'atan' => S.pow(S.add([S.one, S.pow(u, S.two)]), S.minusOne),
        'sinh' => S.fn('cosh', [u]),
        'cosh' => S.fn('sinh', [u]),
        'tanh' => S.pow(S.fn('cosh', [u]), S.integer(-2)),
        'asinh' => S.pow(S.add([S.pow(u, S.two), S.one]), S.n(Rat.frac(-1, 2))),
        'acosh' => S.pow(S.sub(S.pow(u, S.two), S.one), S.n(Rat.frac(-1, 2))),
        'atanh' => S.pow(S.sub(S.one, S.pow(u, S.two)), S.minusOne),
        'ln' => S.pow(u, S.minusOne),
        'abs' => S.mul([u, S.pow(S.fn('abs', [u]), S.minusOne)]),
        _ => throw MathError(MathErrorCode.notSupported,
            {'detail': 'The derivative of $name() is not available symbolically.'}),
      };
      return S.mul([outer, du]);
  }
}

// ------------------------------------------------------ rational functions

/// Splits into (numerator, denominator) without expanding.
(Sym, Sym) numDen(Sym s) {
  if (s is SPow) {
    final r = s.exp.asRat;
    if (r != null && r.isNegative) return (S.one, S.pow(s.base, SNum(-r)));
    return (s, S.one);
  }
  if (s is SNum) return (S.n(Rat(s.v.n)), S.n(Rat(s.v.d)));
  if (s is SMul) {
    final n = <Sym>[], d = <Sym>[];
    for (final f in s.factors) {
      final (fn, fd) = numDen(f);
      n.add(fn);
      d.add(fd);
    }
    return (S.mul(n), S.mul(d));
  }
  if (s is SAdd) {
    // a/b + c/d = (ad + cb)/(bd), grouping equal denominators.
    var num = S.zero as Sym;
    var den = S.one as Sym;
    for (final t in s.terms) {
      final (tn, td) = numDen(t);
      if (td == den) {
        num = S.add([num, tn]);
      } else if (td == S.one) {
        num = S.add([num, S.mul([tn, den])]);
      } else {
        num = S.add([S.mul([num, td]), S.mul([tn, den])]);
        den = S.mul([den, td]);
      }
    }
    return (num, den);
  }
  return (s, S.one);
}

List<Rat>? _ratPoly(Sym s, String x) {
  final c = polyCoefficients(s, x);
  if (c == null) return null;
  final out = <Rat>[];
  for (final k in c) {
    final r = k.asRat;
    if (r == null) return null;
    out.add(r);
  }
  return out;
}

Sym _ratPolyToSym(List<Rat> p, String x) =>
    S.add([for (var k = 0; k < p.length; k++) S.mul([S.n(p[k]), S.pow(S.v(x), S.integer(k))])]);

/// Cancels common polynomial factors of a univariate rational function.
Sym cancel(Sym s) {
  final vars = symVariables(s);
  if (vars.length != 1) return s;
  final x = vars.first;
  final (n, d) = numDen(s);
  if (d == S.one) return s;
  final pn = _ratPoly(n, x), pd = _ratPoly(d, x);
  if (pn == null || pd == null) return s;
  final g = RatPoly.gcd(pn, pd);
  if (g.length <= 1) {
    return S.div(_ratPolyToSym(pn, x), _ratPolyToSym(pd, x));
  }
  final qn = RatPoly.divmod(pn, g).$1, qd = RatPoly.divmod(pd, g).$1;
  // Make the denominator's leading coefficient positive and monic-ish.
  final lead = qd.last;
  final nn = [for (final c in qn) c / lead];
  final dd = [for (final c in qd) c / lead];
  final numSym = factorSym(_ratPolyToSym(nn, x));
  final denSym = factorSym(_ratPolyToSym(dd, x));
  return S.div(numSym, denSym);
}

// ---------------------------------------------------------- factoring

/// Factors polynomials over the rationals (univariate: complete over
/// linear rational factors, with irreducible remainders kept; multivariate:
/// common monomial and numeric content).
Sym factorSym(Sym s) {
  final (n, d) = numDen(s);
  if (d != S.one) {
    final fn = factorSym(n), fd = factorSym(d);
    return S.div(fn, fd);
  }
  final e = expand(s);
  final vars = symVariables(e);
  if (vars.length == 1) {
    final x = vars.first;
    final p = _ratPoly(e, x);
    if (p != null && p.length > 2) return _factorUnivariate(p, x);
  }
  if (e is SAdd) return _factorCommon(e);
  return e;
}

Sym _factorUnivariate(List<Rat> p, String x) {
  // Content: rational number c with c·(primitive integer polynomial).
  final prim = RatPoly.primitive(p);
  final primRat = [for (final c in prim) Rat(c)];
  final content = p.last / primRat.last;
  final factors = <Sym>[S.n(content)];
  final xs = S.v(x);
  var zeros = 0;
  var rest = primRat;
  while (rest.isNotEmpty && rest.first.isZero) {
    rest = rest.sublist(1);
    zeros++;
  }
  if (zeros > 0) factors.add(S.pow(xs, S.integer(zeros)));
  for (final (sf, mult) in RatPoly.squareFree(rest)) {
    var f = sf;
    final lin = <Sym>[];
    if (f.length > 2) {
      final solver = PolynomialSolver(Arith(precision: 30));
      for (final r in solver.roots(f)) {
        final v = r.value;
        if (v is Rat && RatPoly.eval(f, v).isZero) {
          // (d·x − n) with integer coefficients
          lin.add(S.add([S.mul([S.n(Rat(v.d)), xs]), S.n(Rat(-v.n))]));
          f = RatPoly.divmod(f, [-v, Rat.one]).$1;
          if (f.length <= 1) break;
        }
      }
    }
    for (final l in lin) {
      factors.add(S.pow(l, S.integer(mult)));
    }
    if (f.length > 1) {
      // Remaining factor; scale to integer coefficients and fix content.
      final fp = RatPoly.primitive(f);
      final scale = f.last / Rat(fp.last);
      factors.add(S.n(scale.powInt(mult)));
      final rem = _ratPolyToSym([for (final c in fp) Rat(c)], x);
      factors.add(S.pow(rem, S.integer(mult)));
    } else if (f.length == 1) {
      factors.add(S.n(f.first.powInt(mult)));
    }
  }
  // Fix the overall constant so the product equals the original.
  final product = S.mul(factors);
  final check = _ratPoly(expand(product), x);
  if (check != null && check.isNotEmpty) {
    final ratio = p.last / check.last;
    if (!ratio.isOne) return S.mul([S.n(ratio), product]);
  }
  return product;
}

Sym _factorCommon(SAdd s) {
  // Numeric content.
  BigInt? gNum;
  BigInt? lDen;
  for (final t in s.terms) {
    final c = t is SMul ? t.coefficient : (t is SNum ? t.v : Rat.one);
    gNum = gNum == null ? c.n.abs() : gNum.gcd(c.n);
    lDen = lDen == null ? c.d : NumberTheory.lcm(lDen, c.d);
  }
  var content = Rat(gNum ?? BigInt.one, lDen ?? BigInt.one);
  if (_isNegativeTerm(s.terms.first)) content = -content;
  // Common variable powers.
  final common = <String, Rat>{};
  var first = true;
  for (final t in s.terms) {
    final pows = <String, Rat>{};
    final factors = t is SMul ? t.factors : [t];
    for (final f in factors) {
      if (f is SVar) pows[f.name] = (pows[f.name] ?? Rat.zero) + Rat.one;
      if (f is SPow && f.base is SVar && f.exp.asRat != null && !f.exp.asRat!.isNegative) {
        final n = (f.base as SVar).name;
        pows[n] = (pows[n] ?? Rat.zero) + f.exp.asRat!;
      }
    }
    if (first) {
      common.addAll(pows);
      first = false;
    } else {
      for (final k in common.keys.toList()) {
        final v = pows[k];
        if (v == null) {
          common.remove(k);
        } else if (v < common[k]!) {
          common[k] = v;
        }
      }
    }
  }
  if (content.isOne && common.isEmpty) return s;
  final monomial = S.mul([S.n(content), for (final e in common.entries) S.pow(S.v(e.key), S.n(e.value))]);
  final inner = expand(S.div(s, monomial));
  return SMul([...(monomial is SMul ? monomial.factors : [monomial]), inner]);
}

// ---------------------------------------------------------- collect

/// Groups terms by powers of [x]: Σ c_k·x^k with collected coefficients.
Sym collect(Sym s, String x) {
  final e = expand(s);
  final terms = e is SAdd ? e.terms : [e];
  final byPower = <String, (Sym, List<Sym>)>{};
  final order = <String>[];
  for (final t in terms) {
    final factors = t is SMul ? t.factors : [t];
    final xp = <Sym>[], rest = <Sym>[];
    for (final f in factors) {
      if (dependsOn(f, x)) {
        xp.add(f);
      } else {
        rest.add(f);
      }
    }
    final power = S.mul(xp);
    final k = power.key;
    byPower.putIfAbsent(k, () {
      order.add(k);
      return (power, <Sym>[]);
    }).$2.add(S.mul(rest));
  }
  final out = <Sym>[];
  for (final k in order) {
    final (power, coeffs) = byPower[k]!;
    final c = S.add(coeffs);
    if (c == S.zero) continue;
    out.add(c is SAdd ? SMul([c, power]) : S.mul([c, power]));
  }
  if (out.isEmpty) return S.zero;
  if (out.length == 1) return out.first;
  return SAdd(out);
}

// ---------------------------------------------------------- simplify

/// Applies sin²u + cos²u = 1 to an expanded sum.
Sym _pythagorean(Sym s) {
  if (s is! SAdd) return s;
  final terms = List<Sym>.of(s.terms);
  var changed = false;
  for (var i = 0; i < terms.length; i++) {
    final ti = terms[i];
    final si = _findSquare(ti, 'sin');
    if (si == null) continue;
    for (var j = 0; j < terms.length; j++) {
      if (i == j) continue;
      final cj = _findSquare(terms[j], 'cos');
      if (cj == null || cj.$1 != si.$1) continue;
      if (si.$2 == cj.$2) {
        terms[i] = si.$2;
        terms.removeAt(j);
        changed = true;
        break;
      }
    }
  }
  return changed ? S.add(terms) : s;
}

/// For a term c·R·f(u)², returns (u, c·R).
(Sym, Sym)? _findSquare(Sym t, String fn) {
  final factors = t is SMul ? t.factors : [t];
  for (var k = 0; k < factors.length; k++) {
    final f = factors[k];
    if (f is SPow && f.exp == S.two && f.base is SFn && (f.base as SFn).name == fn) {
      final rest = [for (var j = 0; j < factors.length; j++) if (j != k) factors[j]];
      return ((f.base as SFn).args.first, S.mul(rest));
    }
  }
  return null;
}

/// Tries several equivalent forms and returns the simplest.
Sym simplify(Sym s) {
  final candidates = <Sym>[s];
  void tryAdd(Sym Function() f) {
    try {
      candidates.add(f());
    } on MathError {
      // Form not available.
    }
  }

  tryAdd(() => _pythagorean(expand(s)));
  tryAdd(() => cancel(s));
  tryAdd(() => factorSym(s));
  tryAdd(() {
    final (n, d) = numDen(s);
    return d == S.one ? s : S.div(_pythagorean(expand(n)), _pythagorean(expand(d)));
  });
  candidates.sort((p, q) => symSize(p).compareTo(symSize(q)));
  return candidates.first;
}
