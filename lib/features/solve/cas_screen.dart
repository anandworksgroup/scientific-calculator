import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/app_menu_button.dart';
import '../calculator/calculator_controller.dart';
import 'solve_common.dart';

enum CasOp { simplify, expand, factor, collect, substitute, differentiate, integrate, solve, evaluate }

extension on CasOp {
  bool get needsVariable => switch (this) {
    CasOp.collect || CasOp.substitute || CasOp.differentiate || CasOp.integrate || CasOp.solve => true,
    _ => false,
  };
}

/// Output of a CAS operation, prepared in the background isolate.
class CasOutput {
  const CasOutput({this.inputLatex = '', this.latex = '', this.plain = '', this.sendText, this.solution});

  /// Textbook form of what was computed (e.g. d/dx(…)).
  final String inputLatex;

  /// Textbook form of the result (the right-hand side).
  final String latex;

  /// Copyable text.
  final String plain;

  /// Re-parseable expression for the calculator, when the result is one.
  final String? sendText;

  /// For Solve (and equations entered in Evaluate).
  final EquationSolution? solution;
}

EngineResult<CasOutput> Function() casTask(
  CasOp op,
  String input,
  String variable,
  String value,
  int order,
  CalcSettings settings,
  Environment env,
  FormatOptions format,
) =>
    () => runCas(op, input, variable, value, order, settings, env, format);

EngineResult<CasOutput> _then<T>(EngineResult<T> r, CasOutput Function(T value) f) => switch (r) {
  Success(:final value) => guard(() => f(value)),
  Failure(:final error) => Failure(error),
  Cancelled() => const Cancelled(),
};

/// Runs one CAS operation through the engine and renders the result.
EngineResult<CasOutput> runCas(
  CasOp op,
  String input,
  String variable,
  String value,
  int order,
  CalcSettings settings,
  Environment env,
  FormatOptions format,
) {
  const e = EngineService.engine;
  String inTex() {
    try {
      return const LatexPrinter().print(Parser.parseExpression(input, scope: solveScope(env)));
    } on MathError {
      return input;
    }
  }

  CasOutput sym(SymbolicResult r) => CasOutput(inputLatex: inTex(), latex: r.latex, plain: r.text, sendText: r.plain);

  switch (op) {
    case CasOp.simplify:
      return _then(e.simplify(input, settings, env), sym);
    case CasOp.expand:
      return _then(e.expand(input, settings, env), sym);
    case CasOp.factor:
      return _then(e.factor(input, settings, env), sym);
    case CasOp.collect:
      return _then(e.collect(input, variable, settings, env), sym);
    case CasOp.substitute:
      return _then(e.substitute(input, variable, value, settings, env), (r) {
        String valTex;
        try {
          valTex = const LatexPrinter().print(Parser.parseExpression(value, scope: solveScope(env)));
        } on MathError {
          valTex = value;
        }
        return CasOutput(
          inputLatex: '\\left.${_paren(inTex())}\\right|_{${varLatex(variable)}=$valTex}',
          latex: r.latex,
          plain: r.text,
          sendText: r.plain,
        );
      });
    case CasOp.differentiate:
      return _then(e.differentiate(input, variable, order, settings, env), (r) {
        final v = varLatex(variable);
        final op = order == 1 ? '\\frac{d}{d$v}' : '\\frac{d^{$order}}{d$v^{$order}}';
        return CasOutput(
          inputLatex: '$op${_paren(inTex())}',
          latex: r.latex,
          plain: r.text,
          sendText: symPlain(r.derivative),
        );
      });
    case CasOp.integrate:
      return _then(e.integrate(input, variable, settings, env), (r) {
        final anti = r.antiderivative!;
        return CasOutput(
          inputLatex: '\\int ${_paren(inTex())}\\,d${varLatex(variable)}',
          latex: '${symLatex(anti)}+C',
          plain: '${symText(anti)} + C',
          sendText: symPlain(anti),
        );
      });
    case CasOp.solve:
      return _then(e.solve(asEquationText(input, env), variable, settings, env), (s) {
        return CasOutput(inputLatex: lineLatex(input, env) ?? input, solution: s, sendText: _singleRootText(s, format));
      });
    case CasOp.evaluate:
      return _then(e.evaluate(input, settings, env), (ev) {
        if (ev.solution != null) {
          return CasOutput(
            inputLatex: ev.inputLatex,
            solution: ev.solution,
            sendText: _singleRootText(ev.solution!, format),
          );
        }
        final f = ValueFormatter(format).format(ev.value, preferDecimal: ev.preferDecimal);
        final exact = ev.exactLatex;
        return CasOutput(
          inputLatex: ev.inputLatex,
          latex: exact != null ? '$exact\\approx ${f.latex}' : f.latex,
          plain: exact != null ? '${ev.exactText} ≈ ${f.display}' : f.display,
          sendText: f.plain,
        );
      });
  }
}

