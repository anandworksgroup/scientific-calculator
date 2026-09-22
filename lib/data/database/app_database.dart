import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database (all user data stays on the device).
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const fileName = 'advanced_calculator.db';
  static const version = 1;

  /// Opens (and creates/migrates) the database. [factory] and [path] are
  /// injectable for tests (sqflite_common_ffi in-memory databases).
  static Future<AppDatabase> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, v) => _create(db),
        onUpgrade: (db, oldV, newV) async {
          // Future schema migrations go here, stepwise per version.
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _create(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE calculation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expression TEXT NOT NULL,
        expression_latex TEXT NOT NULL DEFAULT '',
        result TEXT NOT NULL,
        result_latex TEXT NOT NULL DEFAULT '',
        result_value TEXT,
        mode TEXT NOT NULL,
        angle_mode TEXT NOT NULL,
        format TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        editor_state TEXT
      )''');
    batch.execute('CREATE INDEX idx_history_created ON calculation_history(created_at DESC)');
    batch.execute('''
      CREATE TABLE saved_variables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        type TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE saved_matrices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        rows INTEGER NOT NULL,
        columns INTEGER NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE saved_functions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        expression TEXT NOT NULL,
        expression_y TEXT NOT NULL DEFAULT '',
        graph_type TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0,
        visible INTEGER NOT NULL DEFAULT 1,
        t_min REAL NOT NULL DEFAULT 0,
        t_max REAL NOT NULL DEFAULT 6.283185307179586,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        reference_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(type, reference_id)
      )''');
    batch.execute('''
      CREATE TABLE recent_conversions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        from_unit TEXT NOT NULL,
        to_unit TEXT NOT NULL,
        input_value TEXT NOT NULL,
        result TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
    await batch.commit(noResult: true);
  }

  Future<void> close() => db.close();

  /// Deletes every user record (used by "Clear all data").
  Future<void> clearAll() async {
    final batch = db.batch();
    for (final t in const [
      'calculation_history',
      'saved_variables',
      'saved_matrices',
      'saved_functions',
      'favorites',
      'recent_conversions',
      'settings',
    ]) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }
}
