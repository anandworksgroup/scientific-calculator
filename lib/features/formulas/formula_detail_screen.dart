import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/error_text.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/math_view.dart';
import '../calculator/calculator_controller.dart' show historyListProvider;
import '../converter/converter_screen.dart' show unitTexText;
import 'formulas_screen.dart';

/// Turns a library equation into one the solver accepts.
///
/// `E_k = 1/2*m*v^2` parses as an assignment (a single name on the left),
/// so it is rewritten as `(E_k)-(1/2*m*v^2)=0`.
String solverEquation(String equation) {
  final k = equation.indexOf('=');
  if (k < 0) return '($equation)=0';
  return '(${equation.substring(0, k).trim()})-(${equation.substring(k + 1).trim()})=0';
}

/// Builds the isolate task. Top-level so the closure only captures plain data.
EngineResult<EquationSolution> Function() formulaSolveTask(
        String equation, String unknown, CalcSettings settings, Map<String, Value> values) =>
    () => EngineService.engine.solve(solverEquation(equation), unknown, settings, Environment(variables: values));

/// One formula with its variables, related formulas and a solver (URS §50).
class FormulaDetailScreen extends ConsumerStatefulWidget {
  const FormulaDetailScreen({super.key, required this.formulaId});
  final String formulaId;

  @override
  ConsumerState<FormulaDetailScreen> createState() => _FormulaDetailScreenState();
}

class _FormulaDetailScreenState extends ConsumerState<FormulaDetailScreen> {
  late final Formula? _formula = formulaById(widget.formulaId);
  late final List<FormulaVariable> _vars = [for (final v in _formula?.variables ?? const <FormulaVariable>[]) if (v.id.isNotEmpty) v];
  late final Map<String, TextEditingController> _fields = {for (final v in _vars) v.id: TextEditingController()};
  bool _favorite = false;

