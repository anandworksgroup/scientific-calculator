import 'package:advanced_calculator/app/providers.dart';
import 'package:advanced_calculator/features/linalg/complex_screen.dart';
import 'package:advanced_calculator/features/linalg/linalg_common.dart';
import 'package:advanced_calculator/features/linalg/matrix_screen.dart';
import 'package:advanced_calculator/features/linalg/vector_screen.dart';
import 'package:advanced_calculator/widgets/math_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_engine/math_engine.dart';

import '../helpers/test_app.dart';

void main() {
  late TestDeps deps;

  setUp(() async => deps = await TestDeps.create());
  tearDown(() async => deps.db.close());

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen, {Size size = const Size(412, 915)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(deps, screen));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(screen.runtimeType)));
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await tester.pump();
  }

  /// Spoken labels of the textbook lines in a result card; also checks that
  /// flutter_math accepts every generated LaTeX string.
  List<String> results(WidgetTester tester, String cardKey) {
    final views = tester.widgetList<MathView>(
      find.descendant(of: find.byKey(ValueKey(cardKey)), matching: find.byType(MathView)),
    );
    for (final v in views) {
      expect(() => TexParser(v.tex, const TexParserSettings()).parse(), returnsNormally, reason: v.tex);
    }
    return [for (final v in views) v.semanticsLabel ?? ''];
  }

  String? errorIn(WidgetTester tester, String cardKey, String text) {
    final f = find.descendant(of: find.byKey(ValueKey(cardKey)), matching: find.text(text));
    return f.evaluate().isEmpty ? null : text;
  }

  Future<void> enterMatrix(WidgetTester tester, List<List<String>> cells) async {
    for (var r = 0; r < cells.length; r++) {
      for (var c = 0; c < cells[r].length; c++) {
        await enter(tester, 'matrix-cell-$r-$c', cells[r][c]);
      }
    }
  }

  group('matrix', () {
    testWidgets('det and inverse of [[1,2],[3,4]]; MatA becomes a calculator variable', (tester) async {
      final c = await pump(tester, const MatrixScreen(runner: runSynchronously));
      await enterMatrix(tester, [
        ['1', '2'],
        ['3', '4'],
      ]);
      await tapKey(tester, 'matrix-op-determinant');
      await tapKey(tester, 'matrix-calculate');
      expect(results(tester, 'matrix-result').first, 'det(MatA) = −2');

      await tapKey(tester, 'matrix-op-inverse');
      await tapKey(tester, 'matrix-calculate');
      expect(results(tester, 'matrix-result').first, 'MatA⁻¹ = [−2, 1], [3/2, −1/2]');

      // Synced into the variable of the same name, usable by the calculator.
      final v = c.read(variablesProvider)['MatA'];
      expect(v, isA<MatrixValue>());
      final r = const DefaultMathEngine().evaluate('det(MatA)', const CalcSettings(), c.read(environmentProvider));
      expect((r.valueOrNull!.value as NumberValue).n, Rat.int(-2));

      // Persisted as cell text.
      final saved = await tester.runAsync(() => c.read(matricesRepositoryProvider).all());
      expect(saved!.single.name, 'MatA');
      expect(saved.single.cells, [
        ['1', '2'],
        ['3', '4'],
      ]);
      final history = await tester.runAsync(() => c.read(historyRepositoryProvider).list());
      expect(history!.where((h) => h.mode == 'matrix').length, 2);
    });

    testWidgets('singular matrix, empty operand and non-square errors are explained', (tester) async {
      await pump(tester, const MatrixScreen(runner: runSynchronously));
      await enterMatrix(tester, [
        ['1', '2'],
        ['2', '4'],
      ]);
      await tapKey(tester, 'matrix-op-inverse');
      await tapKey(tester, 'matrix-calculate');
      expect(
        errorIn(tester, 'matrix-result', 'The matrix is singular (determinant 0), so it has no inverse.'),
        isNotNull,
      );

      await tapKey(tester, 'matrix-op-add');
      await tapKey(tester, 'matrix-calculate');
      expect(
        errorIn(tester, 'matrix-result', 'MatB is empty. Enter its values in the matrix editor first.'),
        isNotNull,
      );

      await tapKey(tester, 'matrix-cols-plus');
      await tapKey(tester, 'matrix-op-determinant');
      await tapKey(tester, 'matrix-calculate');
      expect(errorIn(tester, 'matrix-result', 'The determinant requires a square matrix.'), isNotNull);
    });

    testWidgets('cell expressions, invalid cells and power', (tester) async {
      await pump(tester, const MatrixScreen(runner: runSynchronously));
      await enterMatrix(tester, [
        ['1/2', 'sqrt(4)'],
        ['0', '1'],
      ]);
      await tapKey(tester, 'matrix-op-power');
      await enter(tester, 'matrix-exponent', '2');
      await tapKey(tester, 'matrix-calculate');
      expect(results(tester, 'matrix-result').first, 'MatA^2 = [1/4, 3], [0, 1]');

      await enter(tester, 'matrix-cell-0-0', '1/');
      await tapKey(tester, 'matrix-calculate');
      final card = find.descendant(of: find.byKey(const ValueKey('matrix-result')), matching: find.byType(Text));
      expect(tester.widgetList<Text>(card).any((t) => (t.data ?? '').startsWith('MatA, row 1, column 1:')), isTrue);
    });

    testWidgets('eigenvalues run in the background isolate', (tester) async {
      await pump(tester, const MatrixScreen());
      await enterMatrix(tester, [
        ['2', '0'],
        ['0', '3'],
      ]);
      await tapKey(tester, 'matrix-op-eigen');
      await tester.tap(find.byKey(const ValueKey('matrix-calculate')));
      await tester.pump();
      for (var k = 0; k < 100 && find.byKey(const ValueKey('matrix-result')).evaluate().isEmpty; k++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      final lines = results(tester, 'matrix-result');
      expect(lines, contains('Eigenvalue 1: 2, multiplicity 1'));
      expect(lines, contains('Eigenvalue 2: 3, multiplicity 1'));
      expect(lines, contains('Eigenvector: (1, 0)'));
      expect(lines, contains('Eigenvector: (0, 1)'));
    });

    testWidgets('tablet layout shows editor and operations side by side', (tester) async {
      await pump(tester, const MatrixScreen(runner: runSynchronously), size: const Size(1024, 768));
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    test('pasted text is parsed and sanitized', () {
      expect(parseMatrixText('1\t2\n3\t4\n'), [
        ['1', '2'],
        ['3', '4'],
      ]);
      expect(parseMatrixText('1, 2; 3, 4'), [
        ['1', '2'],
        ['3', '4'],
      ]);
      expect(parseMatrixText('1 2 3\n4 5'), [
        ['1', '2', '3'],
        ['4', '5', ''],
      ]);
      expect(parseMatrixText('[[1,2],[3,−4]]'), [
        ['1', '2'],
        ['3', '-4'],
      ]);
      expect(parseMatrixText('[1, nroot(3,8); 1/3, 4]'), [
        ['1', 'nroot(3,8)'],
        ['1/3', '4'],
      ]);
      expect(parseMatrixText('  \n '), isNull);
    });
  });

  group('vector', () {
    testWidgets('dot and cross product of (1,2,3) and (4,5,6)', (tester) async {
      await pump(tester, const VectorScreen());
      for (var k = 0; k < 3; k++) {
        await enter(tester, 'vector-A-$k', '${k + 1}');
        await enter(tester, 'vector-B-$k', '${k + 4}');
      }
      await tapKey(tester, 'vector-op-dot');
      await tapKey(tester, 'vector-calculate');
      expect(results(tester, 'vector-result').first, 'A · B = 32');

      await tapKey(tester, 'vector-op-cross');
      await tapKey(tester, 'vector-calculate');
      expect(results(tester, 'vector-result').first, 'A × B = (−3, 6, −3)');

      await tapKey(tester, 'vector-op-angle');
      await tapKey(tester, 'vector-calculate');
      expect(results(tester, 'vector-result').first, startsWith('θ = 12.93'));
    });

    testWidgets('unit vector of the zero vector is an explained error', (tester) async {
      await pump(tester, const VectorScreen());
      await tapKey(tester, 'vector-op-unit');
      await tapKey(tester, 'vector-calculate');
      expect(
        errorIn(tester, 'vector-result', 'The result is undefined: the zero vector has no direction.'),
        isNotNull,
        reason: tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join('|'),
      );
    });
  });

  group('complex', () {
    testWidgets('|3+4i| = 5 and both forms of a product', (tester) async {
      await pump(tester, const ComplexScreen());
      await enter(tester, 'complex-z1-a', '3');
      await enter(tester, 'complex-z1-b', '4');
      await tapKey(tester, 'complex-op-modulus');
      await tapKey(tester, 'complex-calculate');
      expect(results(tester, 'complex-result').first, '|z₁| = 5');

      await enter(tester, 'complex-z2-a', '1');
      await enter(tester, 'complex-z2-b', '-2');
      await tapKey(tester, 'complex-op-multiply');
      await tapKey(tester, 'complex-calculate');
      final lines = results(tester, 'complex-result');
      expect(lines[0], 'z₁ × z₂ = 11 − 2i');
      expect(lines[1], startsWith('z₁ × z₂ = 11.18033989∠−10.3048464'));
    });

    testWidgets('cube roots of −8 lists all three roots', (tester) async {
      await pump(tester, const ComplexScreen());
      await enter(tester, 'complex-z1-a', '-8');
      await tapKey(tester, 'complex-op-roots');
      await enter(tester, 'complex-n', '3');
      await tapKey(tester, 'complex-calculate');
      final lines = results(tester, 'complex-result');
      expect(lines, contains('w0 = 1 + 1.732050808i'));
      expect(lines, contains('w1 = −2'));
      expect(lines, contains('w2 = 1 − 1.732050808i'));
    });

    testWidgets('polar input converts and computes', (tester) async {
      await pump(tester, const ComplexScreen());
      await enter(tester, 'complex-z1-a', '3');
      await enter(tester, 'complex-z1-b', '4');
      await tester.ensureVisible(find.text('Polar r∠θ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Polar r∠θ'));
      await tester.pumpAndSettle();
      final a = tester.widget<TextField>(find.byKey(const ValueKey('complex-z1-a')));
      expect(a.controller!.text, '5');
      await tapKey(tester, 'complex-op-real');
      await tapKey(tester, 'complex-calculate');
      expect(results(tester, 'complex-result').first, 'Re z₁ = 3');
    });
  });
}
