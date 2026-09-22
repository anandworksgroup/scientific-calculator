import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../data/settings/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../calculus/calc_ui.dart';

// ------------------------------------------------------------ engine tasks

/// A data cell that could not be read as a real number.
class StatsCellError {
  const StatsCellError(this.row, this.column, this.error);

  /// 1-based row number.
  final int row;

  /// 0 = value / X column, 1 = frequency / Y column.
  final int column;
  final MathError error;
}

class OneVarOutcome {
  const OneVarOutcome(this.stats, this.data);
  final OneVarStats stats;

  /// Data expanded by frequencies (for percentiles).
  final List<Num> data;
}

class TwoVarOutcome {
  const TwoVarOutcome(this.stats, this.fits, this.x, this.y);
  final TwoVarStats stats;
  final Map<RegressionType, EngineResult<RegressionResult>> fits;
  final List<Num> x, y;
}

class StatsOutcome {
  const StatsOutcome({this.cellError, this.one, this.two, this.preferDecimal = false});
  final StatsCellError? cellError;
  final OneVarOutcome? one;
  final TwoVarOutcome? two;

  /// Data was typed with decimals: show decimal results.
  final bool preferDecimal;
}

final _plainNumber = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

/// Reads one cell as a real number (plain numbers fast, anything else via
/// the engine so `1/3`, `sqrt(2)` or `pi` work).
Num _cell(String text, CalcSettings settings, Environment env, void Function() sawDecimal) {
  final s = text.trim();
  if (_plainNumber.hasMatch(s)) {
    if (s.contains('.') || s.contains('e') || s.contains('E')) sawDecimal();
    return Rat.parseDecimal(s);
  }
  final r = const DefaultMathEngine().evaluate(s, settings, env);
  switch (r) {
    case Success(:final value):
      final v = value.value;
      if (v is NumberValue && v.n is! Cpx) {
        if (value.preferDecimal) sawDecimal();
        return v.n;
      }
      throw const MathError(MathErrorCode.typeMismatch, {'detail': 'Statistics require real numbers.'});
    case Failure(:final error):
      throw error;
    case Cancelled():
      throw const MathError(MathErrorCode.cancelled);
  }
}

/// Parses the table and computes one- or two-variable statistics.
/// Top-level so it can run in an isolate.
EngineResult<StatsOutcome> statisticsTask(
    bool twoVar, bool useFrequencies, List<String> colA, List<String> colB, CalcSettings settings, Environment env) {
  return guard(() {
    var decimal = false;
    void saw() => decimal = true;
    final a = <Num>[], b = <Num>[];
    for (var k = 0; k < colA.length; k++) {
      final ta = colA[k].trim(), tb = k < colB.length ? colB[k].trim() : '';
      if (ta.isEmpty && tb.isEmpty) continue;
      final usesB = twoVar || useFrequencies;
      if (ta.isEmpty) {
        return StatsOutcome(cellError: StatsCellError(k + 1, 0, const MathError(MathErrorCode.emptyInput)));
      }
      if (twoVar && tb.isEmpty) {
        return StatsOutcome(cellError: StatsCellError(k + 1, 1, const MathError(MathErrorCode.emptyInput)));
      }
      try {
        a.add(_cell(ta, settings, env, saw));
      } on MathError catch (e) {
        if (e.code == MathErrorCode.cancelled || e.code == MathErrorCode.timeout) rethrow;
        return StatsOutcome(cellError: StatsCellError(k + 1, 0, e));
      }
      if (usesB) {
        try {
          // An empty frequency counts once.
          b.add(tb.isEmpty ? Rat.one : _cell(tb, settings, env, twoVar ? saw : () {}));
        } on MathError catch (e) {
          if (e.code == MathErrorCode.cancelled || e.code == MathErrorCode.timeout) rethrow;
          return StatsOutcome(cellError: StatsCellError(k + 1, 1, e));
        }
      }
    }
    final arith = Arith(precision: settings.precision);
    final st = Statistics(arith);
    if (!twoVar) {
      final stats = st.oneVar(a, frequencies: useFrequencies ? b : null);
      final data = <Num>[];
      if (useFrequencies) {
        for (var k = 0; k < a.length; k++) {
          final f = Arith.asInt(b[k]) ?? 0;
          for (var j = 0; j < f; j++) {
            data.add(a[k]);
          }
        }
      } else {
        data.addAll(a);
      }
      return StatsOutcome(one: OneVarOutcome(stats, data), preferDecimal: decimal);
    }
    final stats = st.twoVar(a, b);
    final fits = <RegressionType, EngineResult<RegressionResult>>{
      for (final t in RegressionType.values) t: guard(() => st.regression(t, a, b)),
    };
    return StatsOutcome(two: TwoVarOutcome(stats, fits, a, b), preferDecimal: decimal);
  });
}