String _paren(String tex) => '\\left($tex\\right)';

String? _singleRootText(EquationSolution s, FormatOptions o) {
  if (s.roots.length != 1 || s.symbolic.isNotEmpty) return null;
  final r = s.roots.first;
  if (r.exact != null) return symPlain(r.exact!);
  return NumberFormatter(
    o.copyWith(fraction: r.value is Rat ? FractionMode.fraction : FractionMode.decimal),
  ).format(r.value, preferDecimal: r.value is! Rat).plain;
}

final _identifier = RegExp(r'^[A-Za-zα-ωΑ-Ωθ][A-Za-z0-9_]*$');

/// Computer algebra (URS §34): simplify, expand, factor, collect,
/// substitute, differentiate, integrate, solve and evaluate.
class CasScreen extends ConsumerStatefulWidget {
  const CasScreen({super.key, this.initialExpression, this.initialOperation});

  /// Optional expression to prefill.
  final String? initialExpression;

  /// Optional operation name (one of [CasOp] names, e.g. `factor`).
  final String? initialOperation;

  @override
  ConsumerState<CasScreen> createState() => _CasScreenState();
}

class _CasScreenState extends ConsumerState<CasScreen> with EngineRunner {
  late final _input = TextEditingController(text: widget.initialExpression ?? '');
  final _variable = TextEditingController(text: 'x');
  final _value = TextEditingController();
  late CasOp _op = CasOp.values.where((o) => o.name == widget.initialOperation).firstOrNull ?? CasOp.simplify;
  int _order = 1;

