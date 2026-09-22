import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/database/app_database.dart';
import 'data/repositories/user_data_repositories.dart';
import 'data/settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = SettingsStore(prefs);
  final db = await AppDatabase.open();

  final variablesRepo = VariablesRepository(db);
  final variables = await variablesRepo.all();
  // Memory M is kept across restarts only when the user wants it (§57).
  if (!store.load().memoryPersists && variables.containsKey('M')) {
    variables.remove('M');
    await variablesRepo.delete('M');
  }
  final functions = await FunctionsRepository(db).all();

  runApp(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      settingsStoreProvider.overrideWithValue(store),
      initialVariablesProvider.overrideWithValue(variables),
      initialFunctionsProvider.overrideWithValue(functions),
    ],
    child: const AdvancedCalculatorApp(),
  ));
}
