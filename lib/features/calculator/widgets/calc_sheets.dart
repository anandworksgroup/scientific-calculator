import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../data/settings/app_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/math_view.dart';
import '../calculator_controller.dart';

/// Localized category names for the function catalog.
String functionCategoryName(AppLocalizations l, FunctionCategory c) => switch (c) {
      FunctionCategory.arithmetic => l.catArithmetic,
      FunctionCategory.powers => l.catPowers,
      FunctionCategory.logarithms => l.catLogarithms,
      FunctionCategory.trigonometry => l.catTrigonometry,
      FunctionCategory.hyperbolic => l.catHyperbolic,
      FunctionCategory.rounding => l.catRounding,
      FunctionCategory.numberTheory => l.catNumberTheory,
      FunctionCategory.probability => l.catProbability,
      FunctionCategory.statistics => l.catStatistics,
      FunctionCategory.complex => l.catComplex,
      FunctionCategory.matrix => l.catMatrix,
      FunctionCategory.vector => l.catVector,
      FunctionCategory.calculus => l.catCalculus,
      FunctionCategory.random => l.catRandom,
    };

/// Mode & setup menu opened from the ⋯ key.
Future<void> showCalculatorMenu(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => const _CalcMenu(),
  );
}

class _CalcMenu extends ConsumerWidget {
  const _CalcMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(t, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.calcModeMenu, style: theme.textTheme.titleMedium),
        header(l.settingsAngleUnit),
        SegmentedButton<AngleMode>(
          segments: [
            ButtonSegment(value: AngleMode.deg, label: Text(l.angleDeg), tooltip: l.angleDegLong),
            ButtonSegment(value: AngleMode.rad, label: Text(l.angleRad), tooltip: l.angleRadLong),
            ButtonSegment(value: AngleMode.grad, label: Text(l.angleGrad), tooltip: l.angleGradLong),
          ],
          selected: {s.angleMode},
          onSelectionChanged: (v) => set.update((x) => x.copyWith(angleMode: v.first)),
        ),
        header(l.settingsNumberFormat),
        SegmentedButton<NumberNotation>(
          segments: [
            ButtonSegment(value: NumberNotation.normal, label: Text(l.notationNormal)),
            ButtonSegment(value: NumberNotation.scientific, label: Text(l.notationSciShort), tooltip: l.notationScientific),
            ButtonSegment(value: NumberNotation.engineering, label: Text(l.notationEngShort), tooltip: l.notationEngineering),
          ],
          selected: {s.notation},
          onSelectionChanged: (v) => set.update((x) => x.copyWith(notation: v.first)),
        ),
        header(l.settingsResultFormat),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in ResultFormat.values)
            ChoiceChip(
              label: Text(switch (f) {
                ResultFormat.auto => l.formatAuto,
                ResultFormat.decimal => l.formatDecimal,
                ResultFormat.fraction => l.formatFraction,
                ResultFormat.mixed => l.formatMixed,
                ResultFormat.exact => l.formatExact,
              }),
              selected: s.resultFormat == f,
              onSelected: (_) => set.update((x) => x.copyWith(resultFormat: f)),
            ),
        ]),
        header(l.settingsPrecision),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in AppSettings.precisionChoices)
            ChoiceChip(
              label: Text('$p'),
              tooltip: l.settingsPrecisionDigits(p),
              selected: s.precision == p,
              onSelected: (_) => set.update((x) => x.copyWith(precision: p)),
            ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.settingsComplexResults),
          subtitle: Text(l.settingsComplexResultsSub),
          value: s.complexResults,
          onChanged: (v) => set.update((x) => x.copyWith(complexResults: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.settingsKeyboard),
          subtitle: Text(s.keyboardLayout == KeyboardLayout.scientific ? l.settingsKeyboardScientific : l.settingsKeyboardBasic),
          value: s.keyboardLayout == KeyboardLayout.scientific,
          onChanged: (v) => set.update((x) => x.copyWith(keyboardLayout: v ? KeyboardLayout.scientific : KeyboardLayout.basic)),
        ),
        const Divider(),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(
            avatar: const Icon(Icons.functions, size: 18),
            label: Text(l.calcFunctionCatalog),
            onPressed: () {
              Navigator.pop(context);
              showFunctionCatalog(context, ref);
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.science_outlined, size: 18),
            label: Text(l.calcConstants),
            onPressed: () {
              Navigator.pop(context);
              showConstantPicker(context, ref);
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.data_object, size: 18),
            label: Text(l.variablesTitle),
            onPressed: () {
              Navigator.pop(context);
              context.push(Routes.variables);
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.show_chart, size: 18),
            label: Text(l.functionsTitle),
            onPressed: () {
              Navigator.pop(context);
              context.push(Routes.functions);
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.settings_outlined, size: 18),
            label: Text(l.settingsTitle),
            onPressed: () {
              Navigator.pop(context);
              context.push(Routes.settings);
            },
          ),
        ]),
      ]),
    );
  }
}

