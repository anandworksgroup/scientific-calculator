import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/settings/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/math_view.dart';
import '../../widgets/steps_view.dart';
import '../calculator/calculator_controller.dart' show historyListProvider;

// ============================================================ isolate tasks
//
// Each factory is top-level so the returned closure only captures its plain
// arguments (strings, numbers, settings, environment) and can be sent to a
// background isolate.

EngineResult<EquationSolution> Function() equationTask(
  String equation,
  String variable,
  CalcSettings settings,
  Environment env,
  double? lower,
  double? upper,
) =>
    () => EngineService.engine.solve(equation, variable, settings, env, lower: lower, upper: upper);

EngineResult<PolynomialSolution> Function() polynomialTask(
  List<String> coefficientsHighToLow,
  CalcSettings settings,
  Environment env,
) =>
    () => EngineService.engine.solvePolynomial(coefficientsHighToLow, settings, env);

EngineResult<LinearSystemSolution> Function() linearSystemTask(
  List<List<String>> coefficients,
  List<String> constants,
  List<String> variables,
  CalcSettings settings,
  Environment env,
) =>
    () => EngineService.engine.solveLinearSystem(coefficients, constants, variables, settings, env);

EngineResult<TextSystemResult> Function() textSystemTask(List<String> lines, CalcSettings settings, Environment env) =>
    () => solveTextSystem(lines, settings, env);

// ================================================ equations typed as text

/// Preferred order of unknowns (x first, then y, z…).
const preferredUnknowns = ['x', 'y', 'z', 'w', 'v', 'u', 't', 's', 'r', 'q', 'p'];

List<String> sortUnknowns(Iterable<String> names) {
  int rank(String n) {
    final i = preferredUnknowns.indexOf(n);
    return i < 0 ? preferredUnknowns.length : i;
  }

  return names.toSet().toList()..sort((a, b) {
    final c = rank(a).compareTo(rank(b));
    return c != 0 ? c : a.compareTo(b);
  });
}

ParseScope solveScope(Environment env) =>
    ParseScope(variables: env.variables.keys.toSet(), userFunctions: env.functions.keys.toSet());

/// Splits `lhs = rhs` input into sides; assignments such as `y = 2x + 1`
/// are read as equations. Returns null when [node] is not an equation.
(Node, Node)? equationSides(Node node) => switch (node) {
  EquationNode(:final left, :final right, :final op) when op == RelOp.eq => (left, right),
  AssignmentNode(:final name, :final value) => (VariableNode(name), value),
  _ => null,
};

/// `y = 2x + 1` parses as an assignment, which the engine's solver rejects;
/// wrapping the left side in parentheses makes it an equation.
String asEquationText(String line, Environment env) {
  try {
    final node = Parser.parse(line, scope: solveScope(env));
    if (node is AssignmentNode) {
      final i = line.indexOf('=');
      if (i > 0) return '(${line.substring(0, i).trim()})${line.substring(i)}';
    }
  } on MathError {
    // The engine reports the parse error with its position.
  }
  return line;
}

/// Free variables of one line of input (or null if it does not parse).
Set<String>? lineVariables(String line, Environment env) {
  try {
    final node = Parser.parse(line, scope: solveScope(env));
    return switch (node) {
      AssignmentNode(:final name, :final value) => {name, ...freeVariables(value)},
      FunctionDefNode() => null,
      _ => freeVariables(node),
    };
  } on MathError {
    return null;
  }
}

/// Unknowns found in [lines]; names that already hold a stored value are
/// listed after the others.
List<String> detectUnknowns(List<String> lines, Environment env) {
  final all = <String>{};
  for (final l in lines) {
    all.addAll(lineVariables(l, env) ?? const {});
  }
  final free = sortUnknowns(all.where((v) => !env.variables.containsKey(v)));
  final stored = sortUnknowns(all.where((v) => env.variables.containsKey(v)));
  return [...free, ...stored];
}

