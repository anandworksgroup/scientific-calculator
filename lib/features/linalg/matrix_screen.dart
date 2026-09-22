import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/clipboard_service.dart';
import '../../services/engine_service.dart';
import '../../widgets/app_menu_button.dart';
import 'linalg_common.dart';

/// Names of the saved matrix slots; each is also a calculator variable.
const matrixSlotNames = ['MatA', 'MatB', 'MatC', 'MatD', 'MatE', 'MatF'];

/// Largest size offered by the editor (the engine accepts up to 20).
const matrixEditorMaxDimension = 10;

enum MatrixOp { add, subtract, multiply, scalar, transpose, determinant, inverse, rank, trace, ref, rref, power, eigen }

extension on MatrixOp {
  bool get binary => this == MatrixOp.add || this == MatrixOp.subtract || this == MatrixOp.multiply;

  String label(AppLocalizations l) => switch (this) {
    MatrixOp.add => l.matrixOpAdd,
    MatrixOp.subtract => l.matrixOpSubtract,
    MatrixOp.multiply => l.matrixOpMultiply,
    MatrixOp.scalar => l.matrixOpScalar,
    MatrixOp.transpose => l.matrixOpTranspose,
    MatrixOp.determinant => l.matrixOpDeterminant,
    MatrixOp.inverse => l.matrixOpInverse,
    MatrixOp.rank => l.matrixOpRank,
    MatrixOp.trace => l.matrixOpTrace,
    MatrixOp.ref => l.matrixOpRef,
    MatrixOp.rref => l.matrixOpRref,
    MatrixOp.power => l.matrixOpPower,
    MatrixOp.eigen => l.matrixOpEigen,
  };
}

/// Eigen decomposition of a matrix literal (top-level: runs in an isolate).
EngineResult<List<EigenPair>> eigenTask(String literal, CalcSettings settings, Environment env) {
  final r = EngineService.engine.evaluate(literal, settings, env);
  switch (r) {
    case Success(:final value):
      final m = value.value;
      if (m is! MatrixValue) return const Failure(MathError(MathErrorCode.typeMismatch));
      return EngineService.engine.eigen(m, settings);
    case Failure(:final error):
      return Failure(error);
    case Cancelled():
      return const Cancelled();
  }
}

Computation<List<EigenPair>> _spawnEigen(LinalgRunner runner, String literal, CalcSettings settings, Environment env) =>
    runner(() => eigenTask(literal, settings, env));

/// Splits [s] at [isSeparator] characters outside parentheses.
List<String> _splitTopLevel(String s, bool Function(String ch) isSeparator, {bool collapse = false}) {
  final out = <String>[];
  final b = StringBuffer();
  var depth = 0;
  for (final ch in s.split('')) {
    if (ch == '(') depth++;
    if (ch == ')' && depth > 0) depth--;
    if (depth == 0 && isSeparator(ch)) {
      if (!collapse || b.isNotEmpty) out.add(b.toString());
      b.clear();
      continue;
    }
    b.write(ch);
  }
  if (!collapse || b.isNotEmpty) out.add(b.toString());
  return out;
}

/// Parses pasted matrix text into sanitized cell strings.
///
/// Accepts spreadsheet/text layouts (rows separated by newlines or
/// semicolons, cells by tabs, commas or spaces) as well as bracket forms
/// such as `[[1,2],[3,4]]` and `[1, 2; 3, 4]`. Returns null when nothing
/// usable was found.
List<List<String>>? parseMatrixText(String raw) {
  var s = raw.length > 20000 ? raw.substring(0, 20000) : raw;
  s = s.trim();
  if (s.isEmpty) return null;
  List<List<String>> rows;
  if (s.startsWith('[')) {
    if (RegExp(r'^\[\s*\[').hasMatch(s)) {
      final inner = s.replaceFirst(RegExp(r'^\[\s*'), '').replaceFirst(RegExp(r'\s*\]\s*$'), '');
      rows = [
        for (final r in inner.split(RegExp(r'\]\s*[,;]?\s*\[')))
          _splitTopLevel(r.replaceAll(RegExp(r'[\[\]]'), ''), (c) => c == ','),
      ];
    } else {
      final inner = s.substring(1).replaceFirst(RegExp(r'\]\s*$'), '');
      rows = [for (final r in _splitTopLevel(inner, (c) => c == ';')) _splitTopLevel(r, (c) => c == ',')];
    }
  } else {
    rows = [];
    for (final line in _splitTopLevel(s, (c) => c == '\n' || c == '\r' || c == ';', collapse: true)) {
      if (line.contains('\t')) {
        rows.add(line.split('\t'));
      } else if (_splitTopLevel(line, (c) => c == ',').length > 1) {
        rows.add(_splitTopLevel(line, (c) => c == ','));
      } else {
        rows.add(_splitTopLevel(line.trim(), (c) => c == ' ', collapse: true));
      }
    }
  }
  final clean = [
    for (final r in rows)
      if (r.any((c) => ClipboardService.sanitize(c).isNotEmpty)) [for (final c in r) ClipboardService.sanitize(c)],
  ];
  if (clean.isEmpty) return null;
  final cols = clean.map((r) => r.length).reduce(math.max);
  return [
    for (final r in clean) [...r, for (var k = r.length; k < cols; k++) ''],
  ];
}

