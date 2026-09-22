import 'package:advanced_calculator/features/calculator/calculator_controller.dart';
import 'package:advanced_calculator/features/calculator/calculator_screen.dart';
import 'package:advanced_calculator/features/calculator/result_presenter.dart';
import 'package:advanced_calculator/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  late TestDeps deps;

  setUp(() async => deps = await TestDeps.create());
  tearDown(() async => deps.db.close());

  Future<ProviderContainer> pump(WidgetTester tester, {Size size = const Size(412, 915)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(deps, const CalculatorScreen()));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(CalculatorScreen)));
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final f = find.bySemanticsLabel(label);
    expect(f, findsWidgets, reason: 'key "$label"');
    await tester.tap(f.first);
    await tester.pump();
  }

  String shown(ProviderContainer c) {
    final s = c.read(calculatorProvider);
    if (s.error != null) return 'ERR:${s.error!.code.name} [${c.read(calculatorProvider.notifier).editor.toEngineText()}]';
    final r = s.result;
    if (r == null) return '';
    return ResultPresenter(c.read(settingsProvider)).main(r.evaluation, s.view).plain;
  }

  testWidgets('2 + 5 × 4 = 22 using keys', (tester) async {
    final c = await pump(tester);
    for (final k in ['2', 'Plus', '5', 'Times', '4', 'Equals']) {
      await tap(tester, k);
    }
    await tester.pumpAndSettle();
    expect(shown(c), '22');
  });

  testWidgets('fraction template and S⇔D', (tester) async {
    final c = await pump(tester);
    // 1 [a/b] 2 → cursor in denominator
    await tap(tester, '1');
    await tap(tester, 'Fraction');
    await tap(tester, '2');
    await tap(tester, 'Move cursor right');
    await tap(tester, 'Plus');
    await tap(tester, '3');
    await tap(tester, 'Fraction');
    await tap(tester, '4');
    await tap(tester, 'Equals');
    await tester.pumpAndSettle();
    expect(shown(c), '5/4');
    await tap(tester, 'Switch between exact and decimal');
    await tester.pumpAndSettle();
    expect(shown(c), '1.25');
  });

  testWidgets('Ans continues after an operator', (tester) async {
    final c = await pump(tester);
    for (final k in ['5', 'Times', '5', 'Equals']) {
      await tap(tester, k);
    }
    await tester.pumpAndSettle();
    expect(shown(c), '25');
    for (final k in ['Times', '2', 'Equals']) {
      await tap(tester, k);
    }
    await tester.pumpAndSettle();
    expect(shown(c), '50');
  });

  testWidgets('sin 30 in DEG, SHIFT gives inverse', (tester) async {
    final c = await pump(tester);
    for (final k in ['Sine', '3', '0', 'Equals']) {
      await tap(tester, k);
    }
    await tester.pumpAndSettle();
    expect(shown(c), '1/2');
    await tap(tester, 'AC'.isEmpty ? '' : 'All clear');
    await tap(tester, 'Shift');
    await tap(tester, 'Inverse sine'); // key label changes under SHIFT
    await tap(tester, '1');
    await tap(tester, 'Equals');
    await tester.pumpAndSettle();
    expect(shown(c), '90');
  });

  testWidgets('errors are explained, not just ERROR', (tester) async {
    final c = await pump(tester);
    for (final k in ['1', 'Divided by', '0', 'Equals']) {
      await tap(tester, k);
    }
    await tester.pumpAndSettle();
    expect(shown(c), startsWith('ERR:divisionByZero'));
    expect(find.textContaining('Division by zero'), findsOneWidget);
  });

  testWidgets('DEL removes a whole function token', (tester) async {
    final c = await pump(tester);
    await tap(tester, 'Natural logarithm');
    expect(c.read(calculatorProvider).tokens.length, 1);
    await tap(tester, 'Delete');
    expect(c.read(calculatorProvider).tokens, isEmpty);
  });

  testWidgets('STO stores into a variable and history records it', (tester) async {
    final c = await pump(tester);
    for (final k in ['7', 'Equals']) {
      await tap(tester, k);
    }
    await tester.pumpAndSettle();
    await tap(tester, 'Store');
    await tap(tester, 'Variable A'); // ALPHA layer is active after STO
    await tester.pumpAndSettle();
    expect(c.read(variablesProvider)['A'], isNotNull);
    final history = await deps.db.db.query('calculation_history');
    expect(history, hasLength(1));
  });

  testWidgets('landscape and tablet layouts build', (tester) async {
    await pump(tester, size: const Size(915, 412));
    expect(find.bySemanticsLabel('Definite integral'), findsWidgets);
    await pump(tester, size: const Size(1280, 800));
    expect(find.byType(CalculatorScreen), findsOneWidget);
  });
}
