import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../widgets/math_view.dart';
import '../calculator/calculator_controller.dart';

/// Stored variables: A–F, X, Y, M, Ans and named variables (§55).
class VariablesScreen extends ConsumerWidget {
  const VariablesScreen({super.key});

  static const _order = ['Ans', 'PreAns', 'A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final vars = ref.watch(variablesProvider);
    final settings = ref.watch(settingsProvider);
    final names = vars.keys.toList()
      ..sort((a, b) {
        final ia = _order.indexOf(a), ib = _order.indexOf(b);
        if (ia >= 0 || ib >= 0) return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
        return a.compareTo(b);
      });
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.variablesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.variablesAdd),
        onPressed: () => editVariable(context, ref),
      ),
      body: names.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(l.variablesEmpty, textAlign: TextAlign.center)))
          : ListView(padding: const EdgeInsets.only(bottom: 96), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(l.variablesAnsNote, style: theme.textTheme.bodySmall),
              ),
              for (final n in names)
                ListTile(
                  title: Text(n, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: MathView(ValueFormatter(settings.formatOptions()).format(vars[n]!).latex, style: theme.textTheme.titleMedium),
                  ),
                  onTap: () {
                    ref.read(calculatorProvider.notifier).insertAtom(n);
                    context.go(Routes.calculator);
                  },
                  trailing: PopupMenuButton<String>(
                    tooltip: l.actionMore,
                    onSelected: (v) async {
                      switch (v) {
                        case 'edit':
                          await editVariable(context, ref, name: n);
                        case 'copy':
                          await ClipboardService.copy(ValueFormatter(settings.formatOptions()).format(vars[n]!).plain);
                        case 'delete':
                          await ref.read(variablesProvider.notifier).remove(n);
                      }
                    },
                    itemBuilder: (context) => [
                      if (n != 'Ans' && n != 'PreAns') PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
                      PopupMenuItem(value: 'copy', child: Text(l.actionCopy)),
                      PopupMenuItem(value: 'delete', child: Text(l.actionDelete)),
                    ],
                  ),
                ),
            ]),
    );
  }
}

/// Creates or edits a variable; the value may be any expression.
Future<void> editVariable(BuildContext context, WidgetRef ref, {String? name}) async {
  final l = AppLocalizations.of(context);
  final nameCtl = TextEditingController(text: name ?? '');
  final settings = ref.read(settingsProvider);
  final current = name == null ? null : ref.read(variablesProvider)[name];
  final valueCtl = TextEditingController(text: current == null ? '' : ValueFormatter(settings.formatOptions().copyWith(fraction: FractionMode.fraction)).format(current).plain);
  String? error;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setLocal) {
      Future<void> save() async {
        final n = nameCtl.text.trim();
        if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,31}$').hasMatch(n)) {
          setLocal(() => error = l.variablesInvalidName);
          return;
        }
        if (reservedNames.contains(n) || functionIndex.containsKey(n) || builtinConstantNames.contains(n)) {
          setLocal(() => error = l.variablesReserved);
          return;
        }
        final r = const DefaultMathEngine().evaluate(ClipboardService.sanitize(valueCtl.text), settings.calcSettings, ref.read(environmentProvider));
        switch (r) {
          case Success(:final value):
            final v = value.value;
            if (v is BoolValue || v is SolutionsValue || v is FactorizationValue) {
              setLocal(() => error = l.invalidNumber);
              return;
            }
            if (name != null && name != n) await ref.read(variablesProvider.notifier).remove(name);
            await ref.read(variablesProvider.notifier).set(n, v);
            if (context.mounted) Navigator.pop(context);
          case Failure(error: final e):
            setLocal(() => error = errorText(l, e));
          case Cancelled():
            break;
        }
      }

      return AlertDialog(
        title: Text(name == null ? l.variablesAdd : l.actionEdit),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtl, decoration: InputDecoration(labelText: l.variablesName), autofocus: name == null),
          const SizedBox(height: 8),
          TextField(controller: valueCtl, decoration: InputDecoration(labelText: l.variablesValue, hintText: '5, 1/3, sqrt(2), [[1,2],[3,4]]')),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
          FilledButton(onPressed: save, child: Text(l.actionSave)),
        ],
      );
    }),
  );
  nameCtl.dispose();
  valueCtl.dispose();
}