/// Textbook LaTeX of one input line, or null when it does not parse.
String? lineLatex(String line, Environment env) {
  try {
    final node = Parser.parse(line, scope: solveScope(env));
    final sides = equationSides(node);
    if (sides != null) {
      return '${const LatexPrinter().print(sides.$1)}=${const LatexPrinter().print(sides.$2)}';
    }
    return const LatexPrinter().print(node);
  } on MathError {
    return null;
  }
}

enum TextSystemStatus { solved, notEquation, nonlinear, noUnknowns }

/// Result of solving several typed equations as a linear system.
class TextSystemResult {
  const TextSystemResult(
    this.status, {
    this.line = -1,
    this.variables = const [],
    this.solution,
    this.equationsLatex = const [],
  });
  final TextSystemStatus status;

  /// Index of the offending line (for [TextSystemStatus.notEquation] and
  /// [TextSystemStatus.nonlinear]).
  final int line;
  final List<String> variables;
  final LinearSystemSolution? solution;
  final List<String> equationsLatex;
}

/// Reads each line as an equation, moves everything to the left
/// (lhs − rhs = 0), extracts the coefficient of every unknown with the
/// engine's [polyCoefficients] and solves the resulting linear system.
EngineResult<TextSystemResult> solveTextSystem(List<String> lines, CalcSettings settings, Environment env) {
  return guard(() {
    final scope = solveScope(env);
    final sides = <(Node, Node)>[];
    final latex = <String>[];
    for (var k = 0; k < lines.length; k++) {
      final node = Parser.parse(lines[k], scope: scope);
      final s = equationSides(node);
      if (s == null) return TextSystemResult(TextSystemStatus.notEquation, line: k);
      sides.add(s);
      latex.add('${const LatexPrinter().print(s.$1)}=${const LatexPrinter().print(s.$2)}');
    }
    final names = <String>{};
    for (final (l, r) in sides) {
      names
        ..addAll(freeVariables(l))
        ..addAll(freeVariables(r));
    }
    final unknowns = sortUnknowns(names.where((v) => !env.variables.containsKey(v)));
    if (unknowns.isEmpty) return const TextSystemResult(TextSystemStatus.noUnknowns);
    final values = Map<String, Value>.of(env.variables)..removeWhere((k, _) => unknowns.contains(k));
    final functions = {for (final e in env.compileFunctions().entries) e.key: (e.value.params, e.value.body)};
    final coefficients = <List<String>>[];
    final constants = <String>[];
    for (var k = 0; k < sides.length; k++) {
      final (l, r) = sides[k];
      final f = SymConverter(
        angleMode: settings.angleMode,
        values: values,
        userFunctions: functions,
      ).convert(BinaryNode(BinaryOp.sub, l, r));
      final row = <String>[];
      for (final v in unknowns) {
        final c = polyCoefficients(f, v, maxDegree: 1);
        if (c == null) return TextSystemResult(TextSystemStatus.nonlinear, line: k, variables: unknowns);
        final coef = c.length > 1 ? c[1] : S.zero;
        if (symVariables(coef).isNotEmpty) {
          return TextSystemResult(TextSystemStatus.nonlinear, line: k, variables: unknowns);
        }
        row.add(const TextPrinter().print(symToNode(coef)));
      }
      var rest = f;
      for (final v in unknowns) {
        rest = polyCoefficients(rest, v, maxDegree: 1)!.first;
      }
      if (symVariables(rest).isNotEmpty) {
        return TextSystemResult(TextSystemStatus.nonlinear, line: k, variables: unknowns);
      }
      coefficients.add(row);
      constants.add(const TextPrinter().print(symToNode(S.neg(rest))));
    }
    final r = EngineService.engine.solveLinearSystem(coefficients, constants, unknowns, settings, env);
    return switch (r) {
      Success(:final value) => TextSystemResult(
        TextSystemStatus.solved,
        variables: unknowns,
        solution: value,
        equationsLatex: latex,
      ),
      Failure(:final error) => throw error,
      Cancelled() => throw const MathError(MathErrorCode.cancelled),
    };
  });
}

// ================================================================ formatting

