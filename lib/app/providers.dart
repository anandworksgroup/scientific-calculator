import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../data/database/app_database.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/user_data_repositories.dart';
import '../data/settings/app_settings.dart';
import '../data/settings/settings_store.dart';
import '../services/engine_service.dart';
import '../services/feedback_service.dart';
import '../services/purchase_service.dart';

/// Overridden in main() after the database is opened.
final appDatabaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('database not opened'));

/// Overridden in main() after SharedPreferences is loaded.
final settingsStoreProvider = Provider<SettingsStore>((ref) => throw UnimplementedError('settings not loaded'));

/// Values loaded at startup (overridden in main()).
final initialVariablesProvider = Provider<Map<String, Value>>((ref) => const {});
final initialFunctionsProvider = Provider<List<SavedFunction>>((ref) => const []);

final historyRepositoryProvider = Provider((ref) => HistoryRepository(ref.watch(appDatabaseProvider)));
final variablesRepositoryProvider = Provider((ref) => VariablesRepository(ref.watch(appDatabaseProvider)));
final matricesRepositoryProvider = Provider((ref) => MatricesRepository(ref.watch(appDatabaseProvider)));
final functionsRepositoryProvider = Provider((ref) => FunctionsRepository(ref.watch(appDatabaseProvider)));
final favoritesRepositoryProvider = Provider((ref) => FavoritesRepository(ref.watch(appDatabaseProvider)));
final conversionsRepositoryProvider = Provider((ref) => ConversionsRepository(ref.watch(appDatabaseProvider)));

final engineServiceProvider = Provider((ref) => const EngineService());
final feedbackServiceProvider = Provider((ref) => const FeedbackService());

// ------------------------------------------------------------------ settings

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsStoreProvider).load();

  void update(AppSettings Function(AppSettings s) change) {
    state = change(state);
    ref.read(settingsStoreProvider).save(state);
  }

  Future<void> reset() async {
    final keepOnboarding = state.onboardingDone;
    await ref.read(settingsStoreProvider).reset();
    state = const AppSettings().copyWith(onboardingDone: keepOnboarding);
    await ref.read(settingsStoreProvider).save(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ----------------------------------------------------------------- variables

/// Names that users cannot use for their own variables.
const reservedNames = {'pi', 'e', 'phi', 'i', 'inf', 'Ans', 'PreAns', 'x', 'y', 't', 'θ'};

class VariablesNotifier extends Notifier<Map<String, Value>> {
  @override
  Map<String, Value> build() => Map.of(ref.read(initialVariablesProvider));

  VariablesRepository get _repo => ref.read(variablesRepositoryProvider);

  Future<void> set(String name, Value value) async {
    state = {...state, name: value};
    final persistMemory = ref.read(settingsProvider).memoryPersists;
    if (name == 'M' && !persistMemory) return;
    await _repo.put(name, value);
  }

  Future<void> remove(String name) async {
    state = Map.of(state)..remove(name);
    await _repo.delete(name);
  }

  /// Applies variables changed by an evaluation (assignments).
  Future<void> applyFrom(Map<String, Value> after, {Set<String> only = const {}}) async {
    for (final name in only) {
      final v = after[name];
      if (v != null) await set(name, v);
    }
  }

  Future<void> clearAll() async {
    for (final k in state.keys.toList()) {
      await _repo.delete(k);
    }
    state = {};
  }
}

final variablesProvider = NotifierProvider<VariablesNotifier, Map<String, Value>>(VariablesNotifier.new);

// ----------------------------------------------------------------- functions

/// Free users can keep this many saved functions/graphs.
const freeFunctionLimit = 12;

class FunctionsNotifier extends Notifier<List<SavedFunction>> {
  @override
  List<SavedFunction> build() => List.of(ref.read(initialFunctionsProvider));

  FunctionsRepository get _repo => ref.read(functionsRepositoryProvider);

  bool get atFreeLimit => !ref.read(premiumProvider).isPremium && state.length >= freeFunctionLimit;

  /// Adds or updates. Returns false when the free limit prevents adding.
  Future<bool> save(SavedFunction f) async {
    if (f.id == null && atFreeLimit) return false;
    final order = f.id == null ? (state.isEmpty ? 0 : state.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1) : f.sortOrder;
    final withOrder = f.copyWith(sortOrder: order);
    final id = await _repo.save(withOrder);
    final saved = withOrder.copyWith(id: id);
    final idx = state.indexWhere((e) => e.id == id);
    state = idx >= 0 ? ([...state]..[idx] = saved) : [...state, saved];
    return true;
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    state = state.where((f) => f.id != id).toList();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    final updated = [for (var k = 0; k < list.length; k++) list[k].copyWith(sortOrder: k)];
    state = updated;
    for (final f in updated) {
      await _repo.save(f);
    }
  }

  Future<void> reload() async => state = await _repo.all();
}

final functionsProvider = NotifierProvider<FunctionsNotifier, List<SavedFunction>>(FunctionsNotifier.new);

/// Engine environment: variables + saved function definitions.
final environmentProvider = Provider<Environment>((ref) {
  final vars = ref.watch(variablesProvider);
  final funcs = ref.watch(functionsProvider);
  final seed = ref.watch(settingsProvider.select((s) => s.randomSeed));
  return Environment(
    variables: Map.of(vars),
    functions: {
      for (final f in funcs)
        if (f.definition != null) f.baseName: f.definition!,
    },
    randomSeed: seed,
  );
});
