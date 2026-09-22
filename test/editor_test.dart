import 'package:advanced_calculator/features/calculator/editor/editor_latex.dart';
import 'package:advanced_calculator/features/calculator/editor/expression_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_engine/math_engine.dart';

String eval(ExpressionEditor e) {
  final r = const DefaultMathEngine().evaluate(e.toEngineText(), const CalcSettings(), Environment());
  final v = r.valueOrNull?.value;
  return v == null ? 'ERR:${r.errorOrNull?.code.name}' : const ValueFormatter(FormatOptions()).format(v).plain;
}

void main() {
  test('fraction template wraps the previous number', () {
    final e = ExpressionEditor()
      ..insertText('12')
      ..insertTemplate(TemplateType.frac, wrapPrevious: true)
      ..insertText('4');
    expect(e.toEngineText(), '((12)/(4))');
    expect(eval(e), '3');
  });

  test('cursor moves through structure slots', () {
    final e = ExpressionEditor()..insertTemplate(TemplateType.frac);
    e.insertText('1');
    e.moveRight(); // numerator → denominator
    e.insertText('3');
    e.moveRight(); // out of the fraction
    e.insertText('+1');
    expect(eval(e), '4/3');
  });

  test('backspace at slot start removes the structure but keeps content', () {
    final e = ExpressionEditor()..insertTemplate(TemplateType.sqrt);
    e.insertText('9');
    e.moveLeft(); // before 9, at slot start
    e.backspace();
    expect(e.toEngineText(), '9');
  });

  test('backspace after a structure steps inside', () {
    final e = ExpressionEditor()..insertClosedTemplate(TemplateType.pow, {0: '2'});
    final before = e.tokens.length;
    e.backspace();
    expect(e.tokens.length, before);
    e.backspace();
    expect(e.toEngineText(), '^()');
  });

  test('undo and redo', () {
    final e = ExpressionEditor()..insertText('5');
    e.insertText('+');
    e.undo();
    expect(e.toEngineText(), '5');
    e.redo();
    expect(e.toEngineText(), '5+');
  });

  test('integral, sum and derivative templates evaluate', () {
    final i = ExpressionEditor()..insertTemplate(TemplateType.integral, prefill: {0: '0', 1: '1', 2: 'x^2'});
    expect(eval(i), '1/3');
    final s = ExpressionEditor()..insertTemplate(TemplateType.sum, prefill: {0: '1', 1: '100', 2: 'x'});
    expect(eval(s), '5050');
    final d = ExpressionEditor()..insertTemplate(TemplateType.deriv, prefill: {0: 'x^3', 1: '2'});
    expect(eval(d), '12');
  });

  test('tokenizeText round-trips function names', () {
    final toks = ExpressionEditor.tokenizeText('sin(30)+sqrt(16)');
    expect(toks.where((t) => t.kind == TokKind.func).map((t) => t.text), ['sin', 'sqrt']);
    expect(eval(ExpressionEditor(toks)), '9/2');
  });

  test('serialization validates structure', () {
    final e = ExpressionEditor()..insertTemplate(TemplateType.frac, prefill: {0: '1', 1: '2'});
    final restored = ExpressionEditor.tokensFromJson(e.toJson());
    expect(restored, e.tokens);
    expect(ExpressionEditor.tokensFromJson('[{"k":2,"p":0,"g":1}]'), isEmpty); // unbalanced
    expect(ExpressionEditor.tokensFromJson('not json'), isEmpty);
  });

  test('renderer places a cursor and placeholders', () {
    final e = ExpressionEditor()..insertTemplate(TemplateType.frac);
    final tex = const EditorLatexRenderer(cursorColor: '#ff0000', placeholderColor: '#999999').render(e.tokens, e.cursor);
    expect(tex, contains(r'\frac'));
    expect(tex, contains(r'\square'));
    expect(tex, contains('#ff0000'));
  });
}
