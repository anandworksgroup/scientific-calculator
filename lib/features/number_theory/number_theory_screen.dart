import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../data/repositories/history_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/math_view.dart';
import '../../widgets/steps_view.dart';
import '../calculator/calculator_controller.dart' show historyListProvider;

// ------------------------------------------------------------ isolate tasks
//
// Everything below runs in a background isolate, so it only uses plain data.

/// Marker parameter: the input named `field` is not a whole number.
const _fieldParam = 'ntField';

/// Marker parameter: fewer than two numbers were given for GCD/LCM.
const _needTwoParam = 'ntNeedTwo';

BigInt _parseInteger(String text, String field, CalcSettings s, Environment env) {
  final r = EngineService.engine.evaluate(ClipboardService.sanitize(text), s, env);
  switch (r) {
    case Success(:final value):
      final v = value.value;
      if (v is NumberValue && v.n is Rat && (v.n as Rat).isInteger) return (v.n as Rat).n;
      throw MathError(MathErrorCode.nonIntegerArgument, {_fieldParam: field});
    case Failure(:final error):
      throw error;
    case Cancelled():
      throw const MathError(MathErrorCode.cancelled);
  }
}

BigInt _evalInteger(String expr, CalcSettings s) {
  final r = EngineService.engine.evaluate(expr, s, Environment());
  final v = r.valueOrNull?.value;
  if (v is NumberValue && v.n is Rat && (v.n as Rat).isInteger) return (v.n as Rat).n;
  throw r.errorOrNull ?? const MathError(MathErrorCode.invalidExpression);
}

/// Results of analyzing a single integer.
class NtAnalysis {
  const NtAnalysis({
    required this.n,
    required this.isPrime,
    required this.factorization,
    required this.divisors,
    required this.divisorCount,
    required this.divisorSum,
    required this.next,
    required this.previous,
    required this.totient,
  });

  final BigInt n;
  final bool isPrime;
  final EngineResult<FactorizationValue> factorization;

  /// First divisors (display is capped); [divisorCount] is the full count.
  final EngineResult<List<BigInt>> divisors;
  final int divisorCount;
  final BigInt divisorSum;
  final EngineResult<BigInt> next;

  /// Success(null) when there is no smaller prime.
  final EngineResult<BigInt?> previous;
  final EngineResult<BigInt> totient;
}

const maxShownDivisors = 500;

EngineResult<NtAnalysis> Function() ntAnalyzeTask(String input, CalcSettings s, Environment env) => () => guard(() {
      final n = _parseInteger(input, 'n', s, env);
      final fact = guard(() {
        final abs = n.abs();
        final factors = abs < BigInt.two ? <(BigInt, int)>[] : NumberTheory.factorize(abs);
        return FactorizationValue(n.isNegative ? -1 : 1, factors, n);
      });
      var count = 0;
      var sum = BigInt.zero;
      final divs = guard(() {
        final all = NumberTheory.divisors(n);
        count = all.length;
        for (final d in all) {
          sum += d;
        }
        return all.length > maxShownDivisors ? all.sublist(0, maxShownDivisors) : all;
      });
      return NtAnalysis(
        n: n,
        isPrime: NumberTheory.isPrime(n),
        factorization: fact,
        divisors: divs,
        divisorCount: count,
        divisorSum: sum,
        next: guard(() => NumberTheory.nextPrime(n)),
        previous: guard(() => NumberTheory.prevPrime(n)),
        totient: guard(() => NumberTheory.totient(n)),
      );
    });

/// One run of Euclid's algorithm on a pair: rows are (a, b, q, r) with a = q·b + r.
class EuclidRun {
  const EuclidRun(this.a, this.b, this.rows, this.gcd);
  final BigInt a, b;
  final List<(BigInt, BigInt, BigInt, BigInt)> rows;
  final BigInt gcd;
}

class NtGcdResult {
  const NtGcdResult(this.numbers, this.gcd, this.lcm, this.runs);
  final List<BigInt> numbers;
  final BigInt gcd;
  final BigInt lcm;
  final List<EuclidRun> runs;
}

EuclidRun _euclid(BigInt x, BigInt y) {
  var a = x.abs(), b = y.abs();
  final rows = <(BigInt, BigInt, BigInt, BigInt)>[];
  while (b != BigInt.zero) {
    final q = a ~/ b;
    final r = a - q * b;
    rows.add((a, b, q, r));
    a = b;
    b = r;
  }
  return EuclidRun(x.abs(), y.abs(), rows, a);
}