String varLatex(String v) => const LatexPrinter().print(VariableNode(v));

String symLatex(Sym s) => const LatexPrinter().print(symToNode(s));

String symText(Sym s) => const TextPrinter(pretty: true).print(symToNode(s));

String symPlain(Sym s) => const TextPrinter().print(symToNode(s));

FormatOptions _decimalOptions(FormatOptions o) =>
    o.copyWith(fraction: FractionMode.decimal, digits: o.digits > 15 ? 15 : o.digits);

FormattedNumber exactNumber(Num n, FormatOptions o) => NumberFormatter(
  o.copyWith(fraction: o.fraction == FractionMode.decimal ? FractionMode.fraction : o.fraction),
).format(n);

FormattedNumber decimalNumber(Num n, FormatOptions o) =>
    NumberFormatter(_decimalOptions(o)).format(n, preferDecimal: true);

String formatDouble(double v, FormatOptions o) {
  if (!v.isFinite) return v.isNaN ? '—' : (v > 0 ? '∞' : '−∞');
  return NumberFormatter(
    o.copyWith(fraction: FractionMode.decimal, digits: 8),
  ).format(Dec.fromDouble(v), preferDecimal: true).display;
}

BigInt _lcm(BigInt a, BigInt b) => a ~/ a.gcd(b) * b;

/// `p + q√d` in textbook form over a common denominator, e.g. (3 + √5)/2.
/// Negative d gives `p + q·i·√|d|`.
(String latex, String text) surdForms(SurdForm s) {
  final imag = s.d.isNegative;
  final absD = s.d.abs();
  final rootTex = absD == BigInt.one ? '' : '\\sqrt{$absD}';
  final rootTxt = absD == BigInt.one ? '' : '√$absD';
  final radTex = imag ? 'i$rootTex' : rootTex;
  final radTxt = imag ? 'i$rootTxt' : rootTxt;
  final den = _lcm(s.p.d, s.q.d);
  final pn = s.p.n * (den ~/ s.p.d);
  final qn = s.q.n * (den ~/ s.q.d);
  final qAbs = qn.abs();
  final qTex = qAbs == BigInt.one ? radTex : '$qAbs$radTex';
  final qTxt = qAbs == BigInt.one ? radTxt : '$qAbs$radTxt';
  if (pn == BigInt.zero) {
    final sign = qn.isNegative ? '-' : '';
    final signTxt = qn.isNegative ? '−' : '';
    if (den == BigInt.one) return ('$sign$qTex', '$signTxt$qTxt');
    return ('$sign\\frac{$qTex}{$den}', '$signTxt$qTxt/$den');
  }
  final pTex = '$pn';
  final pTxt = pn.isNegative ? '−${pn.abs()}' : '$pn';
  final op = qn.isNegative ? '-' : '+';
  final opTxt = qn.isNegative ? ' − ' : ' + ';
  if (den == BigInt.one) return ('$pTex$op$qTex', '$pTxt$opTxt$qTxt');
  return ('\\frac{$pTex$op$qTex}{$den}', '($pTxt$opTxt$qTxt)/$den');
}

/// One root rendered in exact (when available) and decimal forms.
class RootForms {
  RootForms({required this.exactLatex, required this.exactText, required this.decimalLatex, required this.decimalText});

  factory RootForms.of(Num value, FormatOptions o, {SurdForm? surd, Sym? exact}) {
    String? exLatex, exText;
    if (surd != null) {
      (exLatex, exText) = surdForms(surd);
    } else if (exact != null) {
      exLatex = symLatex(exact);
      exText = symText(exact);
    } else if (value is Rat) {
      final f = exactNumber(value, o);
      exLatex = f.latex;
      exText = f.display;
    }
    final d = decimalNumber(value, o);
    return RootForms(exactLatex: exLatex, exactText: exText, decimalLatex: d.latex, decimalText: d.display);
  }

  final String? exactLatex;
  final String? exactText;
  final String decimalLatex;
  final String decimalText;