  Computation<EquationSolution>? _running;
  EquationSolution? _solution;
  String? _unknown;
  bool _preferDecimal = false;
  MathError? _error;
  String? _formError;
  final Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = await ref.read(favoritesRepositoryProvider).ids(FavoriteType.formula);
      if (mounted) setState(() => _favorite = ids.contains(widget.formulaId));
    } catch (e) {
      AppLogger.error('formula favorite load', e);
    }
  }

  @override
  void dispose() {
    _running?.cancel();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final fav = !_favorite;
    setState(() => _favorite = fav);
    try {
      await ref.read(favoritesRepositoryProvider).set(FavoriteType.formula, widget.formulaId, fav);
    } catch (e) {
      AppLogger.error('formula favorite', e);
    }
  }

  Future<void> _solve() async {
    final l = AppLocalizations.of(context);
    final f = _formula;
    if (f == null || f.equation == null) return;
    FocusScope.of(context).unfocus();
    final empty = [for (final v in _vars) if (_fields[v.id]!.text.trim().isEmpty) v.id];
    setState(() {
      _fieldErrors.clear();
      _solution = null;
      _error = null;
      _formError = null;
    });
    if (empty.length != 1) {
      setState(() => _formError = l.formulaNeedOneEmpty);
      return;
    }
    final unknown = empty.single;
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final values = <String, Value>{};
    var decimal = false;
    for (final v in _vars) {
      if (v.id == unknown) continue;
      final text = ClipboardService.sanitize(_fields[v.id]!.text);
      final r = EngineService.engine.evaluate(text, settings.calcSettings, env,
          budget: Budget(timeLimit: const Duration(milliseconds: 500)));
      switch (r) {
        case Success(:final value):
          final val = value.value;
          if (val is NumberValue && Arith.isReal(val.n)) {
            values[v.id] = val;
            decimal = decimal || value.preferDecimal;
          } else {
            _fieldErrors[v.id] = l.formulaInvalidValue;
          }
        case Failure(:final error):
          _fieldErrors[v.id] = errorText(l, error);
        case Cancelled():
          _fieldErrors[v.id] = l.errCancelled;
      }
    }
    if (_fieldErrors.isNotEmpty) {
      setState(() {});
      return;
    }
    final comp = ref.read(engineServiceProvider).run(formulaSolveTask(f.equation!, unknown, settings.calcSettings, values));
    setState(() {
      _running = comp;
      _unknown = unknown;
      _preferDecimal = decimal;
    });
    final result = await comp.result;
    if (!mounted || _running != comp) return;
    setState(() {
      _running = null;
      switch (result) {
        case Success(:final value):
          _solution = value;
        case Failure(:final error):
          _error = error;
        case Cancelled():
          _error = const MathError(MathErrorCode.cancelled);
      }
    });
    if (result case Success(:final value)) await _record(f, unknown, values, value);
  }

  void _cancel() {
    _running?.cancel();
    setState(() {
      _running = null;
      _error = const MathError(MathErrorCode.cancelled);
    });
  }

  void _clear() {
    for (final c in _fields.values) {
      c.clear();
    }
    setState(() {
      _solution = null;
      _error = null;
      _formError = null;
      _fieldErrors.clear();
    });
  }

  List<SolvedRoot> _realRoots(EquationSolution s) => [for (final r in s.roots) if (Arith.isReal(r.value)) r];

  FormattedNumber _format(Num n) =>
      ValueFormatter(ref.read(settingsProvider).formatOptions()).format(NumberValue(n), preferDecimal: _preferDecimal);

  Future<void> _record(Formula f, String unknown, Map<String, Value> values, EquationSolution s) async {
    final settings = ref.read(settingsProvider);
    final roots = _realRoots(s);
    if (!settings.saveHistory || roots.isEmpty) return;
    final formatter = ValueFormatter(settings.formatOptions());
    final given = [for (final e in values.entries) '${e.key}=${formatter.format(e.value).plain}'].join(', ');
    final value = SolutionsValue(unknown, [for (final r in roots) r.value], numeric: s.method == SolveMethod.numeric);
    final shown = formatter.format(value, preferDecimal: _preferDecimal);
    try {
      await ref.read(historyRepositoryProvider).insert(
            HistoryEntry(
              expression: '${f.equation}; $given',
              expressionLatex: f.latex,
              result: '$unknown = ${shown.plain}',
              resultLatex: shown.latex,
              mode: 'formula',
              angleMode: settings.angleMode.name,
              format: settings.resultFormat.name,
              createdAt: DateTime.now(),
            ),
            limit: settings.historyLimit,
          );
      ref.invalidate(historyListProvider);
    } catch (e) {
      AppLogger.error('formula history', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    ref.watch(settingsProvider);
    final f = _formula;
    if (f == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.formulaTitle)),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.formulaNotFound))),
      );
    }

    final header = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(formulaCategoryIcon(f.category), size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(formulaCategoryName(l, f.category), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          ]),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: MathView(f.latex, display: true, style: theme.textTheme.headlineSmall, semanticsLabel: f.name),
          ),
          const SizedBox(height: 16),
          Text(l.formulaDescription, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(f.description, style: theme.textTheme.bodyMedium),
        ]),
      ),
    );

    final variables = f.variables.isEmpty
        ? const SizedBox.shrink()
        : Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ListTile(title: Text(l.formulaVariables, style: theme.textTheme.titleSmall)),
              for (final v in f.variables)
                ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 56,
                    child: Center(child: MathView(v.latex, style: theme.textTheme.titleMedium, semanticsLabel: v.id.isEmpty ? v.latex : v.id)),
                  ),
                  title: Text(v.meaning),
                  trailing: v.unit.isEmpty ? null : Text(v.unit, style: theme.textTheme.bodyMedium),
                ),
            ]),
          );

    final related = [for (final id in f.related) formulaById(id)].whereType<Formula>().toList();
    final relatedCard = related.isEmpty
        ? const SizedBox.shrink()
        : Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ListTile(title: Text(l.formulaRelated, style: theme.textTheme.titleSmall)),
              for (final r in related)
                ListTile(
                  title: Text(r.name),
                  subtitle: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: MathView(r.latex, style: theme.textTheme.bodyMedium),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.formula(r.id)),
                ),
            ]),
          );

    final calculator = f.equation == null
        ? Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l.formulaNoCalculator)))
        : _calculatorCard(context, f);

    return Scaffold(
      appBar: AppBar(
        title: Text(f.name),
        actions: [
          IconButton(
            tooltip: _favorite ? l.actionUnfavorite : l.actionFavorite,
            icon: Icon(_favorite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          const gap = SizedBox(height: 12);
          if (c.maxWidth >= 720) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, gap, variables, gap, relatedCard])),
                const SizedBox(width: 16),
                Expanded(child: calculator),
              ]),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [header, gap, calculator, gap, variables, gap, relatedCard],
          );
        }),
      ),
    );
  }

  Widget _calculatorCard(BuildContext context, Formula f) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(l.formulaCalculate, style: theme.textTheme.titleMedium)),
            IconButton(tooltip: l.formulaClearFields, icon: const Icon(Icons.clear_all), onPressed: _clear),
          ]),
          Text(l.formulaCalculateHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final v in _vars)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                key: ValueKey('formula-field-${v.id}'),
                controller: _fields[v.id],
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: v.meaning,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: MathView(v.latex, style: theme.textTheme.titleMedium, semanticsLabel: v.id),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  suffixText: v.unit.isEmpty ? null : v.unit,
                  errorText: _fieldErrors[v.id],
                  errorMaxLines: 3,
                ),
              ),
            ),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_formError!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (_running != null)
            Row(children: [
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(width: 12),
              Expanded(child: Text(_unknown == null ? l.calculating : l.formulaSolvingFor(_unknown!))),
              TextButton(onPressed: _cancel, child: Text(l.actionCancel)),
            ])
          else
            FilledButton.icon(onPressed: _solve, icon: const Icon(Icons.calculate_outlined), label: Text(l.actionSolve)),
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: _resultView(context)),
        ]),
      ),
    );
  }

  Widget _resultView(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (_error != null) {
      return Text(errorText(l, _error!), style: TextStyle(color: theme.colorScheme.error));
    }
    final s = _solution;
    final unknown = _unknown;
    if (s == null || unknown == null) return const SizedBox.shrink();
    final v = _vars.firstWhere((x) => x.id == unknown);
    if (s.alwaysTrue) return Text(l.formulaAlwaysTrue(v.meaning));
    final roots = _realRoots(s);
    if (roots.isEmpty) {
      return Text(s.roots.isEmpty ? l.errNoRealSolution : l.formulaComplexOnly, style: TextStyle(color: theme.colorScheme.error));
    }
    final unitTex = v.unit.isEmpty ? '' : '\\ ${unitTexText(v.unit)}';
    final copyText = roots.map((r) => _format(r.value).plain).join(', ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (roots.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l.formulaSeveralSolutions(roots.length), style: theme.textTheme.bodySmall),
        ),
      for (final r in roots)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Builder(builder: (context) {
            final shown = _format(r.value);
            final exact = r.exact == null ? null : const LatexPrinter().print(symToNode(r.exact!));
            final approx = s.method == SolveMethod.numeric;
            final tex = StringBuffer('${v.latex} = ');
            if (exact != null && exact != shown.latex) {
              tex.write('$exact \\approx ${shown.latex}');
            } else {
              tex.write('${approx ? '\\approx ' : ''}${shown.latex}');
            }
            tex.write(unitTex);
            return ScrollingMath(
              tex.toString(),
              alignRight: false,
              fallback: '$unknown = ${shown.display} ${v.unit}',
              semanticsLabel: '$unknown = ${shown.display}',
              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
            );
          }),
        ),
      if (s.method == SolveMethod.numeric) Text(l.formulaNumericNote, style: theme.textTheme.bodySmall),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () async {
            await ClipboardService.copy(copyText);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copiedToClipboard)));
          },
          icon: const Icon(Icons.copy, size: 18),
          label: Text(l.formulaCopySolution),
        ),
      ),
    ]);
  }
}