/// Percentile of already-validated data. Top-level for isolates.
EngineResult<Num> percentileTask(List<Num> data, String p, CalcSettings settings, Environment env) {
  return guard(() {
    final pv = _cell(p, settings, env, () {});
    return Statistics(Arith(precision: settings.precision)).percentile(data, pv);
  });
}

Computation<StatsOutcome> _startStats(EngineService s, bool twoVar, bool freq, List<String> a, List<String> b,
        CalcSettings settings, Environment env) =>
    s.run(() => statisticsTask(twoVar, freq, a, b, settings, env));

Computation<Num> _startPercentile(EngineService s, List<Num> data, String p, CalcSettings settings, Environment env) =>
    s.run(() => percentileTask(data, p, settings, env));

/// Splits pasted text into rows of numbers (commas, semicolons, spaces,
/// tabs and newlines separate values).
List<List<String>> parsePastedData(String text) {
  final rows = <List<String>>[];
  for (final line in text.split(RegExp(r'\r\n|\r|\n'))) {
    final cells = [
      for (final t in line.split(RegExp(r'[,;\s]+')))
        if (ClipboardService.sanitize(t).isNotEmpty) ClipboardService.sanitize(t)
    ];
    if (cells.isNotEmpty) rows.add(cells);
  }
  return rows;
}

// ------------------------------------------------------------------ screen

class _DataRow {
  _DataRow([String a = '', String b = ''])
      : a = TextEditingController(text: a),
        b = TextEditingController(text: b);
  final TextEditingController a;
  final TextEditingController b;
  void dispose() {
    a.dispose();
    b.dispose();
  }
}

