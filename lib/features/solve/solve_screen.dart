import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/math_view.dart';

/// Solve hub: equation, polynomial, simultaneous equations and CAS.
class SolveScreen extends StatelessWidget {
  const SolveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = [
      (Routes.equation, l.toolEquation, l.solveEquationSubtitle, r'\cos x = x'),
      (Routes.polynomial, l.toolPolynomial, l.solvePolynomialSubtitle, r'x^{3}-6x^{2}+11x-6=0'),
      (Routes.system, l.toolSystem, l.solveSystemSubtitle, r'\begin{cases}2x+y=5\\x-y=1\end{cases}'),
      (Routes.cas, l.toolCas, l.solveCasSubtitle, r'(x+1)^{2}=x^{2}+2x+1'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.solveTitle),
        actions: [
          IconButton(tooltip: l.actionSearch, icon: const Icon(Icons.search), onPressed: () => context.push(Routes.search)),
          const AppMenuButton(),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 700 ? 2 : 1;
        return GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cols == 1 ? 2.6 : 2.4,
          children: [
            for (final (route, title, subtitle, tex) in items)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(route),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(child: MathView(tex, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary))),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
