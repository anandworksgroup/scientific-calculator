import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../themes/app_theme.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/math_view.dart';
import 'function_editor_sheet.dart';
import 'graph_controller.dart';
import 'graph_view.dart';

String _fmt(double v) {
  if (!v.isFinite) return v.isNaN ? '—' : (v > 0 ? '∞' : '−∞');
  final d = Dec.fromDouble(v);
  return const NumberFormatter(FormatOptions(digits: 8, fraction: FractionMode.decimal)).format(d, preferDecimal: true).display;
}

/// LaTeX for a saved plot definition.
String plotLatex(String expression, GraphType type, {String expressionY = '', String name = ''}) {
  String tex(String s) {
    try {
      final src = s.contains('=') ? s.substring(s.indexOf('=') + 1) : s;
      return const LatexPrinter().print(Parser.parseExpression(src.replaceAll('theta', 'θ'),
          scope: const ParseScope(boundVariables: {'x', 'y', 't', 'θ'})));
    } on MathError {
      return s.replaceAll('\\', '');
    }
  }

  switch (type) {
    case GraphType.cartesian:
      return '${name.isEmpty ? 'y' : '${name.split('(').first}(x)'}=${tex(expression)}';
    case GraphType.polar:
      return 'r=${tex(expression)}';
    case GraphType.parametric:
      return 'x=${tex(expression)},\\;y=${tex(expressionY)}';
    case GraphType.implicit:
      try {
        return const LatexPrinter().print(Parser.parse(expression, scope: const ParseScope(boundVariables: {'x', 'y'})));
      } on MathError {
        return expression;
      }
  }
}

class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key});

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  bool _listOpen = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navGraph),
        actions: [
          IconButton(tooltip: l.graphAddFunction, icon: const Icon(Icons.add), onPressed: () => showFunctionEditor(context, ref)),
          IconButton(tooltip: l.graphWindow, icon: const Icon(Icons.crop_free), onPressed: () => _windowDialog(context)),
          IconButton(tooltip: l.settingsGraph, icon: const Icon(Icons.tune), onPressed: () => context.push(Routes.settingsGraph)),
          const AppMenuButton(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          final side = c.maxWidth >= 720;
          final canvas = Stack(children: [
            const Positioned.fill(child: GraphView()),
            const Positioned(right: 8, top: 8, child: _Controls()),
            const Positioned(left: 8, right: 64, top: 8, child: _TraceCard()),
            const Positioned(left: 8, right: 8, bottom: 8, child: _AnalysisBar()),
          ]);
          if (side) {
            return Row(children: [
              const SizedBox(width: 320, child: _FunctionList()),
              const VerticalDivider(width: 1),
              Expanded(child: ClipRect(child: canvas)),
            ]);
          }
          return Column(children: [
            Expanded(child: ClipRect(child: canvas)),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: InkWell(
                onTap: () => setState(() => _listOpen = !_listOpen),
                child: SizedBox(
                  height: 36,
                  child: Row(children: [
                    const SizedBox(width: 16),
                    Text(l.graphFunctions, style: Theme.of(context).textTheme.labelLarge),
                    const Spacer(),
                    Icon(_listOpen ? Icons.expand_more : Icons.expand_less),
                    const SizedBox(width: 16),
                  ]),
                ),
              ),
            ),
            if (_listOpen) SizedBox(height: (c.maxHeight * 0.33).clamp(120.0, 280.0), child: const _FunctionList()),
          ]);
        }),
      ),
    );
  }

  Future<void> _windowDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final w = ref.read(graphProvider).window;
    final ctrls = [w.xMin, w.xMax, w.yMin, w.yMax].map((v) => TextEditingController(text: _fmt(v).replaceAll('−', '-'))).toList();
    final labels = [l.graphXMin, l.graphXMax, l.graphYMin, l.graphYMax];
    String? error;
    final result = await showDialog<GraphWindow>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) {
        return AlertDialog(
          title: Text(l.graphWindow),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var k = 0; k < 4; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: ctrls[k],
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  decoration: InputDecoration(labelText: labels[k]),
                ),
              ),
            if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
            FilledButton(
              onPressed: () {
                final v = ctrls.map((c) => double.tryParse(c.text.trim().replaceAll('−', '-'))).toList();
                if (v.any((e) => e == null || !e.isFinite) || !(v[0]! < v[1]!) || !(v[2]! < v[3]!)) {
                  setLocal(() => error = l.graphInvalidWindow);
                  return;
                }
                Navigator.pop(context, GraphWindow(v[0]!, v[1]!, v[2]!, v[3]!));
              },
              child: Text(l.actionOk),
            ),
          ],
        );
      }),
    );
    for (final c in ctrls) {
      c.dispose();
    }
    if (result != null) ref.read(graphProvider.notifier).setWindow(result);
  }
}

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final g = ref.watch(graphProvider);
    final ctl = ref.read(graphProvider.notifier);
    Widget btn(IconData icon, String tip, VoidCallback onTap, {bool selected = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: IconButton.filledTonal(
            isSelected: selected,
            tooltip: tip,
            icon: Icon(icon),
            onPressed: onTap,
          ),
        );
    return Column(children: [
      btn(Icons.add, l.graphZoomIn, () => ctl.zoomCenter(1.5)),
      btn(Icons.remove, l.graphZoomOut, () => ctl.zoomCenter(1 / 1.5)),
      btn(Icons.center_focus_strong_outlined, l.graphReset, () {
        final size = MediaQuery.sizeOf(context);
        ctl.reset(size.width, size.height * 0.6);
      }),
      btn(Icons.fit_screen_outlined, l.graphAutoFit, () => ctl.autoFit(ref.read(compiledPlotsProvider))),
      btn(Icons.ads_click, l.graphTrace, () => _ensureSelected(ref, () => ctl.setTool(GraphTool.trace)), selected: g.tool == GraphTool.trace),
      btn(Icons.show_chart, l.graphTangent, () => _ensureSelected(ref, () => ctl.setTool(GraphTool.tangent)), selected: g.tool == GraphTool.tangent),
      btn(Icons.query_stats, l.graphAnalyze, () => _analyze(context, ref)),
    ]);
  }
}