  /// Whether the decimal adds information beyond the exact form.
  bool get showDecimal => exactText == null || exactText!.replaceAll('−', '-') != decimalText.replaceAll('−', '-');

  String get mainLatex => exactLatex ?? decimalLatex;
  String get mainText => exactText ?? '≈ $decimalText';
  String get relation => exactLatex == null ? r'\approx ' : '=';
}

/// LaTeX for a linear combination such as `2x - \frac{1}{3}y + z`, built from
/// coefficient input text (which may be an expression) and the LaTeX of
/// each monomial ('' for the constant term). Unparsable coefficients show as
/// an empty box.
String linearComboLatex(List<(String, String)> terms, Environment env) {
  final out = StringBuffer();
  var first = true;
  for (final (text, mono) in terms) {
    final t = ClipboardService.sanitize(text);
    if (t.isEmpty) continue;
    Node node;
    try {
      node = Parser.parseExpression(t, scope: solveScope(env));
    } on MathError {
      out.write(first ? r'\square ' : r'+\square ');
      out.write(mono);
      first = false;
      continue;
    }
    var neg = false;
    if (node is UnaryNode && node.op == UnaryOp.negate) {
      neg = true;
      node = node.operand;
    }
    String mag;
    if (node is NumberNode) {
      if (node.value.isZero) continue;
      if (node.value.isNegative) neg = !neg;
      final abs = node.value.abs();
      mag = abs.isOne && mono.isNotEmpty ? '' : const LatexPrinter().print(NumberNode(abs, isDecimal: node.isDecimal));
    } else {
      final tex = const LatexPrinter().print(node);
      final wrap =
          node is BinaryNode && (node.op == BinaryOp.add || node.op == BinaryOp.sub) ||
          node is UnaryNode ||
          (mono.isNotEmpty && node is BinaryNode && node.op == BinaryOp.polar);
      mag = wrap ? '\\left($tex\\right)' : tex;
    }
    if (first) {
      if (neg) out.write('-');
    } else {
      out.write(neg ? '-' : '+');
    }
    out.write(mag);
    out.write(mono);
    first = false;
  }
  return first ? '0' : out.toString();
}

// ================================================================== history

Future<void> recordSolveHistory(
  WidgetRef ref, {
  required String mode,
  required String expression,
  required String expressionLatex,
  required String result,
  required String resultLatex,
}) async {
  final settings = ref.read(settingsProvider);
  if (!settings.saveHistory) return;
  try {
    await ref
        .read(historyRepositoryProvider)
        .insert(
          HistoryEntry(
            expression: expression,
            expressionLatex: expressionLatex,
            result: result,
            resultLatex: resultLatex,
            mode: mode,
            angleMode: settings.angleMode.name,
            format: settings.resultFormat.name,
            createdAt: DateTime.now(),
          ),
          limit: settings.historyLimit,
        );
    ref.invalidate(historyListProvider);
  } catch (e) {
    AppLogger.error('history insert ($mode)', e);
  }
}

// ============================================================ engine runner

/// Runs engine work in a background isolate with cancel support.
mixin EngineRunner<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  Computation<Object?>? _computation;

  bool get busy => _computation != null;

  /// Returns null when the computation was cancelled or superseded.
  Future<EngineResult<T>?> runEngine<T>(EngineResult<T> Function() task) async {
    _computation?.cancel();
    final c = ref.read(engineServiceProvider).run<T>(task);
    setState(() => _computation = c);
    final r = await c.result;
    if (!mounted || !identical(_computation, c)) return null;
    setState(() => _computation = null);
    return r;
  }

  void cancelEngine() {
    final c = _computation;
    if (c == null) return;
    c.cancel();
    setState(() => _computation = null);
  }

  @override
  void dispose() {
    _computation?.cancel();
    super.dispose();
  }
}

// ================================================================== widgets

/// Progress row with a Cancel button.
class SolveBusy extends StatelessWidget {
  const SolveBusy({super.key, required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      label: l.solveWorking,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 16),
            Expanded(child: Text(l.solveWorking)),
            TextButton(onPressed: onCancel, child: Text(l.actionCancel)),
          ],
        ),
      ),
    );
  }
}