/// Searchable catalog of all built-in functions (§91).
Future<void> showFunctionCatalog(BuildContext context, WidgetRef ref) async {
  final spec = await showModalBottomSheet<FunctionSpec>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scroll) => _Catalog(scroll: scroll),
    ),
  );
  if (spec != null) ref.read(calculatorProvider.notifier).insertFunction(spec.name);
}

class _Catalog extends StatefulWidget {
  const _Catalog({required this.scroll});
  final ScrollController scroll;

  @override
  State<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<_Catalog> {
  String _q = '';
  FunctionCategory? _cat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = _q.toLowerCase();
    final items = builtinFunctions.where((f) {
      if (_cat != null && f.category != _cat) return false;
      if (q.isEmpty) return true;
      return f.name.toLowerCase().contains(q) ||
          f.spokenName.toLowerCase().contains(q) ||
          f.description.toLowerCase().contains(q) ||
          functionCategoryName(l, f.category).toLowerCase().contains(q);
    }).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          autofocus: false,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.calcCatalogSearch),
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(label: Text(l.toolsAll), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
            ),
            for (final c in FunctionCategory.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(functionCategoryName(l, c)),
                  selected: _cat == c,
                  onSelected: (_) => setState(() => _cat = c),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: items.isEmpty
            ? Center(child: Text(l.searchNoResults))
            : ListView.builder(
                controller: widget.scroll,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final f = items[i];
                  return ListTile(
                    title: Text(f.signature, style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'monospace')),
                    subtitle: Text('${f.spokenName} — ${f.description}'),
                    trailing: Text(functionCategoryName(l, f.category), style: theme.textTheme.labelSmall),
                    onTap: () => Navigator.pop(context, f),
                  );
                },
              ),
      ),
    ]);
  }
}

/// Constant picker; inserts `@id` (or π / e / φ).
Future<void> showConstantPicker(BuildContext context, WidgetRef ref) async {
  final c = await showModalBottomSheet<PhysicalConstant>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scroll) => _ConstantList(scroll: scroll),
    ),
  );
  if (c == null) return;
  final ctl = ref.read(calculatorProvider.notifier);
  switch (c.id) {
    case 'pi':
      ctl.insertText('π');
    case 'e':
      ctl.insertText('e');
    case 'phi':
      ctl.insertText('φ');
    default:
      ctl.insertAtom('@${c.id}');
  }
}

class _ConstantList extends StatefulWidget {
  const _ConstantList({required this.scroll});
  final ScrollController scroll;

  @override
  State<_ConstantList> createState() => _ConstantListState();
}

class _ConstantListState extends State<_ConstantList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = _q.toLowerCase();
    final items = physicalConstants
        .where((c) =>
            q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.symbol.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q) ||
            c.id.toLowerCase().contains(q))
        .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.actionSearch),
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
      ),
      Expanded(
        child: ListView.builder(
          controller: widget.scroll,
          itemCount: items.length,
          itemBuilder: (context, i) {
            final c = items[i];
            return ListTile(
              leading: SizedBox(width: 48, child: Center(child: MathView(c.latex, style: theme.textTheme.titleLarge, fallback: c.symbol))),
              title: Text(c.name),
              subtitle: Text('${c.value} ${c.unit}'.trim(), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(context, c),
            );
          },
        ),
      ),
    ]);
  }
}
