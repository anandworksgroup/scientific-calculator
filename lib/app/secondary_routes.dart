import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/calculus/derivative_screen.dart';
import '../features/calculus/integral_screen.dart';
import '../features/calculus/limit_screen.dart';
import '../features/calculus/series_screen.dart';
import '../features/stats/probability_screen.dart';
import '../features/stats/statistics_screen.dart';
import '../features/table/function_table_screen.dart';
import '../features/constants/constants_screen.dart';
import '../features/converter/converter_screen.dart';
import '../features/formulas/formula_detail_screen.dart';
import '../features/formulas/formulas_screen.dart';
import '../features/number_theory/number_theory_screen.dart';
import '../features/programmer/programmer_screen.dart';
import '../features/random/random_screen.dart';
import '../features/linalg/complex_screen.dart';
import '../features/linalg/matrix_screen.dart';
import '../features/linalg/vector_screen.dart';
import '../features/premium/premium_screen.dart';
import '../features/solve/cas_screen.dart';
import '../features/solve/equation_screen.dart';
import '../features/solve/polynomial_screen.dart';
import '../features/solve/system_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screens.dart';
import '../features/user_data/favorites_screen.dart';
import '../features/user_data/functions_screen.dart';
import '../features/user_data/variables_screen.dart';
import 'routes.dart';

/// Full-screen routes pushed above the main navigation.
List<RouteBase> secondaryRoutes(GlobalKey<NavigatorState> root) {
  GoRoute page(String path, Widget Function(GoRouterState s) build) =>
      GoRoute(path: path, parentNavigatorKey: root, builder: (context, state) => build(state));

  return [
    for (final entry in _pages.entries) page(entry.key, entry.value),
  ];
}

/// Route path → screen builder.
final Map<String, Widget Function(GoRouterState s)> _pages = {
  Routes.search: (s) => const SearchScreen(),
  Routes.settings: (s) => const SettingsScreen(),
  Routes.settingsCalculator: (s) => const CalculatorSettingsScreen(),
  Routes.settingsAppearance: (s) => const AppearanceSettingsScreen(),
  Routes.settingsGraph: (s) => const GraphSettingsScreen(),
  Routes.backup: (s) => const BackupScreen(),
  Routes.privacy: (s) => const PrivacyScreen(),
  Routes.about: (s) => const AboutScreen(),
  Routes.premium: (s) => const PremiumScreen(),
  Routes.variables: (s) => const VariablesScreen(),
  Routes.functions: (s) => const FunctionsScreen(),
  Routes.favorites: (s) => const FavoritesScreen(),
  Routes.matrix: (s) => MatrixScreen(initialSlot: s.uri.queryParameters['slot']),
  Routes.vector: (s) => const VectorScreen(),
  Routes.converter: (s) => ConverterScreen(initialCategory: s.uri.queryParameters['category']),
  Routes.constants: (s) => const ConstantsScreen(),
  Routes.formulas: (s) => const FormulasScreen(),
  '${Routes.formulas}/:id': (s) => FormulaDetailScreen(formulaId: s.pathParameters['id'] ?? ''),
  Routes.programmer: (s) => const ProgrammerScreen(),
  Routes.numberTheory: (s) => const NumberTheoryScreen(),
  Routes.random: (s) => const RandomScreen(),
  Routes.derivative: (s) => const DerivativeScreen(),
  Routes.integral: (s) => const IntegralScreen(),
  Routes.limit: (s) => const LimitScreen(),
  Routes.series: (s) => const SeriesScreen(),
  Routes.statistics: (s) => const StatisticsScreen(),
  Routes.probability: (s) => const ProbabilityScreen(),
  Routes.table: (s) => FunctionTableScreen(initialExpression: s.uri.queryParameters['f']),
  Routes.equation: (s) => EquationScreen(initialEquation: s.uri.queryParameters['eq']),
  Routes.polynomial: (s) => PolynomialScreen(initialDegree: int.tryParse(s.uri.queryParameters['degree'] ?? '') ?? 2),
  Routes.system: (s) => SystemScreen(initialSize: int.tryParse(s.uri.queryParameters['n'] ?? '') ?? 2),
  Routes.cas: (s) => CasScreen(initialExpression: s.uri.queryParameters['expr'], initialOperation: s.uri.queryParameters['op']),
  Routes.complex: (s) => const ComplexScreen(),
};
