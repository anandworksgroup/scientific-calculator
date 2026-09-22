import 'package:math_engine/math_engine.dart';
import 'package:test/test.dart';

/// Names that must never be used as formula variable ids.
final Set<String> _reserved = {
  ...builtinConstantNames,
  ...functionIndex.keys,
  ...functionAliases.keys,
};

Set<String> _equationVariables(Node node) => switch (node) {
      AssignmentNode(:final name, :final value) => {name, ...freeVariables(value)},
      _ => freeVariables(node),
    };

bool _balancedBraces(String s) {
  var depth = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == r'\' && i + 1 < s.length && (s[i + 1] == '{' || s[i + 1] == '}')) {
      i++;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth < 0) return false;
    }
  }
  return depth == 0;
}

void main() {
  test('library has a reasonable size', () {
    expect(formulas.length, greaterThanOrEqualTo(250));
  });

  test('ids are unique and prefixed by category', () {
    final seen = <String>{};
    for (final f in formulas) {
      expect(seen.add(f.id), isTrue, reason: 'duplicate id ${f.id}');
      expect(f.id.startsWith('${f.category.name}.'), isTrue, reason: f.id);
    }
  });

  test('at least 15 formulas per category', () {
    for (final c in FormulaCategory.values) {
      final n = formulas.where((f) => f.category == c).length;
      expect(n, greaterThanOrEqualTo(15), reason: '${c.name} has $n');
    }
  });

  test('related ids exist and are not self-references', () {
    for (final f in formulas) {
      for (final r in f.related) {
        expect(formulaById(r), isNotNull, reason: '${f.id} -> $r');
        expect(r, isNot(f.id));
      }
    }
  });

  test('text fields are non-empty and latex braces are balanced', () {
    for (final f in formulas) {
      expect(f.name.trim(), isNotEmpty, reason: f.id);
      expect(f.description.trim(), isNotEmpty, reason: f.id);
      expect(f.latex.trim(), isNotEmpty, reason: f.id);
      expect(f.latex.contains('\n'), isFalse, reason: f.id);
      expect(f.latex.contains(r'\begin'), isFalse, reason: f.id);
      expect(_balancedBraces(f.latex), isTrue, reason: '${f.id}: ${f.latex}');
    }
  });

  test('variable ids are valid and not reserved names', () {
    final idPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');
    for (final f in formulas) {
      final ids = f.variables.map((v) => v.id).where((id) => id.isNotEmpty).toList();
      expect(ids.toSet().length, ids.length, reason: '${f.id} has duplicate variable ids');
      for (final id in ids) {
        expect(idPattern.hasMatch(id), isTrue, reason: '${f.id}: bad id $id');
        expect(_reserved.contains(id), isFalse, reason: '${f.id}: reserved id $id');
        expect(id.startsWith('nCr') || id.startsWith('nPr'), isFalse, reason: '${f.id}: $id');
      }
      for (final v in f.variables) {
        expect(v.latex, isNotEmpty, reason: '${f.id}: ${v.id}');
        expect(v.meaning, isNotEmpty, reason: '${f.id}: ${v.id}');
      }
    }
  });

  test('equations parse and use exactly the declared variables', () {
    var count = 0;
    for (final f in formulas) {
      final eq = f.equation;
      if (eq == null) continue;
      count++;
      expect('='.allMatches(eq).length, 1, reason: '${f.id}: $eq');
      final ids = f.variables.map((v) => v.id).where((id) => id.isNotEmpty).toSet();
      final Node node;
      try {
        node = Parser.parse(eq, scope: ParseScope(boundVariables: ids));
      } catch (err) {
        fail('${f.id}: "$eq" failed to parse: $err');
      }
      expect(node is EquationNode || node is AssignmentNode, isTrue,
          reason: '${f.id}: parsed as ${node.runtimeType}');
      expect(_equationVariables(node), ids, reason: '${f.id}: $eq');
    }
    expect(count, greaterThan(150));
  });

  test('formulaById', () {
    expect(formulaById('mechanics.kinetic_energy')?.name, 'Kinetic energy');
    expect(formulaById('nope'), isNull);
  });

  test('searchFormulas', () {
    expect(searchFormulas('kinetic').map((f) => f.id), contains('mechanics.kinetic_energy'));
    expect(searchFormulas('KINETIC').first.id, anyOf('mechanics.kinetic_energy', 'mechanics.rotational_ke', 'thermodynamics.mean_kinetic_energy'));
    expect(searchFormulas('quadratic').map((f) => f.id), contains('algebra.quadratic_formula'));
    expect(searchFormulas('quadratic').first.id, 'algebra.quadratic_formula');
    expect(searchFormulas('optics').length, formulas.where((f) => f.category == FormulaCategory.optics).length);
    expect(searchFormulas('zzzz-no-match'), isEmpty);
    expect(searchFormulas('').length, formulas.length);
  });
}
