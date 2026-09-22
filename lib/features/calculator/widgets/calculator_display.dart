import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../../app/providers.dart';
import '../../../core/error_text.dart';
import '../../../data/settings/app_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/clipboard_service.dart';
import '../../../themes/app_theme.dart';
import '../../../widgets/math_view.dart';
import '../calculator_controller.dart';
import '../editor/editor_latex.dart';
import '../editor/expression_editor.dart';
import '../keypad/key_specs.dart';
import '../result_presenter.dart';
import 'result_details_sheet.dart';

/// The calculator screen's display: status indicators, the expression in
/// textbook form with a cursor, and the result / preview / error.
class CalculatorDisplay extends ConsumerWidget {
  const CalculatorDisplay({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(calculatorProvider);
    final settings = ref.watch(settingsProvider);
    final vars = ref.watch(variablesProvider);
    final c = CalcColors.of(context);
    final theme = Theme.of(context);

    final sizeFactor = switch (settings.displaySize) {
      DisplaySize.small => 0.85,
      DisplaySize.medium => 1.0,
      DisplaySize.large => 1.2,
    } * settings.fontScale;
    final baseExpr = (compact ? 22.0 : 26.0) * sizeFactor;
    final baseResult = (compact ? 30.0 : 36.0) * sizeFactor;

    final renderer = EditorLatexRenderer(
      cursorColor: colorToHex(c.cursor),
      placeholderColor: colorToHex(c.placeholder),
      showCursor: !s.justEvaluated,
      selectionColor: s.allSelected ? colorToHex(theme.colorScheme.primaryContainer) : null,
    );
    final exprTex = renderer.render(s.tokens, s.cursor);
    final memory = vars[memoryVariable];
    final memorySet = memory is NumberValue && !memory.n.isZero;

    return Material(
      color: c.displayBackground,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          final ctl = ref.read(calculatorProvider.notifier);
          if (v > 200) ctl.perform(const Command(CalcCommand.left));
          if (v < -200) ctl.perform(const Command(CalcCommand.right));
        },
        onLongPress: () => _showEditMenu(context, ref),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, compact ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Indicators(state: s, settings: settings, memorySet: memorySet),
              const SizedBox(height: 4),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                // Shrink text when the display is short (landscape, split screen).
                final needed = baseExpr * 1.7 + baseResult * 1.95 + 8;
                final k = box.maxHeight >= needed ? 1.0 : (box.maxHeight / needed).clamp(0.4, 1.0);
                final exprSize = baseExpr * k, resultSize = baseResult * k;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: Semantics(
                        label: s.isEmpty ? l.calcPlaceholder : ExpressionEditor(s.tokens).toPlainText(),
                        excludeSemantics: true,
                        child: s.isEmpty
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: Row(children: [
                                  if (!s.justEvaluated)
                                    Container(width: 2, height: exprSize, color: c.cursor),
                                  const SizedBox(width: 6),
                                  Text(l.calcPlaceholder,
                                      style: TextStyle(fontSize: exprSize * 0.7, color: c.placeholder)),
                                ]),
                              )
                            : ScrollingMath(
                                exprTex,
                                alignRight: false,
                                style: TextStyle(fontSize: exprSize, color: c.displayForeground),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ResultLine(state: s, fontSize: resultSize),
                  ],
                );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditMenu(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ctl = ref.read(calculatorProvider.notifier);
    final s = ref.read(calculatorProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.select_all), title: Text(l.actionSelectAll), onTap: () => Navigator.pop(context, 'select')),
          ListTile(leading: const Icon(Icons.copy), title: Text(l.calcCopyExpression), onTap: () => Navigator.pop(context, 'copy')),
          ListTile(leading: const Icon(Icons.content_paste), title: Text(l.actionPaste), onTap: () => Navigator.pop(context, 'paste')),
          ListTile(leading: const Icon(Icons.undo), title: Text(l.actionUndo), enabled: s.canUndo, onTap: () => Navigator.pop(context, 'undo')),
          ListTile(leading: const Icon(Icons.redo), title: Text(l.actionRedo), enabled: s.canRedo, onTap: () => Navigator.pop(context, 'redo')),
        ]),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'select':
        ctl.selectAll();
      case 'copy':
        await ClipboardService.copy(ctl.editor.toPlainText());
        if (context.mounted) _snack(context, l.copiedToClipboard);
      case 'paste':
        final text = await ClipboardService.pasteSanitized();
        if (text != null) ctl.insertText(text);
      case 'undo':
        ctl.perform(const Command(CalcCommand.undo));
      case 'redo':
        ctl.perform(const Command(CalcCommand.redo));
    }
  }
}

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

