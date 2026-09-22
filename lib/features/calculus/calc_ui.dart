import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/settings/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/math_view.dart';
import '../calculator/calculator_controller.dart' show historyListProvider;

/// Shared building blocks for the calculus, statistics, probability and
/// function-table screens.

/// Calculus always works in radians (the engine's symbolic methods do).
CalcSettings radianSettings(CalcSettings s) => s.copyWith(angleMode: AngleMode.rad);

/// Input text as the parser should see it.
String cleanInput(String s) => ClipboardService.sanitize(s);

/// Textbook LaTeX for [src], or null if it does not parse (yet).
String? exprLatex(String src, {Set<String> bound = const {}, Environment? env}) {
  final s = cleanInput(src);
  if (s.isEmpty) return null;
  try {
    return const LatexPrinter().print(Parser.parseExpression(s,
        scope: ParseScope(
          boundVariables: bound,
          variables: env?.variables.keys.toSet() ?? const {},
          userFunctions: env?.functions.keys.toSet() ?? const {},
        )));
  } on MathError {
    return null;
  } catch (_) {
    return null;
  }
}

/// A valid variable name (letters, optionally followed by digits), or null.
String? cleanVariable(String s, {String fallback = 'x'}) {
  final v = s.trim().isEmpty ? fallback : s.trim();
  return RegExp(r'^[A-Za-zα-ωΑ-Ω][A-Za-z0-9_]*$').hasMatch(v) ? v : null;
}

/// LaTeX for a variable name (x, θ, x1 → x_{1}).
String varLatex(String v) {
  try {
    return const LatexPrinter().print(VariableNode(v));
  } catch (_) {
    return v;
  }
}

/// Formats [n] with the user's result format. [decimal] forces a decimal.
FormattedNumber formatNum(AppSettings s, Num n, {bool decimal = false}) =>
    NumberFormatter(decimal ? s.formatOptions(override: ResultFormat.decimal) : s.formatOptions())
        .format(n, preferDecimal: decimal || n is Dec);

bool isNonIntegerRat(Num n) => n is Rat && !n.isInteger;

/// Records a finished calculation in history (respects the history setting).
Future<void> recordHistory(
  WidgetRef ref, {
  required String mode,
  required String expression,
  required String expressionLatex,
  required String result,
  required String resultLatex,
  Value? value,
  bool radians = false,
}) async {
  final settings = ref.read(settingsProvider);
  if (!settings.saveHistory) return;
  final repo = ref.read(historyRepositoryProvider);
  final container = ProviderScope.containerOf(ref.context, listen: false);
  final encodable = value is NumberValue || value is MatrixValue || value is VectorValue || value is ListValue;
  try {
    await repo.insert(
      HistoryEntry(
        expression: expression,
        expressionLatex: expressionLatex,
        result: result,
        resultLatex: resultLatex,
        resultValue: encodable ? ValueCodec.encode(value!) : null,
        mode: mode,
        angleMode: radians ? AngleMode.rad.name : settings.angleMode.name,
        format: settings.resultFormat.name,
        createdAt: DateTime.now(),
      ),
      limit: settings.historyLimit,
    );
    container.invalidate(historyListProvider);
  } catch (e) {
    AppLogger.error('history insert', e);
  }
}

/// Runs engine computations for a screen: one at a time, cancellable,
/// cancelled when the screen closes.
mixin EngineRunner<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  Computation<Object?>? _running;
  void Function()? _cancelRunning;

  bool get busy => _running != null;

  EngineService get engineService => ref.read(engineServiceProvider);

  /// Awaits [c]; returns null if the screen closed or a newer run replaced it.
  Future<EngineResult<T>?> runEngine<T>(Computation<T> c) async {
    _cancelRunning?.call();
    setState(() {
      _running = c;
      _cancelRunning = c.cancel;
    });
    final r = await c.result;
    if (!mounted) return null;
    if (!identical(_running, c)) return null;
    setState(() {
      _running = null;
      _cancelRunning = null;
    });
    return r;
  }

  void cancelRun() => _cancelRunning?.call();

  @override
  void dispose() {
    _cancelRunning?.call();
    super.dispose();
  }
}

