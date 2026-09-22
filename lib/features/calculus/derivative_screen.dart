import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/engine_service.dart';
import 'calc_ui.dart';

/// Result of a derivative request (computed in a background isolate).
class DerivativeOutcome {
  const DerivativeOutcome({
    this.latex,
    this.text,
    this.valueAt,
    this.exactValueTex,
    this.exactValueText,
    this.numeric = false,
  });

  /// Symbolic derivative (null for a numerical result).
  final String? latex;
  final String? text;

  /// Value at the requested point.
  final Num? valueAt;

  /// Exact closed form of [valueAt] when one exists (e.g. √2/2).
  final String? exactValueTex;
  final String? exactValueText;

  /// True when symbolic differentiation was not possible and the value
  /// was computed numerically.
  final bool numeric;
}

/// Symbolic derivative with a numeric fallback. Top-level so it can run in
/// an isolate.
EngineResult<DerivativeOutcome> derivativeTask(
    String f, String variable, int order, String? at, CalcSettings settings, Environment env) {
  const engine = DefaultMathEngine();
  final r = engine.differentiate(f, variable, order, settings, env, at: at);
  switch (r) {
    case Success(:final value):
      String? exTex, exText;
      final v = value.valueAt;
      if (v != null && v is! Rat && at != null) {
        // Find an exact closed form by evaluating the derivative as a
        // function at the point (e.g. cos(π/4) = √2/2).
        final plain = const TextPrinter().print(symToNode(value.derivative));
        final env2 = env.copy()..functions['derivq'] = 'derivq($variable)=$plain';
        final ev = engine.evaluate('derivq(($at))', settings, env2);
        if (ev case Success(value: final e)) {
          exTex = e.exactLatex;
          exText = e.exactText;
        }
      }
      return Success(DerivativeOutcome(
        latex: value.latex,
        text: value.text,
        valueAt: v,
        exactValueTex: exTex,
        exactValueText: exText,
      ));
    case Failure(:final error):
      if (error.code != MathErrorCode.notSupported || at == null || order > 2) return Failure(error);
      final n = engine.evaluate('deriv(($f),$variable,($at),$order)', settings, env);
      return switch (n) {
        Success(value: Evaluation(value: NumberValue(:final n))) => Success(DerivativeOutcome(valueAt: n, numeric: true)),
        Success() => Failure(error),
        Failure(:final error) => Failure(error),
        Cancelled() => const Cancelled(),
      };
    case Cancelled():
      return const Cancelled();
  }
}

Computation<DerivativeOutcome> _startDerivative(
        EngineService s, String f, String v, int order, String? at, CalcSettings settings, Environment env) =>
    s.run(() => derivativeTask(f, v, order, at, settings, env));

/// Derivative calculator (URS §29): symbolic f′, higher orders, partial
/// derivatives and the value at a point.
class DerivativeScreen extends ConsumerStatefulWidget {
  const DerivativeScreen({super.key});

  @override
  ConsumerState<DerivativeScreen> createState() => _DerivativeScreenState();
}

class _DerivativeScreenState extends ConsumerState<DerivativeScreen> with EngineRunner {
  final _f = TextEditingController();
  final _var = TextEditingController(text: 'x');
  final _at = TextEditingController();
  int _order = 1;

  DerivativeOutcome? _result;
  String? _error;
  bool _errorNotSupported = false;

  // Snapshot of the request that produced [_result].
  String _fTex = '';
  String _v = 'x';
  String? _atTex;
  int _n = 1;
  bool _partial = false;

  @override
  void initState() {
    super.initState();
    _var.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _f.dispose();
    _var.dispose();
    _at.dispose();
    super.dispose();
  }

  Set<String> _otherSymbols(String f, String v, Environment env) {
    try {
      final node = Parser.parseExpression(cleanInput(f),
          scope: ParseScope(boundVariables: {v}, variables: env.variables.keys.toSet(), userFunctions: env.functions.keys.toSet()));
      return freeVariables(node).where((n) => n != v).toSet();
    } on MathError {
      return const {};
    } catch (_) {
      return const {};
    }
  }

  static String _opTex(String v, int n, bool partial) {
    final d = partial ? r'\partial' : 'd';
    final vt = varLatex(v);
    return n == 1 ? '\\frac{$d}{$d $vt}' : '\\frac{$d^{$n}}{$d $vt^{$n}}';
  }

  static String _lhsTex(String v, int n, bool partial) {
    final vt = varLatex(v);
    if (partial) {
      return n == 1 ? '\\frac{\\partial f}{\\partial $vt}' : '\\frac{\\partial^{$n} f}{\\partial $vt^{$n}}';
    }
    final marks = switch (n) { 1 => "'", 2 => "''", 3 => "'''", _ => '^{($n)}' };
    return 'f$marks($vt)';
  }