/// Picks the first visible y = f(x) function if none is selected.
void _ensureSelected(WidgetRef ref, VoidCallback then) {
  final g = ref.read(graphProvider);
  final plots = ref.read(compiledPlotsProvider);
  if (g.selectedId == null || !plots.any((p) => p.function.id == g.selectedId)) {
    final first = plots.where((p) => p.function.visible && p.graph != null && p.function.graphType == GraphType.cartesian).firstOrNull;
    if (first != null) ref.read(graphProvider.notifier).select(first.function.id);
  }
  then();
}

Future<void> _analyze(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  _ensureSelected(ref, () {});
  final g = ref.read(graphProvider);
  final plots = ref.read(compiledPlotsProvider);
  final sel = plots.where((p) => p.function.id == g.selectedId && p.graph != null).firstOrNull;
  final messenger = ScaffoldMessenger.of(context);
  if (sel == null || sel.function.graphType != GraphType.cartesian) {
    messenger.showSnackBar(SnackBar(content: Text(l.graphOnlyCartesian)));
    return;
  }
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.adjust), title: Text(l.graphRoots), onTap: () => Navigator.pop(context, 'roots')),
        ListTile(leading: const Icon(Icons.expand), title: Text(l.graphExtrema), onTap: () => Navigator.pop(context, 'extrema')),
        ListTile(leading: const Icon(Icons.join_inner), title: Text(l.graphIntersections), onTap: () => Navigator.pop(context, 'intersect')),
        ListTile(leading: const Icon(Icons.vertical_align_center), title: Text(l.graphYIntercept), onTap: () => Navigator.pop(context, 'yint')),
        ListTile(leading: const Icon(Icons.area_chart_outlined), title: Text(l.graphArea), onTap: () => Navigator.pop(context, 'area')),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  final f = sel.graph!.f!;
  final w = g.window;
  final ctl = ref.read(graphProvider.notifier);
  final id = sel.function.id!;
  switch (choice) {
    case 'roots':
      ctl.setAnalysis(AnalysisResult(functionId: id, points: GraphAnalysis.roots(f, w.xMin, w.xMax)));
    case 'extrema':
      ctl.setAnalysis(AnalysisResult(functionId: id, points: GraphAnalysis.extrema(f, w.xMin, w.xMax)));
    case 'yint':
      final p = GraphAnalysis.yIntercept(f);
      ctl.setAnalysis(AnalysisResult(functionId: id, points: [if (p != null) p]));
    case 'intersect':
      final others = plots.where((p) => p.function.id != id && p.graph != null && p.function.graphType == GraphType.cartesian && p.function.visible).toList();
      if (others.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l.graphNeedTwo)));
        return;
      }
      var other = others.first;
      if (others.length > 1) {
        final picked = await showDialog<CompiledPlot>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l.graphSecondFunction),
            children: [
              for (final o in others)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, o),
                  child: MathView(plotLatex(o.function.expression, o.function.graphType, name: o.function.name)),
                ),
            ],
          ),
        );
        if (picked == null) return;
        other = picked;
      }
      ctl.setAnalysis(AnalysisResult(functionId: id, points: GraphAnalysis.intersections(f, other.graph!.f!, w.xMin, w.xMax)));
    case 'area':
      if (!context.mounted) return;
      final range = await _areaDialog(context, w);
      if (range == null) return;
      final (value, _) = GraphAnalysis.area(f, range.$1, range.$2);
      ctl.setAnalysis(AnalysisResult(functionId: id, points: const [], area: value, areaRange: range));
  }
  final a = ref.read(graphProvider).analysis;
  if (a != null && a.points.isEmpty && a.area == null) {
    messenger.showSnackBar(SnackBar(content: Text(l.graphNoPoints)));
  }
}

