import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../data/settings/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/math_view.dart';
import '../calculator/calculator_controller.dart' show historyListProvider;

/// Icon shown for each unit category.
IconData unitCategoryIcon(UnitCategoryId id) => switch (id) {
      UnitCategoryId.length => Icons.straighten,
      UnitCategoryId.area => Icons.square_foot,
      UnitCategoryId.volume => Icons.local_drink_outlined,
      UnitCategoryId.mass => Icons.scale_outlined,
      UnitCategoryId.time => Icons.schedule,
      UnitCategoryId.temperature => Icons.thermostat,
      UnitCategoryId.speed => Icons.speed,
      UnitCategoryId.acceleration => Icons.rocket_launch_outlined,
      UnitCategoryId.pressure => Icons.compress,
      UnitCategoryId.energy => Icons.bolt,
      UnitCategoryId.power => Icons.power_outlined,
      UnitCategoryId.force => Icons.fitness_center,
      UnitCategoryId.angle => Icons.architecture,
      UnitCategoryId.frequency => Icons.graphic_eq,
      UnitCategoryId.data => Icons.storage,
      UnitCategoryId.fuelEconomy => Icons.local_gas_station_outlined,
      UnitCategoryId.density => Icons.grain,
      UnitCategoryId.torque => Icons.build_outlined,
    };

/// Unit text as KaTeX (`\text{…}` with special characters escaped).
String unitTexText(String s) {
  final clean = s.replaceAll(RegExp(r'[\\{}~]'), '').replaceAllMapped(RegExp(r'[%#$&_^]'), (m) => '\\${m[0]}');
  // flutter_math has no text-mode middle dot (\cdotp), so use math \cdot.
  return clean.split('·').map((p) => '\\text{$p}').join(r'{\cdot}');
}

/// Outcome of converting one value (either a number or an explanation).
class _Converted {
  const _Converted.ok(this.value) : error = null;
  const _Converted.fail(this.error) : value = null;
  final Num? value;
  final MathError? error;
}

/// Unit converter (URS §47–48): exact conversions over the engine's
/// number tower, with favorites, recents and a full table per category.
class ConverterScreen extends ConsumerStatefulWidget {
  const ConverterScreen({super.key, this.initialCategory});

  /// [UnitCategoryId] name (e.g. `temperature`) to open first.
  final String? initialCategory;

  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen> {
  final _input = TextEditingController(text: '1');
  late UnitCategory _category;
  late UnitDef _from;
  late UnitDef _to;
  Set<String> _favUnits = {};
  Set<String> _favCategories = {};
  List<RecentConversion> _recent = [];
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    final wanted = widget.initialCategory?.toLowerCase();
    final cat = unitCategories.firstWhere(
      (c) => c.id.name.toLowerCase() == wanted || c.name.toLowerCase() == wanted,
      orElse: () => unitCategories.first,
    );
    _selectCategory(cat, notify: false);
    _input.addListener(_onInputChanged);
    _load();
  }

  Future<void> _load() async {
    try {
      final favs = ref.read(favoritesRepositoryProvider);
      final units = await favs.ids(FavoriteType.unit);
      final cats = await favs.ids(FavoriteType.converter);
      final recent = await ref.read(conversionsRepositoryProvider).recent();
      if (!mounted) return;
      setState(() {
        _favUnits = units;
        _favCategories = cats;
        _recent = recent;
      });
    } catch (e) {
      AppLogger.error('converter load', e);
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {});
    _scheduleRecord();
  }

  void _selectCategory(UnitCategory c, {bool notify = true}) {
    void apply() {
      _category = c;
      final units = c.units;
      // Default: first unit (usually the base) → second unit.
      _from = units.length > 1 ? units[1] : units.first;
      _to = units.first;
    }

    if (notify) {
      setState(apply);
      _scheduleRecord();
    } else {
      apply();
    }
  }

  List<UnitDef> _sortedUnits(List<UnitDef> units) =>
      [...units.where((u) => _favUnits.contains(u.id)), ...units.where((u) => !_favUnits.contains(u.id))];

  List<UnitCategory> get _sortedCategories => [
        ...unitCategories.where((c) => _favCategories.contains(c.id.name)),
        ...unitCategories.where((c) => !_favCategories.contains(c.id.name)),
      ];

  // ------------------------------------------------------------ conversion

  AppSettings get _settings => ref.read(settingsProvider);