List<List<String>> _blank(int rows, int cols) => [
  for (var r = 0; r < rows; r++) List<String>.filled(cols, '', growable: true),
];

List<List<String>> _copyCells(List<List<String>> m) => [for (final r in m) List<String>.of(r)];

/// Engine literal for a grid of cell texts (empty cells are 0).
String matrixLiteral(List<List<String>> cells) {
  String cell(String c) {
    final s = ClipboardService.sanitize(c);
    return s.isEmpty ? '0' : '($s)';
  }

  return '[${cells.map((r) => '[${r.map(cell).join(',')}]').join(',')}]';
}

class _MatrixEval {
  const _MatrixEval(this.value, this.error, this.cellErrors);
  final MatrixValue? value;
  final String? error;
  final Map<(int, int), String> cellErrors;
}

class _Outcome {
  const _Outcome({this.lines = const [], this.error, this.value, this.copyText});
  final List<ResultLine> lines;
  final String? error;
  final Value? value;
  final String? copyText;
}

/// Matrix calculator and editor (URS §25–26).
///
/// Matrices are kept in six slots, MatA…MatF, saved in the database as cell
/// text and mirrored into calculator variables of the same names so the
/// calculator accepts e.g. `det(MatA)`.
class MatrixScreen extends ConsumerStatefulWidget {
  const MatrixScreen({super.key, this.initialSlot, this.runner});

  /// Slot to open in the editor (e.g. 'MatB'); defaults to MatA.
  final String? initialSlot;

  /// Runs heavy engine work; defaults to the background-isolate runner.
  final LinalgRunner? runner;

  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  final Map<String, List<List<String>>> _saved = {};
  String _slot = matrixSlotNames.first;
  List<List<String>> _draft = _blank(2, 2);
  List<List<TextEditingController>> _ctrl = [];
  int _selRow = 0, _selCol = 0;
  Map<(int, int), String> _cellErrors = const {};
  String? _slotError;

  MatrixOp _op = MatrixOp.determinant;
  String _opA = matrixSlotNames[0];
  String _opB = matrixSlotNames[1];
  final _k = TextEditingController();
  final _n = TextEditingController();
  Computation<Object?>? _running;
  _Outcome? _outcome;