class _Indicators extends StatelessWidget {
  const _Indicators({required this.state, required this.settings, required this.memorySet});
  final CalculatorState state;
  final AppSettings settings;
  final bool memorySet;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = CalcColors.of(context);
    final base = Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6);
    Widget tag(String t, {Color? color, String? semantics}) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Semantics(label: semantics ?? t, child: Text(t, style: base.copyWith(color: color ?? c.displayForeground.withValues(alpha: 0.75)))),
        );
    final angle = switch (settings.angleMode) {
      AngleMode.deg => (l.angleDeg, l.angleDegLong),
      AngleMode.rad => (l.angleRad, l.angleRadLong),
      AngleMode.grad => (l.angleGrad, l.angleGradLong),
    };
    return SizedBox(
      height: 18,
      child: Row(children: [
        if (state.shift) tag(l.indicatorShift, color: c.shiftLabel, semantics: l.keyShift),
        if (state.alpha) tag(l.indicatorAlpha, color: c.alphaLabel, semantics: l.keyAlpha),
        if (state.storePending) tag(l.indicatorStore, color: c.alphaLabel, semantics: l.keyStore),
        if (memorySet) tag(l.indicatorMemory, semantics: l.keyMemoryRecall),
        tag(angle.$1, semantics: angle.$2),
        if (settings.notation == NumberNotation.scientific) tag(l.notationSciShort, semantics: l.notationScientific),
        if (settings.notation == NumberNotation.engineering) tag(l.notationEngShort, semantics: l.notationEngineering),
        if (settings.complexResults) tag('ℂ', semantics: l.settingsComplexResults),
        const Spacer(),
        if (state.calculating) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
    );
  }
}

class _ResultLine extends ConsumerWidget {
  const _ResultLine({required this.state, required this.fontSize});
  final CalculatorState state;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = CalcColors.of(context);
    final settings = ref.watch(settingsProvider);
    final presenter = ResultPresenter(settings);

    if (state.calculating) {
      return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(l.calculating, style: TextStyle(color: c.placeholder)),
        const SizedBox(width: 8),
        TextButton(onPressed: () => ref.read(calculatorProvider.notifier).cancel(), child: Text(l.actionCancel)),
      ]);
    }
    final err = state.error;
    if (err != null) {
      final text = errorText(l, err);
      return Semantics(
        liveRegion: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, size: 18, color: c.error),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: c.error, fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis)),
        ]),
      );
    }
    final r = state.result;
    if (r != null) {
      final shown = presenter.main(r.evaluation, state.view);
      final approx = shown.kind == ResultFormKind.decimal && r.evaluation.exact != null;
      return GestureDetector(
        onTap: () => showResultDetails(context, ref, r),
        onLongPress: () => showResultCopyMenu(context, r, shown.plain),
        child: Semantics(
          liveRegion: true,
          label: shown.plain,
          button: true,
          child: SizedBox(
            height: fontSize * 1.9,
            child: ScrollingMath(
              '${approx ? r'\approx ' : '='}\\;${shown.latex}',
              fallback: shown.plain,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: c.displayForeground),
            ),
          ),
        ),
      );
    }
    final p = state.preview;
    if (p != null) {
      final f = ValueFormatter(settings.formatOptions()).format(p.value, preferDecimal: p.preferDecimal);
      return SizedBox(
        height: fontSize * 1.4,
        child: ScrollingMath(f.latex, fallback: f.plain, style: TextStyle(fontSize: fontSize * 0.7, color: c.placeholder)),
      );
    }
    return SizedBox(height: fontSize * 1.4);
  }
}

Future<void> showResultCopyMenu(BuildContext context, CalcResult r, String resultText) async {
  final l = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.copy), title: Text(l.calcCopyResult), onTap: () => Navigator.pop(context, 0)),
        ListTile(leading: const Icon(Icons.functions), title: Text(l.calcCopyExpression), onTap: () => Navigator.pop(context, 1)),
        ListTile(leading: const Icon(Icons.copy_all), title: Text(l.calcCopyBoth), onTap: () => Navigator.pop(context, 2)),
        ListTile(leading: const Icon(Icons.share), title: Text(l.actionShare), onTap: () => Navigator.pop(context, 3)),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  final both = l.calcShareText(r.expressionText, resultText);
  switch (choice) {
    case 0:
      await Clipboard.setData(ClipboardData(text: resultText));
    case 1:
      await Clipboard.setData(ClipboardData(text: r.expressionText));
    case 2:
      await Clipboard.setData(ClipboardData(text: both));
    case 3:
      await ClipboardService.share(both);
      return;
  }
  if (context.mounted) _snack(context, l.copiedToClipboard);
}
