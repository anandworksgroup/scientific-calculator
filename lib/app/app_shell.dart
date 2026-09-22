import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';

/// Primary navigation: bottom bar on phones, rail on wide screens.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final destinations = [
      (Icons.calculate_outlined, Icons.calculate, l.navCalculator),
      (Icons.science_outlined, Icons.science, l.navScientific),
      (Icons.show_chart, Icons.show_chart, l.navGraph),
      (Icons.functions_outlined, Icons.functions, l.navSolve),
      (Icons.apps_outlined, Icons.apps, l.navTools),
      (Icons.history, Icons.history, l.navHistory),
    ];
    return LayoutBuilder(builder: (context, c) {
      final useRail = c.maxWidth >= 600 && c.maxWidth > c.maxHeight * 0.9;
      if (useRail) {
        return Scaffold(
          body: Row(children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _go,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final (icon, selected, label) in destinations)
                    NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ]),
        );
      }
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          labelBehavior: c.maxWidth < 380
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final (icon, selected, label) in destinations)
              NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label, tooltip: label),
          ],
        ),
      );
    });
  }
}
