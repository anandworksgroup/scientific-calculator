import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/engine_service.dart';
import 'calc_ui.dart';

/// Result of an integral request (computed in a background isolate).
class IntegralOutcome {
  const IntegralOutcome({
    this.antiTex,
    this.antiText,
    this.value,
    this.exact = false,
    this.errorEstimate,
    this.exactValueTex,
    this.exactValueText,
  });

  final String? antiTex;
  final String? antiText;

  /// Definite value (null for an indefinite integral).
  final Num? value;
  final bool exact;
  final double? errorEstimate;

  /// Closed form of an exact but irrational definite value (e.g. π/4).
  final String? exactValueTex;
  final String? exactValueText;
}

/// Antiderivative and/or definite integral. Top-level for isolates.
EngineResult<IntegralOutcome> integralTask(
    String f, String variable, String? lower, String? upper, CalcSettings settings, Environment env) {
  const engine = DefaultMathEngine();
  final r = engine.integrate(f, variable, settings, env, lower: lower, upper: upper);
  switch (r) {
    case Success(:final value):
      final d = value.definite;
      String? exTex, exText;
      final anti = value.antiderivative;
      if (d != null && d.exact && d.value is! Rat && anti != null && lower != null && upper != null) {
        // Evaluate F(b) − F(a) to recover a closed form such as π/4.
        final plain = const TextPrinter().print(symToNode(anti));
        final env2 = env.copy()..functions['antiq'] = 'antiq($variable)=$plain';
        final ev = engine.evaluate('antiq(($upper))-antiq(($lower))', settings, env2);
        if (ev case Success(value: final e)) {
          exTex = e.exactLatex;
          exText = e.exactText;
        }
      }
      return Success(IntegralOutcome(
        antiTex: value.antiderivativeLatex,
        antiText: value.antiderivativeText,
        value: d?.value,
        exact: d?.exact ?? false,
        errorEstimate: d?.errorEstimate,
        exactValueTex: exTex,
        exactValueText: exText,
      ));
    case Failure(:final error):
      return Failure(error);
    case Cancelled():
      return const Cancelled();
  }
}

Computation<IntegralOutcome> _startIntegral(EngineService s, String f, String v, String? lo, String? hi,
        CalcSettings settings, Environment env) =>
    s.run(() => integralTask(f, v, lo, hi, settings, env));

/// Integral calculator (URS §30): antiderivative + C and definite
/// integrals with exact or numerical values.
class IntegralScreen extends ConsumerStatefulWidget {
  const IntegralScreen({super.key});

  @override
  ConsumerState<IntegralScreen> createState() => _IntegralScreenState();
}

class _IntegralScreenState extends ConsumerState<IntegralScreen> with EngineRunner {
  final _f = TextEditingController();
  final _var = TextEditingController(text: 'x');
  final _lo = TextEditingController();
  final _hi = TextEditingController();

  IntegralOutcome? _result;
  String? _error;
  String? _errorHint;
  String _fTex = '';
  String _v = 'x';
  String? _loTex, _hiTex;

  @override
  void initState() {
    super.initState();
    _var.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _f.dispose();
    _var.dispose();
    _lo.dispose();
    _hi.dispose();
    super.dispose();
  }

