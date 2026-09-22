import '../eval/values.dart';
import '../numbers/num.dart';
import 'number_format.dart';

/// Formats any engine [Value] for display, copying and textbook rendering.
class ValueFormatter {
  const ValueFormatter(this.options);
  final FormatOptions options;

  NumberFormatter get _nf => NumberFormatter(options);

  FormattedNumber format(Value v, {bool preferDecimal = false}) {
    switch (v) {
      case NumberValue(:final n):
        return _nf.format(n, preferDecimal: preferDecimal);
      case MatrixValue(:final rows):
        final cells = [for (final r in rows) [for (final c in r) _nf.format(c, preferDecimal: preferDecimal)]];
        return FormattedNumber(
          plain: '[${cells.map((r) => '[${r.map((c) => c.plain).join(',')}]').join(',')}]',
          display: cells.map((r) => '[${r.map((c) => c.display).join(', ')}]').join('\n'),
          latex: '\\begin{bmatrix}${cells.map((r) => r.map((c) => c.latex).join(' & ')).join(r' \\ ')}\\end{bmatrix}',
        );
      case VectorValue(:final items):
        final cells = [for (final c in items) _nf.format(c, preferDecimal: preferDecimal)];
        return FormattedNumber(
          plain: '[${cells.map((c) => c.plain).join(',')}]',
          display: '(${cells.map((c) => c.display).join(', ')})',
          latex: '\\left(${cells.map((c) => c.latex).join(',\\ ')}\\right)',
        );
      case ListValue(:final items):
        final cells = [for (final c in items) format(c, preferDecimal: preferDecimal)];
        return FormattedNumber(
          plain: '[${cells.map((c) => c.plain).join(',')}]',
          display: '{${cells.map((c) => c.display).join(', ')}}',
          latex: '\\left\\{${cells.map((c) => c.latex).join(',\\ ')}\\right\\}',
        );
      case BoolValue(:final value):
        return FormattedNumber(
          plain: value ? '1' : '0',
          display: value ? 'true' : 'false',
          latex: value ? r'\mathrm{true}' : r'\mathrm{false}',
        );
      case InfinityValue(:final sign):
        return FormattedNumber(
          plain: sign > 0 ? 'inf' : '-inf',
          display: sign > 0 ? '∞' : '−∞',
          latex: sign > 0 ? r'\infty' : r'-\infty',
        );
      case FactorizationValue(:final sign, :final factors, :final number):
        if (factors.isEmpty) {
          return FormattedNumber(plain: '$number', display: '$number', latex: '$number');
        }
        final plain = factors.map((f) => f.$2 == 1 ? '${f.$1}' : '${f.$1}^${f.$2}').join('*');
        final disp = factors.map((f) => f.$2 == 1 ? '${f.$1}' : '${f.$1}${superscript('${f.$2}')}').join(' × ');
        final latex = factors.map((f) => f.$2 == 1 ? '${f.$1}' : '${f.$1}^{${f.$2}}').join(r' \times ');
        final s = sign < 0 ? '-' : '';
        return FormattedNumber(plain: '$s$plain', display: '${sign < 0 ? '−' : ''}$disp', latex: '$s$latex');
      case SolutionsValue(:final variable, :final solutions):
        if (solutions.isEmpty) {
          return const FormattedNumber(plain: '', display: '∅', latex: r'\varnothing');
        }
        final parts = [for (final s in solutions) _nf.format(s, preferDecimal: preferDecimal)];
        String sub(int k) => solutions.length == 1 ? '' : '${k + 1}';
        return FormattedNumber(
          plain: parts.map((p) => p.plain).join(', '),
          display: [for (var k = 0; k < parts.length; k++) '$variable${_subscript(sub(k))} = ${parts[k].display}'].join('\n'),
          latex: [
            for (var k = 0; k < parts.length; k++)
              '$variable${solutions.length == 1 ? '' : '_{${k + 1}}'}=${parts[k].latex}'
          ].join(r',\quad '),
        );
    }
  }

  static const _subs = {'0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉'};
  String _subscript(String s) => s.split('').map((c) => _subs[c] ?? c).join();

  /// Full exact digits of an integer result (for the result details view).
  static String? exactInteger(Value v) {
    if (v is NumberValue && v.n is Rat && (v.n as Rat).isInteger) return (v.n as Rat).n.toString();
    return null;
  }
}
