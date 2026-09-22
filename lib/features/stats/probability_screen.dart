import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/engine_service.dart';
import '../../widgets/math_view.dart';
import '../calculus/calc_ui.dart';

enum ProbDist { combinatorics, normal, binomial, poisson }

enum ProbQuantity {
  nCr,
  nPr,
  factorial,
  normPdf,
  normCdf,
  normUpper,
  normBetween,
  normInverse,
  binomPdf,
  binomCdf,
  binomUpper,
  binomInverse,
  poisPdf,
  poisCdf,
  poisUpper,
  poisInverse,
}

/// One computed quantity (each can fail on its own).
class ProbItem {
  const ProbItem(this.quantity, this.result);
  final ProbQuantity quantity;
  final EngineResult<Num> result;
}

Num _evalNum(String text, CalcSettings settings, Environment env) {
  final r = const DefaultMathEngine().evaluate(text, settings, env);
  switch (r) {
    case Success(:final value):
      final v = value.value;
      if (v is NumberValue) return v.n;
      throw const MathError(MathErrorCode.typeMismatch, {'detail': 'Enter a number.'});
    case Failure(:final error):
      throw error;
    case Cancelled():
      throw const MathError(MathErrorCode.cancelled);
  }
}

/// Computes every quantity whose inputs are filled in. Top-level so it can
/// run in an isolate.
EngineResult<List<ProbItem>> probabilityTask(ProbDist dist, Map<String, String> input, CalcSettings settings, Environment env) {
  return guard(() {
    final a = Arith(precision: settings.precision);
    final p = Probability(a);
    String t(String k) => (input[k] ?? '').trim();
    bool has(String k) => t(k).isNotEmpty;
    Num n(String k) {
      if (!has(k)) throw const MathError(MathErrorCode.emptyInput);
      return _evalNum(t(k), settings, env);
    }

    final out = <ProbItem>[];
    void add(ProbQuantity q, Num Function() f) {
      final r = guard(f);
      if (r is Cancelled<Num>) throw const MathError(MathErrorCode.cancelled);
      out.add(ProbItem(q, r));
    }

    switch (dist) {
      case ProbDist.combinatorics:
        if (has('n') && has('r')) {
          add(ProbQuantity.nCr, () => _evalNum('nCr((${t('n')}),(${t('r')}))', settings, env));
          add(ProbQuantity.nPr, () => _evalNum('nPr((${t('n')}),(${t('r')}))', settings, env));
        }
        if (has('n')) add(ProbQuantity.factorial, () => _evalNum('(${t('n')})!', settings, env));
      case ProbDist.normal:
        if (has('x')) {
          add(ProbQuantity.normPdf, () => p.normalPdf(n('x'), n('mu'), n('sigma')));
          add(ProbQuantity.normCdf, () => p.normalCdf(n('x'), n('mu'), n('sigma')));
          add(ProbQuantity.normUpper, () => a.sub(Rat.one, p.normalCdf(n('x'), n('mu'), n('sigma'))));
        }
        if (has('a') && has('b')) add(ProbQuantity.normBetween, () => p.normalBetween(n('a'), n('b'), n('mu'), n('sigma')));
        if (has('p')) add(ProbQuantity.normInverse, () => p.inverseNormal(n('p'), n('mu'), n('sigma')));
      case ProbDist.binomial:
        if (has('k')) {
          add(ProbQuantity.binomPdf, () => p.binomialPdf(n('n'), n('p'), n('k')));
          add(ProbQuantity.binomCdf, () => p.binomialCdf(n('n'), n('p'), n('k')));
          add(ProbQuantity.binomUpper, () {
            final k = n('k');
            final c = p.binomialCdf(n('n'), n('p'), a.sub(a.ceil(k), Rat.one));
            return a.sub(Rat.one, c);
          });
        }
        if (has('q')) add(ProbQuantity.binomInverse, () => p.inverseBinomial(n('n'), n('p'), n('q')));
      case ProbDist.poisson:
        if (has('k')) {
          add(ProbQuantity.poisPdf, () => p.poissonPdf(n('lambda'), n('k')));
          add(ProbQuantity.poisCdf, () => p.poissonCdf(n('lambda'), n('k')));
          add(ProbQuantity.poisUpper, () {
            final k = n('k');
            final c = p.poissonCdf(n('lambda'), a.sub(a.ceil(k), Rat.one));
            return a.sub(Rat.one, c);
          });
        }
        if (has('q')) add(ProbQuantity.poisInverse, () => p.inversePoisson(n('lambda'), n('q')));
    }
    if (out.isEmpty) throw const MathError(MathErrorCode.emptyInput);
    return out;
  });
}