EngineResult<NtGcdResult> Function() ntGcdTask(String input, CalcSettings s, Environment env) => () => guard(() {
      final parts = input.split(RegExp(r'[,;]')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length < 2) throw const MathError(MathErrorCode.missingArgument, {_needTwoParam: true});
      final nums = [for (final p in parts) _parseInteger(p, 'list', s, env)];
      final args = nums.join(',');
      final g = _evalInteger('gcd($args)', s);
      final l = _evalInteger('lcm($args)', s);
      final runs = <EuclidRun>[];
      var acc = nums.first;
      for (final x in nums.skip(1)) {
        final run = _euclid(acc, x);
        runs.add(run);
        acc = run.gcd;
      }
      return NtGcdResult(nums, g, l, runs);
    });

class NtDivisionResult {
  const NtDivisionResult(this.a, this.b, this.quotient, this.remainder, this.modulo);
  final BigInt a, b, quotient, remainder, modulo;
}

EngineResult<NtDivisionResult> Function() ntDivisionTask(String aText, String bText, CalcSettings s, Environment env) =>
    () => guard(() {
          final a = _parseInteger(aText, 'a', s, env);
          final b = _parseInteger(bText, 'b', s, env);
          return NtDivisionResult(
            a,
            b,
            _evalInteger('quot($a,$b)', s),
            _evalInteger('rem($a,$b)', s),
            _evalInteger('mod($a,$b)', s),
          );
        });

// ---------------------------------------------------------------------- UI

/// A running or finished background task.
class _Job<T> {
  Computation<T>? running;
  EngineResult<T>? result;
}

/// Number theory tools (URS §18).
class NumberTheoryScreen extends ConsumerStatefulWidget {
  const NumberTheoryScreen({super.key});

  @override
  ConsumerState<NumberTheoryScreen> createState() => _NumberTheoryScreenState();
}

class _NumberTheoryScreenState extends ConsumerState<NumberTheoryScreen> {
  final _n = TextEditingController();
  final _list = TextEditingController();
  final _a = TextEditingController();
  final _b = TextEditingController();

  final _analysis = _Job<NtAnalysis>();
  final _gcd = _Job<NtGcdResult>();
  final _division = _Job<NtDivisionResult>();