Future<(double, double)?> _areaDialog(BuildContext context, GraphWindow w) async {
  final l = AppLocalizations.of(context);
  final a = TextEditingController(text: _fmt(w.xMin + w.width * 0.25).replaceAll('−', '-'));
  final b = TextEditingController(text: _fmt(w.xMin + w.width * 0.75).replaceAll('−', '-'));
  String? error;
  final r = await showDialog<(double, double)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(l.graphArea),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: a, keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true), decoration: InputDecoration(labelText: l.graphAreaFrom)),
          const SizedBox(height: 8),
          TextField(controller: b, keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true), decoration: InputDecoration(labelText: l.graphAreaTo)),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
          FilledButton(
            onPressed: () {
              final x1 = double.tryParse(a.text.trim()), x2 = double.tryParse(b.text.trim());
              if (x1 == null || x2 == null || !(x1 < x2)) {
                setLocal(() => error = l.graphInvalidWindow);
                return;
              }
              Navigator.pop(context, (x1, x2));
            },
            child: Text(l.actionCalculate),
          ),
        ],
      ),
    ),
  );
  a.dispose();
  b.dispose();
  return r;
}

class _TraceCard extends ConsumerWidget {
  const _TraceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final g = ref.watch(graphProvider);
    if (g.tool == GraphTool.none || g.traceX == null) return const SizedBox.shrink();
    final sel = ref.watch(compiledPlotsProvider).where((p) => p.function.id == g.selectedId && p.graph?.f != null).firstOrNull;
    if (sel == null || sel.function.graphType != GraphType.cartesian) return const SizedBox.shrink();
    final f = sel.graph!.f!;
    final x = g.traceX!;
    final y = f(x);
    final slope = y.isFinite ? GraphAnalysis.derivative(f, x) : double.nan;
    final theme = Theme.of(context);
    final lines = <String>[
      'x = ${_fmt(x)}',
      'y = ${_fmt(y)}',
      '${l.graphSlope} = ${_fmt(slope)}',
      if (g.tool == GraphTool.tangent && y.isFinite && slope.isFinite)
        l.graphTangentEquation('y = ${_fmt(slope)}x ${y - slope * x < 0 ? '−' : '+'} ${_fmt((y - slope * x).abs())}'),
    ];
    return Align(
      alignment: Alignment.topLeft,
      child: Semantics(
        liveRegion: true,
        child: Card(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              for (final t in lines) Text(t, style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AnalysisBar extends ConsumerWidget {
  const _AnalysisBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final a = ref.watch(graphProvider).analysis;
    if (a == null) return const SizedBox.shrink();
    final chips = <String>[
      if (a.area != null) l.graphAreaResult(_fmt(a.area!)),
      for (final p in a.points)
        '${switch (p.kind) {
          PointKind.root => l.graphRoot,
          PointKind.minimum => l.graphMinimum,
          PointKind.maximum => l.graphMaximum,
          PointKind.intersection => l.graphIntersection,
          PointKind.yIntercept => l.graphYIntercept,
        }} (${_fmt(p.x)}, ${_fmt(p.y)})',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in chips) Padding(padding: const EdgeInsets.only(right: 6), child: Chip(label: Text(c))),
                ],
              ),
            ),
          ),
          IconButton(tooltip: l.actionClose, icon: const Icon(Icons.close), onPressed: () => ref.read(graphProvider.notifier).clearAnalysis()),
        ]),
      ),
    );
  }
}

