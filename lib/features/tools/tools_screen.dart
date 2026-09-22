import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/tools_registry.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_menu_button.dart';

/// Tools hub: customizable quick-access shortcuts (§4, §89) and all tools.
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final quick = [
      for (final id in ref.watch(settingsProvider.select((s) => s.quickAccess)))
        if (toolById(id) != null) toolById(id)!,
    ];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.toolsTitle),
        actions: [
          IconButton(tooltip: l.actionSearch, icon: const Icon(Icons.search), onPressed: () => context.push(Routes.search)),
          const AppMenuButton(),
        ],
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(children: [
              Expanded(child: Text(l.toolsQuickAccess, style: theme.textTheme.titleMedium)),
              IconButton(
                tooltip: l.toolsCustomize,
                icon: const Icon(Icons.tune),
                onPressed: () => showQuickAccessEditor(context, ref),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
            ),
            itemCount: quick.length,
            itemBuilder: (context, i) => _QuickTile(tool: quick[i]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(l.toolsAll, style: theme.textTheme.titleMedium),
          ),
        ),
        SliverList.builder(
          itemCount: allTools.length,
          itemBuilder: (context, i) {
            final t = allTools[i];
            return ListTile(
              leading: Icon(t.icon),
              title: Text(t.title(l)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => t.route == Routes.graph ? context.go(t.route) : context.push(t.route),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.tool});
  final ToolInfo tool;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => tool.route == Routes.graph ? context.go(tool.route) : context.push(tool.route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(tool.icon, size: 30, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(tool.title(l), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
          ]),
        ),
      ),
    );
  }
}

/// Reorder / choose quick-access shortcuts.
Future<void> showQuickAccessEditor(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => const _QuickAccessEditor(),
  );
}

class _QuickAccessEditor extends ConsumerWidget {
  const _QuickAccessEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selected = ref.watch(settingsProvider.select((s) => s.quickAccess));
    final set = ref.read(settingsProvider.notifier);
    final chosen = [for (final id in selected) if (toolById(id) != null) toolById(id)!];
    final others = allTools.where((t) => !selected.contains(t.id)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l.toolsCustomize, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: CustomScrollView(slivers: [
            SliverReorderableList(
              itemCount: chosen.length,
              onReorder: (a, b) {
                final list = [...selected];
                final item = list.removeAt(a);
                list.insert(b > a ? b - 1 : b, item);
                set.update((s) => s.copyWith(quickAccess: list));
              },
              itemBuilder: (context, i) {
                final t = chosen[i];
                return Material(
                  key: ValueKey(t.id),
                  child: ListTile(
                    leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                    title: Text(t.title(l)),
                    trailing: IconButton(
                      tooltip: l.actionDelete,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => set.update((s) => s.copyWith(quickAccess: [...selected]..remove(t.id))),
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: Divider()),
            SliverList.builder(
              itemCount: others.length,
              itemBuilder: (context, i) {
                final t = others[i];
                return ListTile(
                  leading: Icon(t.icon),
                  title: Text(t.title(l)),
                  trailing: IconButton(
                    tooltip: l.actionAdd,
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => set.update((s) => s.copyWith(quickAccess: [...selected, t.id])),
                  ),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}
