// Renders real app screens to docs/screenshots/*.png.
//
// Uses the actual app (router, providers, engine) with the real Roboto,
// Material Icons and KaTeX fonts, at a 1080×2400 phone resolution.
// Skipped in normal test runs; generate with:
//   SCREENSHOTS=1 flutter test test/screenshots/generate_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:advanced_calculator/app/app.dart';
import 'package:advanced_calculator/app/providers.dart';
import 'package:advanced_calculator/app/router.dart';
import 'package:advanced_calculator/app/routes.dart';
import 'package:advanced_calculator/data/repositories/user_data_repositories.dart';
import 'package:advanced_calculator/data/settings/app_settings.dart';
import 'package:advanced_calculator/features/calculator/calculator_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_app.dart';

final _enabled = Platform.environment['SCREENSHOTS'] == '1';
const _out = 'docs/screenshots';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await _loadFont('Roboto', [
    '$material/roboto-regular.ttf',
    '$material/roboto-medium.ttf',
    '$material/roboto-bold.ttf',
  ]);
  await _loadFont('MaterialIcons', ['$material/materialicons-regular.otf']);
  final pub = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['LOCALAPPDATA']}/Pub/Cache';
  final katex = Directory('$pub/hosted/pub.dev/flutter_math_fork-0.7.4/lib/katex_fonts/fonts');
  final byFamily = <String, List<String>>{};
  for (final f in katex.listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    final name = f.uri.pathSegments.last.split('-').first; // KaTeX_Main
    byFamily.putIfAbsent('packages/flutter_math_fork/$name', () => []).add(f.path);
  }
  for (final e in byFamily.entries) {
    await _loadFont(e.key, e.value);
  }
}

void main() {
  late TestDeps deps;

  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  setUp(() async => deps = await TestDeps.create());
  tearDown(() => deps.db.close());

  Future<ProviderContainer> launch(WidgetTester t, {Size size = const Size(411.4, 914.3), AppSettings? settings}) async {
    t.view.physicalSize = Size(size.width * 2.625, size.height * 2.625);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    if (settings != null) await deps.store.save(settings);
    // Start every launch on the calculator (the app restores the last section).
    await deps.store.setString('nav.section', Routes.calculator);
    final funcs = await FunctionsRepository(deps.db).all();
    await t.pumpWidget(ProviderScope(
      overrides: [...deps.overrides().cast(), initialFunctionsProvider.overrideWithValue(funcs)],
      child: const RepaintBoundary(child: AdvancedCalculatorApp()),
    ));
    await t.pumpAndSettle();
    return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  }

  Future<void> settle(WidgetTester t, [int ms = 800]) async {
    await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await t.pumpAndSettle();
  }

  Future<void> shot(WidgetTester t, String name) async {
    await t.pumpAndSettle();
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(_out).createSync(recursive: true);
      File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  GoRouter router(ProviderContainer c) => c.read(routerProvider);

  testWidgets('screenshots', (t) async {
    // Seed saved functions for the graph screen.
    final f = FunctionsRepository(deps.db);
    await f.save(const SavedFunction(name: 'f', expression: 'sin(x)', color: 0, sortOrder: 0));
    await f.save(const SavedFunction(name: 'g', expression: 'x^2/4-2', color: 1, sortOrder: 1));
    await f.save(const SavedFunction(name: '', expression: '1/x', color: 2, sortOrder: 2));

    var c = await launch(t, settings: const AppSettings(onboardingDone: true));
    final calc = c.read(calculatorProvider.notifier);

    // 1. Calculator: textbook input and exact result.
    calc.loadExpression('sin(45)+sqrt(16)');
    await calc.evaluate();
    await settle(t);
    await shot(t, '01_calculator');

    // 2. Fractions shown exactly.
    calc.loadExpression('1/2+3/4');
    await calc.evaluate();
    await settle(t);
    await shot(t, '02_fractions');

    // 3. Equation typed in the calculator is solved.
    calc.loadExpression('x^2-5x+6=0');
    await calc.evaluate();
    await settle(t);
    await shot(t, '03_calculator_equation');

    // 4. Scientific palettes.
    router(c).go(Routes.scientific);
    await settle(t);
    await shot(t, '04_scientific');

    // 5. Graphing.
    router(c).go(Routes.graph);
    await settle(t, 1500);
    await shot(t, '05_graph');

    // 6. Solve hub.
    router(c).go(Routes.solve);
    await settle(t);
    await shot(t, '06_solve');

    // 7. Equation solver with steps.
    router(c).push('${Routes.equation}?eq=${Uri.encodeComponent('x^2-5x+3=0')}');
    await settle(t);
    await t.tap(find.text('Solve').last);
    await settle(t, 2000);
    await shot(t, '07_equation_solver');
    router(c).pop();
    await settle(t);

    // 8. Tools.
    router(c).go(Routes.tools);
    await settle(t);
    await shot(t, '08_tools');

    // 9–13. Tool screens.
    for (final (route, name) in [
      (Routes.matrix, '09_matrix'),
      ('${Routes.converter}?category=temperature', '10_converter'),
      (Routes.formula('mechanics.kinetic_energy'), '11_formula'),
      (Routes.programmer, '12_programmer'),
      (Routes.statistics, '13_statistics'),
      (Routes.constants, '14_constants'),
    ]) {
      router(c).push(route);
      await settle(t);
      await shot(t, name);
      router(c).pop();
      await settle(t);
    }

    // 15. History.
    router(c).go(Routes.history);
    await settle(t);
    await shot(t, '15_history');

    // 16. Dark theme calculator.
    await t.pumpWidget(const SizedBox());
    c = await launch(t, settings: const AppSettings(onboardingDone: true, themeMode: AppThemeMode.dark));
    final calc2 = c.read(calculatorProvider.notifier);
    calc2.loadExpression('integral(x^2,x,0,1)+sum(x,x,1,100)');
    await calc2.evaluate();
    await settle(t);
    await shot(t, '16_calculator_dark');

    // 17. Tablet: calculator with history side by side.
    await t.pumpWidget(const SizedBox());
    c = await launch(t, size: const Size(1280, 800), settings: const AppSettings(onboardingDone: true));
    await shot(t, '17_tablet');

    // 18. First launch.
    await t.pumpWidget(const SizedBox());
    c = await launch(t, settings: const AppSettings());
    await shot(t, '18_welcome');
  }, skip: !_enabled);
}
