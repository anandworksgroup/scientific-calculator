import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../../app/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/clipboard_service.dart';
import '../../../widgets/math_view.dart';
import '../../../widgets/steps_view.dart';
import '../calculator_controller.dart';
import '../result_presenter.dart';

String resultFormLabel(AppLocalizations l, ResultFormKind k) => switch (k) {
      ResultFormKind.exact => l.calcExactForm,
      ResultFormKind.fraction => l.calcFractionForm,
      ResultFormKind.mixed => l.calcMixedForm,
      ResultFormKind.decimal => l.calcDecimalForm,
      ResultFormKind.scientific => l.calcScientificForm,
      ResultFormKind.engineering => l.calcEngineeringForm,
      ResultFormKind.allDigits => l.calcAllDigits,
      ResultFormKind.value => l.calcResultDetails,
    };

Future<void> showResultDetails(BuildContext context, WidgetRef ref, CalcResult r) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scroll) => _ResultDetails(result: r, scroll: scroll),
    ),
  );
}

class _ResultDetails extends ConsumerWidget {
  const _ResultDetails({required this.result, required this.scroll});
  final CalcResult result;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final presenter = ResultPresenter(settings);
    final e = result.evaluation;
    final forms = presenter.alternatives(e);
    final main = presenter.main(e, ResultView.standard);
    final sol = e.solution;
    final mathStyle = theme.textTheme.titleLarge!;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(l.calcResultDetails, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MathView(result.expressionLatex, style: mathStyle, fallback: result.expressionText),
        ),
        const Divider(height: 24),
        if (sol == null)
          for (final f in forms)
            _FormTile(label: resultFormLabel(l, f.kind), latex: f.latex, plain: f.plain)
        else ...[
          if (sol.alwaysTrue) Text(l.calcAllValues, style: theme.textTheme.titleMedium),
          if (!sol.alwaysTrue && sol.roots.isEmpty && sol.symbolic.isEmpty) Text(l.calcNoSolution, style: theme.textTheme.titleMedium),
          for (var k = 0; k < sol.roots.length; k++)
            _FormTile(
              label: [
                '${sol.variable}${sol.roots.length > 1 ? '${k + 1}' : ''}',
                if (sol.roots[k].multiplicity > 1) l.calcMultiplicity(sol.roots[k].multiplicity),
                if (!sol.roots[k].isReal) l.calcComplexRoot,
                if (!sol.roots[k].isExact) l.calcNumericalSolution,
              ].join(' · '),
              latex: presenter.rootLatex(sol.roots[k]),
              plain: NumberFormatter(settings.formatOptions()).format(sol.roots[k].value).plain,
              secondaryLatex: sol.roots[k].surd != null || sol.roots[k].exact != null
                  ? '\\approx ${NumberFormatter(settings.formatOptions().copyWith(fraction: FractionMode.decimal)).format(sol.roots[k].value, preferDecimal: true).latex}'
                  : null,
            ),
          for (final s in sol.symbolic)
            _FormTile(label: sol.variable, latex: const LatexPrinter().print(symToNode(s)), plain: const TextPrinter().print(symToNode(s))),
          if (sol.searchInterval != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                sol.periodic
                    ? l.calcPeriodicNote
                    : l.calcIntervalNote(sol.searchInterval!.$1.toStringAsFixed(0), sol.searchInterval!.$2.toStringAsFixed(0)),
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (sol.steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            StepsView(steps: sol.steps),
          ],
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.copy_all),
            label: Text(l.calcCopyBoth),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: l.calcShareText(result.expressionText, main.plain)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copiedToClipboard)));
              }
            },
          ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.share),
            label: Text(l.actionShare),
            onPressed: () => ClipboardService.share(l.calcShareText(result.expressionText, main.plain)),
          ),
          if (e.value is NumberValue || e.value is MatrixValue || e.value is VectorValue)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.save_alt),
              label: Text(l.calcStore),
              onPressed: () => _store(context, ref),
            ),
        ]),
      ],
    );
  }

  Future<void> _store(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    const names = ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'];
    final name = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.calcStore),
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in names)
                ActionChip(label: Text(n), onPressed: () => Navigator.pop(context, n)),
            ],
          ),
        ],
      ),
    );
    if (name == null) return;
    await ref.read(variablesProvider.notifier).set(name, result.evaluation.value);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.calcStoredIn(name))));
    }
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({required this.label, required this.latex, required this.plain, this.secondaryLatex});
  final String label;
  final String latex;
  final String plain;
  final String? secondaryLatex;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: MathView(latex, style: theme.textTheme.titleLarge, fallback: plain),
            ),
            if (secondaryLatex != null)
              MathView(secondaryLatex!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
        IconButton(
          tooltip: l.actionCopy,
          icon: const Icon(Icons.copy, size: 20),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: plain));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copiedToClipboard)));
            }
          },
        ),
      ]),
    );
  }
}
