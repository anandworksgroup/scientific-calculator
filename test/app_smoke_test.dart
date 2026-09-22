import 'package:advanced_calculator/app/app.dart';
import 'package:advanced_calculator/app/providers.dart';
import 'package:advanced_calculator/app/router.dart';
import 'package:advanced_calculator/app/routes.dart';
import 'package:advanced_calculator/app/tools_registry.dart';
import 'package:advanced_calculator/data/repositories/user_data_repositories.dart';
import 'package:advanced_calculator/data/settings/app_settings.dart';
import 'package:advanced_calculator/features/graph/graph_screen.dart';
import 'package:advanced_calculator/features/history/history_screen.dart';
import 'package:advanced_calculator/features/premium/premium_screen.dart';
import 'package:advanced_calculator/features/search/search_screen.dart';
import 'package:advanced_calculator/features/settings/settings_screens.dart';
import 'package:advanced_calculator/features/user_data/favorites_screen.dart';
import 'package:advanced_calculator/features/user_data/functions_screen.dart';
import 'package:advanced_calculator/features/user_data/variables_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  late TestDeps deps;
  setUp(() async => deps = await TestDeps.create());
  tearDown(() => deps.db.close());

  void size(WidgetTester t, Size s) {
    t.view.physicalSize = s * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  final screens = <String, Widget Function()>{
    'settings': () => const SettingsScreen(),
    'calc settings': () => const CalculatorSettingsScreen(),
    'appearance': () => const AppearanceSettingsScreen(),
    'graph settings': () => const GraphSettingsScreen(),
    'backup': () => const BackupScreen(),
    'privacy': () => const PrivacyScreen(),
    'about': () => const AboutScreen(),
    'premium': () => const PremiumScreen(),
    'variables': () => const VariablesScreen(),
    'functions': () => const FunctionsScreen(),
    'favorites': () => const FavoritesScreen(),
    'search': () => const SearchScreen(),
    'history': () => const HistoryScreen(),
    'graph': () => const GraphScreen(),
  };

  for (final b in Brightness.values) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} builds (${b.name})', (t) async {
        size(t, const Size(412, 915));
        await t.pumpWidget(testApp(deps, entry.value(), brightness: b));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('graph plots saved functions on phone and tablet', (t) async {
    await FunctionsRepository(deps.db).save(const SavedFunction(name: 'f', expression: 'sin(x)'));
    await FunctionsRepository(deps.db).save(const SavedFunction(name: '', expression: 'tan(x)', color: 1));
    final funcs = await FunctionsRepository(deps.db).all();
    for (final s in const [Size(412, 915), Size(1280, 800)]) {
      size(t, s);
      await t.pumpWidget(ProviderScope(
        overrides: [...deps.overrides().cast(), initialFunctionsProvider.overrideWithValue(funcs)],
        child: testApp(deps, const GraphScreen()),
      ));
      await t.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('search finds quadratic tools and formulas', (t) async {
    size(t, const Size(412, 915));
    await t.pumpWidget(testApp(deps, const SearchScreen()));
    await t.enterText(find.byType(TextField), 'quadratic');
    await t.pumpAndSettle();
    expect(find.text('Polynomial'), findsWidgets);
    expect(find.textContaining('Quadratic'), findsWidgets);
  });

  testWidgets('every secondary route opens without errors', (t) async {
    size(t, const Size(412, 915));
    await t.pumpWidget(ProviderScope(overrides: [...deps.overrides().cast()], child: const AdvancedCalculatorApp()));
    await t.pumpAndSettle();
    final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    final router = container.read(routerProvider);
    final routes = <String>{
      for (final tool in allTools) tool.route,
      Routes.search, Routes.settings, Routes.settingsCalculator, Routes.settingsAppearance,
      Routes.settingsGraph, Routes.backup, Routes.privacy, Routes.about, Routes.premium,
      Routes.formula('mechanics.kinetic_energy'), '${Routes.table}?f=x%5E2', '${Routes.converter}?category=temperature',
    }..remove(Routes.graph);
    for (final r in routes) {
      router.push(r);
      await t.pumpAndSettle();
      final e = t.takeException();
      if (e != null) debugPrint('[$r] $e');
      expect(e, isNull, reason: r);
      expect(find.byType(Scaffold), findsWidgets, reason: r);
      router.pop();
      await t.pumpAndSettle();
    }
  });

  testWidgets('full app: onboarding then navigation across sections', (t) async {
    final fresh = await TestDeps.create(settings: const AppSettings());
    size(t, const Size(412, 915));
    await t.pumpWidget(ProviderScope(overrides: [...fresh.overrides().cast()], child: const AdvancedCalculatorApp()));
    await t.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
    await t.tap(find.text('Get Started'));
    await t.pumpAndSettle();
    for (final tab in ['Scientific', 'Graph', 'Solve', 'Tools', 'History', 'Calculator']) {
      await t.tap(find.byTooltip(tab).last);
      await t.pumpAndSettle();
      final e = t.takeException();
      if (e is FlutterError) debugPrint('[$tab] ${e.toStringDeep()}');
      expect(e, isNull, reason: tab);
    }
    await fresh.db.close();
  });
}
