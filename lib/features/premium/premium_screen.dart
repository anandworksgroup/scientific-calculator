import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/purchase_service.dart';

/// One-time Premium unlock with purchase, restore, pending and failure
/// states (§75–76). The calculator itself stays fully free.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(premiumProvider);
    final ctl = ref.read(premiumProvider.notifier);
    final theme = Theme.of(context);

    ref.listen(premiumProvider, (prev, next) {
      String? msg;
      if (next.issue == PurchaseIssue.failed && prev?.issue != PurchaseIssue.failed) msg = l.premiumFailed;
      if (next.issue == PurchaseIssue.unavailable && prev?.issue != PurchaseIssue.unavailable) msg = l.premiumUnavailable;
      if (next.issue == PurchaseIssue.nothingToRestore && prev?.issue != PurchaseIssue.nothingToRestore) msg = l.premiumNothingToRestore;
      if (next.restoredNotice && !(prev?.restoredNotice ?? false)) msg = l.premiumRestored;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        ctl.clearNotices();
      }
    });

    Widget feature(IconData icon, String text) => ListTile(leading: Icon(icon, color: theme.colorScheme.primary), title: Text(text));

    return Scaffold(
      appBar: AppBar(title: Text(l.premiumTitle)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Icon(Icons.workspace_premium, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(l.premiumHeadline, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(l.premiumCoreFree, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        feature(Icons.palette_outlined, l.premiumFeatureThemes),
        feature(Icons.show_chart, l.premiumFeatureGraphs),
        feature(Icons.favorite_outline, l.premiumFeatureSupport),
        const SizedBox(height: 20),
        if (s.isPremium)
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.check_circle, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(child: Text(l.premiumActive, style: TextStyle(color: theme.colorScheme.onPrimaryContainer))),
              ]),
            ),
          )
        else ...[
          if (s.pending) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(l.premiumPending, textAlign: TextAlign.center),
            const SizedBox(height: 12),
          ],
          if (s.loading) Text(l.premiumLoading, textAlign: TextAlign.center),
          if (!s.loading && !s.storeAvailable) Text(l.premiumUnavailable, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: s.pending || s.loading || !s.storeAvailable || s.price == null ? null : ctl.buy,
            child: Text(l.premiumBuy(s.price ?? '…')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: s.loading ? null : ctl.restore, child: Text(l.premiumRestore)),
        ],
      ]),
    );
  }
}