  Future<void> _compute() async {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final f = cleanInput(_f.text);
    final v = cleanVariable(_var.text);
    if (v == null) {
      setState(() {
        _result = null;
        _error = l.calculusInvalidVariable;
        _errorNotSupported = false;
      });
      return;
    }
    final atRaw = cleanInput(_at.text);
    final at = atRaw.isEmpty ? null : atRaw;
    final order = _order;
    final partial = _otherSymbols(f, v, env).isNotEmpty;
    final r = await runEngine(_startDerivative(engineService, f, v, order, at, radianSettings(settings.calcSettings), env.copy()));
    if (r == null) return;
    setState(() {
      _fTex = exprLatex(f, bound: {v}, env: env) ?? f;
      _v = v;
      _n = order;
      _partial = partial;
      _atTex = at == null ? null : (exprLatex(at, env: env) ?? at);
      _error = null;
      _errorNotSupported = false;
      _result = null;
      switch (r) {
        case Success(:final value):
          _result = value;
        case Failure(:final error):
          _error = errorText(l, error);
          _errorNotSupported = error.code == MathErrorCode.notSupported;
        case Cancelled():
          _error = l.errCancelled;
      }
    });
    if (r case Success(:final value)) {
      final valuePlain = value.valueAt == null ? null : formatNum(settings, value.valueAt!).plain;
      await recordHistory(
        ref,
        mode: 'derivative',
        expression: at != null ? 'deriv($f,$v,$at,$order)' : 'd^$order/d$v^$order ($f)',
        expressionLatex: '${_opTex(v, order, partial)}\\left($_fTex\\right)${at == null ? '' : '\\Big|_{${varLatex(v)}=$_atTex}'}',
        result: [if (value.text != null) value.text!, if (valuePlain != null) valuePlain].join('; '),
        resultLatex: value.latex ?? (value.valueAt == null ? '' : formatNum(settings, value.valueAt!).latex),
        value: value.valueAt == null || at == null ? null : NumberValue(value.valueAt!),
        radians: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = cleanVariable(_var.text) ?? 'x';
    return Scaffold(
      appBar: AppBar(title: Text(l.toolDerivative)),
      body: FormResultLayout(
        form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MathInputField(
            key: const ValueKey('derivative.f'),
            controller: _f,
            label: l.calculusFunctionLabel(v),
            hint: l.calculusDerivativeHint,
            bound: {v},
            previewPrefix: 'f(${varLatex(v)})=',
            onSubmitted: _compute,
          ),
          const SizedBox(height: 12),
          FieldRow(children: [
            SmallField(key: const ValueKey('derivative.var'), controller: _var, label: l.calculusVariable),
            DropdownButtonFormField<int>(
              key: const ValueKey('derivative.order'),
              value: _order,
              decoration: InputDecoration(labelText: l.calculusOrder, border: const OutlineInputBorder(), isDense: true),
              items: [for (var k = 1; k <= 10; k++) DropdownMenuItem(value: k, child: Text('$k'))],
              onChanged: (k) => setState(() => _order = k ?? 1),
            ),
            SmallField(
              key: const ValueKey('derivative.at'),
              controller: _at,
              label: l.calculusAtPointOptional(v),
              hint: l.calculusPointHint,
              onSubmitted: _compute,
            ),
          ]),
          const SizedBox(height: 12),
          InfoNote(l.calculusPartialNote),
          const SizedBox(height: 4),
          InfoNote(l.calculusRadiansNote),
          const SizedBox(height: 16),
          ComputeButton(label: l.calculusDifferentiate, onPressed: busy ? null : _compute),
          if (busy) BusyRow(onCancel: cancelRun),
        ]),
        result: _buildResult(context, l),
      ),
    );
  }

  Widget _buildResult(BuildContext context, AppLocalizations l) {
    if (_error != null) {
      return ErrorPanel(_error!, hint: _errorNotSupported ? l.calculusNumericFallbackHint : null);
    }
    final r = _result;
    if (r == null) return InfoNote(l.calculusDerivativeEmpty, icon: Icons.functions);
    final settings = ref.watch(settingsProvider);
    final op = _opTex(_v, _n, _partial);
    final vt = varLatex(_v);
    final lhs = _lhsTex(_v, _n, _partial);
    return ResultPanel(children: [
      if (r.numeric) ...[
        InfoNote(l.calculusNumericLabel, icon: Icons.warning_amber),
        const SizedBox(height: 8),
      ],
      if (r.latex != null) ...[
        ResultLine(label: l.calculusDerivativeResult, tex: '$op\\left($_fTex\\right)=${r.latex}', plain: r.text ?? r.latex!, large: true),
        ResultLine(tex: '$lhs=${r.latex}', plain: r.text ?? r.latex!),
      ],
      if (r.valueAt != null) ...[
        const Divider(),
        ...numberResult(
          settings,
          label: r.numeric ? l.calculusNumericValueAt : l.calculusValueAt,
          lhsTex: '\\left.$lhs\\right|_{$vt=${_atTex ?? ''}}${r.numeric ? r'\approx ' : '='}',
          n: r.valueAt!,
          exactTex: r.exactValueTex,
          exactPlain: r.exactValueText,
        ),
      ],
      if (_partial) ...[
        const SizedBox(height: 8),
        InfoNote(l.calculusPartialHeld),
      ],
    ]);
  }
}
