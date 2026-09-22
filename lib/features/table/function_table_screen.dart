import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/math_view.dart';
import '../calculus/calc_ui.dart';

/// Builds the table. Top-level so it can run in an isolate.
EngineResult<List<TableRow>> functionTableTask(
        String expression, String variable, String start, String end, String step, CalcSettings settings, Environment env) =>
    FunctionTable.build(
        expression: expression, variable: variable, start: start, end: end, step: step, settings: settings, env: env);

Computation<List<TableRow>> _startTable(EngineService s, String f, String v, String a, String b, String h,
        CalcSettings settings, Environment env) =>
    s.run(() => functionTableTask(f, v, a, b, h, settings, env));

/// x | f(x) value table (URS §93).
class FunctionTableScreen extends ConsumerStatefulWidget {
  const FunctionTableScreen({super.key, this.initialExpression});

  /// Pre-filled f(x) (the route passes the `f` query parameter).
  final String? initialExpression;

  @override
  ConsumerState<FunctionTableScreen> createState() => _FunctionTableScreenState();
}

class _FunctionTableScreenState extends ConsumerState<FunctionTableScreen> with EngineRunner {
  late final _f = TextEditingController(text: widget.initialExpression ?? '');
  final _var = TextEditingController(text: 'x');
  final _start = TextEditingController(text: '-5');
  final _end = TextEditingController(text: '5');
  final _step = TextEditingController(text: '1');

  List<TableRow>? _rows;
  String? _error;
  String _v = 'x';
  String _fPlain = '';

  @override
  void initState() {
    super.initState();
    _var.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _f.dispose();
    _var.dispose();
    _start.dispose();
    _end.dispose();
    _step.dispose();
    super.dispose();
  }

  Future<void> _compute() async {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final f = cleanInput(_f.text);
    final v = cleanVariable(_var.text);
    if (v == null) {
      setState(() {
        _rows = null;
        _error = l.calculusInvalidVariable;
      });
      return;
    }
    final a = cleanInput(_start.text), b = cleanInput(_end.text), h = cleanInput(_step.text);
    final r = await runEngine(_startTable(engineService, f, v, a, b, h, settings.calcSettings, env.copy()));
    if (r == null) return;
    setState(() {
      _rows = null;
      _error = null;
      _v = v;
      _fPlain = f;
      switch (r) {
        case Success(:final value):
          _rows = value;
        case Failure(:final error):
          _error = errorText(l, error);
        case Cancelled():
          _error = l.errCancelled;
      }
    });
    final rows = _rows;
    if (rows != null) {
      await recordHistory(ref,
          mode: 'table',
          expression: 'table($f,$v,$a,$b,$h)',
          expressionLatex: '${exprLatex(f, bound: {v}, env: env) ?? f},\\ ${varLatex(v)}=${exprLatex(a) ?? a}\\ldots ${exprLatex(b) ?? b}',
          result: l.tableRowCount(rows.length),
          resultLatex: '\\text{${rows.length}}');
    }
  }

  String _csv(List<TableRow> rows) {
    final settings = ref.read(settingsProvider);
    final l = AppLocalizations.of(context);
    final nf = NumberFormatter(settings.formatOptions().copyWith(thousandsSeparator: false, decimalSeparator: '.'));
    final vf = ValueFormatter(settings.formatOptions().copyWith(thousandsSeparator: false, decimalSeparator: '.'));
    String q(String s) => s.contains(',') || s.contains('"') || s.contains('\n') ? '"${s.replaceAll('"', '""')}"' : s;
    final b = StringBuffer('${q(_v)},${q(_fPlain)}\n');
    for (final r in rows) {
      final y = r.value != null ? vf.format(r.value!).plain : (r.error != null ? errorText(l, r.error!) : '');
      b.write('${q(nf.format(r.x).plain)},${q(y)}\n');
    }
    return b.toString();
  }

