import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../data/repositories/history_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/math_view.dart';
import '../calculator/calculator_controller.dart' show historyListProvider;

/// Runs an engine task and returns a cancellable [Computation].
///
/// Screens default to [EngineService.run] (a background isolate); tests can
/// inject [runSynchronously].
typedef LinalgRunner = Computation<T> Function<T>(EngineResult<T> Function() task);

/// Runs [task] on the calling thread (tests and trivially small work).
Computation<T> runSynchronously<T>(EngineResult<T> Function() task) => Computation<T>(Future.value(task()), () {});

/// Evaluates [expression] (top-level so it can run in an isolate).
EngineResult<Evaluation> evaluateTask(String expression, CalcSettings settings, Environment env) =>
    EngineService.engine.evaluate(expression, settings, env);

/// Starts [evaluateTask] on [runner]. Kept top-level so the closure sent to
/// the isolate only captures its plain-data arguments.
Computation<Evaluation> spawnEvaluation(
  LinalgRunner runner,
  String expression,
  CalcSettings settings,
  Environment env,
) => runner(() => evaluateTask(expression, settings, env));

/// Evaluation budget for a single cell or component while typing.
const _fieldBudget = Duration(milliseconds: 150);

/// Outcome of evaluating a single input field.
class FieldValue {
  const FieldValue.ok(this.value) : error = null;
  const FieldValue.fail(this.error) : value = null;
  final Num? value;
  final String? error;
  bool get isOk => value != null;
}

/// Evaluates one text field to a single number. Empty text counts as 0
/// when [emptyIsZero] is set.
FieldValue evalNumberField(
  AppLocalizations l,
  String text,
  CalcSettings settings,
  Environment env, {
  required String notNumberMessage,
  bool emptyIsZero = true,
  bool realOnly = false,
}) {
  final src = ClipboardService.sanitize(text);
  if (src.isEmpty) {
    if (emptyIsZero) return FieldValue.ok(Rat.zero);
    return FieldValue.fail(l.fieldRequired);
  }
  final r = EngineService.engine.evaluate(src, settings, env, budget: Budget(timeLimit: _fieldBudget));
  switch (r) {
    case Success(:final value):
      final v = value.value;
      if (v is NumberValue) {
        if (realOnly && v.n is Cpx) return FieldValue.fail(notNumberMessage);
        return FieldValue.ok(v.n);
      }
      return FieldValue.fail(notNumberMessage);
    case Failure(:final error):
      return FieldValue.fail(errorText(l, error));
    case Cancelled():
      return FieldValue.fail(l.errCancelled);
  }
}

/// Engine-syntax text of a number (re-parseable, exact fractions kept).
String numberSource(Num n, int precision) {
  final f = NumberFormatter(FormatOptions(digits: precision, fraction: FractionMode.fraction)).format(n).plain;
  return f;
}

/// LaTeX superscript for the angle unit of [mode].
String angleUnitLatex(AngleMode mode) => switch (mode) {
  AngleMode.deg => r'^{\circ}',
  AngleMode.rad => r'\ \mathrm{rad}',
  AngleMode.grad => r'^{g}',
};

String angleUnitText(AngleMode mode) => switch (mode) {
  AngleMode.deg => '°',
  AngleMode.rad => ' rad',
  AngleMode.grad => 'ᵍ',
};

String angleUnitName(AppLocalizations l, AngleMode mode) => switch (mode) {
  AngleMode.deg => l.angleDegLong,
  AngleMode.rad => l.angleRadLong,
  AngleMode.grad => l.angleGradLong,
};

/// Records a finished calculation in the history.
Future<void> recordLinalgHistory(
  WidgetRef ref, {
  required String mode,
  required String expression,
  required String expressionLatex,
  required String result,
  required String resultLatex,
  Value? value,
}) async {
  final settings = ref.read(settingsProvider);
  final encodable = value is NumberValue || value is MatrixValue || value is VectorValue || value is ListValue;
  try {
    await ref
        .read(historyRepositoryProvider)
        .insert(
          HistoryEntry(
            expression: expression,
            expressionLatex: expressionLatex,
            result: result,
            resultLatex: resultLatex,
            resultValue: encodable ? ValueCodec.encode(value!) : null,
            mode: mode,
            angleMode: settings.angleMode.name,
            format: settings.resultFormat.name,
            createdAt: DateTime.now(),
          ),
          limit: settings.historyLimit,
        );
    ref.invalidate(historyListProvider);
  } on Object {
    // History is best-effort: a storage failure must not hide the result.
  }
}

/// One line of textbook output.
class ResultLine {
  const ResultLine(this.latex, this.semantics, {this.copyText});
  final String latex;

  /// Spoken/plain description, also used by tests.
  final String semantics;
  final String? copyText;
}

/// Card showing results in textbook form, announced to screen readers.
class LinalgResultCard extends StatelessWidget {
  const LinalgResultCard({
    super.key,
    required this.title,
    required this.lines,
    this.actions = const [],
    this.error,
    this.copyText,
  });

  final String title;
  final List<ResultLine> lines;
  final List<Widget> actions;
  final String? error;
  final String? copyText;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final err = error;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                  if (err == null && copyText != null)
                    IconButton(
                      tooltip: l.actionCopy,
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () async {
                        await ClipboardService.copy(copyText!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copiedToClipboard)));
                        }
                      },
                    ),
                  ...actions,
                ],
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(err, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                )
              else
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 6, bottom: 2),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: MathView(
                        line.latex,
                        semanticsLabel: line.semantics,
                        fallback: line.semantics,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress indicator with a Cancel button for isolate work.
class BusyIndicator extends StatelessWidget {
  const BusyIndicator({super.key, required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 16),
            Expanded(child: Text(l.calculating)),
            TextButton(onPressed: onCancel, child: Text(l.actionCancel)),
          ],
        ),
      ),
    );
  }
}

/// Section heading used by the linear-algebra screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}

/// Formats [v] with the user's settings.
FormattedNumber formatValue(WidgetRef ref, Value v, {bool preferDecimal = false, ComplexFormat? complexFormat}) {
  var o = ref.read(settingsProvider).formatOptions();
  if (complexFormat != null) o = o.copyWith(complexFormat: complexFormat);
  return ValueFormatter(o).format(v, preferDecimal: preferDecimal);
}