/// Explained error message.
class SolveMessage extends StatelessWidget {
  const SolveMessage(this.text, {super.key, this.error = true, this.icon});
  final String text;
  final bool error;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: error ? cs.errorContainer : cs.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon ?? (error ? Icons.error_outline : Icons.info_outline),
                color: error ? cs.onErrorContainer : cs.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: TextStyle(color: error ? cs.onErrorContainer : cs.onSecondaryContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small informational note under a result.
class SolveNote extends StatelessWidget {
  const SolveNote(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// Result card with a title, copy action and live-region semantics.
class SolveResultCard extends StatelessWidget {
  const SolveResultCard({
    super.key,
    required this.title,
    required this.children,
    this.copyText,
    this.actions = const [],
  });
  final String title;
  final List<Widget> children;
  final String? copyText;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                  ...actions,
                  if (copyText != null)
                    IconButton(
                      tooltip: l.actionCopy,
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () async {
                        await ClipboardService.copy(copyText!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copiedToClipboard)));
                        }
                      },
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrollable textbook math aligned left.
class MathLine extends StatelessWidget {
  const MathLine(this.tex, {super.key, this.style, this.fallback, this.semanticsLabel});
  final String tex;
  final TextStyle? style;
  final String? fallback;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: ScrollingMath(
      tex,
      alignRight: false,
      style: style ?? Theme.of(context).textTheme.titleLarge,
      fallback: fallback,
      semanticsLabel: semanticsLabel,
    ),
  );
}

/// One root: `x₁ = exact ≈ decimal` with multiplicity/real/complex tags.
class RootTile extends StatelessWidget {
  const RootTile({
    super.key,
    required this.variable,
    required this.index,
    required this.forms,
    required this.isReal,
    this.multiplicity = 1,
    this.showIndex = true,
  });

  final String variable;
  final int index;
  final RootForms forms;
  final bool isReal;
  final int multiplicity;
  final bool showIndex;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = showIndex ? '${varLatex(variable)}_{$index}' : varLatex(variable);
    final label =
        '$variable${showIndex ? '$index' : ''} ${forms.exactText == null ? '≈' : '='} '
        '${forms.exactText ?? forms.decimalText}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MathLine('$name${forms.relation}${forms.mainLatex}', fallback: label, semanticsLabel: label),
          if (forms.exactLatex != null && forms.showDecimal)
            MathLine(
              '\\approx ${forms.decimalLatex}',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              fallback: '≈ ${forms.decimalText}',
              semanticsLabel: '≈ ${forms.decimalText}',
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _Tag(isReal ? l.solveRealRoot : l.solveComplexRoot),
              _Tag(forms.exactLatex != null ? l.solveExact : l.solveApproximate),
              if (multiplicity > 1) _Tag(l.solveMultiplicity(multiplicity)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer)),
    );
  }
}

/// Discriminant line and classification for quadratics.
class DiscriminantView extends StatelessWidget {
  const DiscriminantView({super.key, required this.discriminant, required this.options});
  final Num discriminant;
  final FormatOptions options;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final f = exactNumber(discriminant, options);
    final d = discriminant;
    final sign = d is Cpx ? null : (d.isZero ? 0 : (d.toDouble() < 0 ? -1 : 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MathLine(
          '\\Delta=b^{2}-4ac=${f.latex}',
          fallback: 'Δ = ${f.display}',
          semanticsLabel: '${l.solveDiscriminant} ${f.display}',
        ),
        if (sign != null)
          SolveNote(switch (sign) {
            > 0 => l.solveTwoRealRoots,
            0 => l.solveRepeatedRoot,
            _ => l.solveComplexPair,
          }),
      ],
    );
  }
}

