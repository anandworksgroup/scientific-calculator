import 'package:math_engine/math_engine.dart';

import '../../data/settings/app_settings.dart';

/// How the result line is currently shown (S⇔D cycles exact ↔ decimal).
enum ResultView { standard, exact, decimal }

/// One way of writing a result (for the details sheet and copy actions).
class ResultForm {
  const ResultForm(this.kind, this.latex, this.plain);
  final ResultFormKind kind;
  final String latex;
  final String plain;
}

enum ResultFormKind { exact, fraction, mixed, decimal, scientific, engineering, allDigits, value }

/// Builds textbook renderings of evaluation results.
class ResultPresenter {
  const ResultPresenter(this.settings);
  final AppSettings settings;

  FormatOptions get _opts => settings.formatOptions();

  bool _isNonIntegerRat(Value v) => v is NumberValue && v.n is Rat && !(v.n as Rat).isInteger;

  /// The main result rendering for [view].
  ResultForm main(Evaluation e, ResultView view) {
    final v = e.value;
    if (v is SolutionsValue && e.solution != null) return _solutions(e);
    if (v is BoolValue) {
      return ResultForm(ResultFormKind.value, v.value ? r'\mathrm{True}' : r'\mathrm{False}', v.value ? 'True' : 'False');
    }
    final exactLatex = e.exactLatex;
    final wantsExact = view == ResultView.exact || (view == ResultView.standard && settings.resultFormat == ResultFormat.exact);
    if (wantsExact && exactLatex != null) {
      return ResultForm(ResultFormKind.exact, exactLatex, e.exactText ?? exactLatex);
    }
    if (view == ResultView.exact && _isNonIntegerRat(v)) {
      final f = NumberFormatter(_opts.copyWith(fraction: FractionMode.fraction)).format((v as NumberValue).n);
      return ResultForm(ResultFormKind.fraction, f.latex, f.plain);
    }
    if (view == ResultView.decimal) {
      final f = ValueFormatter(_opts.copyWith(fraction: FractionMode.decimal)).format(v, preferDecimal: true);
      return ResultForm(ResultFormKind.decimal, f.latex, f.plain);
    }
    // Standard view: follow the result-format setting (auto uses fractions
    // for exact rational input and decimals when decimals were typed).
    final auto = settings.resultFormat == ResultFormat.auto || settings.resultFormat == ResultFormat.exact;
    if (auto && exactLatex != null && !e.preferDecimal && settings.resultFormat == ResultFormat.exact) {
      return ResultForm(ResultFormKind.exact, exactLatex, e.exactText ?? exactLatex);
    }
    final f = ValueFormatter(_opts).format(v, preferDecimal: e.preferDecimal);
    final kind = _isNonIntegerRat(v) && !f.plain.contains('.') ? ResultFormKind.fraction : ResultFormKind.decimal;
    return ResultForm(kind, f.latex, f.plain);
  }

  /// Whether S⇔D has something to switch to.
  bool canToggle(Evaluation e) =>
      e.exact != null || _isNonIntegerRat(e.value) || (e.value is NumberValue && (e.value as NumberValue).n is Dec);

  ResultView nextView(Evaluation e, ResultView current) {
    final shown = main(e, current);
    if (shown.kind == ResultFormKind.decimal) {
      return (e.exact != null || _isNonIntegerRat(e.value)) ? ResultView.exact : ResultView.decimal;
    }
    return ResultView.decimal;
  }

