import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/calculator/calculator_screen.dart';
import '../features/calculator/scientific_screen.dart';
import '../features/graph/graph_screen.dart';
import '../features/history/history_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/solve/solve_screen.dart';
import '../features/tools/tools_screen.dart';
import 'app_shell.dart';
import 'providers.dart';
import 'routes.dart';
import 'secondary_routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

const _primary = [
  Routes.calculator,
  Routes.scientific,
  Routes.graph,
  Routes.solve,
  Routes.tools,
  Routes.history,
];

final routerProvider = Provider<GoRouter>((ref) {
  final store = ref.read(settingsStoreProvider);
  final last = store.getString('nav.section');
  final initial = _primary.contains(last) ? last! : Routes.calculator;

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initial,
    redirect: (context, state) {
      final done = ref.read(settingsProvider).onboardingDone;
      if (!done && state.matchedLocation != Routes.onboarding) return Routes.onboarding;
      return null;
    },
    routes: [
      GoRoute(path: Routes.onboarding, builder: (c, s) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.calculator, builder: (c, s) => const CalculatorScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.scientific, builder: (c, s) => const ScientificScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.graph, builder: (c, s) => const GraphScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.solve, builder: (c, s) => const SolveScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.tools, builder: (c, s) => const ToolsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.history, builder: (c, s) => const HistoryScreen())]),
        ],
      ),
      ...secondaryRoutes(rootNavigatorKey),
    ],
  );
  // Remember the selected section for state restoration.
  router.routerDelegate.addListener(() {
    final loc = router.routerDelegate.currentConfiguration.uri.path;
    if (_primary.contains(loc)) store.setString('nav.section', loc);
  });
  return router;
});