/// Some engine step descriptions embed LaTeX fragments (e.g. "Divide R2 by
/// -\frac{3}{2}"), but StepsView shows descriptions as plain text; rewrite
/// those fragments in readable Unicode.
List<SolutionStep> readableSteps(List<SolutionStep> steps) {
  String clean(String s) {
    if (!s.contains('\\')) return s;
    var out = s;
    String prev;
    do {
      prev = out;
      out = out
          .replaceAllMapped(RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'), (m) => '${m[1]}/${m[2]}')
          .replaceAllMapped(RegExp(r'\\sqrt\{([^{}]*)\}'), (m) => '√${m[1]}')
          .replaceAllMapped(RegExp(r'\^\{([^{}]*)\}'), (m) => '^${m[1]}')
          .replaceAllMapped(RegExp(r'_\{([^{}]*)\}'), (m) => m[1]!);
    } while (out != prev);
    return out
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\,', ' ')
        .replaceAll(r'\quad', ' ')
        .replaceAll('-', '−');
  }

  return [for (final st in steps) SolutionStep(clean(st.description), st.latex)];
}

// ------------------------------------------------------------- equations

/// Plain text + LaTeX summaries of an equation solution (copy / history).
(String, String) equationSummary(EquationSolution s, FormatOptions o, AppLocalizations l) {
  final v = s.variable;
  if (s.alwaysTrue) {
    final text = l.solveAlwaysTrue(v);
    return (text, '\\text{$text}');
  }
  final plain = <String>[];
  final tex = <String>[];
  for (final r in s.roots) {
    final f = RootForms.of(r.value, o, surd: r.surd, exact: r.exact);
    plain.add('$v ${f.exactText == null ? '≈' : '='} ${f.exactText ?? f.decimalText}');
    tex.add('${varLatex(v)}${f.relation}${f.mainLatex}');
  }
  for (final sym in s.symbolic) {
    plain.add('$v = ${symText(sym)}');
    tex.add('${varLatex(v)}=${symLatex(sym)}');
  }
  if (plain.isEmpty) return (l.solveNoSolutionFound, r'\varnothing');
  return (plain.join('; '), tex.join(r',\quad '));
}

/// Full textbook presentation of an [EquationSolution].
class EquationResultView extends StatelessWidget {
  const EquationResultView({super.key, required this.solution, required this.settings, this.actions = const []});
  final EquationSolution solution;
  final AppSettings settings;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final o = settings.formatOptions();
    final s = solution;
    final (plain, _) = equationSummary(s, o, l);
    final children = <Widget>[];
    if (s.alwaysTrue) {
      children.add(SolveMessage(l.solveAlwaysTrue(s.variable), error: false, icon: Icons.all_inclusive));
    }
    if (s.discriminant != null) {
      children.add(DiscriminantView(discriminant: s.discriminant!, options: o));
    }
    final n = s.roots.length;
    for (var k = 0; k < n; k++) {
      final r = s.roots[k];
      children.add(
        RootTile(
          variable: s.variable,
          index: k + 1,
          showIndex: n > 1,
          forms: RootForms.of(r.value, o, surd: r.surd, exact: r.exact),
          isReal: r.isReal,
          multiplicity: r.multiplicity,
        ),
      );
    }
    if (s.symbolic.isNotEmpty) {
      children.add(SolveNote(l.solveSymbolicNote(s.variable)));
      for (var k = 0; k < s.symbolic.length; k++) {
        final name = s.symbolic.length > 1 ? '${varLatex(s.variable)}_{${k + 1}}' : varLatex(s.variable);
        children.add(
          MathLine('$name=${symLatex(s.symbolic[k])}', fallback: '${s.variable} = ${symText(s.symbolic[k])}'),
        );
      }
    }
    if (!s.alwaysTrue && n == 0 && s.symbolic.isEmpty) {
      children.add(
        SolveMessage(s.method == SolveMethod.numeric ? l.solveNoRootInInterval : l.solveNoSolutionFound, error: false),
      );
    }
    if (s.method == SolveMethod.numeric) {
      children.add(SolveNote(l.solveNumericNote, icon: Icons.speed_outlined));
      final iv = s.searchInterval;
      if (iv != null) {
        children.add(
          SolveNote(l.solveSearchedInterval(formatDouble(iv.$1, o), formatDouble(iv.$2, o)), icon: Icons.straighten),
        );
      }
    }
    if (s.periodic) children.add(SolveNote(l.solvePeriodicNote, icon: Icons.all_inclusive));
    if (s.degree != null && s.method == SolveMethod.polynomial) {
      children.add(SolveNote(l.solvePolynomialDegree(s.degree!)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SolveResultCard(
          title: s.alwaysTrue ? l.solveSolution : l.solveSolutionsCount(n + s.symbolic.length),
          copyText: plain,
          actions: actions,
          children: children,
        ),
        if (s.steps.isNotEmpty) StepsView(steps: readableSteps(s.steps)),
      ],
    );
  }
}

// ---------------------------------------------------------- linear systems

(String, String) systemSummary(LinearSystemSolution s, FormatOptions o, AppLocalizations l) {
  switch (s.kind) {
    case SystemKind.unique:
      final plain = <String>[];
      final tex = <String>[];
      for (var k = 0; k < s.variables.length; k++) {
        final f = RootForms.of(s.values[k], o);
        plain.add('${s.variables[k]} = ${f.exactText ?? f.decimalText}');
        tex.add('${varLatex(s.variables[k])}${f.relation}${f.mainLatex}');
      }
      return (plain.join(', '), tex.join(r',\quad '));
    case SystemKind.none:
      return (l.solveSystemNone, r'\varnothing');
    case SystemKind.infinite:
      final tex = [for (var k = 0; k < s.variables.length; k++) '${varLatex(s.variables[k])}=${s.parametric[k]}'];
      return (l.solveSystemInfinite, tex.join(r',\quad '));
  }
}

/// Unique / none / infinitely many solutions with Gauss–Jordan steps.
class LinearSystemResultView extends StatelessWidget {
  const LinearSystemResultView({super.key, required this.solution, required this.settings});
  final LinearSystemSolution solution;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final o = settings.formatOptions();
    final s = solution;
    final (plain, _) = systemSummary(s, o, l);
    final children = <Widget>[];
    switch (s.kind) {
      case SystemKind.unique:
        for (var k = 0; k < s.variables.length; k++) {
          children.add(
            RootTile(
              variable: s.variables[k],
              index: k + 1,
              showIndex: false,
              forms: RootForms.of(s.values[k], o),
              isReal: s.values[k] is! Cpx,
            ),
          );
        }
      case SystemKind.none:
        children.add(SolveMessage(l.solveSystemNone, error: false, icon: Icons.block));
      case SystemKind.infinite:
        children.add(SolveMessage(l.solveSystemInfinite, error: false, icon: Icons.all_inclusive));
        for (var k = 0; k < s.variables.length; k++) {
          children.add(MathLine('${varLatex(s.variables[k])}=${s.parametric[k]}'));
        }
        children.add(SolveNote(l.solveSystemParameters));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SolveResultCard(
          title: switch (s.kind) {
            SystemKind.unique => l.solveSystemUnique,
            SystemKind.none => l.solveSolution,
            SystemKind.infinite => l.solveSolution,
          },
          copyText: s.kind == SystemKind.infinite
              ? [for (var k = 0; k < s.variables.length; k++) '${s.variables[k]} = ${s.parametric[k]}'].join(', ')
              : plain,
          children: children,
        ),
        if (s.steps.isNotEmpty) StepsView(steps: readableSteps(s.steps)),
      ],
    );
  }
}

/// Two-pane layout on wide screens (≥ 720 dp), single scroll on phones.
class SolveLayout extends StatelessWidget {
  const SolveLayout({super.key, required this.input, required this.output});
  final List<Widget> input;
  final List<Widget> output;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 720) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: (c.maxWidth * 0.45).clamp(340.0, 520.0),
                  child: ListView(padding: const EdgeInsets.all(16), children: input),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ListView(padding: const EdgeInsets.all(16), children: output),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [...input, const SizedBox(height: 8), ...output],
          );
        },
      ),
    );
  }
}
