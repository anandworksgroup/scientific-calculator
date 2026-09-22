import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/routes.dart';
import '../../app/tools_registry.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/math_view.dart';
import '../calculator/calculator_controller.dart';

class _Hit {
  const _Hit(this.title, this.subtitle, this.onTap, {this.icon, this.tex});
  final String title;
  final String? subtitle;
  final void Function(BuildContext context, WidgetRef ref) onTap;
  final IconData? icon;
  final String? tex;
}

/// Global search over tools, functions, constants, formulas, units and
/// settings (§51).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _q = '';

  bool _match(String q, Iterable<String> fields) => fields.any((f) => f.toLowerCase().contains(q));

  Map<String, List<_Hit>> _search(AppLocalizations l, String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return const {};
    final out = <String, List<_Hit>>{};

    final tools = [
      for (final t in allTools)
        if (_match(q, [t.title(l), t.id, ...t.keywords]))
          _Hit(t.title(l), null, (c, r) => t.route == Routes.graph ? c.go(t.route) : c.push(t.route), icon: t.icon),
    ];
    if (q.contains('quadratic')) {
      tools.insert(0, _Hit(l.toolPolynomial, 'ax² + bx + c = 0', (c, r) => c.push(Routes.polynomial), icon: Icons.stacked_line_chart));
    }
    if (tools.isNotEmpty) out[l.searchSectionTools] = tools;

    final fns = [
      for (final f in builtinFunctions)
        if (_match(q, [f.name, f.spokenName, f.description, f.signature]))
          _Hit(f.signature, '${f.spokenName} — ${f.description}', (c, r) {
            r.read(calculatorProvider.notifier).insertFunction(f.name);
            c.go(Routes.calculator);
          }, icon: Icons.functions),
    ];
    if (fns.isNotEmpty) out[l.searchSectionFunctions] = fns.take(25).toList();

    final consts = [
      for (final c in physicalConstants)
        if (_match(q, [c.name, c.symbol, c.id, c.description])) _Hit(c.name, '${c.value} ${c.unit}'.trim(), (ctx, r) => ctx.push(Routes.constants), tex: c.latex),
    ];
    if (consts.isNotEmpty) out[l.searchSectionConstants] = consts;

    final forms = [for (final f in searchFormulas(raw)) _Hit(f.name, null, (c, r) => c.push(Routes.formula(f.id)), tex: f.latex)];
    if (forms.isNotEmpty) out[l.searchSectionFormulas] = forms.take(30).toList();

    final units = <_Hit>[
      for (final c in unitCategories)
        if (c.name.toLowerCase().contains(q)) _Hit(c.name, null, (ctx, r) => ctx.push('${Routes.converter}?category=${c.id.name}'), icon: Icons.swap_horiz),
      for (final u in searchUnits(raw).take(15))
        _Hit('${u.name} (${u.symbol})', categoryOf(u.category).name, (ctx, r) => ctx.push('${Routes.converter}?category=${u.category.name}'), icon: Icons.straighten),
    ];
    if (units.isNotEmpty) out[l.searchSectionUnits] = units;

    final settings = <(String, String)>[
      (l.settingsCalculator, Routes.settingsCalculator),
      (l.settingsAngleUnit, Routes.settingsCalculator),
      (l.settingsPrecision, Routes.settingsCalculator),
      (l.settingsResultFormat, Routes.settingsCalculator),
      (l.settingsNumberFormat, Routes.settingsCalculator),
      (l.settingsAppearance, Routes.settingsAppearance),
      (l.settingsTheme, Routes.settingsAppearance),
      (l.settingsGraph, Routes.settingsGraph),
      (l.settingsBackup, Routes.backup),
      (l.privacyTitle, Routes.privacy),
      (l.settingsTitle, Routes.settings),
      (l.premiumTitle, Routes.premium),
    ];
    final sHits = [for (final (t, route) in settings) if (t.toLowerCase().contains(q)) _Hit(t, null, (c, r) => c.push(route), icon: Icons.settings_outlined)];
    if (sHits.isNotEmpty) out[l.searchSectionSettings] = sHits;
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final results = _search(l, _q);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: l.searchHint, border: InputBorder.none),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      body: _q.trim().isEmpty
          ? const SizedBox.shrink()
          : results.isEmpty
              ? Center(child: Text(l.searchNoResults))
              : ListView(children: [
                  for (final MapEntry(key: section, value: hits) in results.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(section, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                    ),
                    for (final h in hits)
                      ListTile(
                        leading: h.tex != null
                            ? SizedBox(width: 48, child: Center(child: FittedBox(child: MathView(h.tex!, fallback: h.title))))
                            : Icon(h.icon),
                        title: Text(h.title),
                        subtitle: h.subtitle == null ? null : Text(h.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => h.onTap(context, ref),
                      ),
                  ],
                ]),
    );
  }
}
