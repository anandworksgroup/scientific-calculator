import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/math_view.dart';
import '../../widgets/steps_view.dart';
import 'solve_common.dart';

/// Polynomial equation solver (URS §21–22): degree 1–10, real and complex
/// roots with multiplicity; discriminant and exact surds for quadratics.
class PolynomialScreen extends ConsumerStatefulWidget {
  const PolynomialScreen({super.key, this.initialDegree = 2});

  /// Degree shown when the screen opens (1–10).
  final int initialDegree;

  @override
  ConsumerState<PolynomialScreen> createState() => _PolynomialScreenState();
}

class _PolynomialScreenState extends ConsumerState<PolynomialScreen> with EngineRunner {
  static const maxDegree = 10;

  late int _degree = widget.initialDegree.clamp(1, maxDegree);

  /// Index = power of x.
  final _coef = List.generate(maxDegree + 1, (_) => TextEditingController());

  PolynomialSolution? _solution;
  String? _solvedLatex;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    for (final c in _coef) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final c in _coef) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  String _monomial(int k) => k == 0 ? '' : (k == 1 ? 'x' : 'x^{$k}');

  String _polyLatex() {
    final env = ref.read(environmentProvider);
    final terms = [for (var k = _degree; k >= 0; k--) (_coef[k].text, _monomial(k))];
    return '${linearComboLatex(terms, env)}=0';
  }

  void _setCoefficients(int degree, List<String> highToLow) {
    setState(() {
      _degree = degree;
      for (var k = 0; k <= maxDegree; k++) {
        _coef[k].text = '';
      }
      for (var i = 0; i < highToLow.length; i++) {
        _coef[degree - i].text = highToLow[i];
      }
      _solution = null;
      _message = null;
    });
  }

  void _showMessage(String text, {bool error = true}) => setState(() {
    _message = text;
    _messageIsError = error;
    _solution = null;
  });

  Future<void> _solve() async {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final coeffs = [for (var k = _degree; k >= 0; k--) ClipboardService.sanitize(_coef[k].text)];
    if (coeffs.every((c) => c.isEmpty)) {
      _showMessage(l.solvePolyEnterCoefficients);
      return;
    }
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider).copy();
    final tex = _polyLatex();
    final r = await runEngine(polynomialTask(coeffs, settings.calcSettings, env));
    if (r == null || !mounted) return;
    switch (r) {
      case Success(:final value):
        setState(() {
          _solution = value;
          _solvedLatex = tex;
          _message = null;
        });
        final (plain, resultTex) = _summary(value, l);
        await recordSolveHistory(
          ref,
          mode: 'polynomial',
          expression: _plainPolynomial(coeffs),
          expressionLatex: tex,
          result: plain,
          resultLatex: resultTex,
        );
      case Failure(:final error):
        _showMessage(errorText(l, error));
      case Cancelled():
        _showMessage(l.errCancelled, error: false);
    }
  }

  String _plainPolynomial(List<String> highToLow) {
    final n = highToLow.length - 1;
    final parts = <String>[];
    for (var i = 0; i <= n; i++) {
      final c = highToLow[i].isEmpty ? '0' : highToLow[i];
      final k = n - i;
      parts.add(k == 0 ? '($c)' : (k == 1 ? '($c)x' : '($c)x^$k'));
    }
    return '${parts.join('+')}=0';
  }

  (String, String) _summary(PolynomialSolution s, AppLocalizations l) {
    final o = ref.read(settingsProvider).formatOptions();
    final plain = <String>[];
    final tex = <String>[];
    for (final r in s.roots) {
      final f = RootForms.of(r.value, o, surd: r.surd);
      final m = r.multiplicity > 1 ? ' (×${r.multiplicity})' : '';
      plain.add('x ${f.exactText == null ? '≈' : '='} ${f.exactText ?? f.decimalText}$m');
      tex.add('x${f.relation}${f.mainLatex}');
    }
    return (plain.join('; '), tex.join(r',\quad '));
  }

  void _cancel() {
    cancelEngine();
    _showMessage(AppLocalizations.of(context).errCancelled, error: false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    ref.watch(environmentProvider); // preview depends on stored variables

    final input = <Widget>[
      Row(
        children: [
          Text(l.solvePolyDegree, style: theme.textTheme.labelLarge),
          const SizedBox(width: 12),
          DropdownButton<int>(
            key: const Key('solve-poly-degree'),
            value: _degree,
            items: [for (var d = 1; d <= maxDegree; d++) DropdownMenuItem(value: d, child: Text('$d'))],
            onChanged: (d) => setState(() {
              if (d != null) _degree = d;
              _solution = null;
            }),
          ),
          const Spacer(),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ActionChip(
            key: const Key('solve-poly-quadratic'),
            avatar: const Icon(Icons.functions, size: 18),
            label: Text(l.solvePolyQuadratic),
            onPressed: () => _setCoefficients(2, const []),
          ),
          ActionChip(
            key: const Key('solve-poly-example'),
            avatar: const Icon(Icons.lightbulb_outline, size: 18),
            label: Text(l.solvePolyExample),
            onPressed: () => _setCoefficients(3, const ['1', '-6', '11', '-6']),
          ),
          ActionChip(
            avatar: const Icon(Icons.clear, size: 18),
            label: Text(l.actionClear),
            onPressed: () => _setCoefficients(_degree, const []),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 480 ? 3 : 2;
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var k = _degree; k >= 0; k--)
                SizedBox(
                  width: w,
                  child: TextField(
                    key: Key('solve-poly-coef-$k'),
                    controller: _coef[k],
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    autocorrect: false,
                    decoration: InputDecoration(
                      label: Semantics(
                        label: l.solvePolyCoefficientOf(k),
                        child: ExcludeSemantics(child: MathView(k == 0 ? 'a_{0}' : 'a_{$k}\\,${_monomial(k)}')),
                      ),
                      hintText: '0',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      Text(l.solvePreview, style: theme.textTheme.labelLarge),
      MathLine(_polyLatex()),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('solve-poly-solve'),
        onPressed: busy ? null : _solve,
        icon: const Icon(Icons.play_arrow),
        label: Text(l.actionSolve),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ];

    final s = _solution;
    final output = <Widget>[
      if (busy) SolveBusy(onCancel: _cancel),
      if (_message != null) SolveMessage(_message!, error: _messageIsError),
      if (s != null) ...[
        if (_solvedLatex != null) MathLine(_solvedLatex!),
        _PolynomialResult(solution: s, summary: _summary(s, l).$1),
        if (s.steps.isNotEmpty) StepsView(steps: readableSteps(s.steps)),
      ],
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.toolPolynomial), actions: const [AppMenuButton()]),
      body: SolveLayout(input: input, output: output),
    );
  }
}

class _PolynomialResult extends ConsumerWidget {
  const _PolynomialResult({required this.solution, required this.summary});
  final PolynomialSolution solution;
  final String summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final o = ref.watch(settingsProvider).formatOptions();
    final s = solution;
    final real = s.roots.where((r) => r.isReal).fold<int>(0, (a, r) => a + r.multiplicity);
    final complex = s.roots.where((r) => !r.isReal).fold<int>(0, (a, r) => a + r.multiplicity);
    return SolveResultCard(
      title: l.solveSolutionsCount(s.roots.length),
      copyText: summary,
      children: [
        SolveNote(l.solvePolynomialDegree(s.degree)),
        if (s.degree == 2 && s.discriminant != null) DiscriminantView(discriminant: s.discriminant!, options: o),
        SolveNote(l.solveRootCounts(real, complex)),
        for (var k = 0; k < s.roots.length; k++)
          RootTile(
            variable: 'x',
            index: k + 1,
            showIndex: s.roots.length > 1,
            forms: RootForms.of(s.roots[k].value, o, surd: s.roots[k].surd),
            isReal: s.roots[k].isReal,
            multiplicity: s.roots[k].multiplicity,
          ),
      ],
    );
  }
}
