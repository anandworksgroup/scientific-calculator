import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/engine_service.dart';
import '../../widgets/math_view.dart';
import 'calc_ui.dart';

/// Value of a finite sum or product.
class SeriesOutcome {
  const SeriesOutcome(this.value, {this.preferDecimal = false, this.exactTex, this.exactText});
  final Value value;
  final bool preferDecimal;
  final String? exactTex;
  final String? exactText;
}

/// Σ/Π via the engine's lazy `sum`/`prod` functions. Top-level for isolates.
EngineResult<SeriesOutcome> seriesTask(
    bool product, String term, String index, String lower, String upper, CalcSettings settings, Environment env) {
  final fn = product ? 'prod' : 'sum';
  final r = const DefaultMathEngine().evaluate('$fn(($term),$index,($lower),($upper))', settings, env);
  return switch (r) {
    Success(:final value) =>
      Success(SeriesOutcome(value.value, preferDecimal: value.preferDecimal, exactTex: value.exactLatex, exactText: value.exactText)),
    Failure(:final error) => Failure(error),
    Cancelled() => const Cancelled(),
  };
}

Computation<SeriesOutcome> _startSeries(EngineService s, bool product, String term, String index, String lo, String hi,
        CalcSettings settings, Environment env) =>
    s.run(() => seriesTask(product, term, index, lo, hi, settings, env));

/// Summation Σ and product Π calculator (URS §32–33).
class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> with EngineRunner {
  final _term = TextEditingController();
  final _index = TextEditingController(text: 'k');
  final _lo = TextEditingController(text: '1');
  final _hi = TextEditingController(text: '10');
  bool _product = false;

  SeriesOutcome? _result;
  String? _error;
  String _lhsTex = '';
  bool _resultProduct = false;

  static const _examples = [
    (false, 'k', '1', '100'),
    (true, 'k', '1', '5'),
    (false, '1/k^2', '1', '100'),
    (false, '2^k', '0', '10'),
    (true, '(1+1/k)', '1', '9'),
  ];

  @override
  void initState() {
    super.initState();
    _index.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _term.dispose();
    _index.dispose();
    _lo.dispose();
    _hi.dispose();
    super.dispose();
  }

  String _headTex(bool product, String index, String loTex, String hiTex) =>
      '${product ? r'\prod' : r'\sum'}_{${varLatex(index)}=$loTex}^{$hiTex}';

  Future<void> _compute() async {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final term = cleanInput(_term.text);
    final k = cleanVariable(_index.text, fallback: 'k');
    final lo = cleanInput(_lo.text), hi = cleanInput(_hi.text);
    if (k == null || lo.isEmpty || hi.isEmpty) {
      setState(() {
        _result = null;
        _error = k == null ? l.calculusInvalidVariable : l.calculusBothBounds;
      });
      return;
    }
    final product = _product;
    final r = await runEngine(_startSeries(engineService, product, term, k, lo, hi, settings.calcSettings, env.copy()));
    if (r == null) return;
    final termTex = exprLatex(term, bound: {k}, env: env) ?? term;
    setState(() {
      _lhsTex =
          '${_headTex(product, k, exprLatex(lo, env: env) ?? lo, exprLatex(hi, env: env) ?? hi)}\\left($termTex\\right)';
      _resultProduct = product;
      _result = null;
      _error = null;
      switch (r) {
        case Success(:final value):
          _result = value;
        case Failure(:final error):
          _error = errorText(l, error);
        case Cancelled():
          _error = l.errCancelled;
      }
    });
    if (r case Success(:final value)) {
      final shown = ValueFormatter(settings.formatOptions()).format(value.value, preferDecimal: value.preferDecimal);
      await recordHistory(
        ref,
        mode: 'series',
        expression: '${product ? 'prod' : 'sum'}($term,$k,$lo,$hi)',
        expressionLatex: _lhsTex,
        result: shown.plain,
        resultLatex: shown.latex,
        value: value.value,
      );
    }
  }

  void _useExample((bool, String, String, String) e) {
    setState(() {
      _product = e.$1;
      _term.text = e.$2;
      _index.text = 'k';
      _lo.text = e.$3;
      _hi.text = e.$4;
    });
    _compute();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final k = cleanVariable(_index.text, fallback: 'k') ?? 'k';
    return Scaffold(
      appBar: AppBar(title: Text(l.toolSeries)),
      body: FormResultLayout(
        form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            label: l.calculusSeriesKind,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.calculusSum), icon: const Text('Σ')),
                ButtonSegment(value: true, label: Text(l.calculusProduct), icon: const Text('Π')),
              ],
              selected: {_product},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _product = s.first),
            ),
          ),
          const SizedBox(height: 12),
          MathInputField(
            key: const ValueKey('series.term'),
            controller: _term,
            label: l.calculusTerm(k),
            hint: l.calculusTermHint,
            bound: {k},
            onSubmitted: _compute,
          ),
          const SizedBox(height: 12),
          FieldRow(minFieldWidth: 100, children: [
            SmallField(key: const ValueKey('series.index'), controller: _index, label: l.calculusIndexVariable),
            SmallField(key: const ValueKey('series.lower'), controller: _lo, label: l.calculusLowerBound, onSubmitted: _compute),
            SmallField(key: const ValueKey('series.upper'), controller: _hi, label: l.calculusUpperBound, onSubmitted: _compute),
          ]),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: Listenable.merge([_term, _lo, _hi]),
            builder: (context, _) {
              final termTex = exprLatex(_term.text, bound: {k}) ?? r'\square';
              final tex = '${_headTex(_product, k, exprLatex(_lo.text) ?? r'\square', exprLatex(_hi.text) ?? r'\square')}$termTex';
              return ExcludeSemantics(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: MathView(tex, display: true, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          InfoNote(l.calculusSeriesNote(settings.angleMode.name.toUpperCase())),
          const SizedBox(height: 16),
          ComputeButton(label: l.actionCalculate, onPressed: busy ? null : _compute),
          if (busy) BusyRow(onCancel: cancelRun),
          const SizedBox(height: 16),
          Text(l.calculusExamples, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in _examples)
              ActionChip(
                onPressed: busy ? null : () => _useExample(e),
                label: MathView(
                  '${_headTex(e.$1, 'k', e.$3, e.$4)}${exprLatex(e.$2, bound: const {'k'}) ?? e.$2}',
                  semanticsLabel: '${e.$1 ? l.calculusProduct : l.calculusSum}: ${e.$2}, k = ${e.$3}…${e.$4}',
                ),
              ),
          ]),
        ]),
        result: _buildResult(l),
      ),
    );
  }

  Widget _buildResult(AppLocalizations l) {
    if (_error != null) return ErrorPanel(_error!);
    final r = _result;
    if (r == null) return InfoNote(l.calculusSeriesEmpty, icon: Icons.functions);
    final s = ref.watch(settingsProvider);
    final v = r.value;
    if (v is NumberValue) {
      return ResultPanel(children: [
        ...numberResult(s,
            label: _resultProduct ? l.calculusProduct : l.calculusSum, lhsTex: '$_lhsTex=', n: v.n, exactTex: r.exactTex, exactPlain: r.exactText),
      ]);
    }
    final shown = ValueFormatter(s.formatOptions()).format(v, preferDecimal: r.preferDecimal);
    return ResultPanel(children: [ResultLine(tex: '$_lhsTex=${shown.latex}', plain: shown.plain, large: true)]);
  }
}
