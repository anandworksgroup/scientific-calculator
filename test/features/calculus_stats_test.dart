import 'package:advanced_calculator/app/providers.dart';
import 'package:advanced_calculator/features/calculus/derivative_screen.dart';
import 'package:advanced_calculator/features/calculus/integral_screen.dart';
import 'package:advanced_calculator/features/calculus/limit_screen.dart';
import 'package:advanced_calculator/features/calculus/series_screen.dart';
import 'package:advanced_calculator/features/stats/probability_screen.dart';
import 'package:advanced_calculator/features/stats/statistics_screen.dart';
import 'package:advanced_calculator/features/table/function_table_screen.dart';
import 'package:advanced_calculator/l10n/generated/app_localizations.dart';
import 'package:advanced_calculator/services/engine_service.dart';
import 'package:advanced_calculator/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_engine/math_engine.dart';

import '../helpers/test_app.dart';

/// Runs engine tasks synchronously (widget tests use a fake clock, so
/// real isolates would never report back).
class SyncEngineService extends EngineService {
  const SyncEngineService();

  @override
  Computation<T> run<T>(EngineResult<T> Function() task) => Computation(Future.value(task()), () {});
}

void main() {
  late TestDeps deps;
  final l = lookupAppLocalizations(const Locale('en'));

  setUp(() async => deps = await TestDeps.create());
  tearDown(() async => deps.db.close());

  Future<void> pump(WidgetTester tester, Widget screen, {Size size = const Size(1280, 1100)}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...deps.overrides().cast(),
        engineServiceProvider.overrideWithValue(const SyncEngineService()),
      ],
      child: MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light, accent: 'indigo'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final f = find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));
    final target = f.evaluate().isEmpty ? find.byKey(ValueKey(key)) : f;
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
    await tester.enterText(target.first, text);
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Future<List<String>> historyModes() async =>
      [for (final r in await deps.db.db.query('calculation_history')) r['mode'] as String];

  Finder label(String pattern) => find.bySemanticsLabel(RegExp(pattern));

  testWidgets('d/dx(x^3+2x) = 3x^2+2', (tester) async {
    await pump(tester, const DerivativeScreen());
    await enter(tester, 'derivative.f', 'x^3+2x');
    await tapText(tester, l.calculusDifferentiate);
    expect(label(r'3·x\^2\+2'), findsWidgets);
    expect(find.textContaining('Error'), findsNothing);
    expect(await historyModes(), contains('derivative'));
  });

  testWidgets('derivative value at a point is exact, partial derivatives hold others constant', (tester) async {
    await pump(tester, const DerivativeScreen());
    await enter(tester, 'derivative.f', 'sin(x)');
    await enter(tester, 'derivative.at', 'pi/4');
    await tapText(tester, l.calculusDifferentiate);
    expect(label(r'cos'), findsWidgets);
    expect(label('${RegExp.escape(l.calculusValueAt)}: √\\(2\\)÷2'), findsWidgets);

    await enter(tester, 'derivative.f', 'x^2*y+y^3');
    await enter(tester, 'derivative.var', 'y');
    await enter(tester, 'derivative.at', '');
    await tapText(tester, l.calculusDifferentiate);
    expect(find.text(l.calculusPartialHeld), findsOneWidget);
    expect(label(r'x\^2\+3·y\^2'), findsWidgets);
  });

  testWidgets('∫_0^1 x^2 dx = 1/3 with antiderivative + C', (tester) async {
    await pump(tester, const IntegralScreen());
    await enter(tester, 'integral.f', 'x^2');
    await enter(tester, 'integral.lower', '0');
    await enter(tester, 'integral.upper', '1');
    await tapText(tester, l.calculusIntegrate);
    expect(label('${RegExp.escape(l.calculusDefiniteExact)}: 1/3'), findsWidgets);
    expect(label(r'\+ C'), findsWidgets);
    expect(await historyModes(), contains('integral'));
  });

  testWidgets('divergent integral is explained', (tester) async {
    await pump(tester, const IntegralScreen());
    await enter(tester, 'integral.f', '1/x');
    await enter(tester, 'integral.lower', '0');
    await enter(tester, 'integral.upper', '1');
    await tapText(tester, l.calculusIntegrate);
    expect(find.text(l.calculusDivergenceHint), findsOneWidget);
  });

  testWidgets('lim sin(x)/x = 1, one-sided 1/x = ∞', (tester) async {
    await pump(tester, const LimitScreen());
    await enter(tester, 'limit.f', 'sin(x)/x');
    await tapText(tester, l.calculusFindLimit);
    expect(label('${RegExp.escape(l.calculusLimitResult)}: 1\$'), findsWidgets);
    expect(await historyModes(), contains('limit'));

    await enter(tester, 'limit.f', '1/x');
    await tapText(tester, l.calculusSideRight);
    await tapText(tester, l.calculusFindLimit);
    expect(label('${RegExp.escape(l.calculusLimitResult)}: ∞'), findsWidgets);

    await tapText(tester, l.calculusSideBoth);
    await tapText(tester, l.calculusFindLimit);
    expect(find.text(l.calculusLimitDneHint), findsOneWidget);
  });

  testWidgets('Σ k from 1 to 100 = 5050 and Π k 1..5 = 120', (tester) async {
    await pump(tester, const SeriesScreen());
    await enter(tester, 'series.term', 'k');
    await enter(tester, 'series.lower', '1');
    await enter(tester, 'series.upper', '100');
    await tapText(tester, l.actionCalculate);
    expect(label('${RegExp.escape(l.calculusSum)}: 5050'), findsWidgets);

    await tapText(tester, l.calculusProduct);
    await enter(tester, 'series.upper', '5');
    await tapText(tester, l.actionCalculate);
    expect(label('${RegExp.escape(l.calculusProduct)}: 120'), findsWidgets);
    expect(await historyModes(), contains('series'));
  });

  testWidgets('mean of 1,2,3,4 = 5/2', (tester) async {
    await pump(tester, const StatisticsScreen(), size: const Size(1280, 2600));
    await tapText(tester, l.statsAddRow);
    for (var k = 0; k < 4; k++) {
      await enter(tester, 'stats.a.$k', '${k + 1}');
    }
    await tapText(tester, l.statsCalculate);
    expect(label('${RegExp.escape(l.statsMean)}: 5/2'), findsWidgets);
    expect(label('${RegExp.escape(l.statsMedian)}: 5/2'), findsWidgets);
    expect(label('${RegExp.escape(l.statsSum)}: 10'), findsWidgets);
    expect(await historyModes(), contains('statistics'));

    // Percentile (type 7): P50 = 2.5.
    await enter(tester, 'stats.percentile', '50');
    await tester.ensureVisible(find.widgetWithText(FilledButton, l.actionCalculate));
    await tester.tap(find.widgetWithText(FilledButton, l.actionCalculate));
    await tester.pumpAndSettle();
    expect(label('${RegExp.escape(l.statsPercentile)}: 5/2'), findsWidgets);
  });

  testWidgets('statistics reports a bad cell by row', (tester) async {
    await pump(tester, const StatisticsScreen(), size: const Size(1280, 2600));
    await enter(tester, 'stats.a.0', '1');
    await enter(tester, 'stats.a.1', 'abc(');
    await tapText(tester, l.statsCalculate);
    expect(find.textContaining('Row 2'), findsOneWidget);
  });

  testWidgets('two-variable linear regression y = 1 + 2x', (tester) async {
    await pump(tester, const StatisticsScreen(), size: const Size(1280, 2600));
    await tapText(tester, l.statsTwoVariable);
    const xs = ['1', '2', '3'], ys = ['3', '5', '7'];
    for (var k = 0; k < 3; k++) {
      await enter(tester, 'stats.a.$k', xs[k]);
      await enter(tester, 'stats.b.$k', ys[k]);
    }
    await tapText(tester, l.statsCalculate);
    expect(label(r'y = 1 \+ 2·x'), findsWidgets);
    expect(label('${RegExp.escape(l.statsCorrelation)}: 1'), findsWidgets);
    await enter(tester, 'stats.predictX', '10');
    await tapText(tester, l.statsPredict);
    expect(label('${RegExp.escape(l.statsPredictedY)}: 21'), findsWidgets);
  });

  testWidgets('nCr(10,3) = 120', (tester) async {
    await pump(tester, const ProbabilityScreen());
    await enter(tester, 'prob.combinatorics.n', '10');
    await enter(tester, 'prob.combinatorics.r', '3');
    await tester.tap(find.byKey(const ValueKey('prob.combinatorics.calculate')));
    await tester.pumpAndSettle();
    expect(label('${RegExp.escape(l.probCombinations)}: 120'), findsWidgets);
    expect(label('${RegExp.escape(l.probPermutations)}: 720'), findsWidgets);
    expect(label('${RegExp.escape(l.probFactorial)}: 3628800'), findsWidgets);
    expect(await historyModes(), contains('probability'));
  });

  testWidgets('binomial tab gives exact probabilities', (tester) async {
    await pump(tester, const ProbabilityScreen());
    await tapText(tester, l.probBinomial);
    await tester.tap(find.byKey(const ValueKey('prob.binomial.calculate')));
    await tester.pumpAndSettle();
    // n = 10, p = 0.5, k = 3: P(X = 3) = 120/1024 = 15/128.
    expect(label('${RegExp.escape(l.probPmf)}: 15/128'), findsWidgets);
  });

  testWidgets('table of x^2 from -5 to 5 has 11 rows', (tester) async {
    await pump(tester, const FunctionTableScreen(initialExpression: 'x^2'));
    await tapText(tester, l.tableBuild);
    expect(find.text(l.tableRowCount(11)), findsOneWidget);
    expect(await historyModes(), contains('table'));
  });

  testWidgets('screens build on phone portrait and landscape', (tester) async {
    for (final size in const [Size(412, 915), Size(915, 412)]) {
      for (final s in const <Widget>[
        DerivativeScreen(),
        IntegralScreen(),
        LimitScreen(),
        SeriesScreen(),
        StatisticsScreen(),
        ProbabilityScreen(),
        FunctionTableScreen(initialExpression: 'x^2'),
      ]) {
        await pump(tester, s, size: size);
        expect(tester.takeException(), isNull);
      }
    }
  });

  test('tasks return sendable results from a real isolate', () async {
    const s = EngineService();
    const settings = CalcSettings(angleMode: AngleMode.rad);
    final env = Environment();
    final d = await s.run(() => derivativeTask('x^3+2x', 'x', 1, '2', settings, env)).result;
    expect(d.valueOrNull?.valueAt, Rat.int(14));
    final i = await s.run(() => integralTask('x^2', 'x', '0', '1', settings, env)).result;
    expect(i.valueOrNull?.value, Rat.frac(1, 3));
    final lim = await s.run(() => limitTask('sin(x)/x', 'x', '0', 0, settings, env)).result;
    expect((lim.valueOrNull as NumberValue).n, Rat.one);
    final sum = await s.run(() => seriesTask(false, 'k', 'k', '1', '100', settings, env)).result;
    expect((sum.valueOrNull?.value as NumberValue).n, Rat.int(5050));
    final st = await s.run(() => statisticsTask(true, false, ['1', '2', '3'], ['3', '5', '7'], settings, env)).result;
    expect(st.valueOrNull?.two?.fits[RegressionType.linear]?.valueOrNull?.coefficients, [Rat.int(1), Rat.int(2)]);
    final pr = await s.run(() => probabilityTask(ProbDist.normal, {'mu': '0', 'sigma': '1', 'x': '0'}, settings, env)).result;
    expect(pr.valueOrNull?.firstWhere((e) => e.quantity == ProbQuantity.normCdf).result.valueOrNull?.toDouble(), closeTo(0.5, 1e-12));
    final t = await s.run(() => functionTableTask('x^2', 'x', '-5', '5', '1', settings, env)).result;
    expect(t.valueOrNull?.length, 11);
  });

  test('pasted data parsing', () {
    expect(parsePastedData('1, 2 3\n4;5'), [
      ['1', '2', '3'],
      ['4', '5'],
    ]);
    expect(parsePastedData('1\t2\r\n3\t4\n\n'), [
      ['1', '2'],
      ['3', '4'],
    ]);
  });

  test('generated LaTeX forms are accepted by flutter_math', () {
    const forms = [
      r'\frac{d}{d x}\left({x}^{3}\right)=3\,{x}^{2}',
      r'\frac{\partial^{2}}{\partial y^{2}}\left(x\right)',
      r'\frac{\partial^{3} f}{\partial x_{1}^{3}}',
      r"f'''(x)=0",
      r'f^{(4)}(x)=0',
      r"\left.f'(x)\right|_{x=\frac{\pi}{4}}=\frac{\sqrt{2}}{2}",
      r'\frac{d}{d x}\left(x\right)\Big|_{x=2}',
      r'\int {x}^{2}\,dx=\frac{{x}^{3}}{3}+C',
      r'\int_{0}^{\infty}{x}^{2}\,dx\approx 1',
      r'\pm 1.6\times10^{-14}',
      r'\lim_{x\to {0}^{-}}\left(x\right)=-\infty',
      r'\lim_{x\to {{2}^{3}}^{+}}\left(x\right)',
      r'\sum_{k=1}^{\square}\square',
      r'\prod_{k=1}^{5}\left(k\right)=120',
      r'\text{—}',
      r'\sum x^{2}=30',
      r'\bar{x}=\frac{5}{2}',
      r'\tilde{x}=1',
      r'\hat{y}=21',
      r'\mathrm{range}=3',
      r'\mathrm{IQR}=2',
      r'\sigma_{xy}=1',
      r's_{xy}=1',
      r'Q_{1}=1',
      r'P_{90}=4',
      r'y=1+2\,x-3\,x^{2}',
      r'y=2\,e^{-0.5\,x}',
      r'y=1+2\,\ln x',
      r'y=2\,x^{-0.5}',
      r'\binom{10}{3}=120',
      r'{}^{10}P_{3}=720',
      r'{10}!=3628800',
      r'X\sim N\left({0},\ {1}^{2}\right)',
      r'X\sim B\left({10},\ {0.5}\right)',
      r'X\sim \mathrm{Po}\left({2}\right)',
      r'P\left(X\le x\right)={0.95}\Rightarrow x=1.64',
      r'\min\left\{k:P\left(X\le k\right)\ge {0.5}\right\}=5',
      r'P\left({-1}\le X\le {1}\right)',
      r'{x}^{2},\ x=-5\ldots 5',
      r'\text{11}',
    ];
    for (final tex in forms) {
      expect(() => TexParser(tex, const TexParserSettings()).parse(), returnsNormally, reason: tex);
    }
  });
}