  CasOutput? _output;
  CasOp? _outputOp;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    _input.addListener(_changed);
  }

  @override
  void dispose() {
    _input.dispose();
    _variable.dispose();
    _value.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  String _opLabel(AppLocalizations l, CasOp op) => switch (op) {
    CasOp.simplify => l.solveCasSimplify,
    CasOp.expand => l.solveCasExpand,
    CasOp.factor => l.solveCasFactor,
    CasOp.collect => l.solveCasCollect,
    CasOp.substitute => l.solveCasSubstitute,
    CasOp.differentiate => l.solveCasDifferentiate,
    CasOp.integrate => l.solveCasIntegrate,
    CasOp.solve => l.actionSolve,
    CasOp.evaluate => l.solveCasEvaluate,
  };

  void _showMessage(String text, {bool error = true}) => setState(() {
    _message = text;
    _messageIsError = error;
    _output = null;
  });

  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final input = ClipboardService.sanitize(_input.text);
    if (input.isEmpty) {
      _showMessage(l.errEmptyInput);
      return;
    }
    final variable = _variable.text.trim();
    if (_op.needsVariable && !_identifier.hasMatch(variable)) {
      _showMessage(l.solveCasInvalidVariable);
      return;
    }
    final value = ClipboardService.sanitize(_value.text);
    if (_op == CasOp.substitute && value.isEmpty) {
      _showMessage(l.solveCasEnterValue);
      return;
    }
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider).copy();
    final op = _op;
    final r = await runEngine(
      casTask(op, input, variable, value, _order, settings.calcSettings, env, settings.formatOptions()),
    );
    if (r == null || !mounted) return;
    switch (r) {
      case Success(value: final out):
        setState(() {
          _output = out;
          _outputOp = op;
          _message = null;
        });
        final (plain, tex) = out.solution != null
            ? equationSummary(out.solution!, settings.formatOptions(), l)
            : (out.plain, out.latex);
        await recordSolveHistory(
          ref,
          mode: 'cas',
          expression: input,
          expressionLatex: out.inputLatex,
          result: plain,
          resultLatex: tex,
        );
      case Failure(:final error):
        _showMessage(errorText(l, error));
      case Cancelled():
        _showMessage(l.errCancelled, error: false);
    }
  }

  void _cancel() {
    cancelEngine();
    _showMessage(AppLocalizations.of(context).errCancelled, error: false);
  }

  void _sendToCalculator(String text) {
    ref.read(calculatorProvider.notifier).loadExpression(text);
    context.go(Routes.calculator);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final env = ref.watch(environmentProvider);
    final text = ClipboardService.sanitize(_input.text);
    final preview = text.isEmpty ? null : lineLatex(text, env);

    final input = <Widget>[
      TextField(
        key: const Key('cas-input'),
        controller: _input,
        autocorrect: false,
        enableSuggestions: false,
        style: theme.textTheme.titleMedium,
        decoration: InputDecoration(
          labelText: l.solveCasInput,
          helperText: l.solveCasInputHelp,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: l.actionClear,
            icon: const Icon(Icons.clear),
            onPressed: () {
              _input.clear();
              setState(() {
                _output = null;
                _message = null;
              });
            },
          ),
        ),
        onSubmitted: (_) => _run(),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (preview != null) MathLine(preview, fallback: text)],
      ),
      const SizedBox(height: 12),
      Text(l.solveCasOperation, style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final op in CasOp.values)
            ChoiceChip(
              key: Key('cas-op-${op.name}'),
              label: Text(_opLabel(l, op)),
              selected: _op == op,
              onSelected: (_) => setState(() => _op = op),
            ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_op.needsVariable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: const Key('cas-variable'),
                    controller: _variable,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: l.solveVariable, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                if (_op == CasOp.substitute)
                  Expanded(
                    child: TextField(
                      key: const Key('cas-value'),
                      controller: _value,
                      autocorrect: false,
                      decoration: InputDecoration(labelText: l.solveCasValue, border: const OutlineInputBorder()),
                    ),
                  ),
                if (_op == CasOp.differentiate) ...[
                  Text(l.solveCasOrder, style: theme.textTheme.labelLarge),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    key: const Key('cas-order'),
                    value: _order,
                    items: [for (var k = 1; k <= 10; k++) DropdownMenuItem(value: k, child: Text('$k'))],
                    onChanged: (v) => setState(() => _order = v ?? 1),
                  ),
                ],
              ],
            ),
          ],
          if (_op == CasOp.integrate) SolveNote(l.solveCasIntegrateNote),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('cas-run'),
        onPressed: busy ? null : _run,
        icon: const Icon(Icons.play_arrow),
        label: Text(_opLabel(l, _op)),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ];

    final out = _output;
    final send = out?.sendText;
    final sendButton = send == null
        ? null
        : IconButton(
            key: const Key('cas-send'),
            tooltip: l.solveCasSendToCalculator,
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => _sendToCalculator(send),
          );
    final output = <Widget>[
      if (busy) SolveBusy(onCancel: _cancel),
      if (_message != null) SolveMessage(_message!, error: _messageIsError),
      if (out != null && out.solution != null) ...[
        MathLine(out.inputLatex),
        EquationResultView(solution: out.solution!, settings: settings, actions: [?sendButton]),
      ] else if (out != null)
        SolveResultCard(
          title: _opLabel(l, _outputOp ?? _op),
          copyText: out.plain,
          actions: [?sendButton],
          children: [
            MathLine(out.inputLatex, style: theme.textTheme.titleMedium),
            MathLine('=${out.latex}', fallback: '= ${out.plain}', semanticsLabel: out.plain),
            const SizedBox(height: 8),
            SelectableText(out.plain, key: const Key('cas-plain'), style: theme.textTheme.bodyMedium),
          ],
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.toolCas), actions: const [AppMenuButton()]),
      body: SolveLayout(input: input, output: output),
    );
  }
}
