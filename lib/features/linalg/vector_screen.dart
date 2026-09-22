import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/app_menu_button.dart';
import 'linalg_common.dart';

enum VectorOp { add, subtract, normA, normB, unit, dot, cross, angle, projection, distance }

extension on VectorOp {
  bool get needsA => this != VectorOp.normB;
  bool get needsB => this != VectorOp.normA && this != VectorOp.unit;

  String label(AppLocalizations l) => switch (this) {
    VectorOp.add => l.vectorOpAdd,
    VectorOp.subtract => l.vectorOpSubtract,
    VectorOp.normA => l.vectorOpNormA,
    VectorOp.normB => l.vectorOpNormB,
    VectorOp.unit => l.vectorOpUnit,
    VectorOp.dot => l.vectorOpDot,
    VectorOp.cross => l.vectorOpCross,
    VectorOp.angle => l.vectorOpAngle,
    VectorOp.projection => l.vectorOpProjection,
    VectorOp.distance => l.vectorOpDistance,
  };
}

/// Maximum number of components in n-D mode.
const vectorMaxDimension = 10;

class _Outcome {
  const _Outcome({this.lines = const [], this.error, this.copyText});
  final List<ResultLine> lines;
  final String? error;
  final String? copyText;
}

/// Vector calculator (URS §27): 2D, 3D and n-D vectors A and B.
class VectorScreen extends ConsumerStatefulWidget {
  const VectorScreen({super.key});

  @override
  ConsumerState<VectorScreen> createState() => _VectorScreenState();
}

class _VectorScreenState extends ConsumerState<VectorScreen> {
  int _dim = 3;
  bool _nd = false;
  final _a = [for (var k = 0; k < vectorMaxDimension; k++) TextEditingController()];
  final _b = [for (var k = 0; k < vectorMaxDimension; k++) TextEditingController()];
  VectorOp _op = VectorOp.dot;
  _Outcome? _outcome;

