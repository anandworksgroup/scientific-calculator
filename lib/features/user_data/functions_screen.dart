import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/purchase_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/math_view.dart';
import '../calculator/calculator_controller.dart';
import '../graph/function_editor_sheet.dart';
import '../graph/graph_screen.dart';

/// Saved functions f(x)=…, usable in the calculator and graphs (§92).
class FunctionsScreen extends ConsumerWidget {
  const FunctionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final funcs = ref.watch(functionsProvider);
    final premium = ref.watch(premiumProvider).isPremium;
    final colors = CalcColors.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.functionsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.functionsAdd),
        onPressed: () => showFunctionEditor(context, ref, initialType: GraphType.cartesian),
      ),
      body: funcs.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(l.functionsEmpty, textAlign: TextAlign.center)))
          : ListView(padding: const EdgeInsets.only(bottom: 96), children: [
              if (!premium)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('${funcs.length} / $freeFunctionLimit', style: theme.textTheme.labelMedium),
                ),
              for (final f in funcs)
                ListTile(
                  leading: CircleAvatar(radius: 8, backgroundColor: colors.graphPalette[f.color % colors.graphPalette.length]),
                  title: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: MathView(plotLatex(f.expression, f.graphType, expressionY: f.expressionY, name: f.name),
                        style: theme.textTheme.titleMedium, fallback: f.expression),
                  ),
                  onTap: f.name.isEmpty
                      ? null
                      : () {
                          ref.read(calculatorProvider.notifier).insertFunction(f.baseName);
                          context.go(Routes.calculator);
                        },
                  trailing: PopupMenuButton<String>(
                    tooltip: l.actionMore,
                    onSelected: (v) async {
                      switch (v) {
                        case 'edit':
                          await showFunctionEditor(context, ref, existing: f);
                        case 'plot':
                          await ref.read(functionsProvider.notifier).save(f.copyWith(visible: true));
                          if (context.mounted) context.go(Routes.graph);
                        case 'table':
                          if (context.mounted) context.push('${Routes.table}?f=${Uri.encodeComponent(f.expression)}');
                        case 'delete':
                          await ref.read(functionsProvider.notifier).delete(f.id!);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
                      PopupMenuItem(value: 'plot', child: Text(l.functionsPlot)),
                      if (f.graphType == GraphType.cartesian && !f.isMultiVariable) PopupMenuItem(value: 'table', child: Text(l.functionsTable)),
                      PopupMenuItem(value: 'delete', child: Text(l.actionDelete)),
                    ],
                  ),
                ),
            ]),
    );
  }
}
