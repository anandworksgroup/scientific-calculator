import 'package:math_engine/math_engine.dart';
import 'package:test/test.dart';

const engine = DefaultMathEngine();

String show(String input,
    {CalcSettings settings = const CalcSettings(precision: 10),
    Environment? env,
    FormatOptions opts = const FormatOptions(digits: 10)}) {
  final r = engine.evaluate(input, settings, env ?? Environment());
  switch (r) {
    case Success(:final value):
      return ValueFormatter(opts).format(value.value, preferDecimal: value.preferDecimal).plain;
    case Failure(:final error):
      return 'ERR:${error.code.name}';
    case Cancelled():
      return 'CANCELLED';
  }
}

String exact(String input, {CalcSettings settings = const CalcSettings(precision: 10)}) {
  final r = engine.evaluate(input, settings, Environment());
  return r.valueOrNull?.exactText ?? 'none';
}

void main() {
  group('basic arithmetic', () {
    final cases = {
      '2+2': '4',
      '2+5×4': '22',
      '2+5*4': '22',
      '(2+5)*4': '28',
      '10-2-3': '5',
      '2^3^2': '512',
      '-2^2': '-4',
      '(-2)^2': '4',
      '2^-1': '1/2',
      '1/2+3/4': '5/4',
      '0.1+0.2': '0.3',
      '7÷2': '7/2',
      '3.5*2': '7',
      '50%': '0.5',
      '200+10%': '220',
      '200-10%': '180',
      '2(5)': '10',
      '(2)(3)': '6',
      '1.2E3': '1200',
      '5!': '120',
      '0!': '1',
      '3²': '9',
      '2³': '8',
      '4⁻¹': '1/4',
      '√16': '4',
      '√(16)+9': '13',
      '∛27': '3',
      '∛(-8)': '-2',
      'nroot(4, 81)': '3',
      'sqrt(1/4)': '1/2',
      '10nCr3': '120',
      '10nPr3': '720',
      'nCr(10,3)': '120',
      'abs(-3.5)': '3.5',
      'floor(-2.5)': '-3',
      'ceil(2.1)': '3',
      'round(2.5)': '3',
      'round(-2.5)': '-3',
      'round(3.14159, 2)': '3.14',
      'sign(-4)': '-1',
      'fpart(3.75)': '0.75',
      'trunc(-3.75)': '-3',
    };
    cases.forEach((input, expected) {
      test(input, () => expect(show(input), expected));
    });
  });

  group('scientific (DEG)', () {
    final cases = {
      'sin(0)': '0',
      'cos(0)': '1',
      'sin(30)': '1/2',
      'cos(60)': '1/2',
      'tan(45)': '1',
      'sin(90)': '1',
      'cos(90)': '0',
      'sin(180)': '0',
      'sin(-30)': '-1/2',
      'sin(390)': '1/2',
      'asin(0.5)': '30',
      'acos(0)': '90',
      'atan(1)': '45',
      'sin(45)+√16': '4.707106781',
      'log(1000)': '3',
      'log(2, 8)': '3',
      'log2(8)': '3',
      'ln(1)': '0',
      'ln(e)': '1',
      'exp(0)': '1',
      'e^1': '2.718281828',
      'pi': '3.141592654',
      '2π': '6.283185307',
      'sinh(0)': '0',
      'cosh(0)': '1',
      'sin(30°)': '1/2',
      'sin((π/6)ʳ)': '0.5',
    };
    cases.forEach((input, expected) {
      test(input, () => expect(show(input), expected));
    });
    test('RAD mode', () {
      const rad = CalcSettings(precision: 10, angleMode: AngleMode.rad);
      expect(show('sin(pi)', settings: rad), '0');
      expect(show('cos(pi)', settings: rad), '-1');
      expect(show('sin(pi/6)', settings: rad), '0.5');
      expect(show('sin(30°)', settings: rad), '0.5');
      expect(show('asin(1)', settings: rad), '1.570796327');
    });
    test('GRAD mode', () {
      const grad = CalcSettings(precision: 10, angleMode: AngleMode.grad);
      expect(show('sin(100)', settings: grad), '1');
      expect(show('cos(200)', settings: grad), '-1');
    });
    test('tan(90) is undefined', () => expect(show('tan(90)'), 'ERR:undefinedResult'));
  });

  group('exact forms', () {
    test('√8 = 2√2', () => expect(exact('√8'), '2√(2)'));
    test('sin(45) = √2/2', () => expect(exact('sin(45)'), '√(2)÷2'));
    test('1/√2', () => expect(exact('1/√2'), '√(2)÷2'));
    test('π/2', () => expect(exact('pi/2'), 'π÷2'));
  });

  group('errors', () {
    final cases = {
      '1/0': 'ERR:divisionByZero',
      'sin(': 'ERR:missingArgument',
      '2+': 'ERR:missingArgument',
      '(2+3))': 'ERR:mismatchedParentheses',
      'log(0)': 'ERR:domainError',
      'ln(-1)': 'ERR:complexResult',
      '√(-4)': 'ERR:complexResult',
      '(-1)!': 'ERR:domainError',
      'foo(2)': 'ERR:unknownIdentifier',
      'q+1': 'ERR:undefinedVariable',
      '': 'ERR:emptyInput',
      '2..3': 'ERR:invalidExpression',
      'det([[1,2],[3,4],[5,6]])': 'ERR:notSquare',
      'inv([[1,2],[2,4]])': 'ERR:singularMatrix',
      '[[1,2],[3,4]]*[[1,2,3]]': 'ERR:dimensionMismatch',
      '10^1000000000': 'ERR:overflow',
      'sin(30': '1/2',
      '((2+3)*4': '20',
    };
    cases.forEach((input, expected) {
      test(input.isEmpty ? '(empty)' : input, () => expect(show(input), expected));
    });
  });

  group('complex', () {
    test('i*i', () => expect(show('i*i'), '-1'));
    test('√(-4) with i present', () => expect(show('√(-4)+0i'), '2i'));
    test('complex results setting', () {
      expect(show('√(-4)', settings: const CalcSettings(precision: 10, complexResults: true)), '2i');
    });
    test('(3+4i) abs', () => expect(show('abs(3+4i)'), '5'));
    test('product', () => expect(show('(1+2i)(3-i)'), '5+5i'));
    test('division', () => expect(show('(1+i)/(1-i)'), 'i'));
    test('conj', () => expect(show('conj(3+4i)'), '3-4i'));
    test('arg DEG', () => expect(show('arg(1+i)'), '45'));
    test('polar entry', () => expect(show('2∠90'), '2i'));
    test('polar format', () {
      final r = engine.evaluate('1+i', const CalcSettings(precision: 10), Environment()).valueOrNull!;
      final f = const ValueFormatter(FormatOptions(complexFormat: ComplexFormat.polar)).format(r.value);
      expect(f.plain, startsWith('1.414213562∠45'));
    });
  });

  group('matrices and vectors', () {
    test('det', () => expect(show('det([[1,2],[3,4]])'), '-2'));
    test('det 3x3', () => expect(show('det([[2,0,1],[1,3,2],[1,1,2]])'), '6'));
    test('inverse', () => expect(show('inv([[1,2],[3,4]])'), '[[-2,1],[3/2,-1/2]]'));
    test('product', () => expect(show('[[1,2],[3,4]]*[[5,6],[7,8]]'), '[[19,22],[43,50]]'));
    test('transpose', () => expect(show('trn([[1,2,3],[4,5,6]])'), '[[1,4],[2,5],[3,6]]'));
    test('rank', () => expect(show('rank([[1,2],[2,4]])'), '1'));
    test('rref', () => expect(show('rref([[1,2,3],[4,5,6]])'), '[[1,0,-1],[0,1,2]]'));
    test('power', () => expect(show('[[1,1],[1,0]]^10'), '[[89,55],[55,34]]'));
    test('eigenvalues', () => expect(show('eigvals([[2,0],[0,3]])'), '[2,3]'));
    test('dot', () => expect(show('dot([1,2,3],[4,5,6])'), '32'));
    test('dot symbol', () => expect(show('[1,2,3]·[4,5,6]'), '32'));
    test('cross', () => expect(show('cross([1,0,0],[0,1,0])'), '[0,0,1]'));
    test('norm', () => expect(show('norm([3,4])'), '5'));
    test('angle', () => expect(show('angle([1,0],[0,1])'), '90'));
    test('tuple vector', () => expect(show('(1,2,3)+(4,5,6)'), '[5,7,9]'));
  });

  group('number theory', () {
    test('gcd', () => expect(show('gcd(24,18)'), '6'));
    test('lcm', () => expect(show('lcm(4,6)'), '12'));
    test('factor', () {
      final r = engine.evaluate('factor(360)', const CalcSettings(), Environment()).valueOrNull!;
      expect(const ValueFormatter(FormatOptions()).format(r.value).display, '2³ × 3² × 5');
    });
    test('isprime', () => expect(show('isprime(97)'), '1'));
    test('mod', () => expect(show('mod(-7,3)'), '2'));
    test('rem', () => expect(show('rem(-7,3)'), '-1'));
    test('quot', () => expect(show('quot(17,5)'), '3'));
    test('divisors', () => expect(show('divisors(12)'), '[1,2,3,4,6,12]'));
    test('big factorial', () => expect(show('25!'), '1.551121004E25'));
    test('large exact factorial', () {
      final r = engine.evaluate('100!', const CalcSettings(), Environment()).valueOrNull!;
      expect(ValueFormatter.exactInteger(r.value)!.length, 158);
    });
  });

  group('statistics & probability', () {
    test('mean', () => expect(show('mean(1,2,3,4)'), '5/2'));
    test('median', () => expect(show('median([3,1,2])'), '2'));
    test('var', () => expect(show('var(2,4,4,4,5,5,7,9)'), '32/7'));
    test('pstdev', () => expect(show('pstdev(2,4,4,4,5,5,7,9)'), '2'));
    test('normcdf', () => expect(show('normcdf(0)'), '0.5'));
    test('invnorm', () => expect(show('invnorm(0.975)'), '1.959963985'));
    test('binompdf', () => expect(show('binompdf(10,0.5,5)'), '0.24609375'));
    test('poissonpdf', () => expect(show('poissonpdf(2,0)'), '0.1353352832'));
  });

  group('variables and functions', () {
    test('Ans', () {
      final env = Environment(variables: {'Ans': NumberValue(Rat.int(25))});
      expect(show('Ans*2', env: env), '50');
    });
    test('assignment', () {
      final r = engine.evaluate('radius = 5', const CalcSettings(), Environment()).valueOrNull!;
      expect(r.assignedName, 'radius');
      final env = Environment(variables: r.variables);
      expect(show('π×radius²', env: env), '78.53981634');
    });
    test('store arrow', () {
      final r = engine.evaluate('7→A', const CalcSettings(), Environment()).valueOrNull!;
      expect(r.variables['A'], NumberValue(Rat.int(7)));
    });
    test('user functions', () {
      final env = Environment(functions: {'f': 'f(x)=x^2', 'g': 'g(x)=f(x)+1'});
      expect(show('g(3)', env: env), '10');
    });
    test('implicit multiplication', () {
      final env = Environment(variables: {'x': NumberValue(Rat.int(3))});
      expect(show('2x', env: env), '6');
      expect(show('3sin(30)'), '3/2');
      expect(show('2pi', settings: const CalcSettings(precision: 10)), '6.283185307');
    });
  });

  group('equations in the calculator', () {
    test('quadratic', () => expect(show('x^2-5x+6=0'), '2, 3'));
    test('linear', () => expect(show('2x+1=7'), '3'));
    test('comparison', () => expect(show('2+2=4'), '1'));
  });

  group('calculus in expressions', () {
    test('Σ k', () => expect(show('sum(k,k,1,100)'), '5050'));
    test('Π k', () => expect(show('prod(k,k,1,5)'), '120'));
    test('∫ x² 0..1', () => expect(show('integral(x^2,x,0,1)'), '1/3'));
    test('∫ sin 0..π (RAD)', () {
      expect(show('integral(sin(x),x,0,pi)', settings: const CalcSettings(precision: 10, angleMode: AngleMode.rad)), '2');
    });
    test('∫ exp(-x²) numeric', () {
      expect(show('integral(e^(-x^2),x,0,1)', settings: const CalcSettings(precision: 10, angleMode: AngleMode.rad)),
          '0.7468241328');
    });
    test('∫ to infinity', () {
      expect(show('integral(e^(-x),x,0,inf)', settings: const CalcSettings(precision: 10, angleMode: AngleMode.rad)), '1');
    });
    test('d/dx x³ at 2', () => expect(show('deriv(x^3,x,2)'), '12'));
    test('limit sin(x)/x', () {
      expect(show('lim(sin(x)/x,x,0)', settings: const CalcSettings(precision: 10, angleMode: AngleMode.rad)), '1');
    });
    test('limit at infinity', () => expect(show('lim((2x^2+1)/(x^2-3),x,inf)'), '2'));
    test('limit 1/x does not exist', () => expect(show('lim(1/x,x,0)'), 'ERR:undefinedResult'));
    test('one-sided limit', () => expect(show('limright(1/x,x,0)'), 'inf'));
  });

  group('precision', () {
    test('50 digits of √2', () {
      final r = engine.evaluate('√2', const CalcSettings(precision: 50), Environment()).valueOrNull!;
      expect(const ValueFormatter(FormatOptions(digits: 50)).format(r.value).plain,
          '1.4142135623730950488016887242096980785696718753769');
    });
    test('100 digits of π', () {
      final r = engine.evaluate('pi', const CalcSettings(precision: 100), Environment()).valueOrNull!;
      expect(const ValueFormatter(FormatOptions(digits: 100)).format(r.value).plain,
          '3.141592653589793238462643383279502884197169399375105820974944592307816406286208998628034825342117068');
    });
  });

  group('formatting', () {
    Num v(String s) => engine.evaluate(s, const CalcSettings(), Environment()).valueOrNull!.value is NumberValue
        ? (engine.evaluate(s, const CalcSettings(), Environment()).valueOrNull!.value as NumberValue).n
        : Rat.zero;
    test('scientific', () {
      final f = const NumberFormatter(FormatOptions(notation: NumberNotation.scientific)).format(v('123000000'));
      expect(f.plain, '1.23E8');
      expect(f.display, '1.23×10⁸');
    });
    test('engineering', () {
      final f = const NumberFormatter(FormatOptions(notation: NumberNotation.engineering)).format(v('1200000'));
      expect(f.plain, '1.2E6');
    });
    test('engineering symbols', () {
      final f = const NumberFormatter(FormatOptions(notation: NumberNotation.engineering, engineeringSymbols: true))
          .format(v('1200000'));
      expect(f.display, '1.2M');
    });
    test('mixed fraction', () {
      final f = const NumberFormatter(FormatOptions(fraction: FractionMode.mixed)).format(Rat.frac(5, 4));
      expect(f.display, '1 1/4');
    });
    test('decimal', () {
      final f = const NumberFormatter(FormatOptions(fraction: FractionMode.decimal)).format(Rat.frac(5, 4));
      expect(f.plain, '1.25');
    });
    test('thousands', () {
      final f = const NumberFormatter(FormatOptions(thousandsSeparator: true)).format(Rat.int(1234567));
      expect(f.display, '1,234,567');
    });
    test('small numbers', () {
      final f = const NumberFormatter(FormatOptions(fraction: FractionMode.decimal)).format(Rat.frac(1, 3));
      expect(f.plain, '0.3333333333');
    });
  });
}