class _FunctionList extends ConsumerWidget {
  const _FunctionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final plots = ref.watch(compiledPlotsProvider);
    final g = ref.watch(graphProvider);
    final colors = CalcColors.of(context);
    final theme = Theme.of(context);
    if (plots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.graphNoFunctions, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton.icon(icon: const Icon(Icons.add), label: Text(l.graphAddFunction), onPressed: () => showFunctionEditor(context, ref)),
          ]),
        ),
      );
    }
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: plots.length,
      onReorder: (a, b) => ref.read(functionsProvider.notifier).reorder(a, b),
      footer: Padding(
        padding: const EdgeInsets.all(8),
        child: OutlinedButton.icon(icon: const Icon(Icons.add), label: Text(l.graphAddFunction), onPressed: () => showFunctionEditor(context, ref)),
      ),
      itemBuilder: (context, i) {
        final p = plots[i];
        final f = p.function;
        final color = colors.graphPalette[f.color % colors.graphPalette.length];
        final selected = g.selectedId == f.id;
        return Material(
          key: ValueKey(f.id),
          color: selected ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.5) : Colors.transparent,
          child: ListTile(
            dense: true,
            onTap: () => ref.read(graphProvider.notifier).select(selected ? null : f.id),
            leading: Checkbox(
              value: f.visible,
              activeColor: color,
              side: BorderSide(color: color, width: 2),
              semanticLabel: f.visible ? l.graphHide : l.graphShow,
              onChanged: (v) => ref.read(functionsProvider.notifier).save(f.copyWith(visible: v ?? true)),
            ),
            title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: MathView(plotLatex(f.expression, f.graphType, expressionY: f.expressionY, name: f.name),
                  style: theme.textTheme.titleMedium?.copyWith(color: color), fallback: f.expression),
            ),
            subtitle: p.error != null
                ? Text(errorText(l, p.error!), style: TextStyle(color: theme.colorScheme.error), maxLines: 2)
                : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              PopupMenuButton<String>(
                tooltip: l.actionMore,
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      await showFunctionEditor(context, ref, existing: f);
                    case 'table':
                      if (context.mounted) context.push('${Routes.table}?f=${Uri.encodeComponent(f.expression)}');
                    case 'delete':
                      await ref.read(functionsProvider.notifier).delete(f.id!);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
                  if (f.graphType == GraphType.cartesian) PopupMenuItem(value: 'table', child: Text(l.functionsTable)),
                  PopupMenuItem(value: 'delete', child: Text(l.actionDelete)),
                ],
              ),
              ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
            ]),
          ),
        );
      },
    );
  }
}
