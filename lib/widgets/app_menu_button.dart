import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/routes.dart';
import '../l10n/generated/app_localizations.dart';

/// Overflow menu (⋮) shared by the primary sections.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = <(String, IconData, String)>[
      (Routes.favorites, Icons.star_outline, l.favoritesTitle),
      (Routes.variables, Icons.data_object, l.variablesTitle),
      (Routes.functions, Icons.timeline, l.functionsTitle),
      (Routes.settings, Icons.settings_outlined, l.settingsTitle),
      (Routes.premium, Icons.workspace_premium_outlined, l.premiumTitle),
      (Routes.about, Icons.info_outline, l.aboutTitle),
    ];
    return PopupMenuButton<String>(
      tooltip: l.actionMore,
      icon: const Icon(Icons.more_vert),
      onSelected: (route) => context.push(route),
      itemBuilder: (context) => [
        for (final (route, icon, title) in items)
          PopupMenuItem(value: route, child: ListTile(leading: Icon(icon), title: Text(title), contentPadding: EdgeInsets.zero)),
      ],
    );
  }
}