  List<List<String>> get _cells => _saved[_slot] ?? _draft;
  int get _rows => _cells.length;
  int get _cols => _cells.first.length;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSlot;
    if (initial != null && matrixSlotNames.contains(initial)) {
      _slot = initial;
      _opA = initial;
    }
    _rebuildControllers();
    _load();
  }

  @override
  void dispose() {
    _running?.cancel();
    _disposeControllers();
    _k.dispose();
    _n.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ storage

  Future<void> _load() async {
    List<SavedMatrix> all;
    try {
      all = await ref.read(matricesRepositoryProvider).all();
    } on Object catch (e) {
      AppLogger.error('loading matrices failed', e);
      all = const [];
    }
    if (!mounted) return;
    setState(() {
      for (final m in all) {
        if (!matrixSlotNames.contains(m.name) || m.rows == 0 || m.columns == 0) continue;
        final cols = m.cells.map((r) => r.length).reduce(math.max);
        _saved[m.name] = [
          for (final r in m.cells) [...r, for (var k = r.length; k < cols; k++) ''],
        ];
      }
      _rebuildControllers();
      _revalidate();
    });
    // Make sure the calculator variables match what is stored.
    final l = AppLocalizations.of(context);
    final vars = ref.read(variablesProvider.notifier);
    final current = ref.read(variablesProvider);
    for (final e in _saved.entries) {
      final value = _evaluate(l, e.value, e.key).value;
      if (value != null && current[e.key] != value) await vars.set(e.key, value);
      if (value == null && current.containsKey(e.key)) await vars.remove(e.key);
    }
  }

  /// Saves slot [name] and mirrors it into the variable of the same name.
  Future<void> _persist(String name) async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(matricesRepositoryProvider);
    final vars = ref.read(variablesProvider.notifier);
    final cells = _saved[name];
    final copy = cells == null ? null : _copyCells(cells);
    final value = cells == null ? null : _evaluate(l, cells, name).value;
    try {
      if (copy == null) {
        await repo.delete(name);
      } else {
        await repo.save(SavedMatrix(name: name, cells: copy));
      }
      if (value != null) {
        await vars.set(name, value);
      } else {
        await vars.remove(name);
      }
    } on Object catch (e) {
      AppLogger.error('saving matrix failed', e);
    }
  }

  /// Evaluates every cell of [cells]; empty cells count as 0.
  _MatrixEval _evaluate(AppLocalizations l, List<List<String>> cells, String name) {
    final settings = ref.read(settingsProvider).calcSettings;
    final env = ref.read(environmentProvider);
    final rows = <List<Num>>[];
    final errors = <(int, int), String>{};
    String? first;
    for (var r = 0; r < cells.length; r++) {
      final row = <Num>[];
      for (var c = 0; c < cells[r].length; c++) {
        final f = evalNumberField(l, cells[r][c], settings, env, notNumberMessage: l.matrixCellNotNumber);
        if (f.isOk) {
          row.add(f.value!);
        } else {
          errors[(r, c)] = f.error!;
          first ??= l.matrixCellError(name, r + 1, c + 1, f.error!);
        }
      }
      rows.add(row);
    }
    if (errors.isNotEmpty) return _MatrixEval(null, first, errors);
    try {
      return _MatrixEval(MatrixValue(rows), null, const {});
    } on MathError catch (e) {
      return _MatrixEval(null, errorText(l, e), const {});
    }
  }

  // ------------------------------------------------------------- editor

  void _disposeControllers() {
    for (final r in _ctrl) {
      for (final c in r) {
        c.dispose();
      }
    }
  }

  void _rebuildControllers() {
    _disposeControllers();
    final cells = _cells;
    _ctrl = [
      for (var r = 0; r < cells.length; r++)
        [for (var c = 0; c < cells[r].length; c++) TextEditingController(text: cells[r][c])],
    ];
    _selRow = _selRow.clamp(0, cells.length - 1);
    _selCol = _selCol.clamp(0, cells.first.length - 1);
  }

  void _revalidate() {
    final l = AppLocalizations.of(context);
    final saved = _saved[_slot];
    if (saved == null) {
      _cellErrors = const {};
      _slotError = null;
      return;
    }
    final ev = _evaluate(l, saved, _slot);
    _cellErrors = ev.cellErrors;
    _slotError = ev.error;
  }

  /// Returns the stored grid of the current slot, creating it on first edit.
  List<List<String>> _edit() => _saved.putIfAbsent(_slot, () => _draft);

  void _onCellChanged(int r, int c, String text) {
    final m = _edit();
    if (r >= m.length || c >= m[r].length) return;
    m[r][c] = text;
    setState(_revalidate);
    _persist(_slot);
  }

  void _structural(void Function(List<List<String>> m) change) {
    final m = _edit();
    change(m);
    setState(() {
      _rebuildControllers();
      _revalidate();
    });
    _persist(_slot);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _selectSlot(String name) {
    if (name == _slot) return;
    setState(() {
      _slot = name;
      _draft = _blank(2, 2);
      _selRow = 0;
      _selCol = 0;
      _rebuildControllers();
      _revalidate();
    });
  }

  void _resizeRows(int delta) {
    final l = AppLocalizations.of(context);
    final n = _rows + delta;
    if (n < 1) return _snack(l.matrixMinSize);
    if (n > matrixEditorMaxDimension) return _snack(l.matrixMaxSize(matrixEditorMaxDimension));
    _structural((m) => delta > 0 ? m.add(List<String>.filled(m.first.length, '', growable: true)) : m.removeLast());
  }

  void _resizeCols(int delta) {
    final l = AppLocalizations.of(context);
    final n = _cols + delta;
    if (n < 1) return _snack(l.matrixMinSize);
    if (n > matrixEditorMaxDimension) return _snack(l.matrixMaxSize(matrixEditorMaxDimension));
    _structural((m) {
      for (final r in m) {
        delta > 0 ? r.add('') : r.removeLast();
      }
    });
  }

  void _insertRow() {
    final l = AppLocalizations.of(context);
    if (_rows >= matrixEditorMaxDimension) return _snack(l.matrixMaxSize(matrixEditorMaxDimension));
    _structural((m) => m.insert(_selRow, List<String>.filled(m.first.length, '', growable: true)));
  }

  void _deleteRow() {
    final l = AppLocalizations.of(context);
    if (_rows <= 1) return _snack(l.matrixMinSize);
    _structural((m) => m.removeAt(_selRow));
  }

  void _insertColumn() {
    final l = AppLocalizations.of(context);
    if (_cols >= matrixEditorMaxDimension) return _snack(l.matrixMaxSize(matrixEditorMaxDimension));
    _structural((m) {
      for (final r in m) {
        r.insert(_selCol, '');
      }
    });
  }

  void _deleteColumn() {
    final l = AppLocalizations.of(context);
    if (_cols <= 1) return _snack(l.matrixMinSize);
    _structural((m) {
      for (final r in m) {
        r.removeAt(_selCol);
      }
    });
  }

  void _fill(String Function(int r, int c) value) => _structural((m) {
    for (var r = 0; r < m.length; r++) {
      for (var c = 0; c < m[r].length; c++) {
        m[r][c] = value(r, c);
      }
    }
  });

  void _identity() {
    final l = AppLocalizations.of(context);
    if (_rows != _cols) return _snack(l.matrixIdentityNeedsSquare);
    _fill((r, c) => r == c ? '1' : '0');
  }

  Future<void> _paste() async {
    final l = AppLocalizations.of(context);
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } on Object {
      text = null;
    }
    if (!mounted) return;
    final parsed = text == null ? null : parseMatrixText(text);
    if (parsed == null) return _snack(l.matrixPasteEmpty);
    final rows = math.min(parsed.length, matrixEditorMaxDimension);
    final cols = math.min(parsed.first.length, matrixEditorMaxDimension);
    final trimmed = rows < parsed.length || cols < parsed.first.length;
    _saved[_slot] = [for (var r = 0; r < rows; r++) parsed[r].sublist(0, cols)];
    _structural((_) {});
    _snack(trimmed ? l.matrixPasteTrimmed(rows, cols) : l.matrixPasted(rows, cols));
  }

  Future<void> _copyMatrix() async {
    final l = AppLocalizations.of(context);
    await ClipboardService.copy(matrixLiteral(_cells).replaceAll(RegExp(r'\((-?[0-9./]+)\)'), r'$1'));
    if (mounted) _snack(l.copiedToClipboard);
  }

  void _deleteMatrix() {
    final l = AppLocalizations.of(context);
    final name = _slot;
    setState(() {
      _saved.remove(name);
      _draft = _blank(2, 2);
      _rebuildControllers();
      _revalidate();
    });
    _persist(name);
    _snack(l.matrixDeleted(name));
  }

  // --------------------------------------------------------- operations

  void _fail(String message) => setState(() {
    _running = null;
    _outcome = _Outcome(error: message);
  });

  static String _nameTex(String n) => '\\mathrm{$n}';

  Future<void> _calculate() async {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final settings = ref.read(settingsProvider);
    final calc = settings.calcSettings;
    final env = ref.read(environmentProvider).copy();

    final names = [_opA, if (_op.binary) _opB];
    final mats = <String, MatrixValue>{};
    for (final n in names) {
      final cells = _saved[n];
      if (cells == null) return _fail(l.matrixUndefined(n));
      final ev = _evaluate(l, cells, n);
      if (ev.value == null) return _fail(ev.error ?? l.matrixUndefined(n));
      mats[n] = ev.value!;
    }
    final a = matrixLiteral(_saved[_opA]!);
    final b = _op.binary ? matrixLiteral(_saved[_opB]!) : '';

    var kSrc = '', kTex = '', kText = '';
    if (_op == MatrixOp.scalar) {
      final f = evalNumberField(l, _k.text, calc, env, notNumberMessage: l.invalidNumber, emptyIsZero: false);
      if (!f.isOk) return _fail('${l.matrixScalar}: ${f.error}');
      kSrc = ClipboardService.sanitize(_k.text);
      final kf = formatValue(ref, NumberValue(f.value!));
      final wrap = f.value is Cpx || kf.plain.startsWith('-');
      kTex = wrap ? '\\left(${kf.latex}\\right)' : kf.latex;
      kText = wrap ? '(${kf.display})' : kf.display;
    }
    var n = 0;
    if (_op == MatrixOp.power) {
      final f = evalNumberField(l, _n.text, calc, env, notNumberMessage: l.matrixExponentInteger, emptyIsZero: false);
      if (!f.isOk) return _fail('${l.matrixExponent}: ${f.error}');
      final k = Arith.asInt(f.value!);
      if (k == null) return _fail(l.matrixExponentInteger);
      n = k;
    }

    final expr = switch (_op) {
      MatrixOp.add => '$a+$b',
      MatrixOp.subtract => '$a-$b',
      MatrixOp.multiply => '$a*$b',
      MatrixOp.scalar => '($kSrc)*$a',
      MatrixOp.transpose => 'trn($a)',
      MatrixOp.determinant => 'det($a)',
      MatrixOp.inverse => 'inv($a)',
      MatrixOp.rank => 'rank($a)',
      MatrixOp.trace => 'trace($a)',
      MatrixOp.ref => 'ref($a)',
      MatrixOp.rref => 'rref($a)',
      MatrixOp.power => '$a^($n)',
      MatrixOp.eigen => 'eigvals($a)',
    };
    final an = _nameTex(_opA), bn = _nameTex(_opB);
    final lhsTex = switch (_op) {
      MatrixOp.add => '$an+$bn',
      MatrixOp.subtract => '$an-$bn',
      MatrixOp.multiply => '$an\\times $bn',
      MatrixOp.scalar => '$kTex\\,$an',
      MatrixOp.transpose => '{$an}^{\\mathsf{T}}',
      MatrixOp.determinant => '\\det\\left($an\\right)',
      MatrixOp.inverse => '{$an}^{-1}',
      MatrixOp.rank => '\\mathrm{rank}\\left($an\\right)',
      MatrixOp.trace => '\\mathrm{tr}\\left($an\\right)',
      MatrixOp.ref => '\\mathrm{ref}\\left($an\\right)',
      MatrixOp.rref => '\\mathrm{rref}\\left($an\\right)',
      MatrixOp.power => '{$an}^{$n}',
      MatrixOp.eigen => '',
    };
    final lhsText = switch (_op) {
      MatrixOp.add => '$_opA + $_opB',
      MatrixOp.subtract => '$_opA − $_opB',
      MatrixOp.multiply => '$_opA × $_opB',
      MatrixOp.scalar => '$kText × $_opA',
      MatrixOp.transpose => '$_opAᵀ',
      MatrixOp.determinant => 'det($_opA)',
      MatrixOp.inverse => '$_opA⁻¹',
      MatrixOp.rank => 'rank($_opA)',
      MatrixOp.trace => 'tr($_opA)',
      MatrixOp.ref => 'ref($_opA)',
      MatrixOp.rref => 'rref($_opA)',
      MatrixOp.power => '$_opA^$n',
      MatrixOp.eigen => '',
    };
    final operandLines = [
      for (final e in mats.entries)
        () {
          final f = formatValue(ref, e.value);
          return ResultLine('${_nameTex(e.key)}=${f.latex}', '${e.key} = ${f.display.replaceAll('\n', ', ')}');
        }(),
    ];

    final maxDim = mats.values.map((m) => math.max(m.rowCount, m.colCount)).reduce(math.max);
    final heavy =
        _op == MatrixOp.eigen ||
        _op == MatrixOp.power ||
        (maxDim > 4 &&
            {
              MatrixOp.determinant,
              MatrixOp.inverse,
              MatrixOp.rank,
              MatrixOp.ref,
              MatrixOp.rref,
              MatrixOp.multiply,
            }.contains(_op));
    final LinalgRunner runner = heavy ? (widget.runner ?? ref.read(engineServiceProvider).run) : runSynchronously;

    if (_op == MatrixOp.eigen) {
      final comp = _spawnEigen(runner, a, calc, env);
      final result = await _await(comp);
      if (result == null) return;
      switch (result) {
        case Success(:final value):
          _showEigen(l, value, expr, operandLines);
        case Failure(:final error):
          _fail(errorText(l, error));
        case Cancelled():
          break;
      }
      return;
    }

    final comp = spawnEvaluation(runner, expr, calc, env);
    final result = await _await(comp);
    if (result == null) return;
    switch (result) {
      case Success(:final value):
        final v = value.value;
        final f = formatValue(ref, v, preferDecimal: value.preferDecimal);
        final display = f.display.replaceAll('\n', ', ');
        setState(
          () => _outcome = _Outcome(
            lines: [ResultLine('$lhsTex=${f.latex}', '$lhsText = $display'), ...operandLines],
            value: v,
            copyText: f.plain,
          ),
        );
        recordLinalgHistory(
          ref,
          mode: 'matrix',
          expression: expr,
          expressionLatex: value.inputLatex,
          result: f.display,
          resultLatex: f.latex,
          value: v,
        );
      case Failure(:final error):
        _fail(errorText(l, error));
      case Cancelled():
        break;
    }
  }

  /// Waits for [comp] while showing progress; null if superseded/cancelled.
  Future<EngineResult<T>?> _await<T>(Computation<T> comp) async {
    setState(() {
      _running = comp;
      _outcome = null;
    });
    final r = await comp.result;
    if (!mounted || !identical(_running, comp)) return null;
    setState(() => _running = null);
    if (r is Cancelled<T>) {
      _snack(AppLocalizations.of(context).calculationCancelled);
      return null;
    }
    return r;
  }

  void _cancel() {
    _running?.cancel();
    setState(() => _running = null);
  }

  void _showEigen(AppLocalizations l, List<EigenPair> pairs, String expr, List<ResultLine> operandLines) {
    final lines = <ResultLine>[];
    final valueTex = <String>[];
    final valueText = <String>[];
    for (var i = 0; i < pairs.length; i++) {
      final p = pairs[i];
      final vf = formatValue(ref, NumberValue(p.value));
      valueTex.add('\\lambda_{${i + 1}}=${vf.latex}');
      valueText.add(vf.display);
      lines.add(
        ResultLine(
          '\\lambda_{${i + 1}}=${vf.latex}\\quad\\left(\\text{${l.matrixMultiplicity(p.multiplicity)}}\\right)',
          l.matrixEigenvalueSemantics(i + 1, vf.display, p.multiplicity),
        ),
      );
      if (p.vectors.isEmpty) {
        lines.add(ResultLine('\\text{${l.matrixNoEigenvector}}', l.matrixNoEigenvector));
      }
      for (final v in p.vectors) {
        final cells = [for (final x in v.items) formatValue(ref, NumberValue(x))];
        lines.add(
          ResultLine(
            '\\mathbf{v}_{${i + 1}}=\\begin{bmatrix}${cells.map((c) => c.latex).join(r'\\')}\\end{bmatrix}',
            l.matrixEigenvectorSemantics('(${cells.map((c) => c.display).join(', ')})'),
          ),
        );
      }
    }
    final listValue = ListValue([for (final p in pairs) NumberValue(p.value)]);
    setState(
      () => _outcome = _Outcome(lines: [...lines, ...operandLines], value: null, copyText: valueText.join(', ')),
    );
    String exprTex;
    try {
      exprTex = const LatexPrinter().print(Parser.parse(expr));
    } on MathError {
      exprTex = expr;
    }
    recordLinalgHistory(
      ref,
      mode: 'matrix',
      expression: expr,
      expressionLatex: exprTex,
      result: valueText.join(', '),
      resultLatex: valueTex.join(r',\quad '),
      value: listValue,
    );
  }

  void _saveResultTo(String name, MatrixValue m) {
    final l = AppLocalizations.of(context);
    final precision = ref.read(settingsProvider).precision;
    _saved[name] = [
      for (final r in m.rows) [for (final c in r) numberSource(c, precision)],
    ];
    setState(() {
      if (name == _slot) _rebuildControllers();
      _revalidate();
    });
    _persist(name);
    _snack(l.matrixSavedTo(name));
  }

  Future<void> _storeResult(String name, Value v) async {
    final l = AppLocalizations.of(context);
    await ref.read(variablesProvider.notifier).set(name, v);
    if (mounted) _snack(l.matrixStoredIn(name));
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.matrixTitle), actions: const [AppMenuButton()]),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final editor = _editorPane(context, l);
            final ops = _operationsPane(context, l);
            if (c.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: editor),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: ops),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [editor, const Divider(height: 32), ops],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _editorPane(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l.matrixEditorTitle),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in matrixSlotNames)
              ChoiceChip(
                key: ValueKey('matrix-slot-$name'),
                label: Text(
                  '$name · ${_saved[name] == null ? l.matrixSlotEmpty : l.matrixSlotSize(_saved[name]!.length, _saved[name]!.first.length)}',
                ),
                selected: name == _slot,
                onSelected: (_) => _selectSlot(name),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _stepper(l.matrixRows, _rows, l.matrixRowsDecrease, l.matrixRowsIncrease, _resizeRows, 'rows'),
            _stepper(l.matrixColumns, _cols, l.matrixColumnsDecrease, l.matrixColumnsIncrease, _resizeCols, 'cols'),
          ],
        ),
        Wrap(
          children: [
            IconButton(tooltip: l.matrixInsertRow, icon: const Icon(Icons.table_rows_outlined), onPressed: _insertRow),
            IconButton(tooltip: l.matrixDeleteRow, icon: const Icon(Icons.playlist_remove), onPressed: _deleteRow),
            IconButton(
              tooltip: l.matrixInsertColumn,
              icon: const Icon(Icons.view_column_outlined),
              onPressed: _insertColumn,
            ),
            IconButton(
              tooltip: l.matrixDeleteColumn,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _deleteColumn,
            ),
            IconButton(
              tooltip: l.matrixClearValues,
              icon: const Icon(Icons.clear_all),
              onPressed: () => _fill((_, _) => ''),
            ),
            IconButton(tooltip: l.matrixIdentityFill, icon: const Icon(Icons.filter_1_outlined), onPressed: _identity),
            IconButton(
              tooltip: l.matrixZeroFill,
              icon: const Icon(Icons.exposure_zero),
              onPressed: () => _fill((_, _) => '0'),
            ),
            IconButton(tooltip: l.matrixPasteValues, icon: const Icon(Icons.content_paste), onPressed: _paste),
            IconButton(tooltip: l.matrixCopyMatrix, icon: const Icon(Icons.copy_outlined), onPressed: _copyMatrix),
            IconButton(
              tooltip: l.matrixDeleteMatrix,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saved.containsKey(_slot) ? _deleteMatrix : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _grid(context, l),
        if (_slotError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(_slotError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.matrixVariableHint(_slot), style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _stepper(String label, int value, String minusTip, String plusTip, void Function(int) change, String key) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        IconButton(
          key: ValueKey('matrix-$key-minus'),
          tooltip: minusTip,
          icon: const Icon(Icons.remove),
          onPressed: value > 1 ? () => change(-1) : null,
        ),
        Semantics(label: '$label $value', excludeSemantics: true, child: Text('$value')),
        IconButton(
          key: ValueKey('matrix-$key-plus'),
          tooltip: plusTip,
          icon: const Icon(Icons.add),
          onPressed: value < matrixEditorMaxDimension ? () => change(1) : null,
        ),
      ],
    );
  }

  Widget _grid(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    final width = MediaQuery.textScalerOf(context).scale(76).clamp(76.0, 160.0);
    final header = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 28),
              for (var c = 0; c < _cols; c++)
                SizedBox(
                  width: width + 4,
                  child: Center(
                    child: ExcludeSemantics(child: Text('${c + 1}', style: header)),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < _rows; r++)
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Center(
                    child: ExcludeSemantics(child: Text('${r + 1}', style: header)),
                  ),
                ),
                for (var c = 0; c < _cols; c++)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: SizedBox(width: width, child: _cell(theme, l, r, c)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(ThemeData theme, AppLocalizations l, int r, int c) {
    final invalid = _cellErrors.containsKey((r, c));
    final selected = r == _selRow && c == _selCol;
    final color = invalid
        ? theme.colorScheme.error
        : (selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant);
    return Focus(
      onFocusChange: (f) {
        if (f && (_selRow != r || _selCol != c)) {
          setState(() {
            _selRow = r;
            _selCol = c;
          });
        }
      },
      child: Semantics(
        label: l.matrixCellLabel(_slot, r + 1, c + 1),
        hint: invalid ? _cellErrors[(r, c)] : null,
        child: TextField(
          key: ValueKey('matrix-cell-$r-$c'),
          controller: _ctrl[r][c],
          textAlign: TextAlign.center,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            isDense: true,
            hintText: '0',
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: color, width: invalid || selected ? 2 : 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: invalid ? theme.colorScheme.error : theme.colorScheme.primary, width: 2),
            ),
          ),
          onChanged: (t) => _onCellChanged(r, c, t),
        ),
      ),
    );
  }

  Widget _operationsPane(BuildContext context, AppLocalizations l) {
    final outcome = _outcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l.matrixOperations),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final op in MatrixOp.values)
              ChoiceChip(
                key: ValueKey('matrix-op-${op.name}'),
                label: Text(op.label(l)),
                selected: _op == op,
                onSelected: (_) => setState(() {
                  _op = op;
                  _outcome = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _operandPicker(l.matrixOperandFirst, _opA, (v) => setState(() => _opA = v), 'a'),
            if (_op.binary) _operandPicker(l.matrixOperandSecond, _opB, (v) => setState(() => _opB = v), 'b'),
            if (_op == MatrixOp.scalar)
              SizedBox(
                width: 160,
                child: TextField(
                  key: const ValueKey('matrix-scalar'),
                  controller: _k,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: l.matrixScalar, border: const OutlineInputBorder()),
                  onSubmitted: (_) => _calculate(),
                ),
              ),
            if (_op == MatrixOp.power)
              SizedBox(
                width: 160,
                child: TextField(
                  key: const ValueKey('matrix-exponent'),
                  controller: _n,
                  autocorrect: false,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  decoration: InputDecoration(labelText: l.matrixExponent, border: const OutlineInputBorder()),
                  onSubmitted: (_) => _calculate(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('matrix-calculate'),
          onPressed: _running == null ? _calculate : null,
          icon: const Icon(Icons.calculate_outlined),
          label: Text(l.actionCalculate),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (_running != null) BusyIndicator(onCancel: _cancel),
        if (outcome != null) ...[
          const SizedBox(height: 12),
          LinalgResultCard(
            key: const ValueKey('matrix-result'),
            title: l.matrixResult,
            lines: outcome.lines,
            error: outcome.error,
            copyText: outcome.copyText,
            actions: [
              if (outcome.value is MatrixValue)
                PopupMenuButton<String>(
                  tooltip: l.matrixSaveTo,
                  icon: const Icon(Icons.save_alt),
                  onSelected: (name) => _saveResultTo(name, outcome.value! as MatrixValue),
                  itemBuilder: (_) => [for (final n in matrixSlotNames) PopupMenuItem(value: n, child: Text(n))],
                ),
              if (outcome.value != null)
                PopupMenuButton<String>(
                  tooltip: l.matrixStoreVariable,
                  icon: const Icon(Icons.input),
                  onSelected: (name) => _storeResult(name, outcome.value!),
                  itemBuilder: (_) => [for (final n in memoryVariableNames) PopupMenuItem(value: n, child: Text(n))],
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _operandPicker(String label, String value, ValueChanged<String> onChanged, String key) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        key: ValueKey('matrix-operand-$key'),
        value: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [for (final n in matrixSlotNames) DropdownMenuItem(value: n, child: Text(n))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
