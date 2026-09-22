import 'package:advanced_calculator/app/providers.dart';
import 'package:advanced_calculator/features/constants/constants_screen.dart';
import 'package:advanced_calculator/features/converter/converter_screen.dart';
import 'package:advanced_calculator/features/formulas/formula_detail_screen.dart';
import 'package:advanced_calculator/features/formulas/formulas_screen.dart';
import 'package:advanced_calculator/features/number_theory/number_theory_screen.dart';
import 'package:advanced_calculator/features/programmer/programmer_screen.dart';
import 'package:advanced_calculator/features/random/random_screen.dart';
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

/// Runs engine tasks synchronously so widget tests need no real isolates.
class SyncEngineService extends EngineService {
  const SyncEngineService();

  @override
  Computation<T> run<T>(EngineResult<T> Function() task) => Computation(Future.value(task()), () {});
}

Widget app(TestDeps deps, Widget child) => ProviderScope(
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
        home: child,
      ),
    );

void expectParses(String tex) {
  expect(() => TexParser(tex, const TexParserSettings()).parse(), returnsNormally, reason: tex);
}

void main() {
  late TestDeps deps;

  setUp(() async => deps = await TestDeps.create());
  tearDown(() async => deps.db.close());

  Future<void> pump(WidgetTester tester, Widget screen, {Size size = const Size(412, 2400)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(deps, screen));
    await tester.pumpAndSettle();
  }

  group('converter', () {
    testWidgets('1 km → 1000 m and recent conversions are stored', (tester) async {
      await pump(tester, const ConverterScreen());
      await tester.enterText(find.byType(TextField).first, '1');
      await tester.pump();
      expect(find.bySemanticsLabel('From unit: Kilometer'), findsOneWidget);
      expect(find.bySemanticsLabel('To unit: Meter'), findsOneWidget);
      expect(find.bySemanticsLabel('1000 Meter'), findsOneWidget);

      // Fractions and E notation are parsed by the engine.
      await tester.enterText(find.byType(TextField).first, '2.5E3');
      await tester.pump();
      expect(find.bySemanticsLabel('2500000 Meter'), findsOneWidget);

      // After a pause the conversion is recorded.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final recent = await deps.db.db.query('recent_conversions');
      expect(recent, hasLength(1));
      expect(recent.single['result'], '2500000');
      final history = await deps.db.db.query('calculation_history');
      expect(history.single['mode'], 'converter');
    });

    testWidgets('100 °C → 212 °F; below absolute zero is explained', (tester) async {
      await pump(tester, const ConverterScreen(initialCategory: 'temperature'));
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.pump();
      expect(find.bySemanticsLabel('From unit: Celsius'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('To unit: Kelvin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fahrenheit').last);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('212 Fahrenheit'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '-300');
      await tester.pump();
      expect(find.textContaining('below absolute zero'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('swap and favorite unit', (tester) async {
      await pump(tester, const ConverterScreen());
      await tester.tap(find.byTooltip('Swap units'));
      await tester.pump();
      expect(find.bySemanticsLabel('From unit: Meter'), findsOneWidget);
      expect(find.bySemanticsLabel('1/1000 Kilometer').evaluate().isNotEmpty || find.bySemanticsLabel('0.001 Kilometer').evaluate().isNotEmpty,
          isTrue);
      await tester.tap(find.byTooltip('Add Mile to favorites'));
      await tester.pumpAndSettle();
      final favs = await deps.db.db.query('favorites');
      expect(favs.single['reference_id'], 'length.mi');
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('formulas', () {
    testWidgets('kinetic energy: solve v from E_k = 50, m = 4 → v = ±5', (tester) async {
      await pump(tester, const FormulaDetailScreen(formulaId: 'mechanics.kinetic_energy'));
      await tester.enterText(find.byKey(const ValueKey('formula-field-E_k')), '50');
      await tester.enterText(find.byKey(const ValueKey('formula-field-m')), '4');
      await tester.tap(find.text('Solve'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('v = 5'), findsOneWidget);
      expect(find.bySemanticsLabel('v = −5'), findsOneWidget);
      expect(find.textContaining('2 real solutions'), findsOneWidget);
      final history = await deps.db.db.query('calculation_history');
      expect(history.single['mode'], 'formula');
    });

    testWidgets('exactly one field must be empty', (tester) async {
      await pump(tester, const FormulaDetailScreen(formulaId: 'mechanics.kinetic_energy'));
      await tester.enterText(find.byKey(const ValueKey('formula-field-E_k')), '50');
      await tester.tap(find.text('Solve'));
      await tester.pumpAndSettle();
      expect(find.textContaining('exactly one field empty'), findsOneWidget);
    });

    testWidgets('browser search finds kinetic energy', (tester) async {
      await pump(tester, const FormulasScreen());
      await tester.enterText(find.byType(TextField), 'kinetic energy');
      await tester.pumpAndSettle();
      expect(find.text('Kinetic energy'), findsOneWidget);
    });

    test('solverEquation rewrites assignments', () {
      expect(solverEquation('E_k = 1/2*m*v^2'), '(E_k)-(1/2*m*v^2)=0');
      final r = const DefaultMathEngine().solve(solverEquation('E_k = 1/2*m*v^2'), 'v', const CalcSettings(),
          Environment(variables: {'E_k': NumberValue(Rat.int(50)), 'm': NumberValue(Rat.int(4))}));
      expect(r.valueOrNull!.roots.map((x) => x.value.toString()).toSet(), {'-5', '5'});
    });
  });

  testWidgets('programmer: 255 → FF / 11111111 / 377', (tester) async {
    await pump(tester, const ProgrammerScreen());
    await tester.enterText(find.byType(TextField), '255');
    await tester.pump();
    expect(find.text('FF'), findsOneWidget);
    expect(find.text('1111 1111'), findsOneWidget);
    expect(find.text('377'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Binary: 11111111')), findsOneWidget);

    // Bitwise keypad and bit toggling.
    await tester.tap(find.bySemanticsLabel('Insert AND'));
    await tester.tap(find.bySemanticsLabel('1'));
    await tester.tap(find.bySemanticsLabel('5'));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp(r'Hexadecimal: F(\s|$)')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Bit 7 is 0. Double tap to toggle.'));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Decimal: 143')), findsOneWidget);

    // HEX mode enables A–F; BIN disables 2–9.
    await tester.tap(find.text('BIN').first);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '10001111');
    final two = tester.widget<FilledButton>(find.ancestor(of: find.text('2'), matching: find.byType(FilledButton)).first);
    expect(two.onPressed, isNull);
  });

  testWidgets('number theory: factor(360), GCD with Euclid steps', (tester) async {
    await pump(tester, const NumberTheoryScreen());
    await tester.enterText(find.byKey(const ValueKey('nt-n')), '360');
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('360 = 2³ × 3² × 5'), findsOneWidget);
    expect(find.text('Number of divisors: 24'), findsOneWidget);
    expect(find.text('Sum of divisors: 1170'), findsOneWidget);
    expect(find.textContaining('φ(360) = 96'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('nt-list')), '48, 180');
    await tester.tap(find.text('Calculate').first);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('gcd(48, 180) = 12'), findsOneWidget);
    expect(find.bySemanticsLabel('lcm(48, 180) = 720'), findsOneWidget);

    final history = await deps.db.db.query('calculation_history');
    expect(history.map((r) => r['mode']).toSet(), {'number-theory'});
  });

  testWidgets('constants: search "planck" finds h', (tester) async {
    await pump(tester, const ConstantsScreen());
    await tester.enterText(find.byType(TextField), 'planck');
    await tester.pumpAndSettle();
    expect(find.text('Planck constant'), findsOneWidget);
    expect(find.text('Reduced Planck constant'), findsOneWidget);
    expect(find.text('Speed of light in vacuum'), findsNothing);
    expect(find.text('Use in expressions as @h'), findsOneWidget);
  });

  testWidgets('random: dice gives 1–6 and history is recorded', (tester) async {
    await pump(tester, const RandomScreen());
    await tester.tap(find.text('Roll a die'));
    await tester.pumpAndSettle();
    final shown = tester.widget<ListTile>(find.byKey(const ValueKey('rand-result-1')));
    final value = int.parse((shown.title as Text).data!);
    expect(value, inInclusiveRange(1, 6));
    final history = await deps.db.db.query('calculation_history');
    expect(history.single['mode'], 'random');
  });

  test('background tasks are sendable to a real isolate', () async {
    const service = EngineService();
    final solved = await service
        .run(formulaSolveTask('E_k = 1/2*m*v^2', 'v', const CalcSettings(),
            {'E_k': NumberValue(Rat.int(50)), 'm': NumberValue(Rat.int(4))}))
        .result;
    expect(solved.valueOrNull!.roots, hasLength(2));
    final nt = await service.run(ntAnalyzeTask('2^61-1', const CalcSettings(), Environment())).result;
    expect(nt.valueOrNull!.isPrime, isTrue);
    final gcd = await service.run(ntGcdTask('12, 18, 30', const CalcSettings(), Environment())).result;
    expect(gcd.valueOrNull!.gcd, BigInt.from(6));
    expect(gcd.valueOrNull!.lcm, BigInt.from(180));
    final div = await service.run(ntDivisionTask('-7', '2', const CalcSettings(), Environment())).result;
    expect([div.valueOrNull!.quotient, div.valueOrNull!.remainder, div.valueOrNull!.modulo],
        [BigInt.from(-3), BigInt.from(-1), BigInt.one]);
  });

  test('seeded random sequences are reproducible', () {
    List<String> seq() {
      final g = RandomGenerator(seed: 42);
      return [for (var k = 0; k < 5; k++) '${(g.call('randint(a,b)', {'a': Rat.int(1), 'b': Rat.int(1000)}) as NumberValue).n}'];
    }

    expect(seq(), seq());
    expect(seq().toSet().length, greaterThan(1));
    final distinct = RandomGenerator(seed: 1).distinct(10, BigInt.one, BigInt.from(10));
    expect(distinct.toSet(), {for (var k = 1; k <= 10; k++) BigInt.from(k)});
    expect(() => RandomGenerator().distinct(5, BigInt.one, BigInt.from(3)), throwsA(isA<MathError>()));
  });

  testWidgets('all screens build on landscape phones and tablets', (tester) async {
    for (final size in const [Size(915, 412), Size(1280, 800)]) {
      for (final screen in const <Widget>[
        ConverterScreen(),
        ConstantsScreen(),
        FormulasScreen(),
        FormulaDetailScreen(formulaId: 'mechanics.kinetic_energy'),
        ProgrammerScreen(),
        NumberTheoryScreen(),
        RandomScreen(),
      ]) {
        await pump(tester, screen, size: size);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pump(const Duration(seconds: 2));
  });

  test('every formula, constant and unit renders as LaTeX', () {
    for (final f in formulas) {
      expectParses(f.latex);
      for (final v in f.variables) {
        expectParses(v.latex);
        if (v.unit.isNotEmpty) expectParses('x\\ ${unitTexText(v.unit)}');
      }
    }
    for (final c in physicalConstants) {
      expectParses(c.latex);
      if (c.unit.isNotEmpty) expectParses('${c.latex}=1\\ ${unitTexText(c.unit)}');
    }
    for (final cat in unitCategories) {
      for (final u in cat.units) {
        expectParses('1\\ ${unitTexText(u.symbol)}');
      }
    }
    expectParses('{${unitTexText('FF AND 0F << 2 % 3 ^ 1 & ~5 | 1')}}_{16}');
  });
}
