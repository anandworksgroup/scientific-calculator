import 'package:advanced_calculator/features/calculator/editor/editor_latex.dart';
import 'package:advanced_calculator/features/calculator/editor/expression_editor.dart';
import 'package:advanced_calculator/features/calculator/result_presenter.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_engine/math_engine.dart';

/// Every LaTeX form the app generates must be accepted by flutter_math;
/// otherwise users would see raw fallback text instead of textbook math.
void expectParses(String tex) {
  expect(() => TexParser(tex, const TexParserSettings()).parse(), returnsNormally, reason: tex);
}

void main() {
  const r = EditorLatexRenderer(cursorColor: '#3f51b5', placeholderColor: '#9e9e9e');

  test('editor templates', () {
    for (final t in TemplateType.values) {
      final e = ExpressionEditor()..insertTemplate(t);
      expectParses(r.render(e.tokens, e.cursor));
      final filled = ExpressionEditor()..insertTemplate(t, prefill: {for (var k = 0; k < t.slots; k++) k: '${k + 1}'});
      expectParses(r.render(filled.tokens, 0));
    }
  });

  test('editor text tokens', () {
    final e = ExpressionEditor(ExpressionEditor.tokenizeText('sin(30)×2÷3-4%+5!+Ans+@c+π+e+∞+2ᴇ5+x°+nCr'));
    expectParses(r.render(e.tokens, 3));
    const selected = EditorLatexRenderer(cursorColor: '#000000', placeholderColor: '#999999', selectionColor: '#e0e0ff');
    expectParses(selected.render(e.tokens, 0));
  });

  test('printer output for every catalog function', () {
    for (final f in builtinFunctions) {
      final args = List.filled(f.minArgs == 0 ? 0 : (f.lazy ? f.minArgs : f.minArgs), 'x');
      if (f.lazy) {
        args[1] = 'x';
      }
      final node = FunctionNode(f.name, [for (final a in args) VariableNode(a)]);
      expectParses(const LatexPrinter().print(node));
    }
  });

  test('formatter output', () {
    final nums = <Num>[
      Rat.frac(5, 4),
      Rat.frac(-7, 3),
      Rat.parseDecimal('123000000'),
      Rat.parseDecimal('0.000012'),
      Cpx.of(Rat.one, Rat.two),
    ];
    for (final n in nums) {
      for (final mode in FractionMode.values) {
        for (final notation in NumberNotation.values) {
          for (final polar in ComplexFormat.values) {
            final f = NumberFormatter(FormatOptions(fraction: mode, notation: notation, complexFormat: polar, thousandsSeparator: true, engineeringSymbols: true)).format(n);
            expectParses(f.latex);
          }
        }
      }
    }
    final m = MatrixValue([[Rat.one, Rat.frac(1, 2)], [Rat.int(3), Rat.int(4)]]);
    expectParses(const ValueFormatter(FormatOptions()).format(m).latex);
    expectParses(const ValueFormatter(FormatOptions()).format(FactorizationValue(1, [(BigInt.two, 3), (BigInt.from(5), 1)], BigInt.from(40))).latex);
  });

  test('solver steps and surds', () {
    final sol = const DefaultMathEngine().solve('x^2-5x+3=0', 'x', const CalcSettings(), Environment()).valueOrNull!;
    for (final s in sol.steps) {
      if (s.latex != null) expectParses(s.latex!);
    }
    for (final root in sol.roots) {
      expectParses(ResultPresenter.surdLatex(root.surd!));
    }
    final sys = const DefaultMathEngine()
        .solveLinearSystem([['2', '1'], ['1', '-1']], ['5', '1'], ['x', 'y'], const CalcSettings(), Environment())
        .valueOrNull!;
    for (final s in sys.steps) {
      if (s.latex != null) expectParses(s.latex!);
    }
  });

  test('onboarding and hub samples', () {
    for (final t in [
      r'\frac{1}{2}+\frac{3}{4}=\frac{5}{4}\qquad\sqrt{8}=2\sqrt{2}',
      r'x^{2}-5x+6=0\;\Rightarrow\;x=2,\,3',
      r'y=\sin x,\quad r=\sin 3\theta',
      r'\int_{0}^{1}x^{2}\,dx=\frac{1}{3}',
      r'\begin{cases}2x+y=5\\x-y=1\end{cases}',
      r'S\Leftrightarrow D',
      r'\mathrm{Ran\#}',
      r'\square\frac{\square}{\square}',
    ]) {
      expectParses(t);
    }
  });
}
