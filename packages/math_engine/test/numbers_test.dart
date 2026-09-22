import 'package:math_engine/src/core/errors.dart';
import 'package:math_engine/src/numbers/num.dart';
import 'package:test/test.dart';

String dec(Num x, [int digits = 30]) {
  final d = x is Dec ? x : Dec.fromRat(x as Rat, digits + 5);
  return d.round(digits).toString();
}

void main() {
  final a = Arith(precision: 40);

  group('Rat', () {
    test('normalizes', () {
      expect(Rat.frac(6, -4).toString(), '-3/2');
      expect(Rat.parseDecimal('1.25').toString(), '5/4');
      expect(Rat.parseDecimal('1.2E-3').toString(), '3/2500');
      expect(Rat.parseDecimal('.5').toString(), '1/2');
    });
    test('0.1 + 0.2 is exactly 0.3', () {
      expect(a.add(Rat.parseDecimal('0.1'), Rat.parseDecimal('0.2')), Rat.parseDecimal('0.3'));
    });
    test('division by zero', () {
      expect(() => a.div(Rat.one, Rat.zero), throwsA(isA<MathError>()));
    });
  });

  group('DecMath', () {
    test('pi', () {
      expect(dec(a.pi(), 40), '3.141592653589793238462643383279502884197');
    });
    test('e', () {
      expect(dec(a.e(), 40), '2.718281828459045235360287471352662497757');
    });
    test('sqrt 2', () {
      expect(dec(a.sqrt(Rat.two), 40), '1.41421356237309504880168872420969807857');
      expect(a.sqrt(Rat.int(16)), Rat.int(4));
      expect(a.sqrt(Rat.frac(9, 4)), Rat.frac(3, 2));
    });
    test('ln', () {
      expect(dec(a.ln(Rat.two), 40), '6.931471805599453094172321214581765680755e-1');
      expect(dec(a.ln(Rat.int(10)), 40), '2.302585092994045684017991454684364207601');
      expect(dec(a.ln(Rat.parseDecimal('1.0000000001')), 20), '9.9999999995e-11');
    });
    test('log10 exact', () {
      expect(a.log10(Rat.int(1000)), Rat.int(3));
      expect(a.log10(Rat.frac(1, 100)), Rat.int(-2));
      expect(a.logBase(Rat.int(2), Rat.int(8)), Rat.int(3));
    });
    test('exp', () {
      expect(dec(a.exp(Rat.int(-1)), 30), '3.67879441171442321595523770161e-1');
      expect(dec(a.exp(Rat.int(100)), 20), '2.6881171418161354484e43');
    });
    test('trig', () {
      expect(dec(a.sin(Rat.one), 30), '8.4147098480789650665250232163e-1');
      expect(dec(a.cos(Rat.one), 30), '5.40302305868139717400936607443e-1');
      expect(a.sin(a.pi()), Rat.zero);
      expect(dec(a.atan(Rat.one), 30), dec(a.div(a.pi(), Rat.int(4)), 30));
      expect(dec(a.asin(Rat.half), 30), dec(a.div(a.pi(), Rat.int(6)), 30));
      expect(dec(a.acos(Rat.parseDecimal('0.99')), 25), '1.415394733244272187457894e-1');
    });
    test('pow', () {
      expect(a.pow(Rat.int(2), Rat.int(10)), Rat.int(1024));
      expect(a.pow(Rat.int(8), Rat.frac(2, 3)), Rat.int(4));
      expect(a.pow(Rat.int(-8), Rat.frac(1, 3)), Rat.int(-2));
      expect(dec(a.pow(Rat.int(2), Rat.half), 30), dec(a.sqrt(Rat.two), 30));
      expect(() => a.pow(Rat.int(-4), Rat.half), throwsA(isA<MathError>()));
    });
    test('complex', () {
      final c = Arith(precision: 30, allowComplex: true);
      expect(c.sqrt(Rat.int(-4)), Cpx.of(Rat.zero, Rat.two));
      expect(c.abs(Cpx.of(Rat.int(3), Rat.int(4))), Rat.int(5));
      final z = c.exp(c.mul(Cpx.i, c.pi()));
      expect(z, Rat.minusOne);
    });
    test('gamma and factorial', () {
      expect(a.factorial(Rat.int(5)), Rat.int(120));
      expect(a.factorial(Rat.int(0)), Rat.one);
      expect(dec(a.gamma(Rat.half), 30), dec(a.sqrt(a.pi()), 30));
      final exact = Dec(Arith.productRange(BigInt.one, BigInt.from(30000)), 0).round(20).toString();
      expect(dec(a.factorial(Rat.int(30000)), 20), exact);
    });
  });
}


