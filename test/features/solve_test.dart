import 'package:advanced_calculator/features/solve/cas_screen.dart';
import 'package:advanced_calculator/features/solve/equation_screen.dart';
import 'package:advanced_calculator/features/solve/polynomial_screen.dart';
import 'package:advanced_calculator/features/solve/solve_common.dart';
import 'package:advanced_calculator/features/solve/system_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_engine/math_engine.dart';

import '../helpers/test_app.dart';

void main() {
  const settings = CalcSettings();

  group('LaTeX used by the solve screens parses in flutter_math_fork', () {
    void parses(String tex) {
      expect(() => TexParser(tex, const TexParserSettings()).parse(), returnsNormally, reason: tex);
    }

    test('Gauss–Jordan augmented matrices (array with |)', () {
      final r = const DefaultMathEngine().solveLinearSystem([
        ['2', '1'],
        ['1', '-1'],
      ], ['5', '1'], ['x', 'y'], settings, Environment());
      final s = (r as Success<LinearSystemSolution>).value;
      expect(s.steps.where((st) => st.latex?.contains(r'\begin{array}') ?? false), isNotEmpty);
      for (final st in s.steps) {
        if (st.latex != null) parses(st.latex!);
      }
    });

    test('surds, substitution bar, derivative and integral notation', () {
      parses(surdForms(SurdForm(Rat.frac(3, 2), Rat.frac(1, 2), BigInt.from(5))).$1);
      parses(surdForms(SurdForm(Rat.frac(1, 2), Rat.frac(-1, 2), BigInt.from(-3))).$1);
      parses(r'\left.\left(x^{2}\right)\right|_{x=2}');
      parses(r'\frac{d^{2}}{dx^{2}}\left(x^{3}\right)');
      parses(r'\int \left(x\right)\,dx');
      parses(linearComboLatex([('1', 'x^{2}'), ('-5', 'x'), ('6', '')], Environment()));
    });
  });

  group('helpers', () {
    test('surd forms', () {
      expect(surdForms(SurdForm(Rat.frac(3, 2), Rat.frac(1, 2), BigInt.from(5))).$1, r'\frac{3+\sqrt{5}}{2}');
      expect(surdForms(SurdForm(Rat.zero, Rat.minusOne, BigInt.two)).$2, '−√2');
      expect(surdForms(SurdForm(Rat.int(1), Rat.int(1), BigInt.from(-1))).$2, '1 + i');
    });

    test('linear combination preview', () {
      final env = Environment();
      expect(linearComboLatex([('1', 'x^{2}'), ('-5', 'x'), ('6', '')], env), 'x^{2}-5x+6');
      expect(linearComboLatex([('', 'x'), ('0', 'y')], env), '0');
      expect(linearComboLatex([('-1', 'x'), ('2', 'y')], env), '-x+2y');
    });

    test('unknown detection prefers x', () {
      expect(detectUnknowns(['a*x+b=0'], Environment()), ['x', 'a', 'b']);
      expect(detectUnknowns(['2t=4'], Environment()), ['t']);
    });

    test('typed linear system', () {
      final r = solveTextSystem(['2x+y=5', 'x-y=1'], settings, Environment());
      final v = (r as Success<TextSystemResult>).value;
      expect(v.status, TextSystemStatus.solved);
      expect(v.variables, ['x', 'y']);
      expect(v.solution!.values.map((n) => n.toString()), ['2', '1']);
      final y = solveTextSystem(['y = 2x + 1', 'x + y = 4'], settings, Environment());
      expect((y as Success<TextSystemResult>).value.solution!.values.map((n) => n.toString()), ['1', '3']);
    });

    test('typed nonlinear system is reported', () {
      final r = solveTextSystem(['x^2+y=1', 'x-y=0'], settings, Environment());
      final v = (r as Success<TextSystemResult>).value;
      expect(v.status, TextSystemStatus.nonlinear);
      expect(v.line, 0);
      final xy = solveTextSystem(['x*y=1', 'x+y=3'], settings, Environment());
      expect((xy as Success<TextSystemResult>).value.status, TextSystemStatus.nonlinear);
    });

    test('CAS operations', () {
      final env = Environment();
      const fo = FormatOptions();
      String plain(CasOp op, String input, {String v = 'x', String value = '', int order = 1}) {
        final r = runCas(op, input, v, value, order, settings, env, fo);
        expect(r, isA<Success<CasOutput>>(), reason: '$op $input: ${r.errorOrNull}');
        return (r as Success<CasOutput>).value.plain;
      }

      expect(plain(CasOp.factor, 'x^2-9'), anyOf('(x−3)·(x+3)', '(x+3)·(x−3)'));
      expect(plain(CasOp.expand, '(x+1)^2'), contains('2x'));
      expect(plain(CasOp.integrate, 'x'), endsWith('+ C'));
      expect(plain(CasOp.substitute, 'x^2+1', value: '3'), '10');
      expect(plain(CasOp.evaluate, '2+3'), '5');
      final s = runCas(CasOp.solve, 'x^2=4', 'x', '', 1, settings, env, fo) as Success<CasOutput>;
      expect(s.value.solution!.roots.map((r) => r.value.toString()), ['-2', '2']);
    });
  });

  group('screens', () {
    late TestDeps deps;

    setUp(() async => deps = await TestDeps.create());
    tearDown(() async => deps.db.close());

    Future<void> pump(WidgetTester tester, Widget screen, {Size size = const Size(1200, 1600)}) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(deps, screen));
      await tester.pumpAndSettle();
    }

    /// Taps [button], then lets the background isolate finish.
    Future<void> solve(WidgetTester tester, Key button, Finder until) async {
      await tester.ensureVisible(find.byKey(button));
      await tester.tap(find.byKey(button));
      await tester.pump();
      for (var k = 0; k < 300 && until.evaluate().isEmpty; k++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    Future<int> historyCount(WidgetTester tester, String mode) async {
      final rows = await tester.runAsync(
          () => deps.db.db.query('calculation_history', where: 'mode = ?', whereArgs: [mode]));
      return rows!.length;
    }

    void noTexErrors() {
      // MathView falls back to raw LaTeX text when parsing fails.
      expect(find.textContaining(r'\frac'), findsNothing);
      expect(find.textContaining(r'\begin'), findsNothing);
      expect(find.textContaining(r'\sqrt'), findsNothing);
    }

    testWidgets('equation: quadratic roots 2 and 3 with steps', (tester) async {
      await pump(tester, const EquationScreen());
      await tester.enterText(find.byKey(const Key('solve-equation-input')), 'x^2-5x+6=0');
      await tester.pump();
      await solve(tester, const Key('solve-equation-solve'), find.bySemanticsLabel('x1 = 2'));
      expect(find.bySemanticsLabel('x1 = 2'), findsOneWidget);
      expect(find.bySemanticsLabel('x2 = 3'), findsOneWidget);
      expect(find.textContaining('Δ > 0'), findsOneWidget);
      await tester.tap(find.text('Show steps'));
      await tester.pumpAndSettle();
      expect(find.textContaining('discriminant'), findsWidgets);
      noTexErrors();
      expect(await historyCount(tester, 'equation'), 1);
    });

    testWidgets('equation: irrational quadratic shows exact surd and decimal', (tester) async {
      await pump(tester, const EquationScreen());
      await tester.enterText(find.byKey(const Key('solve-equation-input')), 'x^2-3x+1=0');
      await tester.pump();
      await solve(tester, const Key('solve-equation-solve'), find.bySemanticsLabel(RegExp(r'^x1 = ')));
      expect(find.bySemanticsLabel('x1 = (3 − √5)/2'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^≈ 0\.381966')), findsOneWidget);
      noTexErrors();
    });

    testWidgets('equation: cos(x)=x is solved numerically', (tester) async {
      await pump(tester, const EquationScreen());
      await tester.enterText(find.byKey(const Key('solve-equation-input')), 'cos(x)=x');
      await tester.enterText(find.byKey(const Key('solve-equation-lower')), '-5');
      await tester.enterText(find.byKey(const Key('solve-equation-upper')), '5');
      await tester.pump();
      await solve(tester, const Key('solve-equation-solve'), find.textContaining('Numerical solution'));
      expect(find.textContaining('Numerical solution'), findsOneWidget);
      expect(find.textContaining('Searched from −5 to 5'), findsOneWidget);
      // DEG mode (the default): cos x = x at x ≈ 0.99985
      expect(find.bySemanticsLabel(RegExp(r'^x ≈ 0\.9998')), findsOneWidget);
    });

    testWidgets('equation: symbolic, identity and variable choice', (tester) async {
      await pump(tester, const EquationScreen());
      await tester.enterText(find.byKey(const Key('solve-equation-input')), 'a*x+b=0');
      await tester.pump();
      expect(find.widgetWithText(ChoiceChip, 'a'), findsOneWidget);
      await solve(tester, const Key('solve-equation-solve'), find.textContaining('in terms of the other letters'));
      expect(find.textContaining('in terms of the other letters'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('solve-equation-input')), '2(x+1)=2x+2');
      await tester.pump();
      await solve(tester, const Key('solve-equation-solve'), find.textContaining('true for all values'));
      expect(find.textContaining('true for all values of x'), findsWidgets);
    });

    testWidgets('equation: several lines are solved as a linear system', (tester) async {
      await pump(tester, const EquationScreen());
      await tester.enterText(find.byKey(const Key('solve-equation-input')), '2x+y=5\nx-y=1');
      await tester.pump();
      expect(find.textContaining('2 equations'), findsOneWidget);
      await solve(tester, const Key('solve-equation-solve'), find.bySemanticsLabel('x = 2'));
      expect(find.bySemanticsLabel('x = 2'), findsOneWidget);
      expect(find.bySemanticsLabel('y = 1'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('solve-equation-input')), 'x^2+y=1\nx-y=0');
      await tester.pump();
      await solve(tester, const Key('solve-equation-solve'), find.textContaining('not linear'));
      expect(find.textContaining('Line 1 is not linear'), findsOneWidget);
    });

    testWidgets('polynomial: example x³−6x²+11x−6 has roots 1, 2, 3', (tester) async {
      await pump(tester, const PolynomialScreen());
      await tester.tap(find.byKey(const Key('solve-poly-example')));
      await tester.pump();
      await solve(tester, const Key('solve-poly-solve'), find.bySemanticsLabel('x1 = 1'));
      expect(find.bySemanticsLabel('x1 = 1'), findsOneWidget);
      expect(find.bySemanticsLabel('x2 = 2'), findsOneWidget);
      expect(find.bySemanticsLabel('x3 = 3'), findsOneWidget);
      expect(find.textContaining('3 real, 0 complex'), findsOneWidget);
      noTexErrors();
      expect(await historyCount(tester, 'polynomial'), 1);
    });

    testWidgets('polynomial: quadratic with complex roots and discriminant', (tester) async {
      await pump(tester, const PolynomialScreen());
      await tester.tap(find.byKey(const Key('solve-poly-quadratic')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('solve-poly-coef-2')), '1');
      await tester.enterText(find.byKey(const Key('solve-poly-coef-1')), '2');
      await tester.enterText(find.byKey(const Key('solve-poly-coef-0')), '5');
      await tester.pump();
      await solve(tester, const Key('solve-poly-solve'), find.textContaining('complex conjugate'));
      expect(find.textContaining('Δ < 0'), findsOneWidget);
      expect(find.bySemanticsLabel('Discriminant −16'), findsOneWidget);
      expect(find.text('Complex'), findsNWidgets(2));
      expect(find.bySemanticsLabel(RegExp(r'^x1 = −1 [−+] 2i$')), findsOneWidget);
      noTexErrors();
    });

    testWidgets('polynomial: repeated root multiplicity', (tester) async {
      await pump(tester, const PolynomialScreen(initialDegree: 3));
      // (x-1)^2 (x+2) = x^3 - 3x + 2
      await tester.enterText(find.byKey(const Key('solve-poly-coef-3')), '1');
      await tester.enterText(find.byKey(const Key('solve-poly-coef-1')), '-3');
      await tester.enterText(find.byKey(const Key('solve-poly-coef-0')), '2');
      await tester.pump();
      await solve(tester, const Key('solve-poly-solve'), find.text('Multiplicity 2'));
      expect(find.text('Multiplicity 2'), findsOneWidget);
    });

    testWidgets('system: x = 2, y = 1 with Gauss–Jordan steps', (tester) async {
      await pump(tester, const SystemScreen());
      await tester.tap(find.byKey(const Key('solve-sys-example')));
      await tester.pump();
      await solve(tester, const Key('solve-sys-solve'), find.bySemanticsLabel('x = 2'));
      expect(find.bySemanticsLabel('x = 2'), findsOneWidget);
      expect(find.bySemanticsLabel('y = 1'), findsOneWidget);
      await tester.tap(find.text('Show steps'));
      await tester.pumpAndSettle();
      expect(find.textContaining('augmented matrix'), findsOneWidget);
      expect(tester.takeException(), isNull);
      noTexErrors();
      expect(await historyCount(tester, 'system'), 1);
    });

    testWidgets('system: fractions, no solution and infinitely many', (tester) async {
      await pump(tester, const SystemScreen());
      Future<void> fill(List<String> a, List<String> b) async {
        for (var k = 0; k < 4; k++) {
          await tester.enterText(find.byKey(Key('solve-sys-a-${k ~/ 2}-${k % 2}')), a[k]);
        }
        for (var k = 0; k < 2; k++) {
          await tester.enterText(find.byKey(Key('solve-sys-b-$k')), b[k]);
        }
        await tester.pump();
      }

      await fill(['1/3', '1', '1', '-1'], ['1', '0']);
      await solve(tester, const Key('solve-sys-solve'), find.bySemanticsLabel(RegExp(r'^x = ')));
      expect(find.bySemanticsLabel('x = 3/4'), findsOneWidget);

      await fill(['1', '1', '2', '2'], ['1', '3']);
      await solve(tester, const Key('solve-sys-solve'), find.textContaining('no solution'));
      expect(find.textContaining('no solution'), findsWidgets);

      await fill(['1', '1', '2', '2'], ['1', '2']);
      await solve(tester, const Key('solve-sys-solve'), find.textContaining('infinitely many'));
      expect(find.textContaining('infinitely many'), findsWidgets);
      expect(find.byType(Math), findsWidgets);
      noTexErrors();
    });

    testWidgets('CAS: factor x^2-9 and differentiate', (tester) async {
      await pump(tester, const CasScreen());
      await tester.enterText(find.byKey(const Key('cas-input')), 'x^2-9');
      await tester.tap(find.byKey(const Key('cas-op-factor')));
      await tester.pump();
      await solve(tester, const Key('cas-run'), find.byKey(const Key('cas-plain')));
      final text = tester.widget<SelectableText>(find.byKey(const Key('cas-plain'))).data;
      expect(text, anyOf('(x−3)·(x+3)', '(x+3)·(x−3)'));
      expect(find.byKey(const Key('cas-send')), findsOneWidget);
      expect(await historyCount(tester, 'cas'), 1);

      await tester.tap(find.byKey(const Key('cas-op-differentiate')));
      await tester.pump();
      final derivative = find.byWidgetPredicate((w) => w is SelectableText && w.key == const Key('cas-plain') && w.data == '2x');
      await solve(tester, const Key('cas-run'), derivative);
      expect(derivative, findsOneWidget);
      noTexErrors();
    });

    testWidgets('phone portrait and landscape layouts build', (tester) async {
      for (final screen in const [EquationScreen(), PolynomialScreen(), SystemScreen(), CasScreen()]) {
        await pump(tester, screen, size: const Size(412, 915));
        expect(tester.takeException(), isNull);
        await pump(tester, screen, size: const Size(915, 412));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
