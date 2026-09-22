import 'package:advanced_calculator/data/repositories/history_repository.dart';
import 'package:advanced_calculator/data/repositories/user_data_repositories.dart';
import 'package:advanced_calculator/data/settings/app_settings.dart';
import 'package:advanced_calculator/services/backup_service.dart';
import 'package:advanced_calculator/services/clipboard_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_engine/math_engine.dart';

import 'helpers/test_app.dart';

HistoryEntry entry(String expr, {DateTime? at, bool fav = false}) => HistoryEntry(
      expression: expr,
      expressionLatex: expr,
      result: '1',
      resultLatex: '1',
      mode: 'calculator',
      angleMode: 'deg',
      format: 'auto',
      createdAt: at ?? DateTime.now(),
      isFavorite: fav,
    );

void main() {
  late TestDeps deps;
  setUp(() async => deps = await TestDeps.create());
  tearDown(() => deps.db.close());

  test('history insert, search, favorite, trim', () async {
    final repo = HistoryRepository(deps.db);
    for (var k = 0; k < 10; k++) {
      await repo.insert(entry('$k+1', at: DateTime(2026, 1, 1, 0, k)));
    }
    final list = await repo.list();
    expect(list.first.expression, '9+1');
    expect((await repo.list(query: '5+')).single.expression, '5+1');
    await repo.setFavorite(list.last.id!, true);
    await repo.trimTo(3);
    final after = await repo.list();
    expect(after.length, 4); // 3 newest + the favorite
    expect(after.any((e) => e.isFavorite), isTrue);
    await repo.clear();
    expect((await repo.list()).single.isFavorite, isTrue);
  });

  test('variables are stored losslessly', () async {
    final repo = VariablesRepository(deps.db);
    final pi50 = Arith(precision: 50).pi();
    await repo.put('A', NumberValue(Rat.frac(1, 3)));
    await repo.put('B', NumberValue(pi50));
    await repo.put('MatA', MatrixValue([[Rat.one, Rat.two], [Rat.int(3), Rat.int(4)]]));
    final all = await repo.all();
    expect((all['A'] as NumberValue).n, Rat.frac(1, 3));
    expect((all['B'] as NumberValue).n, pi50);
    expect(all['MatA'], isA<MatrixValue>());
  });

  test('functions and favorites repositories', () async {
    final f = FunctionsRepository(deps.db);
    final id = await f.save(const SavedFunction(name: 'f', expression: 'x^2'));
    expect((await f.all()).single.definition, 'f(x)=x^2');
    await f.save(SavedFunction(id: id, name: 'f', expression: 'x^3'));
    expect((await f.all()).single.expression, 'x^3');
    final fav = FavoritesRepository(deps.db);
    await fav.set(FavoriteType.formula, 'mechanics.kinetic_energy', true);
    await fav.set(FavoriteType.formula, 'mechanics.kinetic_energy', true);
    expect(await fav.ids(FavoriteType.formula), {'mechanics.kinetic_energy'});
  });

  test('backup export → import round trip', () async {
    await HistoryRepository(deps.db).insert(entry('2+2'));
    await VariablesRepository(deps.db).put('X', NumberValue(Rat.int(42)));
    await FunctionsRepository(deps.db).save(const SavedFunction(name: 'g', expression: 'sin(x)'));
    final svc = BackupService(deps.db);
    final json = await svc.export(const AppSettings(precision: 20, onboardingDone: true));
    await deps.db.clearAll();
    final settings = await svc.import(json);
    expect(settings.precision, 20);
    expect((await HistoryRepository(deps.db).list()).single.expression, '2+2');
    expect((await VariablesRepository(deps.db).all())['X'], NumberValue(Rat.int(42)));
    expect((await FunctionsRepository(deps.db).all()).single.name, 'g');
  });

  test('invalid backups are rejected without touching data', () async {
    await HistoryRepository(deps.db).insert(entry('keep'));
    final svc = BackupService(deps.db);
    for (final bad in [
      'not json',
      '{"format":"other"}',
      '{"format":"advanced-calculator-backup","version":99}',
      '{"format":"advanced-calculator-backup","version":1,"history":[{"expression":5}]}',
      '{"format":"advanced-calculator-backup","version":1,"variables":[{"name":"x","value":"{}","type":"n","updated_at":1}]}',
    ]) {
      await expectLater(svc.import(bad), throwsA(isA<BackupFormatException>()), reason: bad);
    }
    expect((await HistoryRepository(deps.db).list()).single.expression, 'keep');
  });

  test('settings JSON tolerates garbage', () {
    final s = AppSettings.fromJson({'precision': 7, 'fontScale': 'big', 'angleMode': 'rad', 'quickAccess': [1, 'graph']});
    expect(s.precision, 10);
    expect(s.fontScale, 1.0);
    expect(s.angleMode, AngleMode.rad);
    expect(s.quickAccess, ['graph']);
  });

  test('clipboard sanitizing', () {
    expect(ClipboardService.sanitize('1,234,567.5'), '1234567.5');
    expect(ClipboardService.sanitize('2×3−1​'), '2*3-1');
    expect(ClipboardService.sanitize('rm -rf /; <script>'), 'rm -rf /; <script>'.replaceAll(RegExp(r'[^A-Za-z0-9 \-/;<>]'), ''));
    expect(ClipboardService.sanitize('x**2'), 'x^2');
  });
}
