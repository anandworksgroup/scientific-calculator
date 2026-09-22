import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/tools_registry.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/math_view.dart';
import '../history/history_panel.dart';

final _favoritesProvider = FutureProvider.autoDispose<List<(FavoriteType, String)>>(
    (ref) => ref.watch(favoritesRepositoryProvider).all());

final _favoriteCalculationsProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(historyRepositoryProvider).list(favoritesOnly: true, limit: 1000);
});

/// Everything the user starred (§54).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final favs = ref.watch(_favoritesProvider).value ?? const [];
    final calcs = ref.watch(_favoriteCalculationsProvider).value ?? const [];
    final theme = Theme.of(context);
    List<String> ids(FavoriteType t) => [for (final (type, id) in favs) if (type == t) id];

    final formulasList = [for (final id in ids(FavoriteType.formula)) if (formulaById(id) != null) formulaById(id)!];
    final constantsList = [for (final id in ids(FavoriteType.constant)) if (constantIndex[id] != null) constantIndex[id]!];
    final converters = [
      for (final id in ids(FavoriteType.converter))
        if (unitCategories.any((c) => c.id.name == id)) unitCategories.firstWhere((c) => c.id.name == id)
    ];
    final units = [for (final id in ids(FavoriteType.unit)) if (unitById(id) != null) unitById(id)!];
    final tools = [for (final id in ids(FavoriteType.tool)) if (toolById(id) != null) toolById(id)!];

    final empty = calcs.isEmpty && formulasList.isEmpty && constantsList.isEmpty && converters.isEmpty && units.isEmpty && tools.isEmpty;
    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(t, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.favoritesTitle)),
      body: empty
          ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(l.favoritesEmpty, textAlign: TextAlign.center)))
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              if (calcs.isNotEmpty) ...[
                header(l.favoritesCalculations),
                for (final e in calcs) HistoryTile(entry: e),
              ],
              if (formulasList.isNotEmpty) ...[
                header(l.favoritesFormulas),
                for (final f in formulasList)
                  ListTile(
                    title: Text(f.name),
                    subtitle: SingleChildScrollView(scrollDirection: Axis.horizontal, child: MathView(f.latex)),
                    onTap: () => context.push(Routes.formula(f.id)),
                  ),
              ],
              if (constantsList.isNotEmpty) ...[
                header(l.favoritesConstants),
                for (final c in constantsList)
                  ListTile(
                    leading: SizedBox(width: 40, child: Center(child: MathView(c.latex, fallback: c.symbol))),
                    title: Text(c.name),
                    subtitle: Text('${c.value} ${c.unit}'.trim()),
                    onTap: () => context.push(Routes.constants),
                  ),
              ],
              if (converters.isNotEmpty || units.isNotEmpty) ...[
                header(l.favoritesConverters),
                for (final c in converters)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(c.name),
                    onTap: () => context.push('${Routes.converter}?category=${c.id.name}'),
                  ),
                for (final u in units)
                  ListTile(
                    leading: const Icon(Icons.straighten),
                    title: Text('${u.name} (${u.symbol})'),
                    onTap: () => context.push('${Routes.converter}?category=${u.category.name}'),
                  ),
              ],
              if (tools.isNotEmpty) ...[
                header(l.favoritesTools),
                for (final t in tools)
                  ListTile(leading: Icon(t.icon), title: Text(t.title(l)), onTap: () => context.push(t.route)),
              ],
            ]),
    );
  }
}
