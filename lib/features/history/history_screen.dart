import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_menu_button.dart';
import '../calculator/calculator_controller.dart';
import 'history_panel.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _searching = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final filter = ref.watch(historyFilterProvider);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(hintText: l.historySearch, border: InputBorder.none),
                onChanged: (v) => ref.read(historyFilterProvider.notifier).setQuery(v),
              )
            : Text(l.historyTitle),
        actions: [
          IconButton(
            tooltip: l.historySearch,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _controller.clear();
                ref.read(historyFilterProvider.notifier).setQuery('');
              }
            },
          ),
          IconButton(
            tooltip: l.historyFavoritesOnly,
            isSelected: filter.favoritesOnly,
            icon: const Icon(Icons.star_outline),
            selectedIcon: const Icon(Icons.star),
            onPressed: () => ref.read(historyFilterProvider.notifier).toggleFavorites(),
          ),
          IconButton(
            tooltip: l.historyClearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l.historyClearAll),
                  content: Text(l.historyClearConfirm),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.actionDelete)),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(historyRepositoryProvider).clear();
                ref.invalidate(historyListProvider);
              }
            },
          ),
          const AppMenuButton(),
        ],
      ),
      body: const HistoryPanel(),
    );
  }
}
