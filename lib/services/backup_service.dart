import 'dart:convert';

import 'package:math_engine/math_engine.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database/app_database.dart';
import '../data/settings/app_settings.dart';

/// Thrown when an imported file is not a valid backup.
class BackupFormatException implements Exception {
  const BackupFormatException(this.reason);
  final String reason;
  @override
  String toString() => 'BackupFormatException: $reason';
}

/// Local export/import of all user data as a JSON document (§103).
///
/// Imports are validated field by field (types, lengths, counts, and that
/// stored values decode) before anything is written, and are applied in a
/// single transaction, so a bad file can never leave partial data (§104).
class BackupService {
  BackupService(this._db);
  final AppDatabase _db;

  static const format = 'advanced-calculator-backup';
  static const version = 1;
  static const maxBytes = 20 * 1024 * 1024;
  static const _maxRows = 200000;

  Future<String> export(AppSettings settings) async {
    final d = _db.db;
    final doc = {
      'format': format,
      'version': version,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'history': await d.query('calculation_history', orderBy: 'id'),
      'favorites': await d.query('favorites', orderBy: 'id'),
      'variables': await d.query('saved_variables', orderBy: 'id'),
      'matrices': await d.query('saved_matrices', orderBy: 'id'),
      'functions': await d.query('saved_functions', orderBy: 'id'),
      'settings': settings.toJson(),
    };
    return const JsonEncoder.withIndent(' ').convert(doc);
  }

  /// Parses and validates; returns the settings contained in the backup.
  Future<AppSettings> import(String text) async {
    if (text.length > maxBytes) throw const BackupFormatException('file too large');
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw const BackupFormatException('not JSON');
    }
    if (root is! Map || root['format'] != format) throw const BackupFormatException('not a backup');
    final v = root['version'];
    if (v is! int || v < 1 || v > version) throw const BackupFormatException('unsupported version');

    final history = _rows(root['history'], _historyCols);
    final favorites = _rows(root['favorites'], _favoriteCols);
    final variables = _rows(root['variables'], _variableCols);
    final matrices = _rows(root['matrices'], _matrixCols);
    final functions = _rows(root['functions'], _functionCols);

    // Deep checks on stored values.
    for (final r in variables) {
      try {
        ValueCodec.decode(r['value'] as String);
      } on MathError {
        throw const BackupFormatException('invalid variable value');
      }
      if (!RegExp(r'^[A-Za-z_]\w{0,31}$').hasMatch(r['name'] as String)) {
        throw const BackupFormatException('invalid variable name');
      }
    }
    for (final r in matrices) {
      try {
        final data = jsonDecode(r['data'] as String);
        if (data is! List || data.length > 50 || data.any((row) => row is! List || row.length > 50)) {
          throw const BackupFormatException('invalid matrix');
        }
      } on FormatException {
        throw const BackupFormatException('invalid matrix');
      }
    }
    for (final r in functions) {
      if (!GraphType.values.any((t) => t.name == r['graph_type'])) {
        throw const BackupFormatException('invalid graph type');
      }
    }
    final settingsJson = root['settings'];
    final settings = settingsJson is Map<String, Object?> ? AppSettings.fromJson(settingsJson) : const AppSettings();

    await _db.db.transaction((txn) async {
      for (final t in const ['calculation_history', 'favorites', 'saved_variables', 'saved_matrices', 'saved_functions']) {
        await txn.delete(t);
      }
      Future<void> put(String table, List<Map<String, Object?>> rows) async {
        final b = txn.batch();
        for (final r in rows) {
          b.insert(table, Map.of(r)..remove('id'), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await b.commit(noResult: true);
      }

      await put('calculation_history', history);
      await put('favorites', favorites);
      await put('saved_variables', variables);
      await put('saved_matrices', matrices);
      await put('saved_functions', functions);
    });
    return settings.copyWith(onboardingDone: true);
  }

  // Column specs: name → (type, required, max length for strings)
  static const _historyCols = {
    'expression': (String, true, 5000),
    'expression_latex': (String, false, 20000),
    'result': (String, true, 200000),
    'result_latex': (String, false, 200000),
    'result_value': (String, false, 2000000),
    'mode': (String, true, 40),
    'angle_mode': (String, true, 10),
    'format': (String, true, 20),
    'created_at': (int, true, 0),
    'is_favorite': (int, false, 0),
    'editor_state': (String, false, 200000),
  };
  static const _favoriteCols = {
    'type': (String, true, 20),
    'reference_id': (String, true, 200),
    'created_at': (int, true, 0),
  };
  static const _variableCols = {
    'name': (String, true, 32),
    'value': (String, true, 2000000),
    'type': (String, true, 40),
    'updated_at': (int, true, 0),
  };
  static const _matrixCols = {
    'name': (String, true, 32),
    'rows': (int, true, 0),
    'columns': (int, true, 0),
    'data': (String, true, 500000),
    'created_at': (int, true, 0),
    'updated_at': (int, true, 0),
  };
  static const _functionCols = {
    'name': (String, true, 64),
    'expression': (String, true, 5000),
    'expression_y': (String, false, 5000),
    'graph_type': (String, true, 20),
    'color': (int, false, 0),
    'visible': (int, false, 0),
    't_min': (num, false, 0),
    't_max': (num, false, 0),
    'sort_order': (int, false, 0),
    'created_at': (int, true, 0),
    'updated_at': (int, true, 0),
  };

  List<Map<String, Object?>> _rows(Object? list, Map<String, (Type, bool, int)> cols) {
    if (list == null) return const [];
    if (list is! List || list.length > _maxRows) throw const BackupFormatException('invalid table');
    final out = <Map<String, Object?>>[];
    for (final item in list) {
      if (item is! Map) throw const BackupFormatException('invalid row');
      final row = <String, Object?>{};
      for (final MapEntry(key: name, value: spec) in cols.entries) {
        final (type, required, maxLen) = spec;
        final v = item[name];
        if (v == null) {
          if (required) throw BackupFormatException('missing $name');
          continue;
        }
        final ok = switch (type) {
          const (String) => v is String && v.length <= maxLen,
          const (int) => v is int,
          _ => v is num && v.isFinite,
        };
        if (!ok) throw BackupFormatException('invalid $name');
        row[name] = v;
      }
      out.add(row);
    }
    return out;
  }
}
