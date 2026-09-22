import 'package:math_engine/math_engine.dart';
import 'package:test/test.dart';

const engine = DefaultMathEngine();
const s = CalcSettings(precision: 12, angleMode: AngleMode.rad);

String sym(EngineResult<SymbolicResult> r) => switch (r) {
      Success(:final value) => value.plain,
      Failure(:final error) => 'ERR:${error.code.name}',
      Cancelled() => 'CANCELLED',
    };

void main() {
  group('expand / factor / simplify', () {
    test('expand (x+1)^2', () => expect(sym(engine.expand('(x+1)^2', s, Environment())), 'x^2+2x+1'));
    test('expand (x+y)(x-y)', () => expect(sym(engine.expand('(x+y)(x-y)', s, Environment())), 'x^2-y^2'));
    test('factor x^2-9', () {
      final r = sym(engine.factor('x^2-9', s, Environment()));
      expect(r, anyOf('(x-3)*(x+3)', '(x+3)*(x-3)'));
    });
    test('factor x^2+2x+1', () => expect(sym(engine.factor('x^2+2x+1', s, Environment())), '(x+1)^2'));
    test('factor 2x^3-2x', () {
      final r = sym(engine.factor('2x^3-2x', s, Environment()));
      expect(r, contains('x-1'));
      expect(r, contains('x+1'));
      expect(r, startsWith('2'));
    });
    test('factor irreducible quadratic kept', () {
      final r = sym(engine.factor('x^3+x', s, Environment()));
      expect(r, contains('x^2+1'));
    });
    test('simplify cancels', () => expect(sym(engine.simplify('(x^2-1)/(x-1)', s, Environment())), 'x+1'));
    test('simplify trig identity', () => expect(sym(engine.simplify('sin(x)^2+cos(x)^2', s, Environment())), '1'));
    test('collect', () {
      final r = sym(engine.collect('a*x+b*x+c', 'x', s, Environment()));
      expect(r, contains('(a+b)*x'));
    });
    test('substitute', () => expect(sym(engine.substitute('x^2+1', 'x', '3', s, Environment())), '10'));
    test('like terms', () => expect(sym(engine.simplify('2x+3x-x', s, Environment())), '4x'));
    test('surd combination', () => expect(sym(engine.simplify('sqrt(2)*sqrt(3)', s, Environment())), 'sqrt(6)'));
    test('rationalize', () => expect(sym(engine.simplify('1/sqrt(2)', s, Environment())), 'sqrt(2)/2'));
  });

  group('derivatives', () {
    String d(String f, [int order = 1]) => switch (engine.differentiate(f, 'x', order, s, Environment())) {
          Success(:final value) => value.derivative.toString().isEmpty ? '' : const TextPrinter().print(symToNode(value.derivative)),
          Failure(:final error) => 'ERR:${error.code.name}',
          Cancelled() => 'C',
        };
    test('x²', () => expect(d('x^2'), '2x'));
    test('x³+2x', () => expect(d('x^3+2x'), '3*x^2+2'));
    test('sin', () => expect(d('sin(x)'), 'cos(x)'));
    test('second derivative', () => expect(d('x^3', 2), '6x'));
    test('product rule', () => expect(d('x*e^x'), anyOf('x*e^x+e^x', 'e^x*x+e^x', 'e^x+x*e^x', '(x+1)*e^x', 'e^x*(x+1)')));
    test('chain rule', () => expect(d('sin(x^2)'), '2x*cos(x^2)'));
    test('ln', () => expect(d('ln(x)'), '1/x'));
    test('value at point', () {
      final r = engine.differentiate('x^3', 'x', 1, s, Environment(), at: '2').valueOrNull!;
      expect(r.valueAt, Rat.int(12));
    });
  });

  group('integrals', () {
    String anti(String f) {
      final r = engine.integrate(f, 'x', s, Environment());
      return r.valueOrNull?.antiderivative == null
          ? 'none'
          : const TextPrinter().print(symToNode(r.valueOrNull!.antiderivative!));
    }

    Num definite(String f, String lo, String hi) =>
        engine.integrate(f, 'x', s, Environment(), lower: lo, upper: hi).valueOrNull!.definite!.value;

    test('∫2x', () => expect(anti('2x'), 'x^2'));
    test('∫x²', () => expect(anti('x^2'), 'x^3/3'));
    test('∫1/x', () => expect(anti('1/x'), 'ln(abs(x))'));
    test('∫sin', () => expect(anti('sin(x)'), '-cos(x)'));
    test('∫e^(2x)', () => expect(anti('e^(2x)'), 'e^(2x)/2'));
    test('∫x e^x', () => expect(anti('x*e^x'), isNot('none')));
    test('∫x cos x', () => expect(anti('x*cos(x)'), isNot('none')));
    test('∫ln x', () => expect(anti('ln(x)'), isNot('none')));
    test('∫1/(1+x²)', () => expect(anti('1/(1+x^2)'), 'atan(x)'));
    test('∫2x/(x²+1)', () => expect(anti('2x/(x^2+1)'), 'ln(x^2+1)'));
    test('∫1/(x²-1)', () => expect(anti('1/(x^2-1)'), isNot('none')));
    test('∫x e^(x²)', () => expect(anti('x*e^(x^2)'), 'e^(x^2)/2'));
    test('∫sin²', () => expect(anti('sin(x)^2'), isNot('none')));
    test('∫1/sqrt(1-x²)', () => expect(anti('1/sqrt(1-x^2)'), 'asin(x)'));
    test('definite exact', () => expect(definite('x^2', '0', '1'), Rat.frac(1, 3)));
    test('definite reversed', () => expect(definite('x', '1', '0'), Rat.frac(-1, 2)));
    test('definite numeric', () {
      final v = definite('e^(-x^2)', '-inf', 'inf').toDouble();
      expect(v, closeTo(1.7724538509055159, 1e-12));
    });
    test('divergent', () {
      final r = engine.integrate('1/x', 'x', s, Environment(), lower: '0', upper: '1');
      expect(r.errorOrNull?.code, MathErrorCode.noConvergence);
    });
  });

  group('equation solver', () {
    List<String> roots(String eq, [String v = 'x']) {
      final r = engine.solve(eq, v, s, Environment()).valueOrNull!;
      return [
        for (final x in r.roots)
          const NumberFormatter(FormatOptions(digits: 10, fraction: FractionMode.fraction)).format(x.value).plain
      ];
    }

    test('quadratic', () => expect(roots('x^2-5x+6=0'), ['2', '3']));
    test('linear', () => expect(roots('3x+2=11'), ['3']));
    test('cubic', () => expect(roots('x^3-6x^2+11x-6=0'), ['1', '2', '3']));
    test('complex roots', () => expect(roots('x^2+1=0'), ['-i', 'i']));
    test('irrational', () => expect(roots('x^2=2'), ['-1.414213562', '1.414213562']));
    test('rational equation excludes poles', () => expect(roots('(x^2-1)/(x-1)=0'), ['-1']));
    test('exponential isolation', () => expect(roots('2^x=8'), ['3']));
    test('ln isolation', () => expect(roots('ln(x)=0'), ['1']));
    test('numeric', () => expect(roots('cos(x)=x'), ['0.7390851332']));
    test('extraneous root dropped', () => expect(engine.solve('sqrt(x)=-2', 'x', s, Environment()).errorOrNull?.code, MathErrorCode.noRealSolution));
    test('quadratic steps', () {
      final r = engine.solve('x^2-5x+6=0', 'x', s, Environment()).valueOrNull!;
      expect(r.discriminant, Rat.one);
      expect(r.steps.length, greaterThanOrEqualTo(5));
    });
    test('symbolic linear', () {
      final r = engine.solve('a*x+b=0', 'x', s, Environment()).valueOrNull!;
      expect(const TextPrinter().print(symToNode(r.symbolic.single)), '-b/a');
    });
  });

  group('polynomial solver', () {
    test('multiplicity', () {
      final r = engine.solvePolynomial(['1', '-2', '1'], s, Environment()).valueOrNull!;
      expect(r.roots.single.value, Rat.one);
      expect(r.roots.single.multiplicity, 2);
    });
    test('quartic', () {
      final r = engine.solvePolynomial(['1', '0', '-5', '0', '4'], s, Environment()).valueOrNull!;
      expect([for (final x in r.roots) x.value], [Rat.int(-2), Rat.int(-1), Rat.int(1), Rat.int(2)]);
    });
    test('quadratic surd', () {
      final r = engine.solvePolynomial(['1', '-5', '3'], s, Environment()).valueOrNull!;
      expect(r.roots.first.surd, isNotNull);
      expect(r.discriminant, Rat.int(13));
    });
    test('degree 5 numeric', () {
      final r = engine.solvePolynomial(['1', '0', '0', '0', '-1', '-1'], s, Environment()).valueOrNull!;
      expect(r.roots.length, 5);
      final real = r.roots.where((x) => x.isReal).single.value.toDouble();
      expect(real, closeTo(1.1673039782614187, 1e-12));
    });
  });

  group('linear systems', () {
    test('2x2', () {
      final r = engine.solveLinearSystem([['2', '1'], ['1', '-1']], ['5', '1'], ['x', 'y'], s, Environment()).valueOrNull!;
      expect(r.kind, SystemKind.unique);
      expect(r.values, [Rat.int(2), Rat.int(1)]);
    });
    test('3x3', () {
      final r = engine.solveLinearSystem(
          [['1', '1', '1'], ['0', '2', '5'], ['2', '5', '-1']], ['6', '-4', '27'], ['x', 'y', 'z'], s, Environment()).valueOrNull!;
      expect(r.values, [Rat.int(5), Rat.int(3), Rat.int(-2)]);
    });
    test('inconsistent', () {
      final r = engine.solveLinearSystem([['1', '1'], ['1', '1']], ['1', '2'], ['x', 'y'], s, Environment()).valueOrNull!;
      expect(r.kind, SystemKind.none);
    });
    test('infinite', () {
      final r = engine.solveLinearSystem([['1', '1'], ['2', '2']], ['1', '2'], ['x', 'y'], s, Environment()).valueOrNull!;
      expect(r.kind, SystemKind.infinite);
      expect(r.parametric.length, 2);
    });
  });

  group('limits', () {
    String lim(String f, String at, [int side = 0]) {
      final r = engine.limit(f, 'x', at, side, s, Environment());
      return switch (r) {
        Success(:final value) => const ValueFormatter(FormatOptions(digits: 10)).format(value).plain,
        Failure(:final error) => 'ERR:${error.code.name}',
        Cancelled() => 'C',
      };
    }

    test('sin x / x', () => expect(lim('sin(x)/x', '0'), '1'));
    test('(1+1/x)^x', () => expect(lim('(1+1/x)^x', 'inf'), '2.718281828'));
    test('(x²-1)/(x-1)', () => expect(lim('(x^2-1)/(x-1)', '1'), '2'));
    test('1/x from right', () => expect(lim('1/x', '0', 1), 'inf'));
    test('1/x from left', () => expect(lim('1/x', '0', -1), '-inf'));
    test('1/x two-sided', () => expect(lim('1/x', '0'), 'ERR:undefinedResult'));
    test('rational at -inf', () => expect(lim('(3x^3)/(x^2+1)', '-inf'), '-inf'));
    test('(1-cos x)/x²', () => expect(lim('(1-cos(x))/x^2', '0'), '1/2'));
  });

  group('eigen', () {
    test('eigenvectors', () {
      final m = MatrixValue([
        [Rat.int(2), Rat.int(1)],
        [Rat.int(1), Rat.int(2)],
      ]);
      final r = engine.eigen(m, s).valueOrNull!;
      expect([for (final p in r) p.value], [Rat.int(1), Rat.int(3)]);
      expect(r.every((p) => p.vectors.length == 1), isTrue);
    });
  });
}
