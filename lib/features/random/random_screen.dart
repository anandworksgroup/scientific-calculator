import 'dart:math' as math;

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
import '../calculator/calculator_controller.dart' show historyListProvider;

/// Marker parameter for "fewer distinct values than requested".
const _tooFewParam = 'randTooFew';
const _countParam = 'randCount';
const _notRealParam = 'randNotReal';

/// Random number generation through the engine's random functions, with one
/// generator per screen so a seed gives a reproducible *sequence*.
class RandomGenerator {
  RandomGenerator({int? seed, this.precision = 15}) : _rng = seed == null ? math.Random() : math.Random(seed);

  final math.Random _rng;
  final int precision;

  /// Evaluates an engine random call such as `randint(a, b)` with [args]
  /// bound as variables.
  Value call(String expr, [Map<String, Num> args = const {}]) {
    final ctx = EvalContext(
      arith: Arith(precision: precision),
      variables: {for (final e in args.entries) e.key: NumberValue(e.value)},
      random: _rng,
    );
    final ast = Parser.parseExpression(expr, scope: ParseScope(variables: args.keys.toSet()));
    return Evaluator(ctx).eval(ast);
  }

  /// [count] distinct integers from [lo]..[hi] in random order.
  List<BigInt> distinct(int count, BigInt lo, BigInt hi) {
    final span = hi - lo + BigInt.one;
    if (span < BigInt.from(count)) {
      throw MathError(MathErrorCode.domainError, {_tooFewParam: '${span < BigInt.zero ? BigInt.zero : span}', _countParam: '$count'});
    }
    if (span <= BigInt.from(10000)) {
      // A random permutation of the whole range, cut to length.
      final perm = call('randperm(n)', {'n': Rat(span)}) as ListValue;
      return [
        for (final v in perm.items.take(count)) lo + ((v as NumberValue).n as Rat).n - BigInt.one,
      ];
    }
    // Large range: draw until enough different values (collisions are rare).
    final seen = <BigInt>{};
    final out = <BigInt>[];
    var attempts = 0;
    while (out.length < count) {
      if (++attempts > count * 100) throw const MathError(MathErrorCode.noConvergence);
      final v = ((call('randint(a,b)', {'a': Rat(lo), 'b': Rat(hi)}) as NumberValue).n as Rat).n;
      if (seen.add(v)) out.add(v);
    }
    return out;
  }
}

class _Result {
  _Result(this.label, this.value, {this.preferDecimal = false, this.text});
  final String label;
  final Value? value;
  final bool preferDecimal;

  /// Replaces the formatted value (coin faces).
  final String? text;
}

/// Random numbers (URS §19).
class RandomScreen extends ConsumerStatefulWidget {
  const RandomScreen({super.key});

  @override
  ConsumerState<RandomScreen> createState() => _RandomScreenState();
}

