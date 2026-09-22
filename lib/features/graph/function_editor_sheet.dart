import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/error_text.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/math_view.dart';
import 'graph_screen.dart';

/// Add / edit a plot or saved function (graph function editor).
Future<void> showFunctionEditor(BuildContext context, WidgetRef ref, {SavedFunction? existing, GraphType? initialType}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FunctionEditor(existing: existing, initialType: initialType),
    ),
  );
}

class FunctionEditor extends ConsumerStatefulWidget {
  const FunctionEditor({super.key, this.existing, this.initialType});
  final SavedFunction? existing;
  final GraphType? initialType;

  @override
  ConsumerState<FunctionEditor> createState() => _FunctionEditorState();
}

class _FunctionEditorState extends ConsumerState<FunctionEditor> {
  late GraphType _type = widget.existing?.graphType ?? widget.initialType ?? GraphType.cartesian;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _expr = TextEditingController(text: widget.existing?.expression ?? '');
  late final _exprY = TextEditingController(text: widget.existing?.expressionY ?? '');
  late final _tMin = TextEditingController(text: '${widget.existing?.tMin ?? 0}');
  late final _tMax = TextEditingController(text: widget.existing == null ? '2π' : _num(widget.existing!.tMax));
  late int _color = widget.existing?.color ?? ref.read(functionsProvider).length;
  MathError? _error;

  static String _num(double v) {
    if ((v - 2 * math.pi).abs() < 1e-12) return '2π';
    if ((v - math.pi).abs() < 1e-12) return 'π';
    return v.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _expr.dispose();
    _exprY.dispose();
    _tMin.dispose();
    _tMax.dispose();
    super.dispose();
  }

  double? _evalBound(String s) {
    final r = const DefaultMathEngine().evaluate(s.trim().isEmpty ? '0' : s, const CalcSettings(angleMode: AngleMode.rad), Environment());
    final v = r.valueOrNull?.value;
    if (v is NumberValue && v.n is! Cpx) return v.n.toDouble();
    return null;
  }

  SavedFunction? _build() {
    final expr = ClipboardService.sanitize(_expr.text);
    if (expr.isEmpty) {
      setState(() => _error = const MathError(MathErrorCode.emptyInput));
      return null;
    }
    final name = _type == GraphType.cartesian ? _name.text.trim() : '';
    if (name.isNotEmpty && (!RegExp(r'^[A-Za-z]\w{0,15}$').hasMatch(name) || functionIndex.containsKey(name) || reservedNames.contains(name))) {
      setState(() => _error = MathError(MathErrorCode.invalidAssignment, {'name': name}));
      return null;
    }
    final tMin = _evalBound(_tMin.text), tMax = _evalBound(_tMax.text);
    if ((_type == GraphType.polar || _type == GraphType.parametric) && (tMin == null || tMax == null || !(tMin < tMax))) {
      setState(() => _error = const MathError(MathErrorCode.invalidExpression, {'detail': 'the parameter range is empty'}));
      return null;
    }
    final f = SavedFunction(
      id: widget.existing?.id,
      name: name,
      expression: expr,
      expressionY: _type == GraphType.parametric ? ClipboardService.sanitize(_exprY.text) : '',
      graphType: _type,
      color: _color,
      visible: widget.existing?.visible ?? true,
      tMin: tMin ?? 0,
      tMax: tMax ?? 2 * math.pi,
      sortOrder: widget.existing?.sortOrder ?? 0,
    );
    try {
      CompiledGraph.compile(f.toSpec(), ref.read(environmentProvider));
    } on MathError catch (e) {
      setState(() => _error = e);
      return null;
    }
    return f;
  }

  Future<void> _save() async {
    final f = _build();
    if (f == null) return;
    final ok = await ref.read(functionsProvider.notifier).save(f);
    if (!mounted) return;
    if (!ok) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.functionsLimitReached(freeFunctionLimit)),
        action: SnackBarAction(label: l.premiumTitle, onPressed: () => context.push(Routes.premium)),
      ));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = CalcColors.of(context).graphPalette;
    final previewTex = plotLatex(_expr.text, _type, expressionY: _exprY.text, name: _name.text);
    final paramName = _type == GraphType.polar ? 'θ' : 't';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.existing == null ? l.graphAddFunction : l.actionEdit, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<GraphType>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: GraphType.cartesian, label: Text(l.graphTypeCartesianShort), tooltip: l.graphTypeCartesian),
            ButtonSegment(value: GraphType.polar, label: Text(l.graphTypePolarShort), tooltip: l.graphTypePolar),
            ButtonSegment(value: GraphType.parametric, label: Text(l.graphTypeParametricShort), tooltip: l.graphTypeParametric),
            ButtonSegment(value: GraphType.implicit, label: Text(l.graphTypeImplicitShort), tooltip: l.graphTypeImplicit),
          ],
          selected: {_type},
          onSelectionChanged: (v) => setState(() {
            _type = v.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        if (_type == GraphType.cartesian)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l.graphName, helperText: l.graphNameHelp),
              onChanged: (_) => setState(() {}),
            ),
          ),
        TextField(
          controller: _expr,
          autofocus: widget.existing == null,
          decoration: InputDecoration(
            labelText: switch (_type) {
              GraphType.cartesian => l.graphExpressionCartesian,
              GraphType.polar => l.graphExpressionPolar,
              GraphType.parametric => l.graphExpressionX,
              GraphType.implicit => l.graphExpressionImplicit,
            },
            hintText: switch (_type) {
              GraphType.cartesian => 'x^2 - 3',
              GraphType.polar => '1 + cos(θ)',
              GraphType.parametric => 'cos(3t)',
              GraphType.implicit => 'x^2 + y^2 = 16',
            },
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_type == GraphType.parametric) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _exprY,
            decoration: InputDecoration(labelText: l.graphExpressionY, hintText: 'sin(2t)'),
            onChanged: (_) => setState(() => _error = null),
          ),
        ],
        if (_type == GraphType.polar || _type == GraphType.parametric) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _tMin, decoration: InputDecoration(labelText: l.graphParamMin(paramName)))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _tMax, decoration: InputDecoration(labelText: l.graphParamMax(paramName)))),
          ]),
        ],
        const SizedBox(height: 12),
        if (_expr.text.trim().isNotEmpty)
          Center(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: MathView(previewTex, style: theme.textTheme.titleLarge, fallback: _expr.text))),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(errorText(l, _error!), style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 12),
        Text(l.graphColor, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: [
          for (var k = 0; k < palette.length; k++)
            Semantics(
              selected: _color % palette.length == k,
              button: true,
              label: '${l.graphColor} ${k + 1}',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _color = k),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette[k],
                    shape: BoxShape.circle,
                    border: _color % palette.length == k ? Border.all(color: theme.colorScheme.onSurface, width: 3) : null,
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
          const SizedBox(width: 8),
          FilledButton(onPressed: _save, child: Text(l.actionSave)),
        ]),
      ]),
    );
  }
}
