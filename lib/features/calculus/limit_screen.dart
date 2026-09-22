import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/engine_service.dart';
import 'calc_ui.dart';

/// Limit of f as variable → point. Top-level for isolates.
EngineResult<Value> limitTask(String f, String variable, String point, int side, CalcSettings settings, Environment env) =>
    const DefaultMathEngine().limit(f, variable, point, side, settings, env);

Computation<Value> _startLimit(
        EngineService s, String f, String v, String point, int side, CalcSettings settings, Environment env) =>
    s.run(() => limitTask(f, v, point, side, settings, env));

/// Limit calculator (URS §31): two-sided and one-sided limits, limits at
/// ±∞ and infinite limits.
class LimitScreen extends ConsumerStatefulWidget {
  const LimitScreen({super.key});

  @override
  ConsumerState<LimitScreen> createState() => _LimitScreenState();
}

class _LimitScreenState extends ConsumerState<LimitScreen> with EngineRunner {
  final _f = TextEditingController();
  final _var = TextEditingController(text: 'x');
  final _point = TextEditingController(text: '0');
  int _side = 0;

  Value? _result;
  String? _error;
  String? _errorHint;
  String _lhsTex = '';

  @override
  void initState() {
    super.initState();
    _var.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _f.dispose();
    _var.dispose();
    _point.dispose();
    super.dispose();
  }

  Future<void> _compute() async {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final f = cleanInput(_f.text);
    final v = cleanVariable(_var.text);
    final point = cleanInput(_point.text);
    if (v == null || point.isEmpty) {
      setState(() {
        _result = null;
        _error = v == null ? l.calculusInvalidVariable : l.calculusPointRequired;
        _errorHint = null;
      });
      return;
    }
    final side = _side;
    final r = await runEngine(_startLimit(engineService, f, v, point, side, radianSettings(settings.calcSettings), env.copy()));
    if (r == null) return;
    final pointTex = exprLatex(point, env: env) ?? point;
    final sideTex = switch (side) { -1 => '^{-}', 1 => '^{+}', _ => '' };
    final fTex = exprLatex(f, bound: {v}, env: env) ?? f;
    setState(() {
      _lhsTex = '\\lim_{${varLatex(v)}\\to {$pointTex}$sideTex}\\left($fTex\\right)';
      _result = null;
      _error = null;
      _errorHint = null;
      switch (r) {
        case Success(:final value):
          _result = value;
        case Failure(:final error):
          _error = errorText(l, error);
          if (error.code == MathErrorCode.undefinedResult || error.code == MathErrorCode.noConvergence) {
            _errorHint = l.calculusLimitDneHint;
          }
        case Cancelled():
          _error = l.errCancelled;
      }
    });
    if (r case Success(:final value)) {
      final shown = ValueFormatter(settings.formatOptions()).format(value);
      final fn = switch (side) { -1 => 'limleft', 1 => 'limright', _ => 'lim' };
      await recordHistory(
        ref,
        mode: 'limit',
        expression: '$fn($f,$v,$point)',
        expressionLatex: _lhsTex,
        result: shown.display,
        resultLatex: shown.latex,
        value: value,
        radians: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = cleanVariable(_var.text) ?? 'x';
    return Scaffold(
      appBar: AppBar(title: Text(l.toolLimit)),
      body: FormResultLayout(
        form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MathInputField(
            key: const ValueKey('limit.f'),
            controller: _f,
            label: l.calculusFunctionLabel(v),
            hint: l.calculusLimitHint,
            bound: {v},
            previewPrefix: 'f(${varLatex(v)})=',
            onSubmitted: _compute,
          ),
          const SizedBox(height: 12),
          FieldRow(children: [
            SmallField(key: const ValueKey('limit.var'), controller: _var, label: l.calculusVariable),
            SmallField(
                key: const ValueKey('limit.point'),
                controller: _point,
                label: l.calculusLimitPoint(v),
                hint: l.calculusLimitPointHint,
                onSubmitted: _compute),
          ]),
          const SizedBox(height: 12),
          Semantics(
            label: l.calculusSide,
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l.calculusSideBoth)),
                ButtonSegment(value: -1, label: Text(l.calculusSideLeft)),
                ButtonSegment(value: 1, label: Text(l.calculusSideRight)),
              ],
              selected: {_side},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _side = s.first),
            ),
          ),
          const SizedBox(height: 12),
          InfoNote(l.calculusRadiansNote),
          const SizedBox(height: 16),
          ComputeButton(label: l.calculusFindLimit, onPressed: busy ? null : _compute),
          if (busy) BusyRow(onCancel: cancelRun),
        ]),
        result: _buildResult(l),
      ),
    );
  }

  Widget _buildResult(AppLocalizations l) {
    if (_error != null) return ErrorPanel(_error!, hint: _errorHint);
    final r = _result;
    if (r == null) return InfoNote(l.calculusLimitEmpty, icon: Icons.functions);
    final settings = ref.watch(settingsProvider);
    if (r is NumberValue) {
      return ResultPanel(children: [...numberResult(settings, label: l.calculusLimitResult, lhsTex: '$_lhsTex=', n: r.n)]);
    }
    final shown = ValueFormatter(settings.formatOptions()).format(r);
    return ResultPanel(children: [
      ResultLine(label: l.calculusLimitResult, tex: '$_lhsTex=${shown.latex}', plain: shown.display, large: true),
      if (r is InfinityValue) ...[
        const SizedBox(height: 8),
        InfoNote(r.sign > 0 ? l.calculusLimitPlusInfinity : l.calculusLimitMinusInfinity),
      ],
    ]);
  }
}
