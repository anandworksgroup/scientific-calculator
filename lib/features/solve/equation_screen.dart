import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/app_menu_button.dart';
import 'solve_common.dart';

/// Equation solver (URS §20): any equation in one unknown, or several
/// linear equations typed one per line.
class EquationScreen extends ConsumerStatefulWidget {
  const EquationScreen({super.key, this.initialEquation});

  /// Optional equation to prefill (e.g. from a route query parameter).
  final String? initialEquation;

  @override
  ConsumerState<EquationScreen> createState() => _EquationScreenState();
}

class _EquationScreenState extends ConsumerState<EquationScreen> with EngineRunner {
  late final _input = TextEditingController(text: widget.initialEquation ?? '');
  final _lower = TextEditingController();
  final _upper = TextEditingController();

  List<String> _unknowns = const [];
  String? _variable;

  EquationSolution? _solution;
  TextSystemResult? _system;
  String? _message;
  bool _messageIsError = true;

  static const _examples = ['x^2-5x+6=0', 'cos(x)=x', '2^x=8', 'a*x+b=0', '2x+y=5\nx-y=1'];

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    _detect();
  }

  void _detect() {
    final found = detectUnknowns(_lines, ref.read(environmentProvider));
    _unknowns = found;
    if (_variable == null || !found.contains(_variable)) {
      _variable = found.contains('x') ? 'x' : (found.isEmpty ? null : found.first);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _lower.dispose();
    _upper.dispose();
    super.dispose();
  }

  List<String> get _lines => _input.text.split('\n').map(ClipboardService.sanitize).where((s) => s.isNotEmpty).toList();

  void _onInputChanged() => setState(_detect);

  void _showMessage(String text, {bool error = true}) => setState(() {
    _message = text;
    _messageIsError = error;
    _solution = null;
    _system = null;
  });

  /// Evaluates an interval bound (accepts expressions such as -2pi).
  (double?, String?) _bound(String text, AppLocalizations l) {
    final t = ClipboardService.sanitize(text);
    if (t.isEmpty) return (null, null);
    final settings = ref.read(settingsProvider).calcSettings;
    final r = EngineService.engine.evaluate(
      t,
      settings,
      ref.read(environmentProvider),
      budget: Budget(timeLimit: const Duration(milliseconds: 300)),
    );
    switch (r) {
      case Success(:final value):
        final v = value.value;
        if (v is NumberValue && v.n is! Cpx) {
          final d = v.n.toDouble();
          if (d.isFinite) return (d, null);
        }
        return (null, l.solveIntervalInvalid);
      case Failure(:final error):
        return (null, errorText(l, error));
      case Cancelled():
        return (null, l.errCancelled);
    }
  }

  Future<void> _solve() async {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final lines = _lines;
    if (lines.isEmpty) {
      _showMessage(l.errEmptyInput);
      return;
    }
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider).copy();
    if (lines.length > 1) {
      final r = await runEngine(textSystemTask(lines, settings.calcSettings, env));
      if (r == null || !mounted) return;
      _handleSystem(r, lines, l);
      return;
    }
    final variable = _variable ?? 'x';
    final (lo, loErr) = _bound(_lower.text, l);
    final (hi, hiErr) = _bound(_upper.text, l);
    if (loErr != null || hiErr != null) {
      _showMessage(l.solveIntervalError(loErr ?? hiErr!));
      return;
    }
    if ((lo == null) != (hi == null)) {
      _showMessage(l.solveIntervalBoth);
      return;
    }
    if (lo != null && hi != null && !(lo < hi)) {
      _showMessage(l.solveIntervalOrder);
      return;
    }
    final equation = asEquationText(lines.first, env);
    final r = await runEngine(equationTask(equation, variable, settings.calcSettings, env, lo, hi));
    if (r == null || !mounted) return;
    switch (r) {
      case Success(:final value):
        setState(() {
          _solution = value;
          _system = null;
          _message = null;
        });
        final (plain, tex) = equationSummary(value, settings.formatOptions(), l);
        await recordSolveHistory(
          ref,
          mode: 'equation',
          expression: lines.first,
          expressionLatex: lineLatex(lines.first, env) ?? lines.first,
          result: plain,
          resultLatex: tex,
        );
      case Failure(:final error):
        _showMessage(errorText(l, error));
      case Cancelled():
        _showMessage(l.errCancelled, error: false);
    }
  }

  Future<void> _handleSystem(EngineResult<TextSystemResult> r, List<String> lines, AppLocalizations l) async {
    switch (r) {
      case Success(:final value):
        switch (value.status) {
          case TextSystemStatus.solved:
            setState(() {
              _system = value;
              _solution = null;
              _message = null;
            });
            final settings = ref.read(settingsProvider);
            final (plain, tex) = systemSummary(value.solution!, settings.formatOptions(), l);
            await recordSolveHistory(
              ref,
              mode: 'equation',
              expression: lines.join('; '),
              expressionLatex: value.equationsLatex.join(r',\quad '),
              result: plain,
              resultLatex: tex,
            );
          case TextSystemStatus.notEquation:
            _showMessage(l.solveLineNotEquation(value.line + 1));
          case TextSystemStatus.nonlinear:
            _showMessage(l.solveSystemNonlinear(value.line + 1));
          case TextSystemStatus.noUnknowns:
            _showMessage(l.solveNoUnknowns);
        }
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

  void _clear() {
    _input.clear();
    _lower.clear();
    _upper.clear();
    setState(() {
      _solution = null;
      _system = null;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final env = ref.watch(environmentProvider);
    final lines = _lines;
    final isSystem = lines.length > 1;

    final input = <Widget>[
      TextField(
        key: const Key('solve-equation-input'),
        controller: _input,
        minLines: 1,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        autocorrect: false,
        enableSuggestions: false,
        style: theme.textTheme.titleMedium,
        decoration: InputDecoration(
          labelText: l.solveEquationInput,
          helperText: l.solveEquationHelp,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(tooltip: l.actionClear, icon: const Icon(Icons.clear), onPressed: _clear),
        ),
      ),
      const SizedBox(height: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            if (lineLatex(line, env) case final tex?) MathLine(tex, fallback: line),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final e in _examples)
            ActionChip(
              label: Text(e.replaceAll('\n', '; ')),
              tooltip: l.solveUseExample,
              onPressed: () {
                _input.text = e;
                _input.selection = TextSelection.collapsed(offset: e.length);
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isSystem)
            SolveNote(l.solveSystemDetected(lines.length), icon: Icons.view_agenda_outlined)
          else ...[
            Text(l.solveVariable, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            if (_unknowns.isEmpty)
              Text(l.solveNoVariableYet, style: theme.textTheme.bodySmall)
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final v in _unknowns)
                    ChoiceChip(
                      label: Text(v),
                      selected: v == _variable,
                      tooltip: l.solveSolveFor(v),
                      onSelected: (_) => setState(() => _variable = v),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Text(l.solveInterval, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('solve-equation-lower'),
                    controller: _lower,
                    decoration: InputDecoration(labelText: l.solveLower, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('solve-equation-upper'),
                    controller: _upper,
                    decoration: InputDecoration(labelText: l.solveUpper, border: const OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            SolveNote(l.solveIntervalHelp),
          ],
        ],
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('solve-equation-solve'),
        onPressed: busy ? null : _solve,
        icon: const Icon(Icons.play_arrow),
        label: Text(l.actionSolve),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ];

    final output = <Widget>[
      if (busy) SolveBusy(onCancel: _cancel),
      if (_message != null) SolveMessage(_message!, error: _messageIsError),
      if (_solution != null) EquationResultView(solution: _solution!, settings: settings),
      if (_system?.solution != null) ...[
        for (final tex in _system!.equationsLatex) MathLine(tex),
        const SizedBox(height: 8),
        LinearSystemResultView(solution: _system!.solution!, settings: settings),
      ],
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.toolEquation), actions: const [AppMenuButton()]),
      body: SolveLayout(input: input, output: output),
    );
  }
}