class _RandomScreenState extends ConsumerState<RandomScreen> {
  late RandomGenerator _gen;
  final _seed = TextEditingController();
  final _intA = TextEditingController(text: '1');
  final _intB = TextEditingController(text: '100');
  final _decA = TextEditingController(text: '0');
  final _decB = TextEditingController(text: '10');
  final _listN = TextEditingController(text: '10');
  final _listA = TextEditingController(text: '1');
  final _listB = TextEditingController(text: '50');
  final _permN = TextEditingController(text: '10');
  bool _duplicates = true;
  String? _seedError;
  String? _error;
  final List<_Result> _results = [];

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    if (s.randomSeed != null) _seed.text = '${s.randomSeed}';
    _gen = RandomGenerator(seed: s.randomSeed, precision: s.precision);
  }

  @override
  void dispose() {
    for (final c in [_seed, _intA, _intB, _decA, _decB, _listN, _listA, _listB, _permN]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ seed

  void _applySeed() {
    final l = AppLocalizations.of(context);
    final text = _seed.text.trim();
    if (text.isEmpty) {
      _clearSeed();
      return;
    }
    final seed = int.tryParse(text);
    if (seed == null) {
      setState(() => _seedError = l.randSeedInvalid);
      return;
    }
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(randomSeed: () => seed));
    setState(() {
      _seedError = null;
      _gen = RandomGenerator(seed: seed, precision: ref.read(settingsProvider).precision);
    });
  }

  void _clearSeed() {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(randomSeed: () => null));
    _seed.clear();
    setState(() {
      _seedError = null;
      _gen = RandomGenerator(precision: ref.read(settingsProvider).precision);
    });
  }

  // ------------------------------------------------------------ generation

  Num _number(TextEditingController c) {
    final settings = ref.read(settingsProvider);
    final r = EngineService.engine.evaluate(ClipboardService.sanitize(c.text), settings.calcSettings,
        ref.read(environmentProvider), budget: Budget(timeLimit: const Duration(milliseconds: 300)));
    switch (r) {
      case Success(:final value):
        final v = value.value;
        if (v is NumberValue && Arith.isReal(v.n)) return v.n;
        throw const MathError(MathErrorCode.typeMismatch, {_notRealParam: true});
      case Failure(:final error):
        throw error;
      case Cancelled():
        throw const MathError(MathErrorCode.cancelled);
    }
  }

  int _count(TextEditingController c) {
    final n = Arith.asInt(_number(c));
    if (n == null || n < 1 || n > 10000) throw const MathError(MathErrorCode.domainError, {_countParam: true});
    return n;
  }

  String _errorMessage(AppLocalizations l, MathError e) {
    if (e.params[_tooFewParam] != null) return l.randTooFew('${e.params[_tooFewParam]}', '${e.params[_countParam]}');
    if (e.params[_countParam] != null) return l.randCountRange;
    if (e.params[_notRealParam] != null) return l.randNotReal;
    return errorText(l, e);
  }

  /// Runs [make] through the engine and records the result.
  Future<void> _generate(String Function() expression, _Result Function() make) async {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final r = guard(make);
    switch (r) {
      case Success(:final value):
        setState(() {
          _error = null;
          _results.insert(0, value);
          if (_results.length > 200) _results.removeLast();
        });
        await _record(expression(), value);
      case Failure(:final error):
        setState(() => _error = _errorMessage(l, error));
      case Cancelled():
        setState(() => _error = l.errCancelled);
    }
  }

  FormattedNumber _format(_Result r) =>
      ValueFormatter(ref.read(settingsProvider).formatOptions()).format(r.value!, preferDecimal: r.preferDecimal);

  String _plain(_Result r) {
    if (r.text != null) return r.text!;
    final v = r.value!;
    if (v is ListValue) return v.items.map((e) => _format(_Result('', e, preferDecimal: r.preferDecimal)).plain).join(', ');
    return _format(r).plain;
  }

  String _display(_Result r) {
    if (r.text != null) return r.text!;
    final v = r.value!;
    if (v is ListValue) return v.items.map((e) => _format(_Result('', e, preferDecimal: r.preferDecimal)).display).join(', ');
    return _format(r).display;
  }

  Future<void> _record(String expression, _Result r) async {
    final settings = ref.read(settingsProvider);
    if (!settings.saveHistory) return;
    try {
      final shown = r.value == null ? null : _format(r);
      await ref.read(historyRepositoryProvider).insert(
            HistoryEntry(
              expression: expression,
              expressionLatex: const LatexPrinter().print(Parser.parseExpression(expression)),
              result: _plain(r),
              resultLatex: r.text != null ? '\\text{${r.text}}' : shown!.latex,
              resultValue: r.value == null ? null : ValueCodec.encode(r.value!),
              mode: 'random',
              angleMode: settings.angleMode.name,
              format: settings.resultFormat.name,
              createdAt: DateTime.now(),
            ),
            limit: settings.historyLimit,
          );
      ref.invalidate(historyListProvider);
    } catch (e) {
      AppLogger.error('random history', e);
    }
  }

  String _txt(Num n) => NumberFormatter(const FormatOptions(digits: 30)).format(n).plain;

  void _decimal(AppLocalizations l) =>
      _generate(() => 'rand()', () => _Result(l.randDecimal, _gen.call('rand()'), preferDecimal: true));

  void _integer(AppLocalizations l) {
    late Num a, b;
    _generate(() => 'randint(${_txt(a)},${_txt(b)})', () {
      a = _number(_intA);
      b = _number(_intB);
      return _Result('${l.randInteger}: [${_txt(a)}, ${_txt(b)}]', _gen.call('randint(a,b)', {'a': a, 'b': b}));
    });
  }

  void _range(AppLocalizations l) {
    late Num a, b;
    _generate(() => 'randreal(${_txt(a)},${_txt(b)})', () {
      a = _number(_decA);
      b = _number(_decB);
      return _Result('${l.randRange}: [${_txt(a)}, ${_txt(b)})', _gen.call('randreal(a,b)', {'a': a, 'b': b}),
          preferDecimal: true);
    });
  }

  void _list(AppLocalizations l) {
    late int n;
    late Num a, b;
    _generate(() => 'randlist($n,${_txt(a)},${_txt(b)})', () {
      n = _count(_listN);
      a = _number(_listA);
      b = _number(_listB);
      final label = '${l.randList}: $n × [${_txt(a)}, ${_txt(b)}]';
      if (_duplicates) {
        return _Result(label, _gen.call('randlist(n,a,b)', {'n': Rat.int(n), 'a': a, 'b': b}));
      }
      final ar = Arith(precision: _gen.precision);
      final lo = Arith.asBigInt(ar.ceil(a)), hi = Arith.asBigInt(ar.floor(b));
      if (lo == null || hi == null) throw const MathError(MathErrorCode.nonIntegerArgument, {'function': 'randlist'});
      final values = _gen.distinct(n, lo, hi);
      return _Result(label, ListValue([for (final v in values) NumberValue(Rat(v))]));
    });
  }

  void _permutation(AppLocalizations l) {
    late int n;
    _generate(() => 'randperm($n)', () {
      n = _count(_permN);
      return _Result('${l.randPermutation}: n = $n', _gen.call('randperm(n)', {'n': Rat.int(n)}));
    });
  }

  void _dice(AppLocalizations l) =>
      _generate(() => 'randint(1,6)', () => _Result(l.randDice, _gen.call('randint(1,6)')));

  void _coin(AppLocalizations l) => _generate(() => 'randint(0,1)', () {
        final v = _gen.call('randint(0,1)');
        final heads = v is NumberValue && v.n.isZero;
        return _Result(l.randCoin, v, text: heads ? l.randHeads : l.randTails);
      });

  Future<void> _copy(String text) async {
    await ClipboardService.copy(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controls = _controls(context);
    final results = _resultsCard(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.randTitle)),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 720) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [controls])),
              const VerticalDivider(width: 1),
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [results])),
            ]);
          }
          return ListView(padding: const EdgeInsets.all(16), children: [controls, const SizedBox(height: 12), results]);
        }),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {Key? key}) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextField(
            key: key,
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          ),
        ),
      );

  Widget _block(String title, List<Widget> fields, VoidCallback onGenerate, {Widget? extra}) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          ...fields,
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onGenerate,
            child: Text(l.randGenerate),
          ),
        ]),
        ?extra,
      ]),
    );
  }

  Widget _controls(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final seed = ref.watch(settingsProvider.select((s) => s.randomSeed));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => _dice(l),
            icon: const Icon(Icons.casino_outlined),
            label: Text(l.randDice),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => _coin(l),
            icon: const Icon(Icons.monetization_on_outlined),
            label: Text(l.randCoin),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _block(l.randDecimal, [const Spacer()], () => _decimal(l)),
            _block(l.randInteger, [_field(_intA, l.randMin), _field(_intB, l.randMax)], () => _integer(l)),
            _block(l.randRange, [_field(_decA, l.randMin), _field(_decB, l.randMax)], () => _range(l)),
            _block(
              l.randList,
              [_field(_listN, l.randCount), _field(_listA, l.randMin), _field(_listB, l.randMax)],
              () => _list(l),
              extra: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.randAllowDuplicates),
                value: _duplicates,
                onChanged: (v) => setState(() => _duplicates = v),
              ),
            ),
            _block(l.randPermutation, [_field(_permN, l.randCount)], () => _permutation(l)),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _seed,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  onSubmitted: (_) => _applySeed(),
                  decoration: InputDecoration(
                    labelText: l.randSeed,
                    hintText: l.randSeedHint,
                    border: const OutlineInputBorder(),
                    errorText: _seedError,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(tooltip: l.randApplySeed, icon: const Icon(Icons.check), onPressed: _applySeed),
              if (seed != null) IconButton(tooltip: l.randClearSeed, icon: const Icon(Icons.close), onPressed: _clearSeed),
            ]),
            const SizedBox(height: 8),
            Text(seed == null ? l.randSeedOff : l.randSeedActive('$seed'), style: theme.textTheme.bodySmall),
          ]),
        ),
      ),
    ]);
  }

  Widget _resultsCard(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          title: Text(l.randResults, style: theme.textTheme.titleMedium),
          trailing: _results.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: l.randCopyAll,
                    icon: const Icon(Icons.copy_all),
                    onPressed: () => _copy(_results.reversed.map(_plain).join('\n')),
                  ),
                  IconButton(
                    tooltip: l.randClearResults,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => setState(_results.clear),
                  ),
                ]),
        ),
        if (_results.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(l.randNoResults))
        else
          Semantics(
            liveRegion: true,
            child: Column(children: [
              for (var k = 0; k < _results.length; k++)
                ListTile(
                  key: ValueKey('rand-result-${_results.length - k}'),
                  title: Text(_display(_results[k]),
                      style: (k == 0 ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
                          ?.copyWith(color: k == 0 ? theme.colorScheme.primary : null)),
                  subtitle: Text(_results[k].label),
                  trailing: IconButton(
                    tooltip: l.actionCopy,
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copy(_plain(_results[k])),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}
