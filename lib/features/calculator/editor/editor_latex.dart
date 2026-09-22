import 'package:math_engine/math_engine.dart';

import 'expression_editor.dart';

/// Renders editor tokens as LaTeX in textbook notation, with a visible
/// cursor and placeholder boxes for empty template slots.
class EditorLatexRenderer {
  const EditorLatexRenderer({
    required this.cursorColor,
    required this.placeholderColor,
    this.showCursor = true,
    this.selectionColor,
  });

  /// '#rrggbb' colors.
  final String cursorColor;
  final String placeholderColor;
  final bool showCursor;

  /// When set, the whole expression is highlighted as selected.
  final String? selectionColor;

  static const _funcLatex = {
    'sin': r'\sin', 'cos': r'\cos', 'tan': r'\tan', 'sec': r'\sec', 'csc': r'\csc', 'cot': r'\cot',
    'asin': r'\sin^{-1}', 'acos': r'\cos^{-1}', 'atan': r'\tan^{-1}',
    'sinh': r'\sinh', 'cosh': r'\cosh', 'tanh': r'\tanh',
    'asinh': r'\sinh^{-1}', 'acosh': r'\cosh^{-1}', 'atanh': r'\tanh^{-1}',
    'ln': r'\ln', 'log': r'\log', 'log2': r'\log_{2}', 'exp': r'\exp',
    'det': r'\det', 'gcd': r'\gcd', 'min': r'\min', 'max': r'\max', 'arg': r'\arg',
    'sqrt': r'\mathrm{sqrt}',
  };

  static const _greek = {'θ': r'\theta', 'π': r'\pi', 'φ': r'\varphi', 'λ': r'\lambda', 'μ': r'\mu', 'σ': r'\sigma'};

  String render(List<EdToken> tokens, int cursor) {
    var i = 0;
    String cursorTex() => showCursor ? '\\textcolor{$cursorColor}{\\rule{1.4pt}{1.05em}}' : '';
    String placeholder() => '\\textcolor{$placeholderColor}{\\square}';

    String seq(int? group) {
      final b = StringBuffer();
      var empty = true;
      while (i <= tokens.length) {
        if (i == cursor) b.write(cursorTex());
        if (i == tokens.length) break;
        final t = tokens[i];
        if ((t.kind == TokKind.sep || t.kind == TokKind.close) && t.group == group) break;
        empty = false;
        i++;
        switch (t.kind) {
          case TokKind.text:
            b.write(_text(t.text));
          case TokKind.func:
            final f = _funcLatex[t.text] ?? '\\mathrm{${t.text.replaceAll('_', r'\_')}}';
            b.write('$f(');
          case TokKind.open:
            final g = t.group;
            final slots = <String>[];
            for (var k = 0; k < t.template!.slots; k++) {
              final start = i;
              var s = seq(g);
              final hadCursor = cursor >= start && cursor <= i;
              if (i == start && !hadCursor) s = placeholder();
              if (i == start && hadCursor && s.isEmpty) s = placeholder();
              slots.add(s);
              if (i < tokens.length) i++;
            }
            b.write(_template(t.template!, slots));
          case TokKind.sep:
          case TokKind.close:
            break;
        }
      }
      if (empty && group == null && tokens.isEmpty) return b.toString();
      return b.toString();
    }

    final body = seq(null);
    if (selectionColor != null && tokens.isNotEmpty) return '\\colorbox{$selectionColor}{\$$body\$}';
    return body;
  }

  String _text(String s) {
    final g = _greek[s];
    if (g != null) return '{$g}';
    if (s.startsWith('@')) {
      final c = constantIndex[s.substring(1)];
      return c == null ? '\\mathrm{${s.substring(1)}}' : '{\\color{#1565c0}${c.latex}}';
    }
    switch (s) {
      case '×':
        return r'\times ';
      case '÷':
        return r'\div ';
      case '*':
        return r'\times ';
      case '/':
        return r'\div ';
      case '-':
        return '-';
      case '+':
        return '+';
      case 'ᴇ':
        return r'{\scriptstyle\mathrm{E}}';
      case '%':
        return r'\%';
      case '°':
        return r'^{\circ}';
      case 'ʳ':
        return '^{r}';
      case 'ᵍ':
        return '^{g}';
      case '→':
        return r'\to ';
      case '∠':
        return r'\angle ';
      case '∞':
        return r'\infty ';
      case ',':
        return r',\,';
      case '·':
        return r'\cdot ';
      case '≤':
        return r'\le ';
      case '≥':
        return r'\ge ';
      case '≠':
        return r'\ne ';
      case '√':
        return r'\surd ';
      case 'Ans':
        return r'\mathrm{Ans}';
      case 'PreAns':
        return r'\mathrm{PreAns}';
      case 'nCr':
        return r'\,\mathrm{C}\,';
      case 'nPr':
        return r'\,\mathrm{P}\,';
      case '{' || '}' || '#' || '&' || '_' || r'$' || '~' || '^' || '\\':
        return '\\$s';
    }
    return s;
  }

  String _template(TemplateType t, List<String> s) => switch (t) {
        TemplateType.frac => '\\frac{${s[0]}}{${s[1]}}',
        TemplateType.mixed => '${s[0]}\\frac{${s[1]}}{${s[2]}}',
        TemplateType.pow => '^{${s[0]}}',
        TemplateType.sqrt => '\\sqrt{${s[0]}}',
        TemplateType.root => '\\sqrt[${s[0]}]{${s[1]}}',
        TemplateType.abs => '\\left|${s[0]}\\right|',
        TemplateType.logb => '\\log_{${s[0]}}\\left(${s[1]}\\right)',
        TemplateType.integral => '\\displaystyle\\int_{${s[0]}}^{${s[1]}}${s[2]}\\,dx',
        TemplateType.deriv => '\\left.\\frac{d}{dx}\\left(${s[0]}\\right)\\right|_{x=${s[1]}}',
        TemplateType.sum => '\\displaystyle\\sum_{x=${s[0]}}^{${s[1]}}\\left(${s[2]}\\right)',
        TemplateType.prod => '\\displaystyle\\prod_{x=${s[0]}}^{${s[1]}}\\left(${s[2]}\\right)',
        TemplateType.lim => '\\displaystyle\\lim_{x\\to ${s[0]}}\\left(${s[1]}\\right)',
      };
}