  /// Parses the input with the engine so `1/3`, `2.5E3` or `sqrt(2)` work.
  (Num?, MathError?, bool) _parseInput() {
    final text = ClipboardService.sanitize(_input.text);
    if (text.isEmpty) return (null, null, false);
    final r = EngineService.engine.evaluate(text, _settings.calcSettings, ref.read(environmentProvider),
        budget: Budget(timeLimit: const Duration(milliseconds: 300)));
    switch (r) {
      case Success(:final value):
        final v = value.value;
        if (v is NumberValue && Arith.isReal(v.n)) return (v.n, null, value.preferDecimal);
        return (null, const MathError(MathErrorCode.typeMismatch), false);
      case Failure(:final error):
        return (null, error, false);
      case Cancelled():
        return (null, const MathError(MathErrorCode.cancelled), false);
    }
  }

  _Converted _convert(Num value, UnitDef from, UnitDef to) {
    final r = guard(() => UnitConverter(Arith(precision: _settings.precision)).convert(value, from, to));
    return switch (r) {
      Success(:final value) => _Converted.ok(value),
      Failure(:final error) => _Converted.fail(error),
      Cancelled() => const _Converted.fail(MathError(MathErrorCode.cancelled)),
    };
  }

  String _explain(AppLocalizations l, MathError e) {
    if (e.code == MathErrorCode.domainError && e.params['function'] == 'temperature') return l.convBelowAbsoluteZero;
    if (e.code == MathErrorCode.divisionByZero) return l.convReciprocalZero;
    if (e.code == MathErrorCode.typeMismatch && e.params.isEmpty) return l.convNotReal;
    return errorText(l, e);
  }

  FormattedNumber _fmt(Num n, {bool decimal = true}) =>
      ValueFormatter(_settings.formatOptions()).format(NumberValue(n), preferDecimal: decimal);

  void _scheduleRecord() {
    _recordTimer?.cancel();
    _recordTimer = Timer(const Duration(milliseconds: 1500), _record);
  }

  Future<void> _record() async {
    if (!mounted) return;
    final (value, _, _) = _parseInput();
    if (value == null) return;
    final res = _convert(value, _from, _to);
    if (res.value == null) return;
    final shown = _fmt(res.value!);
    final input = _input.text.trim();
    final entry = RecentConversion(_category.id.name, _from.id, _to.id, input, shown.plain, DateTime.now());
    try {
      await ref.read(conversionsRepositoryProvider).add(entry);
      if (!mounted) return;
      final settings = _settings;
      if (settings.saveHistory) {
        await ref.read(historyRepositoryProvider).insert(
              HistoryEntry(
                expression: '$input ${_from.symbol} → ${_to.symbol}',
                expressionLatex: '$input\\ ${unitTexText(_from.symbol)}\\to${unitTexText(_to.symbol)}',
                result: '${shown.plain} ${_to.symbol}',
                resultLatex: '${shown.latex}\\ ${unitTexText(_to.symbol)}',
                resultValue: ValueCodec.encode(NumberValue(res.value!)),
                mode: 'converter',
                angleMode: settings.angleMode.name,
                format: settings.resultFormat.name,
                createdAt: DateTime.now(),
              ),
              limit: settings.historyLimit,
            );
        ref.invalidate(historyListProvider);
      }
      final recent = await ref.read(conversionsRepositoryProvider).recent();
      if (mounted) setState(() => _recent = recent);
    } catch (e) {
      AppLogger.error('converter record', e);
    }
  }


  // --------------------------------------------------------------- actions