Computation<List<ProbItem>> _startProbability(
        EngineService s, ProbDist d, Map<String, String> input, CalcSettings settings, Environment env) =>
    s.run(() => probabilityTask(d, input, settings, env));

/// Probability tools (URS §44): combinatorics, normal, binomial and Poisson
/// distributions.
class ProbabilityScreen extends StatelessWidget {
  const ProbabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.toolProbability),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.probCombinatorics),
              Tab(text: l.probNormal),
              Tab(text: l.probBinomial),
              Tab(text: l.probPoisson),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _ProbTab(ProbDist.combinatorics),
          _ProbTab(ProbDist.normal),
          _ProbTab(ProbDist.binomial),
          _ProbTab(ProbDist.poisson),
        ]),
      ),
    );
  }
}

class _Field {
  const _Field(this.key, this.initial);
  final String key;
  final String initial;
}

const _fields = {
  ProbDist.combinatorics: [_Field('n', '10'), _Field('r', '3')],
  ProbDist.normal: [_Field('mu', '0'), _Field('sigma', '1'), _Field('x', '1.96'), _Field('a', '-1'), _Field('b', '1'), _Field('p', '0.95')],
  ProbDist.binomial: [_Field('n', '10'), _Field('p', '0.5'), _Field('k', '3'), _Field('q', '0.5')],
  ProbDist.poisson: [_Field('lambda', '2'), _Field('k', '3'), _Field('q', '0.5')],
};

class _ProbTab extends ConsumerStatefulWidget {
  const _ProbTab(this.dist);
  final ProbDist dist;

  @override
  ConsumerState<_ProbTab> createState() => _ProbTabState();
}

class _ProbTabState extends ConsumerState<_ProbTab> with EngineRunner, AutomaticKeepAliveClientMixin {
  late final Map<String, TextEditingController> _c = {
    for (final f in _fields[widget.dist]!) f.key: TextEditingController(text: f.initial),
  };
  List<ProbItem>? _items;
  Map<String, String> _usedTex = const {};
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _label(AppLocalizations l, String key) => switch ((widget.dist, key)) {
        (_, 'n') when widget.dist == ProbDist.combinatorics => l.probNItems,
        (_, 'r') => l.probRChosen,
        (_, 'mu') => l.probMean,
        (_, 'sigma') => l.probStdDev,
        (_, 'x') => l.probXValue,
        (_, 'a') => l.probLowerA,
        (_, 'b') => l.probUpperB,
        (ProbDist.normal, 'p') => l.probAreaP,
        (_, 'n') => l.probTrials,
        (_, 'p') => l.probSuccess,
        (_, 'k') => l.probK,
        (_, 'q') => l.probCumulativeQ,
        (_, 'lambda') => l.probLambda,
        _ => key,
      };

  Future<void> _compute() async {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final input = {for (final e in _c.entries) e.key: cleanInput(e.value.text)};
    final dist = widget.dist;
    final r = await runEngine(_startProbability(engineService, dist, input, settings.calcSettings, env.copy()));
    if (r == null) return;
    setState(() {
      _items = null;
      _error = null;
      _usedTex = {for (final e in input.entries) e.key: exprLatex(e.value, env: env) ?? e.value};
      switch (r) {
        case Success(:final value):
          _items = value;
        case Failure(:final error):
          _error = errorText(l, error);
        case Cancelled():
          _error = l.errCancelled;
      }
    });
    final items = _items;
    if (items == null) return;
    final first = items.where((i) => i.result.isSuccess).firstOrNull;
    if (first == null) return;
    final v = first.result.valueOrNull!;
    final f = formatNum(settings, v);
    final (label, tex) = _describe(l, first.quantity);
    await recordHistory(ref,
        mode: 'probability',
        expression: '$label (${input.entries.where((e) => e.value.isNotEmpty).map((e) => '${e.key}=${e.value}').join(', ')})',
        expressionLatex: tex,
        result: f.plain,
        resultLatex: f.latex,
        value: NumberValue(v));
  }

