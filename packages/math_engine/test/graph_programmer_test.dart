import 'dart:math' as math;

import 'package:math_engine/math_engine.dart';
import 'package:test/test.dart';

CurveSamples sample(String expr, {GraphType type = GraphType.cartesian, String y = '', double tMax = 2 * math.pi,
    Viewport vp = const Viewport(-10, 10, -10, 10, 800, 800)}) {
  final g = CompiledGraph.compile(
      GraphSpec(id: 'a', type: type, expression: expr, expressionY: y, tMax: tMax), Environment());
  return GraphSampler(vp).sample(g);
}

/// Largest vertical screen jump between consecutive points of any polyline.
double maxJumpPx(CurveSamples s, Viewport vp) {
  var m = 0.0;
  for (final p in s.polylines) {
    for (var k = 2; k + 1 < p.length; k += 2) {
      final a = vp.toPy(p[k - 1]), b = vp.toPy(p[k + 1]);
      // Only count segments that are at least partly visible.
      if ((a < 0 && b < 0) || (a > vp.heightPx && b > vp.heightPx)) continue;
      m = math.max(m, (a - b).abs());
    }
  }
  return m;
}

void main() {
  const vp = Viewport(-10, 10, -10, 10, 800, 800);

  group('graph sampling', () {
    for (final f in ['sin(x)', 'cos(x)', 'x^2', 'x^3', 'sqrt(x)', 'ln(x)', 'e^x']) {
      test('$f is continuous and smooth', () {
        final s = sample(f);
        expect(s.polylines, isNotEmpty);
        expect(maxJumpPx(s, vp), lessThan(60));
      });
    }
    test('tan(x) breaks at asymptotes', () {
      final s = sample('tan(x)');
      // −10..10 contains 6 odd multiples of π/2, so ≥ 7 separate branches.
      expect(s.polylines.length, greaterThanOrEqualTo(7));
      expect(maxJumpPx(s, vp), lessThan(400));
    });
    test('1/x is not connected across 0', () {
      final s = sample('1/x');
      expect(s.polylines.length, greaterThanOrEqualTo(2));
      for (final p in s.polylines) {
        var neg = false, pos = false;
        for (var k = 0; k < p.length; k += 2) {
          if (p[k] < -1e-9) neg = true;
          if (p[k] > 1e-9) pos = true;
        }
        expect(neg && pos, isFalse, reason: 'a polyline crosses x = 0');
      }
    });
    test('floor(x) steps are not joined', () {
      final s = sample('floor(x)');
      expect(s.polylines.length, greaterThanOrEqualTo(18));
    });
    test('sqrt(x) starts at 0', () {
      final s = sample('sqrt(x)');
      final minX = s.polylines.map((p) => p[0]).reduce(math.min);
      expect(minX, lessThan(0.05));
      expect(minX, greaterThanOrEqualTo(0));
    });
    test('polar rose', () {
      final s = sample('sin(3θ)', type: GraphType.polar);
      expect(s.polylines, isNotEmpty);
      final pts = s.polylines.first;
      for (var k = 0; k < pts.length; k += 2) {
        expect(math.sqrt(pts[k] * pts[k] + pts[k + 1] * pts[k + 1]), lessThanOrEqualTo(1.0000001));
      }
    });
    test('parametric circle', () {
      final s = sample('cos(t)', type: GraphType.parametric, y: 'sin(t)');
      final pts = s.polylines.first;
      for (var k = 0; k < pts.length; k += 2) {
        expect(pts[k] * pts[k] + pts[k + 1] * pts[k + 1], closeTo(1, 1e-9));
      }
    });
    test('implicit circle', () {
      final s = sample('x^2+y^2=16', type: GraphType.implicit);
      final pts = s.polylines.first;
      expect(pts.length, greaterThan(40));
      for (var k = 0; k < pts.length; k += 2) {
        expect(math.sqrt(pts[k] * pts[k] + pts[k + 1] * pts[k + 1]), closeTo(4, 0.05));
      }
    });
    test('y = prefix accepted', () => expect(sample('y = x^2').polylines, isNotEmpty));
    test('type detection', () {
      expect(CompiledGraph.detectType('y=x^2'), GraphType.cartesian);
      expect(CompiledGraph.detectType('r=sin(3θ)'), GraphType.polar);
      expect(CompiledGraph.detectType('x^2+y^2=4'), GraphType.implicit);
      expect(CompiledGraph.detectType('sin(x)'), GraphType.cartesian);
    });
    test('invalid expression throws MathError', () {
      expect(() => sample('sin('), throwsA(isA<MathError>()));
    });
  });

  group('graph analysis', () {
    double f(double x) => x * x - 4;
    test('roots', () {
      final r = GraphAnalysis.roots(f, -10, 10).map((p) => p.x).toList();
      expect(r.length, 2);
      expect(r[0], closeTo(-2, 1e-9));
      expect(r[1], closeTo(2, 1e-9));
    });
    test('tangential root', () {
      final r = GraphAnalysis.roots((x) => (x - 1) * (x - 1), -5, 5);
      expect(r.single.x, closeTo(1, 1e-5));
    });
    test('no roots at poles', () {
      expect(GraphAnalysis.roots((x) => 1 / x, -5, 5), isEmpty);
    });
    test('extrema', () {
      final e = GraphAnalysis.extrema((x) => x * x * x - 3 * x, -3, 3);
      expect(e.length, 2);
      expect(e[0].kind, PointKind.maximum);
      expect(e[0].x, closeTo(-1, 1e-6));
      expect(e[1].kind, PointKind.minimum);
      expect(e[1].y, closeTo(-2, 1e-9));
    });
    test('intersections', () {
      final i = GraphAnalysis.intersections(math.sin, math.cos, 0, 3);
      expect(i.single.x, closeTo(math.pi / 4, 1e-9));
    });
    test('tangent', () {
      final t = GraphAnalysis.tangent((x) => x * x, 3);
      expect(t.slope, closeTo(6, 1e-8));
      expect(t.intercept, closeTo(-9, 1e-7));
    });
    test('area', () {
      final (v, err) = GraphAnalysis.area((x) => x * x, 0, 3);
      expect(v, closeTo(9, 1e-12));
      expect(err, lessThan(1e-9));
    });
    test('y intercept', () => expect(GraphAnalysis.yIntercept((x) => x + 5)!.y, 5));
    test('nice steps', () {
      expect(GraphAnalysis.niceStep(20), 2);
      expect(GraphAnalysis.niceStep(1), 0.1);
      expect(GraphAnalysis.niceStep(700), 100);
    });
  });

  group('programmer', () {
    final c = ProgrammerCalc(bits: 8, signed: false);
    test('base conversion 255', () {
      final v = BigInt.from(255);
      expect(c.format(v, IntBase.hex), 'FF');
      expect(c.format(v, IntBase.bin), '11111111');
      expect(c.format(v, IntBase.oct), '377');
      expect(c.format(v, IntBase.dec), '255');
    });
    test('unsigned wrap', () => expect(c.evaluate('255+1', IntBase.dec), BigInt.zero));
    test('signed wrap', () {
      final s = ProgrammerCalc(bits: 8, signed: true);
      expect(s.evaluate('127+1', IntBase.dec), BigInt.from(-128));
      expect(s.format(BigInt.from(-1), IntBase.hex), 'FF');
      expect(s.format(BigInt.from(-1), IntBase.bin), '11111111');
    });
    test('bitwise ops', () {
      final p = ProgrammerCalc(bits: 16, signed: false);
      expect(p.evaluate('F0 AND 3C', IntBase.hex), BigInt.from(0x30));
      expect(p.evaluate('F0 | 0F', IntBase.hex), BigInt.from(0xFF));
      expect(p.evaluate('F0 XOR FF', IntBase.hex), BigInt.from(0x0F));
      expect(p.evaluate('NOT 0', IntBase.hex), BigInt.from(0xFFFF));
      expect(p.evaluate('F0 NAND FF', IntBase.hex), BigInt.from(0xFF0F));
      expect(p.evaluate('0 NOR 0', IntBase.hex), BigInt.from(0xFFFF));
      expect(p.evaluate('1 << 4', IntBase.dec), BigInt.from(16));
      expect(p.evaluate('256 >> 2', IntBase.dec), BigInt.from(64));
      expect(p.evaluate('1011 + 1', IntBase.bin), BigInt.from(12));
    });
    test('arithmetic shift in signed mode', () {
      final s = ProgrammerCalc(bits: 8, signed: true);
      expect(s.evaluate('-8 >> 1', IntBase.dec), BigInt.from(-4));
    });
    test('division truncates and by zero errors', () {
      final s = ProgrammerCalc(bits: 32, signed: true);
      expect(s.evaluate('-7/2', IntBase.dec), BigInt.from(-3));
      expect(() => s.evaluate('1/0', IntBase.dec), throwsA(isA<MathError>()));
    });
    test('invalid digit', () {
      expect(() => c.evaluate('102', IntBase.bin), throwsA(isA<MathError>()));
    });
    test('64-bit', () {
      final s = ProgrammerCalc(bits: 64, signed: false);
      expect(s.format(s.evaluate('0 - 1', IntBase.dec), IntBase.hex), 'FFFFFFFFFFFFFFFF');
    });
    test('bit list', () => expect(c.bitList(BigInt.from(5)).where((b) => b).length, 2));
  });

  group('function table', () {
    test('x² from −5 to 5', () {
      final r = FunctionTable.build(
          expression: 'x^2', variable: 'x', start: '-5', end: '5', step: '1',
          settings: const CalcSettings(), env: Environment()).valueOrNull!;
      expect(r.length, 11);
      expect((r.first.value as NumberValue).n, Rat.int(25));
      expect((r[5].value as NumberValue).n, Rat.zero);
    });
    test('exact decimal steps', () {
      final r = FunctionTable.build(
          expression: 'f(x)=x', variable: 'x', start: '0', end: '1', step: '0.1',
          settings: const CalcSettings(), env: Environment()).valueOrNull!;
      expect(r.length, 11);
      expect(r.last.x, Rat.one);
    });
    test('errors per row', () {
      final r = FunctionTable.build(
          expression: '1/x', variable: 'x', start: '-1', end: '1', step: '1',
          settings: const CalcSettings(), env: Environment()).valueOrNull!;
      expect(r[1].error?.code, MathErrorCode.divisionByZero);
    });
  });
}