/// One- and two-variable statistics with regression (URS §42–43).
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> with EngineRunner {
  static const maxRows = 10000;

  bool _twoVar = false;
  bool _useFreq = false;
  final List<_DataRow> _rows = [_DataRow(), _DataRow(), _DataRow()];
  final _percentile = TextEditingController(text: '90');
  final _predictX = TextEditingController();

  StatsOutcome? _result;
  bool _resultTwoVar = false;
  String? _error;
  RegressionType _regType = RegressionType.linear;

  Num? _percentileValue;
  String? _percentileError;
  String _percentileP = '';
  Num? _predicted;
  String? _predictError;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _percentile.dispose();
    _predictX.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- editing

  void _addRow() => setState(() => _rows.add(_DataRow()));

  void _removeRow(int i) => setState(() {
        _rows.removeAt(i).dispose();
        if (_rows.isEmpty) _rows.add(_DataRow());
      });

  void _clear() => setState(() {
        for (final r in _rows) {
          r.dispose();
        }
        _rows
          ..clear()
          ..addAll([_DataRow(), _DataRow(), _DataRow()]);
        _result = null;
        _error = null;
      });

  Future<void> _paste() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final lines = parsePastedData(text.length > 500000 ? text.substring(0, 500000) : text);
    final parsed = <(String, String)>[];
    if (_twoVar) {
      final multiColumn = lines.any((r) => r.length >= 2) && lines.length > 1;
      if (multiColumn) {
        for (final r in lines) {
          parsed.add((r[0], r.length > 1 ? r[1] : ''));
        }
      } else {
        final flat = [for (final r in lines) ...r];
        for (var k = 0; k < flat.length; k += 2) {
          parsed.add((flat[k], k + 1 < flat.length ? flat[k + 1] : ''));
        }
      }
    } else {
      for (final r in lines) {
        for (final c in r) {
          parsed.add((c, ''));
        }
      }
    }
    if (!mounted) return;
    if (parsed.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.statsPasteEmpty)));
      return;
    }
    final truncated = parsed.length > maxRows;
    setState(() {
      // Replace empty rows, then append.
      final kept = _rows.where((r) => r.a.text.trim().isNotEmpty || r.b.text.trim().isNotEmpty).toList();
      for (final r in _rows.where((r) => !kept.contains(r))) {
        r.dispose();
      }
      _rows
        ..clear()
        ..addAll(kept);
      for (final p in parsed.take(maxRows - _rows.length < 0 ? 0 : maxRows - _rows.length)) {
        _rows.add(_DataRow(p.$1, p.$2));
      }
      if (_rows.isEmpty) _rows.add(_DataRow());
    });
    messenger.showSnackBar(SnackBar(
        content: Text(truncated ? l.statsPasteTruncated(maxRows) : l.statsPasted(parsed.length))));
  }

  // ------------------------------------------------------------ compute

  String _columnName(AppLocalizations l, int column, bool twoVar) =>
      twoVar ? (column == 0 ? l.statsX : l.statsY) : (column == 0 ? l.statsValue : l.statsFrequency);

  Future<void> _compute() async {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final twoVar = _twoVar;
    final a = [for (final r in _rows) r.a.text];
    final b = [for (final r in _rows) r.b.text];
    final r = await runEngine(_startStats(engineService, twoVar, !twoVar && _useFreq, a, b, settings.calcSettings, env.copy()));
    if (r == null) return;
    setState(() {
      _result = null;
      _error = null;
      _percentileValue = null;
      _percentileError = null;
      _predicted = null;
      _predictError = null;
      _resultTwoVar = twoVar;
      switch (r) {
        case Success(:final value):
          final ce = value.cellError;
          if (ce != null) {
            _error = l.statsCellError(ce.row, _columnName(l, ce.column, twoVar), errorText(l, ce.error));
          } else {
            _result = value;
          }
        case Failure(:final error):
          _error = errorText(l, error);
        case Cancelled():
          _error = l.errCancelled;
      }
    });
    final out = _result;
    if (out == null) return;
    final values = [for (final row in _rows) if (row.a.text.trim().isNotEmpty) row.a.text.trim()];
    final dataText = values.length > 20 ? '${values.take(20).join(',')},…' : values.join(',');
    if (out.one case final one?) {
      final m = formatNum(settings, one.stats.mean, decimal: out.preferDecimal);
      await recordHistory(ref,
          mode: 'statistics',
          expression: 'mean($dataText)',
          expressionLatex: '\\bar{x}\\left(${dataText.replaceAll(',', ',\\,')}\\right)',
          result: m.plain,
          resultLatex: '\\bar{x}=${m.latex}',
          value: NumberValue(one.stats.mean));
    } else if (out.two case final two?) {
      final rr = two.stats.correlation;
      if (rr != null) {
        final f = formatNum(settings, rr, decimal: true);
        await recordHistory(ref,
            mode: 'statistics',
            expression: 'correlation(n=${two.stats.count})',
            expressionLatex: 'r_{n=${two.stats.count}}',
            result: f.plain,
            resultLatex: 'r=${f.latex}',
            value: NumberValue(rr));
      }
    }
  }

  Future<void> _computePercentile() async {
    final l = AppLocalizations.of(context);
    final one = _result?.one;
    if (one == null) return;
    final settings = ref.read(settingsProvider);
    final p = cleanInput(_percentile.text);
    final r = await runEngine(_startPercentile(engineService, one.data, p, settings.calcSettings, ref.read(environmentProvider).copy()));
    if (r == null) return;
    setState(() {
      _percentileValue = null;
      _percentileError = null;
      _percentileP = p;
      switch (r) {
        case Success(:final value):
          _percentileValue = value;
        case Failure(:final error):
          _percentileError = errorText(l, error);
        case Cancelled():
          _percentileError = l.errCancelled;
      }
    });
  }

  void _predict() {
    final l = AppLocalizations.of(context);
    final fit = _result?.two?.fits[_regType]?.valueOrNull;
    if (fit == null) return;
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final r = guard<Num>(() {
      final x = _cell(cleanInput(_predictX.text), settings.calcSettings, env, () {});
      final c = fit.coefficients;
      final a = Arith(precision: settings.precision);
      switch (fit.type) {
        case RegressionType.linear:
          return a.add(c[0], a.mul(c[1], x));
        case RegressionType.quadratic:
          return a.add(c[0], a.add(a.mul(c[1], x), a.mul(c[2], a.mul(x, x))));
        default:
          final y = fit.predict(x.toDouble());
          if (!y.isFinite) {
            throw MathError(MathErrorCode.domainError, {'function': _regName(l, fit.type), 'value': 'x = ${_predictX.text.trim()}'});
          }
          return Dec.fromDouble(y);
      }
    });
    setState(() {
      _predicted = r.valueOrNull;
      _predictError = r.errorOrNull == null ? null : errorText(l, r.errorOrNull!);
    });
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.toolStatistics),
        actions: [
          IconButton(tooltip: l.statsPaste, icon: const Icon(Icons.content_paste), onPressed: busy ? null : _paste),
          IconButton(tooltip: l.statsClear, icon: const Icon(Icons.delete_sweep_outlined), onPressed: busy ? null : _clear),
        ],
      ),
      body: FormResultLayout(form: _buildForm(l), result: _buildResult(l)),
    );
  }

  Widget _buildForm(AppLocalizations l) {
    final theme = Theme.of(context);
    final usesB = _twoVar || _useFreq;
    final headA = _twoVar ? l.statsX : l.statsValue;
    final headB = _twoVar ? l.statsY : l.statsFrequency;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        label: l.statsMode,
        child: SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.statsOneVariable)),
            ButtonSegment(value: true, label: Text(l.statsTwoVariable)),
          ],
          selected: {_twoVar},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _twoVar = s.first),
        ),
      ),
      if (!_twoVar)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.statsUseFrequencies),
          value: _useFreq,
          onChanged: (v) => setState(() => _useFreq = v),
        )
      else
        const SizedBox(height: 12),
      Row(children: [
        Text(l.statsDataTable, style: theme.textTheme.titleSmall),
        const SizedBox(width: 8),
        Text(l.statsRowsCount(_rows.length), style: theme.textTheme.bodySmall),
      ]),
      const SizedBox(height: 8),
      Container(
        constraints: const BoxConstraints(maxHeight: 340),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            child: Row(children: [
              SizedBox(width: 36, child: Text('#', style: theme.textTheme.labelMedium)),
              Expanded(child: Text(headA, style: theme.textTheme.labelMedium)),
              if (usesB) ...[const SizedBox(width: 8), Expanded(child: Text(headB, style: theme.textTheme.labelMedium))],
              const SizedBox(width: 48),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final row = _rows[i];
                InputDecoration deco(String label) => InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: label,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    );
                return Padding(
                  key: ObjectKey(row),
                  padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
                  child: Row(children: [
                    SizedBox(width: 36, child: Text('${i + 1}', style: theme.textTheme.bodySmall)),
                    Expanded(
                      child: Semantics(
                        label: '$headA ${i + 1}',
                        child: TextField(
                          key: ValueKey('stats.a.$i'),
                          controller: row.a,
                          decoration: deco(headA),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ),
                    if (usesB) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          label: '$headB ${i + 1}',
                          child: TextField(
                            key: ValueKey('stats.b.$i'),
                            controller: row.b,
                            decoration: deco(_twoVar ? headB : '1'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                    ],
                    IconButton(
                      tooltip: l.statsRemoveRow(i + 1),
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: busy ? null : () => _removeRow(i),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: busy ? null : _addRow, icon: const Icon(Icons.add), label: Text(l.statsAddRow)),
        OutlinedButton.icon(onPressed: busy ? null : _paste, icon: const Icon(Icons.content_paste), label: Text(l.statsPaste)),
        OutlinedButton.icon(onPressed: busy ? null : _clear, icon: const Icon(Icons.clear_all), label: Text(l.statsClear)),
      ]),
      const SizedBox(height: 8),
      InfoNote(_twoVar ? l.statsPasteHelpTwo : l.statsPasteHelpOne),
      const SizedBox(height: 16),
      ComputeButton(label: l.statsCalculate, onPressed: busy ? null : _compute),
      if (busy) BusyRow(onCancel: cancelRun),
    ]);
  }

  Widget _buildResult(AppLocalizations l) {
    if (_error != null) return ErrorPanel(_error!);
    final r = _result;
    if (r == null) return InfoNote(l.statsEmpty, icon: Icons.bar_chart);
    final settings = ref.watch(settingsProvider);
    if (!_resultTwoVar && r.one != null) return _oneVarResult(l, settings, r.one!, r.preferDecimal);
    if (_resultTwoVar && r.two != null) return _twoVarResult(l, settings, r.two!, r.preferDecimal);
    return InfoNote(l.statsEmpty, icon: Icons.bar_chart);
  }

  Widget _line(AppSettings s, String label, String symTex, Num n, bool dec) {
    final f = formatNum(s, n, decimal: dec || n is Dec);
    return ResultLine(label: label, tex: '$symTex=${f.latex}', plain: f.plain);
  }

  Widget _oneVarResult(AppLocalizations l, AppSettings s, OneVarOutcome o, bool dec) {
    final st = o.stats;
    final modesTex = st.modes.isEmpty ? null : st.modes.map((m) => formatNum(s, m, decimal: dec || m is Dec)).toList();
    return ResultPanel(children: [
      ResultLine(label: l.statsCount, tex: 'n=${st.count}', plain: '${st.count}'),
      _line(s, l.statsSum, r'\sum x', st.sum, dec),
      _line(s, l.statsSumSquares, r'\sum x^{2}', st.sumSquares, dec),
      _line(s, l.statsMean, r'\bar{x}', st.mean, dec),
      _line(s, l.statsMedian, r'\tilde{x}', st.median, dec),
      if (modesTex == null)
        ResultLine(label: l.statsModes, tex: r'\text{—}', plain: l.statsNoMode, copyable: false)
      else
        ResultLine(
            label: l.statsModes,
            tex: modesTex.map((f) => f.latex).join(r',\ '),
            plain: modesTex.map((f) => f.plain).join(', ')),
      if (st.modes.isEmpty) InfoNote(l.statsNoMode),
      _line(s, l.statsMin, r'\min', st.min, dec),
      _line(s, l.statsMax, r'\max', st.max, dec),
      _line(s, l.statsRange, r'\mathrm{range}', st.range, dec),
      const Divider(),
      if (st.sampleVariance != null) _line(s, l.statsSampleVariance, 's^{2}', st.sampleVariance!, dec),
      _line(s, l.statsPopulationVariance, r'\sigma^{2}', st.populationVariance, dec),
      if (st.sampleStdDev != null) _line(s, l.statsSampleStdDev, 's', st.sampleStdDev!, dec),
      _line(s, l.statsPopulationStdDev, r'\sigma', st.populationStdDev, dec),
      if (st.sampleVariance == null) InfoNote(l.statsSampleNeedsTwo),
      const Divider(),
      _line(s, l.statsQ1, 'Q_{1}', st.q1, dec),
      _line(s, l.statsQ3, 'Q_{3}', st.q3, dec),
      _line(s, l.statsIqr, r'\mathrm{IQR}', st.iqr, dec),
      InfoNote(l.statsQuartileNote),
      const Divider(),
      Text(l.statsPercentile, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: SmallField(
              key: const ValueKey('stats.percentile'),
              controller: _percentile,
              label: l.statsPercentileP,
              hint: l.statsPercentileHint,
              onSubmitted: _computePercentile),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: FilledButton.tonal(onPressed: busy ? null : _computePercentile, child: Text(l.actionCalculate)),
        ),
      ]),
      if (_percentileError != null) ...[const SizedBox(height: 8), ErrorPanel(_percentileError!)],
      if (_percentileValue != null) _line(s, l.statsPercentile, 'P_{$_percentileP}', _percentileValue!, dec),
    ]);
  }

  String _regName(AppLocalizations l, RegressionType t) => switch (t) {
        RegressionType.linear => l.statsRegLinear,
        RegressionType.quadratic => l.statsRegQuadratic,
        RegressionType.exponential => l.statsRegExponential,
        RegressionType.logarithmic => l.statsRegLogarithmic,
        RegressionType.power => l.statsRegPower,
      };

  /// Equation with fitted coefficients: (latex, plain).
  (String, String) _equation(AppSettings s, RegressionResult fit, bool dec) {
    final a = Arith(precision: s.precision);
    final c = fit.coefficients;
    FormattedNumber f(Num n) => formatNum(s, n, decimal: dec || n is Dec);
    // Adds "± |c|·suffix" to a sum.
    (String, String) join(List<(Num, String, String)> terms) {
      final tex = StringBuffer(), plain = StringBuffer();
      for (var k = 0; k < terms.length; k++) {
        final (n, sTex, sPlain) = terms[k];
        final neg = a.signOf(n) < 0;
        final fa = f(neg ? a.neg(n) : n);
        if (k == 0) {
          tex.write('${neg ? '-' : ''}${fa.latex}$sTex');
          plain.write('${neg ? '-' : ''}${fa.plain}$sPlain');
        } else {
          tex.write('${neg ? '-' : '+'}${fa.latex}$sTex');
          plain.write(' ${neg ? '-' : '+'} ${fa.plain}$sPlain');
        }
      }
      return (tex.toString(), plain.toString());
    }

    final (String tex, String plain) = switch (fit.type) {
      RegressionType.linear => join([(c[0], '', ''), (c[1], r'\,x', '·x')]),
      RegressionType.quadratic => join([(c[0], '', ''), (c[1], r'\,x', '·x'), (c[2], r'\,x^{2}', '·x^2')]),
      RegressionType.exponential => (
          '${f(c[0]).latex}\\,e^{${f(c[1]).latex}\\,x}',
          '${f(c[0]).plain}·e^(${f(c[1]).plain}·x)'
        ),
      RegressionType.logarithmic => join([(c[0], '', ''), (c[1], r'\,\ln x', '·ln(x)')]),
      RegressionType.power => ('${f(c[0]).latex}\\,x^{${f(c[1]).latex}}', '${f(c[0]).plain}·x^(${f(c[1]).plain})'),
    };
    return ('y=$tex', 'y = $plain');
  }

  Widget _twoVarResult(AppLocalizations l, AppSettings s, TwoVarOutcome o, bool dec) {
    final st = o.stats;
    final fitResult = o.fits[_regType];
    final fit = fitResult?.valueOrNull;
    final theme = Theme.of(context);
    return ResultPanel(children: [
      ResultLine(label: l.statsCount, tex: 'n=${st.count}', plain: '${st.count}'),
      _line(s, l.statsMeanX, r'\bar{x}', st.meanX, dec),
      _line(s, l.statsMeanY, r'\bar{y}', st.meanY, dec),
      _line(s, l.statsSumX, r'\sum x', st.sumX, dec),
      _line(s, l.statsSumY, r'\sum y', st.sumY, dec),
      _line(s, l.statsSumXY, r'\sum xy', st.sumXY, dec),
      _line(s, l.statsSumX2, r'\sum x^{2}', st.sumX2, dec),
      _line(s, l.statsSumY2, r'\sum y^{2}', st.sumY2, dec),
      if (st.sampleCovariance != null) _line(s, l.statsSampleCovariance, r's_{xy}', st.sampleCovariance!, dec),
      _line(s, l.statsPopulationCovariance, r'\sigma_{xy}', st.populationCovariance, dec),
      if (st.correlation != null)
        _line(s, l.statsCorrelation, 'r', st.correlation!, true)
      else
        InfoNote(l.statsNoCorrelation),
      const Divider(),
      Text(l.statsRegression, style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      DropdownButtonFormField<RegressionType>(
        key: const ValueKey('stats.regression'),
        value: _regType,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.statsRegressionModel, border: const OutlineInputBorder(), isDense: true),
        items: [
          for (final t in RegressionType.values) DropdownMenuItem(value: t, child: Text(_regName(l, t))),
        ],
        onChanged: (t) => setState(() {
          _regType = t ?? RegressionType.linear;
          _predicted = null;
          _predictError = null;
        }),
      ),
      const SizedBox(height: 8),
      if (fitResult case Failure(:final error))
        ErrorPanel(errorText(l, error))
      else if (fit != null) ...[
        Builder(builder: (context) {
          final (tex, plain) = _equation(s, fit, dec);
          return ResultLine(label: _regName(l, fit.type), tex: tex, plain: plain, large: true);
        }),
        _line(s, l.statsR2, 'r^{2}', fit.r2, true),
        if (fit.r != null && fit.type != RegressionType.linear) _line(s, l.statsCorrelationTransformed, 'r', fit.r!, true),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: Semantics(
            label: l.statsScatterLabel(st.count),
            image: true,
            child: CustomPaint(
              painter: _ScatterPainter(
                x: [for (final v in o.x) v.toDouble()],
                y: [for (final v in o.y) v.toDouble()],
                fit: fit,
                point: theme.colorScheme.primary,
                line: theme.colorScheme.tertiary,
                axis: theme.colorScheme.outline,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: SmallField(
                key: const ValueKey('stats.predictX'), controller: _predictX, label: l.statsPredictX, onSubmitted: _predict),
          ),
          const SizedBox(width: 8),
          SizedBox(height: 48, child: FilledButton.tonal(onPressed: _predict, child: Text(l.statsPredict))),
        ]),
        if (_predictError != null) ...[const SizedBox(height: 8), ErrorPanel(_predictError!)],
        if (_predicted != null) _line(s, l.statsPredictedY, r'\hat{y}', _predicted!, dec),
      ],
    ]);
  }
}