  Future<void> _compute() async {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final f = cleanInput(_f.text);
    final v = cleanVariable(_var.text);
    final lo = cleanInput(_lo.text), hi = cleanInput(_hi.text);
    if (v == null || (lo.isEmpty != hi.isEmpty)) {
      setState(() {
        _result = null;
        _error = v == null ? l.calculusInvalidVariable : l.calculusBothBounds;
        _errorHint = null;
      });
      return;
    }
    final definite = lo.isNotEmpty;
    final r = await runEngine(_startIntegral(engineService, f, v, definite ? lo : null, definite ? hi : null,
        radianSettings(settings.calcSettings), env.copy()));
    if (r == null) return;
    setState(() {
      _fTex = exprLatex(f, bound: {v}, env: env) ?? f;
      _v = v;
      _loTex = definite ? (exprLatex(lo, env: env) ?? lo) : null;
      _hiTex = definite ? (exprLatex(hi, env: env) ?? hi) : null;
      _result = null;
      _error = null;
      _errorHint = null;
      switch (r) {
        case Success(:final value):
          _result = value;
        case Failure(:final error):
          _error = errorText(l, error);
          if (definite &&
              (error.code == MathErrorCode.noConvergence ||
                  error.code == MathErrorCode.undefinedResult ||
                  error.code == MathErrorCode.overflow ||
                  error.code == MathErrorCode.divisionByZero)) {
            _errorHint = l.calculusDivergenceHint;
          }
        case Cancelled():
          _error = l.errCancelled;
      }
    });
    if (r case Success(:final value)) {
      final vt = varLatex(v);
      final intTex = definite ? '\\int_{$_loTex}^{$_hiTex}' : '\\int';
      final valueF = value.value == null ? null : formatNum(settings, value.value!, decimal: !value.exact);
      await recordHistory(
        ref,
        mode: 'integral',
        expression: definite ? 'integral($f,$v,$lo,$hi)' : '∫($f)d$v',
        expressionLatex: '$intTex $_fTex\\,d$vt',
        result: valueF?.plain ?? '${value.antiText} + C',
        resultLatex: valueF?.latex ?? '${value.antiTex}+C',
        value: value.value == null ? null : NumberValue(value.value!),
        radians: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = cleanVariable(_var.text) ?? 'x';
    return Scaffold(
      appBar: AppBar(title: Text(l.toolIntegral)),
      body: FormResultLayout(
        form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MathInputField(
            key: const ValueKey('integral.f'),
            controller: _f,
            label: l.calculusFunctionLabel(v),
            hint: l.calculusIntegralHint,
            bound: {v},
            previewPrefix: 'f(${varLatex(v)})=',
            onSubmitted: _compute,
          ),
          const SizedBox(height: 12),
          FieldRow(children: [
            SmallField(key: const ValueKey('integral.var'), controller: _var, label: l.calculusVariable),
            SmallField(
                key: const ValueKey('integral.lower'), controller: _lo, label: l.calculusLowerBound, hint: l.calculusBoundHint, onSubmitted: _compute),
            SmallField(
                key: const ValueKey('integral.upper'), controller: _hi, label: l.calculusUpperBound, hint: l.calculusBoundHint, onSubmitted: _compute),
          ]),
          const SizedBox(height: 12),
          InfoNote(l.calculusBoundsNote),
          const SizedBox(height: 4),
          InfoNote(l.calculusRadiansNote),
          const SizedBox(height: 16),
          ComputeButton(label: l.calculusIntegrate, onPressed: busy ? null : _compute),
          if (busy) BusyRow(onCancel: cancelRun),
        ]),
        result: _buildResult(l),
      ),
    );
  }

  Widget _buildResult(AppLocalizations l) {
    if (_error != null) return ErrorPanel(_error!, hint: _errorHint);
    final r = _result;
    if (r == null) return InfoNote(l.calculusIntegralEmpty, icon: Icons.functions);
    final settings = ref.watch(settingsProvider);
    final vt = varLatex(_v);
    final body = '$_fTex\\,d$vt';
    final children = <Widget>[];
    if (r.antiTex != null) {
      children.add(ResultLine(
          label: l.calculusAntiderivative, tex: '\\int $body=${r.antiTex}+C', plain: '${r.antiText} + C', large: r.value == null));
    } else if (r.value != null) {
      children.add(InfoNote(l.calculusNoAntiderivative));
    }
    final value = r.value;
    if (value != null) {
      if (children.isNotEmpty) children.add(const Divider());
      final lhs = '\\int_{$_loTex}^{$_hiTex}$body';
      if (r.exact) {
        children.addAll(numberResult(settings,
            label: l.calculusDefiniteExact, lhsTex: '$lhs=', n: value, exactTex: r.exactValueTex, exactPlain: r.exactValueText));
      } else {
        final d = formatNum(settings, value, decimal: true);
        children.add(ResultLine(label: l.calculusDefiniteNumeric, tex: '$lhs\\approx ${d.latex}', plain: d.plain, large: true));
        final err = r.errorEstimate;
        if (err != null && err.isFinite) {
          final e = NumberFormatter(settings.formatOptions().copyWith(digits: 3, fraction: FractionMode.decimal))
              .format(Dec.fromDouble(err.abs()), preferDecimal: true);
          children.add(ResultLine(label: l.calculusErrorEstimate, tex: '\\pm ${e.latex}', plain: '±${e.plain}'));
        }
      }
    }
    return ResultPanel(children: children);
  }
}