/// Text field for math input with a live textbook preview underneath.
class MathInputField extends ConsumerWidget {
  const MathInputField({
    super.key,
    required this.controller,
    required this.label,
    this.bound = const {},
    this.previewPrefix = '',
    this.hint,
    this.onSubmitted,
    this.showPreview = true,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final Set<String> bound;
  final String previewPrefix;
  final String? hint;
  final String? helper;
  final VoidCallback? onSubmitted;
  final bool showPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(environmentProvider);
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: controller,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
      if (showPreview)
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, v, _) {
            final tex = exprLatex(v.text, bound: bound, env: env);
            if (tex == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: ExcludeSemantics(
                child: ScrollingMath('$previewPrefix$tex',
                    alignRight: false, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
              ),
            );
          },
        ),
    ]);
  }
}

/// Short text field for numbers or short expressions (bounds, parameters).
class SmallField extends StatelessWidget {
  const SmallField({super.key, required this.controller, required this.label, this.hint, this.onSubmitted});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true),
      );
}

/// Places form fields in a responsive row (wraps to a column when narrow).
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.children, this.minFieldWidth = 120});
  final List<Widget> children;
  final double minFieldWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final perRow = (c.maxWidth / minFieldWidth).floor().clamp(1, children.length);
        final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

/// Form on the left, results on the right on wide screens (≥ 720 dp);
/// stacked on phones.
class FormResultLayout extends StatelessWidget {
  const FormResultLayout({super.key, required this.form, required this.result});
  final Widget form;
  final Widget result;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 720) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 5, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: form)),
              const VerticalDivider(width: 1),
              Expanded(flex: 6, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: result)),
            ]);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [form, const SizedBox(height: 16), result]),
          );
        }),
      );
}

/// Progress row with a Cancel button.
class BusyRow extends StatelessWidget {
  const BusyRow({super.key, required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(width: 16),
        Expanded(child: Text(l.calculusWorking)),
        TextButton(onPressed: onCancel, child: Text(l.actionCancel)),
      ]),
    );
  }
}

/// Primary action button (full width, 48 dp high).
class ComputeButton extends StatelessWidget {
  const ComputeButton({super.key, required this.label, required this.onPressed, this.icon = Icons.calculate});
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
      );
}

/// Results container announced to screen readers when it changes.
class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );
}

/// Explained error message.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel(this.message, {super.key, this.hint});
  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: cs.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline, color: cs.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(message, style: TextStyle(color: cs.onErrorContainer)),
                if (hint != null) ...[
                  const SizedBox(height: 6),
                  Text(hint!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onErrorContainer)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small informational note (e.g. "calculus uses radians").
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
    ]);
  }
}

/// One labelled result in textbook form with a copy button.
class ResultLine extends StatelessWidget {
  const ResultLine({super.key, this.label, required this.tex, required this.plain, this.large = false, this.copyable = true});
  final String? label;
  final String tex;
  final String plain;
  final bool large;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (label != null) Text(label!, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ScrollingMath(tex,
                alignRight: false,
                fallback: plain,
                semanticsLabel: label == null ? plain : '$label: $plain',
                style: large ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium),
          ]),
        ),
        if (copyable)
          IconButton(
            tooltip: l.actionCopy,
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () async {
              await ClipboardService.copy(plain);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l.copiedToClipboard), duration: const Duration(seconds: 2)));
              }
            },
          ),
      ]),
    );
  }
}

/// A result number line: exact form plus a decimal approximation when useful.
List<Widget> numberResult(AppSettings s, {String? label, required String lhsTex, required Num n, String? exactTex, String? exactPlain}) {
  final f = formatNum(s, n);
  final lines = <Widget>[];
  if (exactTex != null) {
    lines.add(ResultLine(label: label, tex: '$lhsTex$exactTex', plain: exactPlain ?? f.plain, large: true));
    final d = formatNum(s, n, decimal: true);
    lines.add(ResultLine(tex: r'\approx ' + d.latex, plain: d.plain));
  } else {
    lines.add(ResultLine(label: label, tex: '$lhsTex${f.latex}', plain: f.plain, large: true));
    if (isNonIntegerRat(n)) {
      final d = formatNum(s, n, decimal: true);
      if (d.latex != f.latex) lines.add(ResultLine(tex: r'\approx ' + d.latex, plain: d.plain));
    }
  }
  return lines;
}