  @override
  void dispose() {
    for (final j in [_analysis, _gcd, _division]) {
      j.running?.cancel();
    }
    for (final c in [_n, _list, _a, _b]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _start<T>(_Job<T> job, EngineResult<T> Function() task, Future<void> Function(T value) onSuccess) async {
    FocusScope.of(context).unfocus();
    job.running?.cancel();
    final comp = ref.read(engineServiceProvider).run(task);
    setState(() {
      job.running = comp;
      job.result = null;
    });
    final r = await comp.result;
    if (!mounted || job.running != comp) return;
    setState(() {
      job.running = null;
      job.result = r;
    });
    if (r case Success(:final value)) await onSuccess(value);
  }

  void _cancel<T>(_Job<T> job) {
    job.running?.cancel();
    setState(() {
      job.running = null;
      job.result = Cancelled<T>();
    });
  }

  Future<void> _record(String expression, String result, String resultLatex) async {
    final settings = ref.read(settingsProvider);
    if (!settings.saveHistory) return;
    try {
      await ref.read(historyRepositoryProvider).insert(
            HistoryEntry(
              expression: expression,
              expressionLatex: const LatexPrinter().print(Parser.parse(expression)),
              result: result,
              resultLatex: resultLatex,
              mode: 'number-theory',
              angleMode: settings.angleMode.name,
              format: settings.resultFormat.name,
              createdAt: DateTime.now(),
            ),
            limit: settings.historyLimit,
          );
      ref.invalidate(historyListProvider);
    } catch (e) {
      AppLogger.error('number theory history', e);
    }
  }

  void _analyze() {
    final s = ref.read(settingsProvider).calcSettings;
    _start(_analysis, ntAnalyzeTask(_n.text, s, ref.read(environmentProvider)), (v) async {
      final f = v.factorization.valueOrNull;
      if (f == null) return;
      final shown = ValueFormatter(ref.read(settingsProvider).formatOptions()).format(f);
      await _record('factor(${v.n})', shown.plain, shown.latex);
    });
  }

  void _runGcd() {
    final s = ref.read(settingsProvider).calcSettings;
    _start(_gcd, ntGcdTask(_list.text, s, ref.read(environmentProvider)), (v) async {
      final args = v.numbers.join(',');
      await _record('gcd($args)', '${v.gcd}; lcm = ${v.lcm}', '${v.gcd};\\ \\mathrm{lcm}=${v.lcm}');
    });
  }

  void _runDivision() {
    final s = ref.read(settingsProvider).calcSettings;
    _start(_division, ntDivisionTask(_a.text, _b.text, s, ref.read(environmentProvider)), (v) async {
      await _record('mod(${v.a},${v.b})', '${v.modulo}; q = ${v.quotient}, r = ${v.remainder}',
          '${v.modulo};\\ q=${v.quotient},\\ r=${v.remainder}');
    });
  }

  String _error(AppLocalizations l, MathError e) {
    final field = e.params[_fieldParam];
    if (field != null) {
      final label = switch (field) {
        'a' => l.ntDividend,
        'b' => l.ntDivisor,
        'list' => l.ntNumbers,
        _ => l.ntNumber,
      };
      return l.ntNotInteger(label);
    }
    if (e.params[_needTwoParam] != null) return l.ntNeedTwo;
    return errorText(l, e);
  }

  Future<void> _copy(String text) async {
    await ClipboardService.copy(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(settingsProvider);
    final analyze = _analyzeCard(context);
    final gcd = _gcdCard(context);
    final division = _divisionCard(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.ntTitle)),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          const gap = SizedBox(height: 12);
          if (c.maxWidth >= 720) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: analyze),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [gcd, gap, division])),
              ]),
            );
          }
          return ListView(padding: const EdgeInsets.all(16), children: [analyze, gap, gcd, gap, division]);
        }),
      ),
    );
  }

  Widget _progress<T>(_Job<T> job) {
    final l = AppLocalizations.of(context);
    return Row(children: [
      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
      const SizedBox(width: 12),
      Expanded(child: Text(l.calculating)),
      TextButton(onPressed: () => _cancel(job), child: Text(l.actionCancel)),
    ]);
  }

  Widget _section(String title, Widget body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        body,
      ]),
    );
  }

  Widget _errorLine(MathError e) =>
      Text(_error(AppLocalizations.of(context), e), style: TextStyle(color: Theme.of(context).colorScheme.error));

  Widget _analyzeCard(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final job = _analysis;
    final formatter = ValueFormatter(ref.read(settingsProvider).formatOptions());
    Widget? results;
    final r = job.result;
    if (r is Failure<NtAnalysis>) results = _errorLine(r.error);
    if (r is Cancelled<NtAnalysis>) results = _errorLine(const MathError(MathErrorCode.cancelled));
    if (r is Success<NtAnalysis>) {
      final a = r.value;
      final n = '${a.n}';
      final factors = a.factorization.valueOrNull?.factors ?? const [];
      final smallest = !a.isPrime && factors.isNotEmpty ? factors.first.$1 : null;
      Widget item<T>(EngineResult<T> res, Widget Function(T v) ok) => switch (res) {
            Success(:final value) => ok(value),
            Failure(:final error) => _errorLine(error),
            Cancelled() => _errorLine(const MathError(MathErrorCode.cancelled)),
          };
      results = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _section(
          l.ntPrimeTest,
          Text([
            a.isPrime ? l.ntIsPrime(n) : l.ntNotPrime(n),
            if (smallest != null) l.ntSmallestFactor('$smallest'),
          ].join(' ')),
        ),
        _section(
          l.ntFactorization,
          item(a.factorization, (f) {
            final shown = formatter.format(f);
            return Row(children: [
              Expanded(
                child: ScrollingMath(
                  '$n = ${shown.latex}',
                  alignRight: false,
                  fallback: '$n = ${shown.display}',
                  semanticsLabel: '$n = ${shown.display}',
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              IconButton(tooltip: l.actionCopy, icon: const Icon(Icons.copy, size: 20), onPressed: () => _copy(shown.plain)),
            ]);
          }),
        ),
        _section(
          l.ntDivisors,
          item(a.divisors, (d) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.ntDivisorCount('${a.divisorCount}')),
                Text(l.ntDivisorSum('${a.divisorSum}')),
                const SizedBox(height: 4),
                SelectableText(
                  d.join(', ') + (a.divisorCount > d.length ? ' ${l.ntMoreDivisors(a.divisorCount - d.length)}' : ''),
                  style: theme.textTheme.bodyMedium,
                ),
              ])),
        ),
        _section(l.ntNextPrime, item(a.next, (p) => SelectableText('$p'))),
        _section(l.ntPrevPrime, item(a.previous, (p) => SelectableText(p == null ? l.ntNoPrevPrime(n) : '$p'))),
        _section(l.ntTotient, item(a.totient, (t) => SelectableText('φ($n) = $t'))),
      ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            key: const ValueKey('nt-n'),
            controller: _n,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _analyze(),
            decoration: InputDecoration(labelText: l.ntNumber, hintText: l.ntNumberHint, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (job.running != null)
            _progress(job)
          else
            FilledButton.icon(onPressed: _analyze, icon: const Icon(Icons.tag), label: Text(l.ntAnalyze)),
          if (results != null) Semantics(liveRegion: true, child: results),
        ]),
      ),
    );
  }

  Widget _gcdCard(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final job = _gcd;
    Widget? results;
    final r = job.result;
    if (r is Failure<NtGcdResult>) results = _errorLine(r.error);
    if (r is Cancelled<NtGcdResult>) results = _errorLine(const MathError(MathErrorCode.cancelled));
    if (r is Success<NtGcdResult>) {
      final v = r.value;
      final steps = <SolutionStep>[];
      for (final run in v.runs) {
        if (run.rows.isEmpty) {
          steps.add(SolutionStep(l.ntEuclidZero('${run.a}', '${run.gcd}'), '\\gcd(${run.a},0)=${run.gcd}'));
          continue;
        }
        for (final (a, b, q, rem) in run.rows) {
          steps.add(SolutionStep(l.ntEuclidStep('$a', '$b', '$q', '$rem'), '$a = $q \\cdot $b + $rem'));
        }
        steps.add(SolutionStep(l.ntEuclidDone('${run.a}', '${run.b}', '${run.gcd}'), '\\gcd(${run.a},${run.b})=${run.gcd}'));
      }
      final list = v.numbers.join(', ');
      results = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _section(
          l.ntGcd,
          Semantics(
            label: 'gcd($list) = ${v.gcd}',
            child: SelectableText('gcd($list) = ${v.gcd}', style: theme.textTheme.titleMedium),
          ),
        ),
        _section(
          l.ntLcm,
          Semantics(
            label: 'lcm($list) = ${v.lcm}',
            child: SelectableText('lcm($list) = ${v.lcm}', style: theme.textTheme.titleMedium),
          ),
        ),
        const SizedBox(height: 8),
        if (steps.isNotEmpty) StepsView(steps: steps),
      ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.ntGcdLcm, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('nt-list'),
            controller: _list,
            onSubmitted: (_) => _runGcd(),
            decoration: InputDecoration(labelText: l.ntNumbers, hintText: l.ntNumbersHint, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (job.running != null)
            _progress(job)
          else
            FilledButton.tonal(onPressed: _runGcd, child: Text(l.actionCalculate)),
          if (results != null) Semantics(liveRegion: true, child: results),
        ]),
      ),
    );
  }

  Widget _divisionCard(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final job = _division;
    Widget? results;
    final r = job.result;
    if (r is Failure<NtDivisionResult>) results = _errorLine(r.error);
    if (r is Cancelled<NtDivisionResult>) results = _errorLine(const MathError(MathErrorCode.cancelled));
    if (r is Success<NtDivisionResult>) {
      final v = r.value;
      results = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MathView('${v.a} = ${v.quotient} \\cdot (${v.b}) + (${v.remainder})',
              style: theme.textTheme.titleMedium, fallback: '${v.a} = ${v.quotient}·(${v.b}) + (${v.remainder})'),
        ),
        const SizedBox(height: 8),
        for (final (label, value) in [(l.ntQuotient, v.quotient), (l.ntRemainder, v.remainder), (l.ntModulo, v.modulo)])
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(label),
            trailing: SelectableText('$value', style: theme.textTheme.titleMedium),
          ),
      ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.ntDivision, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('nt-a'),
                controller: _a,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(labelText: l.ntDividend, border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const ValueKey('nt-b'),
                controller: _b,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                onSubmitted: (_) => _runDivision(),
                decoration: InputDecoration(labelText: l.ntDivisor, border: const OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (job.running != null)
            _progress(job)
          else
            FilledButton.tonal(onPressed: _runDivision, child: Text(l.actionCalculate)),
          if (results != null) Semantics(liveRegion: true, child: results),
        ]),
      ),
    );
  }
}
