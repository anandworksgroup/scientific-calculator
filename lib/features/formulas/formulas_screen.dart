import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../widgets/math_view.dart';

/// Localized name of a formula category.
String formulaCategoryName(AppLocalizations l, FormulaCategory c) => switch (c) {
      FormulaCategory.algebra => l.formulaCatAlgebra,
      FormulaCategory.geometry => l.formulaCatGeometry,
      FormulaCategory.trigonometry => l.formulaCatTrigonometry,
      FormulaCategory.calculus => l.formulaCatCalculus,
      FormulaCategory.statistics => l.formulaCatStatistics,
      FormulaCategory.probability => l.formulaCatProbability,
      FormulaCategory.physics => l.formulaCatPhysics,
      FormulaCategory.mechanics => l.formulaCatMechanics,
      FormulaCategory.electricity => l.formulaCatElectricity,
      FormulaCategory.magnetism => l.formulaCatMagnetism,
      FormulaCategory.thermodynamics => l.formulaCatThermodynamics,
      FormulaCategory.optics => l.formulaCatOptics,
      FormulaCategory.waves => l.formulaCatWaves,
    };

IconData formulaCategoryIcon(FormulaCategory c) => switch (c) {
      FormulaCategory.algebra => Icons.functions,
      FormulaCategory.geometry => Icons.change_history,
      FormulaCategory.trigonometry => Icons.architecture,
      FormulaCategory.calculus => Icons.area_chart_outlined,
      FormulaCategory.statistics => Icons.bar_chart,
      FormulaCategory.probability => Icons.casino_outlined,
      FormulaCategory.physics => Icons.science_outlined,
      FormulaCategory.mechanics => Icons.settings_outlined,
      FormulaCategory.electricity => Icons.electric_bolt,
      FormulaCategory.magnetism => Icons.explore_outlined,
      FormulaCategory.thermodynamics => Icons.thermostat,
      FormulaCategory.optics => Icons.visibility_outlined,
      FormulaCategory.waves => Icons.waves,
    };

/// Formula library browser (URS §49).
class FormulasScreen extends ConsumerStatefulWidget {
  const FormulasScreen({super.key});

  @override
  ConsumerState<FormulasScreen> createState() => _FormulasScreenState();
}

class _FormulasScreenState extends ConsumerState<FormulasScreen> {
  String _query = '';
  FormulaCategory? _category;
  bool _favoritesOnly = false;
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = await ref.read(favoritesRepositoryProvider).ids(FavoriteType.formula);
      if (mounted) setState(() => _favorites = ids);
    } catch (e) {
      AppLogger.error('formula favorites', e);
    }
  }

  Future<void> _toggleFavorite(Formula f) async {
    final fav = !_favorites.contains(f.id);
    setState(() => _favorites = fav ? {..._favorites, f.id} : ({..._favorites}..remove(f.id)));
    try {
      await ref.read(favoritesRepositoryProvider).set(FavoriteType.formula, f.id, fav);
    } catch (e) {
      AppLogger.error('formula favorite', e);
    }
  }

  Future<void> _open(Formula f) async {
    await context.push(Routes.formula(f.id));
    // The detail screen may have changed the favorite.
    await _load();
  }

  List<Formula> get _visible => searchFormulas(_query).where((f) {
        if (_favoritesOnly && !_favorites.contains(f.id)) return false;
        if (_category != null && f.category != _category) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final visible = _visible;

    final search = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: l.formulaSearch,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );

    final filterItems = <(String, IconData?, bool, VoidCallback)>[
      (l.formulaAll, Icons.apps, _category == null && !_favoritesOnly, () => setState(() {
            _category = null;
            _favoritesOnly = false;
          })),
      (l.formulaFavorites, Icons.star, _favoritesOnly, () => setState(() => _favoritesOnly = !_favoritesOnly)),
      for (final c in FormulaCategory.values)
        (formulaCategoryName(l, c), formulaCategoryIcon(c), _category == c, () => setState(() => _category = _category == c ? null : c)),
    ];

    Widget results() {
      if (visible.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_favoritesOnly && _favorites.isEmpty ? l.formulaNoFavorites : l.formulaNoResults, textAlign: TextAlign.center),
          ),
        );
      }
      // Group by category when browsing everything without a query.
      final grouped = _query.trim().isEmpty && _category == null;
      final children = <Widget>[];
      FormulaCategory? last;
      for (final f in visible) {
        if (grouped && f.category != last) {
          last = f.category;
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(formulaCategoryName(l, f.category),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ));
        }
        children.add(_tile(context, f));
      }
      return ListView(padding: const EdgeInsets.only(bottom: 16), children: children);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.formulaTitle)),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 720) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 260,
                child: ListView(children: [
                  for (final (label, icon, selected, onTap) in filterItems)
                    ListTile(leading: Icon(icon), title: Text(label), selected: selected, onTap: onTap),
                ]),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(children: [
                  search,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(alignment: Alignment.centerLeft, child: Text(l.formulaCount(visible.length))),
                  ),
                  Expanded(child: results()),
                ]),
              ),
            ]);
          }
          return Column(children: [
            search,
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final (label, icon, selected, onTap) in filterItems)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: icon == null ? null : Icon(icon, size: 18),
                        label: Text(label),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) => onTap(),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: results()),
          ]);
        }),
      ),
    );
  }

  Widget _tile(BuildContext context, Formula f) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fav = _favorites.contains(f.id);
    return ListTile(
      title: Text(f.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MathView(f.latex, style: theme.textTheme.bodyLarge, fallback: f.latex),
        ),
      ),
      trailing: IconButton(
        tooltip: fav ? l.actionUnfavorite : l.actionFavorite,
        icon: Icon(fav ? Icons.star : Icons.star_border),
        onPressed: () => _toggleFavorite(f),
      ),
      onTap: () => _open(f),
    );
  }
}