  @override
  void dispose() {
    for (final c in [..._a, ..._b]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setDimension(int dim, {required bool nd}) => setState(() {
    _dim = dim.clamp(2, vectorMaxDimension);
    _nd = nd;
    _outcome = null;
  });

  /// Validated engine literal of vector [name], or an error message.
  ({String? literal, VectorValue? value, String? error}) _read(
    AppLocalizations l,
    String name,
    List<TextEditingController> ctrls,
    CalcSettings calc,
    Environment env,
  ) {
    final parts = <String>[];
    final nums = <Num>[];
    for (var k = 0; k < _dim; k++) {
      final f = evalNumberField(l, ctrls[k].text, calc, env, notNumberMessage: l.vectorNotNumber);
      if (!f.isOk) return (literal: null, value: null, error: l.vectorComponentError(name, k + 1, f.error!));
      final s = ClipboardService.sanitize(ctrls[k].text);
      parts.add(s.isEmpty ? '0' : '($s)');
      nums.add(f.value!);
    }
    return (literal: '[${parts.join(',')}]', value: VectorValue(nums), error: null);
  }

  void _calculate() {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final settings = ref.read(settingsProvider);
    final calc = settings.calcSettings;
    final env = ref.read(environmentProvider).copy();
    final a = _op.needsA ? _read(l, 'A', _a, calc, env) : null;
    final b = _op.needsB ? _read(l, 'B', _b, calc, env) : null;
    final err = a?.error ?? b?.error;
    if (err != null) {
      setState(() => _outcome = _Outcome(error: err));
      return;
    }
    final la = a?.literal ?? '', lb = b?.literal ?? '';
    final expr = switch (_op) {
      VectorOp.add => '$la+$lb',
      VectorOp.subtract => '$la-$lb',
      VectorOp.normA => 'norm($la)',
      VectorOp.normB => 'norm($lb)',
      VectorOp.unit => 'unit($la)',
      VectorOp.dot => 'dot($la,$lb)',
      VectorOp.cross => 'cross($la,$lb)',
      VectorOp.angle => 'angle($la,$lb)',
      VectorOp.projection => 'proj($la,$lb)',
      VectorOp.distance => 'dist($la,$lb)',
    };
    const va = r'\vec{A}', vb = r'\vec{B}';
    final lhsTex = switch (_op) {
      VectorOp.add => '$va+$vb',
      VectorOp.subtract => '$va-$vb',
      VectorOp.normA => '\\left|$va\\right|',
      VectorOp.normB => '\\left|$vb\\right|',
      VectorOp.unit => r'\hat{A}',
      VectorOp.dot => '$va\\cdot $vb',
      VectorOp.cross => '$va\\times $vb',
      VectorOp.angle => r'\theta',
      VectorOp.projection => '\\mathrm{proj}_{$vb}\\,$va',
      VectorOp.distance => '\\mathrm{d}\\left($va,$vb\\right)',
    };
    final lhsText = switch (_op) {
      VectorOp.add => 'A + B',
      VectorOp.subtract => 'A − B',
      VectorOp.normA => '|A|',
      VectorOp.normB => '|B|',
      VectorOp.unit => 'Â',
      VectorOp.dot => 'A · B',
      VectorOp.cross => 'A × B',
      VectorOp.angle => 'θ',
      VectorOp.projection => 'proj_B A',
      VectorOp.distance => 'd(A, B)',
    };
    final r = EngineService.engine.evaluate(expr, calc, env);
    switch (r) {
      case Success(:final value):
        final v = value.value;
        final f = formatValue(ref, v, preferDecimal: value.preferDecimal);
        final isAngle = _op == VectorOp.angle;
        final unitTex = isAngle ? angleUnitLatex(settings.angleMode) : '';
        final unitText = isAngle ? angleUnitText(settings.angleMode) : '';
        final operands = [
          if (a?.value != null) _operandLine('A', a!.value!),
          if (b?.value != null) _operandLine('B', b!.value!),
        ];
        setState(
          () => _outcome = _Outcome(
            lines: [ResultLine('$lhsTex=${f.latex}$unitTex', '$lhsText = ${f.display}$unitText'), ...operands],
            copyText: '${f.plain}${isAngle ? unitText.trim() : ''}',
          ),
        );
        recordLinalgHistory(
          ref,
          mode: 'vector',
          expression: expr,
          expressionLatex: value.inputLatex,
          result: '${f.display}$unitText',
          resultLatex: '${f.latex}$unitTex',
          value: v,
        );
      case Failure(:final error):
        setState(() => _outcome = _Outcome(error: errorText(l, error)));
      case Cancelled():
        setState(() => _outcome = _Outcome(error: l.errCancelled));
    }
  }

  ResultLine _operandLine(String name, VectorValue v) {
    final f = formatValue(ref, v);
    return ResultLine('\\vec{$name}=${f.latex}', '$name = ${f.display}');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.vectorTitle), actions: const [AppMenuButton()]),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final inputs = _inputs(context, l);
            final ops = _operations(context, l);
            if (c.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: inputs),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: ops),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [inputs, const SizedBox(height: 8), ops],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _inputs(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l.vectorDimension),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 2, label: Text(l.vector2d)),
            ButtonSegment(value: 3, label: Text(l.vector3d)),
            ButtonSegment(value: 0, label: Text(l.vectorNd)),
          ],
          selected: {_nd ? 0 : _dim},
          onSelectionChanged: (s) {
            final v = s.first;
            if (v == 0) {
              _setDimension(_dim < 4 ? 4 : _dim, nd: true);
            } else {
              _setDimension(v, nd: false);
            }
          },
        ),
        if (_nd)
          Row(
            children: [
              Expanded(child: Text(l.vectorComponentCount(_dim))),
              IconButton(
                tooltip: l.vectorFewerComponents,
                icon: const Icon(Icons.remove),
                onPressed: _dim > 2 ? () => _setDimension(_dim - 1, nd: true) : null,
              ),
              IconButton(
                tooltip: l.vectorMoreComponents,
                icon: const Icon(Icons.add),
                onPressed: _dim < vectorMaxDimension ? () => _setDimension(_dim + 1, nd: true) : null,
              ),
            ],
          ),
        SectionTitle(l.vectorA),
        _components(l, 'A', _a),
        SectionTitle(l.vectorB),
        _components(l, 'B', _b),
      ],
    );
  }

  Widget _components(AppLocalizations l, String name, List<TextEditingController> ctrls) {
    const axes = ['x', 'y', 'z'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var k = 0; k < _dim; k++)
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(96).clamp(96.0, 180.0),
            child: Semantics(
              label: l.vectorComponentLabel(name, k + 1),
              child: TextField(
                key: ValueKey('vector-$name-$k'),
                controller: ctrls[k],
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _dim <= 3 ? '$name${axes[k]}' : '$name${k + 1}',
                  hintText: '0',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _operations(BuildContext context, AppLocalizations l) {
    final outcome = _outcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l.vectorOperations),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final op in VectorOp.values)
              ChoiceChip(
                key: ValueKey('vector-op-${op.name}'),
                label: Text(op.label(l)),
                selected: _op == op,
                onSelected: (_) => setState(() {
                  _op = op;
                  _outcome = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('vector-calculate'),
          onPressed: _calculate,
          icon: const Icon(Icons.calculate_outlined),
          label: Text(l.actionCalculate),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (outcome != null) ...[
          const SizedBox(height: 12),
          LinalgResultCard(
            key: const ValueKey('vector-result'),
            title: l.vectorResult,
            lines: outcome.lines,
            error: outcome.error,
            copyText: outcome.copyText,
          ),
        ],
      ],
    );
  }
}