  Future<void> _copy() async {
    final rows = _rows;
    if (rows == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ClipboardService.copy(_csv(rows));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.tableCopied)));
  }

  Future<void> _share() async {
    final rows = _rows;
    if (rows == null) return;
    final l = AppLocalizations.of(context);
    try {
      await ClipboardService.share(_csv(rows), subject: l.toolTable);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.tableShareFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasRows = _rows != null && _rows!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.toolTable),
        actions: [
          IconButton(tooltip: l.tableCopyCsv, icon: const Icon(Icons.copy_all), onPressed: hasRows ? _copy : null),
          IconButton(tooltip: l.actionShare, icon: const Icon(Icons.share), onPressed: hasRows ? _share : null),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          final form = _buildForm(l);
          if (c.maxWidth >= 720) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 5, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: form)),
              const VerticalDivider(width: 1),
              Expanded(flex: 6, child: CustomScrollView(slivers: _tableSlivers(l))),
            ]);
          }
          return CustomScrollView(slivers: [
            SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverToBoxAdapter(child: form)),
            ..._tableSlivers(l),
          ]);
        }),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l) {
    final v = cleanVariable(_var.text) ?? 'x';
    final funcs = ref.watch(functionsProvider).where((f) => f.graphType == GraphType.cartesian && !f.isMultiVariable).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: MathInputField(
            key: const ValueKey('table.f'),
            controller: _f,
            label: l.calculusFunctionLabel(v),
            hint: l.tableFunctionHint,
            bound: {v},
            previewPrefix: 'f(${varLatex(v)})=',
            onSubmitted: _compute,
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<SavedFunction>(
          tooltip: l.tableSavedFunctions,
          icon: const Icon(Icons.bookmarks_outlined),
          enabled: funcs.isNotEmpty,
          onSelected: (f) => setState(() {
            _f.text = f.expression;
            _var.text = 'x';
          }),
          itemBuilder: (context) => [
            for (final f in funcs)
              PopupMenuItem(
                value: f,
                child: MathView(
                  '${f.name.isEmpty ? 'y' : '${f.baseName}(x)'}=${exprLatex(f.expression, bound: const {'x'}) ?? f.expression}',
                  fallback: f.expression,
                  semanticsLabel: f.name.isEmpty ? f.expression : '${f.name}(x) = ${f.expression}',
                ),
              ),
          ],
        ),
      ]),
      if (funcs.isEmpty) ...[const SizedBox(height: 4), InfoNote(l.tableNoSavedFunctions)],
      const SizedBox(height: 12),
      FieldRow(minFieldWidth: 100, children: [
        SmallField(key: const ValueKey('table.var'), controller: _var, label: l.calculusVariable),
        SmallField(key: const ValueKey('table.start'), controller: _start, label: l.tableStart, onSubmitted: _compute),
        SmallField(key: const ValueKey('table.end'), controller: _end, label: l.tableEnd, onSubmitted: _compute),
        SmallField(key: const ValueKey('table.step'), controller: _step, label: l.tableStep, onSubmitted: _compute),
      ]),
      const SizedBox(height: 12),
      InfoNote(l.tableAngleNote(ref.watch(settingsProvider).angleMode.name.toUpperCase(), FunctionTable.maxRows)),
      const SizedBox(height: 16),
      ComputeButton(label: l.tableBuild, icon: Icons.table_rows_outlined, onPressed: busy ? null : _compute),
      if (busy) BusyRow(onCancel: cancelRun),
    ]);
  }

  List<Widget> _tableSlivers(AppLocalizations l) {
    const pad = EdgeInsets.symmetric(horizontal: 16);
    if (_error != null) {
      return [SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverToBoxAdapter(child: ErrorPanel(_error!)))];
    }
    final rows = _rows;
    if (rows == null) {
      return [
        SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(child: InfoNote(l.tableEmpty, icon: Icons.table_chart_outlined))),
      ];
    }
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final nf = NumberFormatter(settings.formatOptions());
    final vf = ValueFormatter(settings.formatOptions());
    final vt = varLatex(_v);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Semantics(
            liveRegion: true,
            child: Text(l.tableRowCount(rows.length), style: theme.textTheme.titleSmall),
          ),
        ),
      ),
      SliverPadding(
        padding: pad,
        sliver: SliverToBoxAdapter(
          child: Container(
            color: theme.colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(child: MathView(vt, style: theme.textTheme.titleSmall, semanticsLabel: _v)),
              Expanded(child: MathView('f($vt)', style: theme.textTheme.titleSmall, semanticsLabel: 'f($_v)')),
            ]),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            final x = nf.format(r.x);
            final y = r.value == null ? null : vf.format(r.value!);
            final err = r.error == null ? null : errorText(l, r.error!);
            return Container(
              key: ValueKey('table.row.$i'),
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: i.isOdd ? theme.colorScheme.surfaceContainerLow : null,
                border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
              ),
              child: Semantics(
                label: '$_v = ${x.display}, f = ${y?.display ?? err ?? ''}',
                excludeSemantics: true,
                child: Row(children: [
                  Expanded(child: MathView(x.latex, fallback: x.display)),
                  Expanded(
                    child: y != null
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal, child: MathView(y.latex, fallback: y.display))
                        : Text(err ?? '', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ];
  }
}