  /// All alternative forms for the result details sheet (§94).
  List<ResultForm> alternatives(Evaluation e) {
    final v = e.value;
    final out = <ResultForm>[];
    if (e.exactLatex != null) out.add(ResultForm(ResultFormKind.exact, e.exactLatex!, e.exactText ?? ''));
    if (v is NumberValue) {
      final n = v.n;
      if (n is Rat && !n.isInteger) {
        final fr = NumberFormatter(_opts.copyWith(fraction: FractionMode.fraction)).format(n);
        out.add(ResultForm(ResultFormKind.fraction, fr.latex, fr.plain));
        if (n.abs() > Rat.one) {
          final mx = NumberFormatter(_opts.copyWith(fraction: FractionMode.mixed)).format(n);
          out.add(ResultForm(ResultFormKind.mixed, mx.latex, mx.display));
        }
      }
      final dec = NumberFormatter(_opts.copyWith(fraction: FractionMode.decimal, notation: NumberNotation.normal)).format(n, preferDecimal: true);
      out.add(ResultForm(ResultFormKind.decimal, dec.latex, dec.plain));
      if (n is! Cpx) {
        final sci = NumberFormatter(_opts.copyWith(fraction: FractionMode.decimal, notation: NumberNotation.scientific)).format(n, preferDecimal: true);
        out.add(ResultForm(ResultFormKind.scientific, sci.latex, sci.plain));
        final eng = NumberFormatter(_opts.copyWith(fraction: FractionMode.decimal, notation: NumberNotation.engineering)).format(n, preferDecimal: true);
        out.add(ResultForm(ResultFormKind.engineering, eng.latex, eng.plain));
      }
      final digits = ValueFormatter.exactInteger(v);
      if (digits != null && digits.length > settings.precision) {
        out.add(ResultForm(ResultFormKind.allDigits, digits, digits));
      }
    } else {
      final f = ValueFormatter(_opts).format(v, preferDecimal: e.preferDecimal);
      out.add(ResultForm(ResultFormKind.value, f.latex, f.plain));
    }
    // Remove duplicates with identical rendering.
    final seen = <String>{};
    return [for (final f in out) if (seen.add(f.latex)) f];
  }

  ResultForm _solutions(Evaluation e) {
    final sol = e.solution!;
    if (sol.alwaysTrue) return const ResultForm(ResultFormKind.value, r'\mathrm{All\ values}', 'all values');
    final v = sol.variable;
    final parts = <String>[];
    final plain = <String>[];
    for (var k = 0; k < sol.roots.length; k++) {
      final r = sol.roots[k];
      final idx = sol.roots.length > 1 ? '_{${k + 1}}' : '';
      final value = rootLatex(r);
      parts.add('$v$idx=$value');
      plain.add(NumberFormatter(_opts).format(r.value).plain);
    }
    if (parts.isEmpty) return const ResultForm(ResultFormKind.value, r'\varnothing', '');
    return ResultForm(ResultFormKind.value, parts.join(r',\quad '), plain.join(', '));
  }

  /// Exact form of a root when known (surd / symbolic), else formatted.
  String rootLatex(SolvedRoot r) {
    final s = r.surd;
    if (s != null) return surdLatex(s);
    if (r.exact != null) return const LatexPrinter().print(symToNode(r.exact!));
    final f = NumberFormatter(_opts.copyWith(fraction: FractionMode.auto)).format(r.value, preferDecimal: !r.isExact);
    return r.isExact ? f.latex : f.latex;
  }

  /// p + q√d (or p + q·i√|d| when d < 0) in LaTeX.
  static String surdLatex(SurdForm s) {
    final p = s.p, q = s.q;
    final d = s.d;
    final imag = d.isNegative;
    final rad = '\\sqrt{${d.abs()}}';
    String rat(Rat r) => r.isInteger ? '${r.n}' : '\\frac{${r.n.abs()}}{${r.d}}';
    final qAbs = q.abs();
    final coef = qAbs.isOne ? '' : (qAbs.isInteger ? '${qAbs.n}' : '');
    String term;
    if (qAbs.isInteger) {
      term = '$coef${imag ? 'i' : ''}$rad';
    } else {
      term = '\\frac{${qAbs.n == BigInt.one ? '' : qAbs.n}${imag ? 'i' : ''}$rad}{${qAbs.d}}';
    }
    final sign = q.isNegative ? '-' : '+';
    if (p.isZero) return q.isNegative ? '-$term' : term;
    final ps = p.isNegative ? '-${rat(p.abs())}' : rat(p);
    return '$ps$sign$term';
  }
}
