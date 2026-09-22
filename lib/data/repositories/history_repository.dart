import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.expression,
    required this.expressionLatex,
    required this.result,
    required this.resultLatex,
    this.resultValue,
    required this.mode,
    required this.angleMode,
    required this.format,
    required this.createdAt,
    this.isFavorite = false,
    this.editorState,
  });

  final int? id;

  /// Engine-syntax expression (re-parseable).
  final String expression;
  final String expressionLatex;

  /// Display text of the result.
  final String result;
  final String resultLatex;

  /// Lossless encoded result value (ValueCodec), when available.
  final String? resultValue;

  /// Which module produced it: calculator, scientific, solve, …
  final String mode;
  final String angleMode;
  final String format;
  final DateTime createdAt;
  final bool isFavorite;

  /// Serialized editor tokens so the entry can be re-edited structurally.
  final String? editorState;

  HistoryEntry copyWith({bool? isFavorite}) => HistoryEntry(
        id: id,
        expression: expression,
        expressionLatex: expressionLatex,
        result: result,
        resultLatex: resultLatex,
        resultValue: resultValue,
        mode: mode,
        angleMode: angleMode,
        format: format,
        createdAt: createdAt,
        isFavorite: isFavorite ?? this.isFavorite,
        editorState: editorState,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'expression': expression,
        'expression_latex': expressionLatex,
        'result': result,
        'result_latex': resultLatex,
        'result_value': resultValue,
        'mode': mode,
        'angle_mode': angleMode,
        'format': format,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_favorite': isFavorite ? 1 : 0,
        'editor_state': editorState,
      };

  factory HistoryEntry.fromRow(Map<String, Object?> r) => HistoryEntry(
        id: r['id'] as int?,
        expression: r['expression'] as String? ?? '',
        expressionLatex: r['expression_latex'] as String? ?? '',
        result: r['result'] as String? ?? '',
        resultLatex: r['result_latex'] as String? ?? '',
        resultValue: r['result_value'] as String?,
        mode: r['mode'] as String? ?? 'calculator',
        angleMode: r['angle_mode'] as String? ?? 'deg',
        format: r['format'] as String? ?? 'auto',
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int? ?? 0),
        isFavorite: (r['is_favorite'] as int? ?? 0) == 1,
        editorState: r['editor_state'] as String?,
      );
}

class HistoryRepository {
  HistoryRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  Future<int> insert(HistoryEntry e, {int? limit}) async {
    final id = await _d.insert('calculation_history', e.toRow()..remove('id'));
    if (limit != null) await trimTo(limit);
    return id;
  }

  /// Newest first. [query] matches expression or result text.
  Future<List<HistoryEntry>> list({int limit = 500, int offset = 0, String? query, bool favoritesOnly = false}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (query != null && query.trim().isNotEmpty) {
      where.add('(expression LIKE ? OR result LIKE ?)');
      final q = '%${query.trim().replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
      args.addAll([q, q]);
    }
    if (favoritesOnly) where.add('is_favorite = 1');
    final rows = await _d.query(
      'calculation_history',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(HistoryEntry.fromRow).toList();
  }

  Future<HistoryEntry?> byId(int id) async {
    final rows = await _d.query('calculation_history', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : HistoryEntry.fromRow(rows.first);
  }

  Future<void> setFavorite(int id, bool favorite) =>
      _d.update('calculation_history', {'is_favorite': favorite ? 1 : 0}, where: 'id = ?', whereArgs: [id]);

  Future<void> delete(int id) => _d.delete('calculation_history', where: 'id = ?', whereArgs: [id]);

  /// Deletes everything except favorites unless [includeFavorites].
  Future<void> clear({bool includeFavorites = false}) =>
      _d.delete('calculation_history', where: includeFavorites ? null : 'is_favorite = 0');

  Future<int> count() async =>
      Sqflite.firstIntValue(await _d.rawQuery('SELECT COUNT(*) FROM calculation_history')) ?? 0;

  /// Keeps the newest [limit] non-favorite entries.
  Future<void> trimTo(int limit) => _d.rawDelete('''
        DELETE FROM calculation_history WHERE is_favorite = 0 AND id NOT IN (
          SELECT id FROM calculation_history WHERE is_favorite = 0 ORDER BY created_at DESC, id DESC LIMIT ?
        )''', [limit]);

  Future<List<Map<String, Object?>>> exportRows() => _d.query('calculation_history', orderBy: 'id');
}
