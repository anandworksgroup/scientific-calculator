import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../data/repositories/history_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../widgets/math_view.dart';
import '../calculator/calculator_controller.dart';

/// Query + favorites filter for the history list.
class HistoryFilter {
  const HistoryFilter({this.query = '', this.favoritesOnly = false});
  final String query;
  final bool favoritesOnly;
}

class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => const HistoryFilter();
  void setQuery(String q) => state = HistoryFilter(query: q, favoritesOnly: state.favoritesOnly);
  void toggleFavorites() => state = HistoryFilter(query: state.query, favoritesOnly: !state.favoritesOnly);
}

final historyFilterProvider = NotifierProvider<HistoryFilterNotifier, HistoryFilter>(HistoryFilterNotifier.new);

final filteredHistoryProvider = FutureProvider.autoDispose<List<HistoryEntry>>((ref) async {
  ref.watch(historyListProvider); // refresh after new calculations
  final f = ref.watch(historyFilterProvider);
  return ref.watch(historyRepositoryProvider).list(limit: 2000, query: f.query, favoritesOnly: f.favoritesOnly);
});

enum HistoryGroup { today, yesterday, week, month, older }

HistoryGroup groupOf(DateTime t, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return HistoryGroup.today;
  if (diff == 1) return HistoryGroup.yesterday;
  if (diff <= 7) return HistoryGroup.week;
  if (diff <= 30) return HistoryGroup.month;
  return HistoryGroup.older;
}

String groupTitle(AppLocalizations l, HistoryGroup g) => switch (g) {
      HistoryGroup.today => l.historyToday,
      HistoryGroup.yesterday => l.historyYesterday,
      HistoryGroup.week => l.historyPrevious7,
      HistoryGroup.month => l.historyPrevious30,
      HistoryGroup.older => l.historyOlder,
    };

/// The history list, used by the History tab and beside the calculator on
/// tablets.
class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(filteredHistoryProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.errInvalidExpression)),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(settings.saveHistory ? l.historyEmpty : l.historyDisabled, textAlign: TextAlign.center),
              ]),
            ),
          );
        }
        final now = DateTime.now();
        final rows = <Object>[];
        HistoryGroup? last;
        for (final e in entries) {
          final g = groupOf(e.createdAt, now);
          if (g != last) {
            rows.add(g);
            last = g;
          }
          rows.add(e);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            if (r is HistoryGroup) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(groupTitle(l, r), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
              );
            }
            return HistoryTile(entry: r as HistoryEntry);
          },
        );
      },
    );
  }
}

class HistoryTile extends ConsumerWidget {
  const HistoryTile({super.key, required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = DateFormat.jm(Localizations.localeOf(context).toLanguageTag()).format(entry.createdAt);
    return Dismissible(
      key: ValueKey('h${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        await ref.read(historyRepositoryProvider).delete(entry.id!);
        ref.invalidate(historyListProvider);
      },
      child: InkWell(
        onTap: () => showHistoryActions(context, ref, entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: MathView(
                    entry.expressionLatex.isEmpty ? entry.expression : entry.expressionLatex,
                    fallback: entry.expression,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: MathView(
                    '=\\;${entry.resultLatex.isEmpty ? entry.result : entry.resultLatex}',
                    fallback: '= ${entry.result}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(time, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
              ]),
            ),
            IconButton(
              tooltip: entry.isFavorite ? l.actionUnfavorite : l.actionFavorite,
              icon: Icon(entry.isFavorite ? Icons.star : Icons.star_outline,
                  color: entry.isFavorite ? theme.colorScheme.primary : null),
              onPressed: () async {
                await ref.read(historyRepositoryProvider).setFavorite(entry.id!, !entry.isFavorite);
                ref.invalidate(historyListProvider);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

/// Actions for a history entry (§52, §59).
Future<void> showHistoryActions(BuildContext context, WidgetRef ref, HistoryEntry e) async {
  final l = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.actionEdit), onTap: () => Navigator.pop(context, 'edit')),
          ListTile(leading: const Icon(Icons.input), title: Text(l.calcUseExpression), onTap: () => Navigator.pop(context, 'expr')),
          ListTile(leading: const Icon(Icons.east), title: Text(l.calcUseResult), onTap: () => Navigator.pop(context, 'result')),
          ListTile(leading: const Icon(Icons.copy), title: Text(l.calcCopyResult), onTap: () => Navigator.pop(context, 'copyResult')),
          ListTile(leading: const Icon(Icons.copy_all), title: Text(l.calcCopyBoth), onTap: () => Navigator.pop(context, 'copyBoth')),
          ListTile(leading: const Icon(Icons.share), title: Text(l.actionShare), onTap: () => Navigator.pop(context, 'share')),
          ListTile(
            leading: Icon(e.isFavorite ? Icons.star : Icons.star_outline),
            title: Text(e.isFavorite ? l.actionUnfavorite : l.actionFavorite),
            onTap: () => Navigator.pop(context, 'fav'),
          ),
          ListTile(leading: const Icon(Icons.delete_outline), title: Text(l.actionDelete), onTap: () => Navigator.pop(context, 'delete')),
        ]),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final calc = ref.read(calculatorProvider.notifier);
  final both = l.calcShareText(e.expression, e.result);
  switch (choice) {
    case 'edit':
      calc.loadExpression(e.expression, editorJson: e.editorState);
      context.go(Routes.calculator);
    case 'expr':
      calc.insertText(e.expression);
      context.go(Routes.calculator);
    case 'result':
      calc.insertText(e.result.contains('/') || e.result.startsWith('-') ? '(${e.result})' : e.result);
      context.go(Routes.calculator);
    case 'copyResult':
      await Clipboard.setData(ClipboardData(text: e.result));
    case 'copyBoth':
      await Clipboard.setData(ClipboardData(text: both));
    case 'share':
      await ClipboardService.share(both);
    case 'fav':
      await ref.read(historyRepositoryProvider).setFavorite(e.id!, !e.isFavorite);
      ref.invalidate(historyListProvider);
    case 'delete':
      await ref.read(historyRepositoryProvider).delete(e.id!);
      ref.invalidate(historyListProvider);
  }
  if ((choice == 'copyResult' || choice == 'copyBoth') && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copiedToClipboard)));
  }
}
