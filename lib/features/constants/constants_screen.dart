import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/clipboard_service.dart';
import '../../widgets/math_view.dart';
import '../calculator/calculator_controller.dart';
import '../converter/converter_screen.dart' show unitTexText;

/// Localized name of a constant category.
String constantCategoryName(AppLocalizations l, ConstantCategory c) => switch (c) {
      ConstantCategory.mathematical => l.constCatMathematical,
      ConstantCategory.universal => l.constCatUniversal,
      ConstantCategory.electromagnetic => l.constCatElectromagnetic,
      ConstantCategory.atomic => l.constCatAtomic,
      ConstantCategory.physicoChemical => l.constCatPhysicoChemical,
      ConstantCategory.astronomical => l.constCatAstronomical,
      ConstantCategory.adopted => l.constCatAdopted,
    };

/// Calculator atom that inserts [c]: π, e and φ have dedicated symbols,
/// everything else is referenced as `@id`.
String constantAtom(PhysicalConstant c) => switch (c.id) {
      'pi' => 'π',
      'e' => 'e',
      'phi' => 'φ',
      _ => '@${c.id}',
    };

/// Case-insensitive match over name, symbol, id, unit and description.
bool constantMatches(PhysicalConstant c, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [c.name, c.symbol, c.id, c.unit, c.description].any((s) => s.toLowerCase().contains(q));
}

/// Physical and mathematical constants (URS §10).
class ConstantsScreen extends ConsumerStatefulWidget {
  const ConstantsScreen({super.key});

  @override
  ConsumerState<ConstantsScreen> createState() => _ConstantsScreenState();
}

class _ConstantsScreenState extends ConsumerState<ConstantsScreen> {
  String _query = '';

  /// Null = all categories.
  ConstantCategory? _category;
  bool _favoritesOnly = false;
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = await ref.read(favoritesRepositoryProvider).ids(FavoriteType.constant);
      if (mounted) setState(() => _favorites = ids);
    } catch (e) {
      AppLogger.error('constants favorites', e);
    }
  }

  Future<void> _toggleFavorite(PhysicalConstant c) async {
    final fav = !_favorites.contains(c.id);
    setState(() => _favorites = fav ? {..._favorites, c.id} : ({..._favorites}..remove(c.id)));
    try {
      await ref.read(favoritesRepositoryProvider).set(FavoriteType.constant, c.id, fav);
    } catch (e) {
      AppLogger.error('constant favorite', e);
    }
  }

  Future<void> _copy(PhysicalConstant c) async {
    await ClipboardService.copy(c.value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)));
  }

  void _insert(PhysicalConstant c) {
    ref.read(calculatorProvider.notifier).insertAtom(constantAtom(c));
    context.go(Routes.calculator);
  }

  List<PhysicalConstant> get _visible {
    final list = physicalConstants.where((c) {
      if (_favoritesOnly && !_favorites.contains(c.id)) return false;
      if (_category != null && c.category != _category) return false;
      return constantMatches(c, _query);
    }).toList();
    // Favorites first, catalog order otherwise.
    return [...list.where((c) => _favorites.contains(c.id)), ...list.where((c) => !_favorites.contains(c.id))];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final visible = _visible;
    final formatter = ValueFormatter(settings.formatOptions());
    final arith = Arith(precision: settings.precision);

    final filters = <Widget>[
      _chip(l.constAll, selected: _category == null && !_favoritesOnly, onTap: () => setState(() {
            _category = null;
            _favoritesOnly = false;
          })),
      _chip(l.constFavorites, icon: Icons.star, selected: _favoritesOnly, onTap: () => setState(() {
            _favoritesOnly = !_favoritesOnly;
          })),
      for (final c in ConstantCategory.values)
        _chip(constantCategoryName(l, c), selected: _category == c, onTap: () => setState(() {
              _category = _category == c ? null : c;
            })),
    ];

    final search = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: l.constSearch,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );

    Widget list(int columns) {
      if (visible.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_favoritesOnly && _favorites.isEmpty ? l.constNoFavorites : l.constNoResults, textAlign: TextAlign.center),
          ),
        );
      }
      if (columns == 1) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: visible.length,
          itemBuilder: (context, k) => _card(context, visible[k], formatter, arith),
        );
      }
      // Two balanced columns on wide screens.
      final left = [for (var k = 0; k < visible.length; k += 2) visible[k]];
      final right = [for (var k = 1; k < visible.length; k += 2) visible[k]];
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: [for (final c in left) _card(context, c, formatter, arith)])),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [for (final c in right) _card(context, c, formatter, arith)])),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.constTitle)),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 720) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 240,
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  for (final f in filters) Padding(padding: const EdgeInsets.only(bottom: 6), child: f),
                ]),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: Column(children: [search, Expanded(child: list(c.maxWidth >= 1100 ? 2 : 1))])),
            ]);
          }
          return Column(children: [
            search,
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [for (final f in filters) Padding(padding: const EdgeInsets.only(right: 8), child: f)],
              ),
            ),
            Expanded(child: list(1)),
          ]);
        }),
      ),
    );
  }

  Widget _chip(String label, {required bool selected, required VoidCallback onTap, IconData? icon}) => FilterChip(
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        showCheckmark: icon == null,
        onSelected: (_) => onTap(),
      );

  Widget _card(BuildContext context, PhysicalConstant c, ValueFormatter formatter, Arith arith) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fav = _favorites.contains(c.id);
    final shown = formatter.format(NumberValue(c.numericValue(arith)), preferDecimal: true);
    final unit = c.unit.isEmpty ? l.constDimensionless : c.unit;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44),
              child: MathView(c.latex,
                  style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary), semanticsLabel: c.symbol),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: theme.textTheme.titleMedium),
                Text(constantCategoryName(l, c.category), style: theme.textTheme.bodySmall),
              ]),
            ),
            IconButton(
              tooltip: fav ? l.actionUnfavorite : l.actionFavorite,
              icon: Icon(fav ? Icons.star : Icons.star_border),
              onPressed: () => _toggleFavorite(c),
            ),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ScrollingMath(
              '${c.latex} = ${shown.latex}${c.unit.isEmpty ? '' : '\\ ${unitTexText(c.unit)}'}',
              alignRight: false,
              fallback: '${c.symbol} = ${shown.display} ${c.unit}',
              semanticsLabel: '${c.symbol} = ${shown.display} $unit',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.exact ? l.constExact : (c.uncertainty != null ? l.constUncertainty('${c.uncertainty} ${c.unit}'.trim()) : l.constMeasured),
            style: theme.textTheme.bodySmall?.copyWith(color: c.exact ? theme.colorScheme.primary : null),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(c.description, style: theme.textTheme.bodyMedium),
          ),
          Text(l.constUsage(constantAtom(c)), style: theme.textTheme.bodySmall),
          Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
            TextButton.icon(onPressed: () => _copy(c), icon: const Icon(Icons.copy, size: 18), label: Text(l.constCopyValue)),
            TextButton.icon(
              onPressed: () => _insert(c),
              icon: const Icon(Icons.input, size: 18),
              label: Text(l.constInsert),
            ),
          ]),
        ]),
      ),
    );
  }
}