  void _swap() {
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
    });
    _scheduleRecord();
  }

  Future<void> _toggleUnitFavorite(UnitDef u) async {
    final fav = !_favUnits.contains(u.id);
    setState(() => _favUnits = fav ? {..._favUnits, u.id} : ({..._favUnits}..remove(u.id)));
    try {
      await ref.read(favoritesRepositoryProvider).set(FavoriteType.unit, u.id, fav);
    } catch (e) {
      AppLogger.error('favorite unit', e);
    }
  }

  Future<void> _toggleCategoryFavorite() async {
    final id = _category.id.name;
    final fav = !_favCategories.contains(id);
    setState(() => _favCategories = fav ? {..._favCategories, id} : ({..._favCategories}..remove(id)));
    try {
      await ref.read(favoritesRepositoryProvider).set(FavoriteType.converter, id, fav);
    } catch (e) {
      AppLogger.error('favorite category', e);
    }
  }

  void _restore(RecentConversion r) {
    final cat = unitCategories.where((c) => c.id.name == r.category).firstOrNull;
    final from = unitById(r.fromUnit), to = unitById(r.toUnit);
    if (cat == null || from == null || to == null) return;
    setState(() {
      _category = cat;
      _from = from;
      _to = to;
    });
    _input.text = r.input;
  }

  Future<void> _clearRecent() async {
    try {
      await ref.read(conversionsRepositoryProvider).clear();
    } catch (e) {
      AppLogger.error('clear conversions', e);
    }
    if (mounted) setState(() => _recent = []);
  }

  Future<void> _copy(String text) async {
    await ClipboardService.copy(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)));
  }

  Future<void> _pickUnit({required bool from}) async {
    final l = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<UnitDef>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _UnitPickerSheet(
        title: from ? l.convSelectFromUnit : l.convSelectToUnit,
        category: _category.id,
        selected: from ? _from : _to,
        favorites: _favUnits,
        onToggleFavorite: _toggleUnitFavorite,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => from ? _from = picked : _to = picked);
    _scheduleRecord();
  }

  Future<void> _searchAll() async {
    final l = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<UnitDef>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _UnitPickerSheet(
        title: l.convSearchAllUnits,
        category: null,
        selected: null,
        favorites: _favUnits,
        onToggleFavorite: _toggleUnitFavorite,
      ),
    );
    if (picked == null || !mounted) return;
    final cat = categoryOf(picked.category);
    setState(() {
      if (cat.id != _category.id) {
        _category = cat;
        _to = cat.units.firstWhere((u) => u.id != picked.id, orElse: () => cat.units.first);
      }
      _from = picked;
      if (_to.id == picked.id) _to = cat.units.firstWhere((u) => u.id != picked.id, orElse: () => picked);
    });
    _scheduleRecord();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(settingsProvider);
    final favCat = _favCategories.contains(_category.id.name);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.convTitle),
        actions: [
          IconButton(tooltip: l.convSearchAllUnits, icon: const Icon(Icons.search), onPressed: _searchAll),
          IconButton(
            tooltip: favCat ? l.convUnfavoriteCategory : l.convFavoriteCategory,
            icon: Icon(favCat ? Icons.star : Icons.star_border),
            onPressed: _toggleCategoryFavorite,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 720) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 240, child: _categoryList(context)),
              const VerticalDivider(width: 1),
              Expanded(child: _content(context, wide: true)),
            ]);
          }
          return Column(children: [
            SizedBox(height: 60, child: _categoryChips(context)),
            const Divider(height: 1),
            Expanded(child: _content(context, wide: false)),
          ]);
        }),
      ),
    );
  }

  Widget _categoryList(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(children: [
      for (final c in _sortedCategories)
        ListTile(
          leading: Icon(unitCategoryIcon(c.id)),
          title: Text(c.name),
          trailing: _favCategories.contains(c.id.name) ? Icon(Icons.star, size: 18, color: theme.colorScheme.primary) : null,
          selected: c.id == _category.id,
          onTap: () => _selectCategory(c),
        ),
    ]);
  }

  Widget _categoryChips(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (final c in _sortedCategories)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(unitCategoryIcon(c.id), size: 18),
              label: Text(c.name),
              selected: c.id == _category.id,
              showCheckmark: false,
              onSelected: (_) => _selectCategory(c),
            ),
          ),
      ],
    );
  }

  Widget _content(BuildContext context, {required bool wide}) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (value, parseError, _) = _parseInput();
    final result = value == null ? null : _convert(value, _from, _to);

    Widget resultBox;
    if (_input.text.trim().isEmpty) {
      resultBox = Text(l.convEnterValue, style: theme.textTheme.bodyMedium);
    } else if (parseError != null) {
      resultBox = Text(_explain(l, parseError), style: TextStyle(color: theme.colorScheme.error));
    } else if (result?.error != null) {
      resultBox = Text(_explain(l, result!.error!), style: TextStyle(color: theme.colorScheme.error));
    } else {
      final n = result!.value!;
      final main = _fmt(n);
      final exact = _fmt(n, decimal: false);
      resultBox = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: ScrollingMath(
              '${main.latex}\\ ${unitTexText(_to.symbol)}',
              alignRight: false,
              fallback: '${main.display} ${_to.symbol}',
              semanticsLabel: '${main.display} ${_to.name}',
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          IconButton(
            tooltip: l.convCopyResult,
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(main.plain),
          ),
        ]),
        if (exact.plain != main.plain)
          Text(l.convExactValue(exact.display), style: theme.textTheme.bodySmall),
      ]);
    }

    final converter = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(unitCategoryIcon(_category.id), color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(_category.name, style: theme.textTheme.titleMedium)),
          ]),
          const SizedBox(height: 12),
          Text(l.convFrom, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          TextField(
            controller: _input,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            decoration: InputDecoration(
              labelText: l.convValue,
              hintText: l.convValueHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          _UnitButton(unit: _from, label: l.convFromUnitLabel(_from.name), onTap: () => _pickUnit(from: true)),
          Center(
            child: IconButton.filledTonal(
              tooltip: l.convSwap,
              icon: const Icon(Icons.swap_vert),
              onPressed: _swap,
            ),
          ),
          Text(l.convTo, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          _UnitButton(unit: _to, label: l.convToUnitLabel(_to.name), onTap: () => _pickUnit(from: false)),
          const SizedBox(height: 12),
          Text(l.convResult, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Semantics(liveRegion: true, child: resultBox),
        ]),
      ),
    );

    final allUnits = Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(title: Text(l.convAllUnits), subtitle: Text(l.convAllUnitsHint)),
        for (final u in _sortedUnits(_category.units)) _unitRow(context, u, value),
      ]),
    );

    final recent = Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          title: Text(l.convRecent),
          trailing: _recent.isEmpty
              ? null
              : IconButton(tooltip: l.convClearRecent, icon: const Icon(Icons.delete_sweep_outlined), onPressed: _clearRecent),
        ),
        if (_recent.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(l.convRecentEmpty))
        else
          for (final r in _recent.take(10)) _recentRow(context, r),
      ]),
    );

    final content = <Widget>[converter, const SizedBox(height: 12), allUnits, const SizedBox(height: 12), recent];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 760 : double.infinity),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
          ),
        ),
      ],
    );
  }

  Widget _unitRow(BuildContext context, UnitDef u, Num? value) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String text;
    if (value == null) {
      text = '—';
    } else {
      final r = _convert(value, _from, u);
      text = r.value == null ? '—' : '${_fmt(r.value!).display} ${u.symbol}';
    }
    final fav = _favUnits.contains(u.id);
    return ListTile(
      selected: u.id == _to.id,
      title: Text(u.name),
      subtitle: Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      trailing: IconButton(
        tooltip: fav ? l.convUnfavoriteUnit(u.name) : l.convFavoriteUnit(u.name),
        icon: Icon(fav ? Icons.star : Icons.star_border),
        onPressed: () => _toggleUnitFavorite(u),
      ),
      onTap: () {
        setState(() => _to = u);
        _scheduleRecord();
      },
    );
  }

  Widget _recentRow(BuildContext context, RecentConversion r) {
    final from = unitById(r.fromUnit), to = unitById(r.toUnit);
    if (from == null || to == null) return const SizedBox.shrink();
    final cat = unitCategories.where((c) => c.id.name == r.category).firstOrNull;
    return ListTile(
      leading: cat == null ? null : Icon(unitCategoryIcon(cat.id)),
      title: Text('${r.input} ${from.symbol} → ${r.result} ${to.symbol}'),
      subtitle: Text('${from.name} → ${to.name}'),
      onTap: () => _restore(r),
    );
  }
}