/// Scatter plot of the data with the fitted curve.
class _ScatterPainter extends CustomPainter {
  _ScatterPainter({required this.x, required this.y, required this.fit, required this.point, required this.line, required this.axis});
  final List<double> x, y;
  final RegressionResult fit;
  final Color point, line, axis;

  @override
  void paint(Canvas canvas, Size size) {
    if (x.isEmpty) return;
    var x0 = x.reduce(math.min), x1 = x.reduce(math.max);
    var y0 = y.reduce(math.min), y1 = y.reduce(math.max);
    if (x1 - x0 < 1e-12) {
      x0 -= 1;
      x1 += 1;
    }
    const samples = 120;
    final curveY = <double>[];
    for (var k = 0; k <= samples; k++) {
      final xv = x0 + (x1 - x0) * k / samples;
      final yv = fit.predict(xv);
      curveY.add(yv);
    }
    for (final v in curveY) {
      if (v.isFinite) {
        y0 = math.min(y0, v);
        y1 = math.max(y1, v);
      }
    }
    if (y1 - y0 < 1e-12) {
      y0 -= 1;
      y1 += 1;
    }
    final padX = (x1 - x0) * 0.05, padY = (y1 - y0) * 0.08;
    x0 -= padX;
    x1 += padX;
    y0 -= padY;
    y1 += padY;
    Offset map(double a, double b) =>
        Offset((a - x0) / (x1 - x0) * size.width, size.height - (b - y0) / (y1 - y0) * size.height);

    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1;
    if (x0 < 0 && x1 > 0) canvas.drawLine(map(0, y0), map(0, y1), axisPaint);
    if (y0 < 0 && y1 > 0) canvas.drawLine(map(x0, 0), map(x1, 0), axisPaint);
    canvas.drawRect(Offset.zero & size, axisPaint..style = PaintingStyle.stroke);

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    var started = false;
    for (var k = 0; k <= samples; k++) {
      final v = curveY[k];
      if (!v.isFinite) {
        started = false;
        continue;
      }
      final p = map(x0 + padX + (x1 - x0 - 2 * padX) * k / samples, v);
      if (started) {
        path.lineTo(p.dx, p.dy);
      } else {
        path.moveTo(p.dx, p.dy);
        started = true;
      }
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, linePaint);
    final dot = Paint()..color = point;
    for (var k = 0; k < x.length; k++) {
      canvas.drawCircle(map(x[k], y[k]), 3.5, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScatterPainter old) =>
      old.x != x || old.y != y || old.fit != fit || old.point != point || old.line != line || old.axis != axis;
}
