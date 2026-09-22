import 'dart:convert';

import 'package:math_engine/math_engine.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

/// Variables (A–F, X, Y, M, Ans, named) stored losslessly.
class VariablesRepository {
  VariablesRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  Future<Map<String, Value>> all() async {
    final rows = await _d.query('saved_variables', orderBy: 'name');
    final out = <String, Value>{};
    for (final r in rows) {
      try {
        out[r['name'] as String] = ValueCodec.decode(r['value'] as String);
      } on MathError {
        // Skip corrupted rows rather than failing startup.
      }
    }
    return out;
  }

  Future<void> put(String name, Value value) => _d.insert(
        'saved_variables',
        {
          'name': name,
          'value': ValueCodec.encode(value),
          'type': value.typeName,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> delete(String name) => _d.delete('saved_variables', where: 'name = ?', whereArgs: [name]);

  Future<List<Map<String, Object?>>> exportRows() => _d.query('saved_variables', orderBy: 'id');
}

class SavedMatrix {
  const SavedMatrix({this.id, required this.name, required this.cells});
  final int? id;
  final String name;

  /// Cell input text (may contain expressions such as 1/3 or √2).
  final List<List<String>> cells;

  int get rows => cells.length;
  int get columns => cells.isEmpty ? 0 : cells.first.length;
}

class MatricesRepository {
  MatricesRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  Future<List<SavedMatrix>> all() async {
    final rows = await _d.query('saved_matrices', orderBy: 'name');
    final out = <SavedMatrix>[];
    for (final r in rows) {
      try {
        final data = (jsonDecode(r['data'] as String) as List)
            .map((row) => (row as List).map((c) => '$c').toList())
            .toList();
        out.add(SavedMatrix(id: r['id'] as int, name: r['name'] as String, cells: data));
      } on Object {
        continue;
      }
    }
    return out;
  }

  Future<void> save(SavedMatrix m) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _d.insert(
      'saved_matrices',
      {
        'name': m.name,
        'rows': m.rows,
        'columns': m.columns,
        'data': jsonEncode(m.cells),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String name) => _d.delete('saved_matrices', where: 'name = ?', whereArgs: [name]);

  Future<List<Map<String, Object?>>> exportRows() => _d.query('saved_matrices', orderBy: 'id');
}

class SavedFunction {
  const SavedFunction({
    this.id,
    required this.name,
    required this.expression,
    this.expressionY = '',
    this.graphType = GraphType.cartesian,
    this.color = 0,
    this.visible = true,
    this.tMin = 0,
    this.tMax = 6.283185307179586,
    this.sortOrder = 0,
  });

  final int? id;

  /// Function name (f, g, area…); empty for anonymous plots.
  final String name;
  final String expression;
  final String expressionY;
  final GraphType graphType;
  final int color;
  final bool visible;
  final double tMin;
  final double tMax;
  final int sortOrder;

  /// Name without a parameter list (`g` for `g(x,y)`).
  String get baseName => name.split('(').first;

  /// Multi-variable functions store their parameters in [name].
  bool get isMultiVariable => name.contains('(');

  /// Definition usable by the calculator, e.g. `f(x)=x^2`.
  String? get definition {
    if (name.isEmpty || graphType != GraphType.cartesian) return null;
    return isMultiVariable ? '$name=$expression' : '$name(x)=$expression';
  }

  GraphSpec toSpec() => GraphSpec(
        id: '${id ?? name}',
        type: graphType,
        expression: expression,
        expressionY: expressionY,
        tMin: tMin,
        tMax: tMax,
      );

  SavedFunction copyWith({
    int? id,
    String? name,
    String? expression,
    String? expressionY,
    GraphType? graphType,
    int? color,
    bool? visible,
    double? tMin,
    double? tMax,
    int? sortOrder,
  }) =>
      SavedFunction(
        id: id ?? this.id,
        name: name ?? this.name,
        expression: expression ?? this.expression,
        expressionY: expressionY ?? this.expressionY,
        graphType: graphType ?? this.graphType,
        color: color ?? this.color,
        visible: visible ?? this.visible,
        tMin: tMin ?? this.tMin,
        tMax: tMax ?? this.tMax,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, Object?> toRow() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      if (id != null) 'id': id,
      'name': name,
      'expression': expression,
      'expression_y': expressionY,
      'graph_type': graphType.name,
      'color': color,
      'visible': visible ? 1 : 0,
      't_min': tMin,
      't_max': tMax,
      'sort_order': sortOrder,
      'created_at': now,
      'updated_at': now,
    };
  }

  factory SavedFunction.fromRow(Map<String, Object?> r) => SavedFunction(
        id: r['id'] as int?,
        name: r['name'] as String? ?? '',
        expression: r['expression'] as String? ?? '',
        expressionY: r['expression_y'] as String? ?? '',
        graphType: GraphType.values.firstWhere((t) => t.name == r['graph_type'], orElse: () => GraphType.cartesian),
        color: r['color'] as int? ?? 0,
        visible: (r['visible'] as int? ?? 1) == 1,
        tMin: (r['t_min'] as num?)?.toDouble() ?? 0,
        tMax: (r['t_max'] as num?)?.toDouble() ?? 6.283185307179586,
        sortOrder: r['sort_order'] as int? ?? 0,
      );
}

class FunctionsRepository {
  FunctionsRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  Future<List<SavedFunction>> all() async {
    final rows = await _d.query('saved_functions', orderBy: 'sort_order, id');
    return rows.map(SavedFunction.fromRow).toList();
  }

  Future<int> save(SavedFunction f) async {
    if (f.id != null) {
      final row = f.toRow()..remove('created_at');
      await _d.update('saved_functions', row, where: 'id = ?', whereArgs: [f.id]);
      return f.id!;
    }
    return _d.insert('saved_functions', f.toRow());
  }

  Future<void> delete(int id) => _d.delete('saved_functions', where: 'id = ?', whereArgs: [id]);

  Future<int> count() async =>
      Sqflite.firstIntValue(await _d.rawQuery('SELECT COUNT(*) FROM saved_functions')) ?? 0;

  Future<List<Map<String, Object?>>> exportRows() => _d.query('saved_functions', orderBy: 'id');
}

enum FavoriteType { calculation, formula, constant, converter, unit, tool }

class FavoritesRepository {
  FavoritesRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  Future<Set<String>> ids(FavoriteType type) async {
    final rows = await _d.query('favorites', columns: ['reference_id'], where: 'type = ?', whereArgs: [type.name]);
    return rows.map((r) => r['reference_id'] as String).toSet();
  }

  Future<List<(FavoriteType, String)>> all() async {
    final rows = await _d.query('favorites', orderBy: 'created_at DESC');
    return [
      for (final r in rows)
        if (FavoriteType.values.any((t) => t.name == r['type']))
          (FavoriteType.values.byName(r['type'] as String), r['reference_id'] as String)
    ];
  }

  Future<void> set(FavoriteType type, String ref, bool favorite) async {
    if (favorite) {
      await _d.insert(
        'favorites',
        {'type': type.name, 'reference_id': ref, 'created_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await _d.delete('favorites', where: 'type = ? AND reference_id = ?', whereArgs: [type.name, ref]);
    }
  }

  Future<List<Map<String, Object?>>> exportRows() => _d.query('favorites', orderBy: 'id');
}

class RecentConversion {
  const RecentConversion(this.category, this.fromUnit, this.toUnit, this.input, this.result, this.createdAt);
  final String category, fromUnit, toUnit, input, result;
  final DateTime createdAt;
}

class ConversionsRepository {
  ConversionsRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;
  static const keep = 30;

  Future<void> add(RecentConversion c) async {
    await _d.delete('recent_conversions',
        where: 'category = ? AND from_unit = ? AND to_unit = ?', whereArgs: [c.category, c.fromUnit, c.toUnit]);
    await _d.insert('recent_conversions', {
      'category': c.category,
      'from_unit': c.fromUnit,
      'to_unit': c.toUnit,
      'input_value': c.input,
      'result': c.result,
      'created_at': c.createdAt.millisecondsSinceEpoch,
    });
    await _d.rawDelete(
        'DELETE FROM recent_conversions WHERE id NOT IN (SELECT id FROM recent_conversions ORDER BY created_at DESC LIMIT ?)',
        [keep]);
  }

  Future<List<RecentConversion>> recent() async {
    final rows = await _d.query('recent_conversions', orderBy: 'created_at DESC');
    return [
      for (final r in rows)
        RecentConversion(r['category'] as String, r['from_unit'] as String, r['to_unit'] as String,
            r['input_value'] as String, r['result'] as String, DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int))
    ];
  }

  Future<void> clear() => _d.delete('recent_conversions');
}
