import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Loads and saves [AppSettings] (and small UI state) in SharedPreferences.
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'settings.v1';

  AppSettings load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return AppSettings.fromJson(decoded);
    } on FormatException {
      // Corrupted settings: fall back to defaults.
    }
    return const AppSettings();
  }

  Future<void> save(AppSettings s) => _prefs.setString(_key, jsonEncode(s.toJson()));

  Future<void> reset() => _prefs.remove(_key);

  // Lightweight UI state (state restoration, §102).
  String? getString(String key) => _prefs.getString('ui.$key');
  Future<void> setString(String key, String value) => _prefs.setString('ui.$key', value);
  Future<void> remove(String key) => _prefs.remove('ui.$key');
}