  /// (label, left-hand side LaTeX) for a quantity using the inputs.
  (String, String) _describe(AppLocalizations l, ProbQuantity q) {
    String t(String k) => '{${_usedTex[k] ?? k}}';
    return switch (q) {
      ProbQuantity.nCr => (l.probCombinations, '\\binom${t('n')}${t('r')}'),
      ProbQuantity.nPr => (l.probPermutations, '{}^{${_usedTex['n']}}P_{${_usedTex['r']}}'),
      ProbQuantity.factorial => (l.probFactorial, '${t('n')}!'),
      ProbQuantity.normPdf => (l.probDensity, 'f\\left(${t('x')}\\right)'),
      ProbQuantity.normCdf => (l.probCdf, 'P\\left(X\\le ${t('x')}\\right)'),
      ProbQuantity.normUpper => (l.probUpperTail, 'P\\left(X>${t('x')}\\right)'),
      ProbQuantity.normBetween => (l.probBetween, 'P\\left(${t('a')}\\le X\\le ${t('b')}\\right)'),
      ProbQuantity.normInverse => (l.probInverseNormal, 'P\\left(X\\le x\\right)=${t('p')}\\Rightarrow x'),
      ProbQuantity.binomPdf || ProbQuantity.poisPdf => (l.probPmf, 'P\\left(X=${t('k')}\\right)'),
      ProbQuantity.binomCdf || ProbQuantity.poisCdf => (l.probCdf, 'P\\left(X\\le ${t('k')}\\right)'),
      ProbQuantity.binomUpper || ProbQuantity.poisUpper => (l.probUpperTail, 'P\\left(X\\ge ${t('k')}\\right)'),
      ProbQuantity.binomInverse ||
      ProbQuantity.poisInverse =>
        (l.probInverseDiscrete, '\\min\\left\\{k:P\\left(X\\le k\\right)\\ge ${t('q')}\\right\\}'),
    };
  }

  String? _distTex() {
    String t(String k) => '{${_usedTex[k] ?? k}}';
    return switch (widget.dist) {
      ProbDist.combinatorics => null,
      ProbDist.normal => 'X\\sim N\\left(${t('mu')},\\ ${t('sigma')}^{2}\\right)',
      ProbDist.binomial => 'X\\sim B\\left(${t('n')},\\ ${t('p')}\\right)',
      ProbDist.poisson => 'X\\sim \\mathrm{Po}\\left(${t('lambda')}\\right)',
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final fields = _fields[widget.dist]!;
    final form = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FieldRow(minFieldWidth: 130, children: [
        for (final f in fields)
          SmallField(
            key: ValueKey('prob.${widget.dist.name}.${f.key}'),
            controller: _c[f.key]!,
            label: _label(l, f.key),
            onSubmitted: _compute,
          ),
      ]),
      const SizedBox(height: 12),
      InfoNote(widget.dist == ProbDist.combinatorics ? l.probCombinatoricsHelp : l.probOptionalHelp),
      const SizedBox(height: 16),
      ComputeButton(
          key: ValueKey('prob.${widget.dist.name}.calculate'), label: l.actionCalculate, onPressed: busy ? null : _compute),
      if (busy) BusyRow(onCancel: cancelRun),
    ]);
    Widget result;
    if (_error != null) {
      result = ErrorPanel(_error!);
    } else if (_items == null) {
      result = InfoNote(l.probEmpty, icon: Icons.casino_outlined);
    } else {
      final dt = _distTex();
      result = ResultPanel(children: [
        if (dt != null) ...[
          ExcludeSemantics(child: MathView(dt, style: Theme.of(context).textTheme.titleMedium)),
          const Divider(),
        ],
        for (final item in _items!)
          ...switch (item.result) {
            Success(:final value) => () {
                final (label, tex) = _describe(l, item.quantity);
                return numberResult(settings, label: label, lhsTex: '$tex=', n: value);
              }(),
            Failure(:final error) => [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ErrorPanel('${_describe(l, item.quantity).$1}: ${errorText(l, error)}'),
                ),
              ],
            Cancelled() => const <Widget>[],
          },
      ]);
    }
    return FormResultLayout(form: form, result: result);
  }
}