class _UnitButton extends StatelessWidget {
  const _UnitButton({required this.unit, required this.label, required this.onTap});
  final UnitDef unit;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), alignment: Alignment.centerLeft),
        onPressed: onTap,
        child: Row(children: [
          Expanded(child: Text('${unit.name} (${unit.symbol})', style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down),
        ]),
      ),
    );
  }
}

/// Bottom sheet listing units (favorites first) with a search box.
class _UnitPickerSheet extends StatefulWidget {
  const _UnitPickerSheet({
    required this.title,
    required this.category,
    required this.selected,
    required this.favorites,
    required this.onToggleFavorite,
  });

  final String title;

  /// Null searches every category.
  final UnitCategoryId? category;
  final UnitDef? selected;
  final Set<String> favorites;
  final Future<void> Function(UnitDef u) onToggleFavorite;

  @override
  State<_UnitPickerSheet> createState() => _UnitPickerSheetState();
}

class _UnitPickerSheetState extends State<_UnitPickerSheet> {
  String _query = '';
  late final Set<String> _fav = {...widget.favorites};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final found = searchUnits(_query, category: widget.category);
    final units = [...found.where((u) => _fav.contains(u.id)), ...found.where((u) => !_fav.contains(u.id))];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(widget.title, style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: widget.category == null,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.convSearchUnits,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: units.isEmpty
                ? Center(child: Text(l.convNoUnits))
                : ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (context, k) {
                      final u = units[k];
                      final fav = _fav.contains(u.id);
                      final showCat = widget.category == null;
                      return ListTile(
                        selected: u.id == widget.selected?.id,
                        leading: showCat ? Icon(unitCategoryIcon(u.category)) : null,
                        title: Text(u.name),
                        subtitle: Text([
                          u.symbol,
                          if (showCat) categoryOf(u.category).name,
                          if (u.system != null) u.system!,
                        ].join(' · ')),
                        trailing: IconButton(
                          tooltip: fav ? l.convUnfavoriteUnit(u.name) : l.convFavoriteUnit(u.name),
                          icon: Icon(fav ? Icons.star : Icons.star_border),
                          onPressed: () {
                            setState(() => fav ? _fav.remove(u.id) : _fav.add(u.id));
                            widget.onToggleFavorite(u);
                          },
                        ),
                        onTap: () => Navigator.pop(context, u),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
