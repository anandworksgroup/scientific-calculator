import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../services/app_logger.dart';
import '../../services/engine_service.dart';
import 'editor/editor_latex.dart';
import 'editor/expression_editor.dart';
import 'keypad/key_specs.dart';
import 'result_presenter.dart';

/// Result of the last `=`.
class CalcResult {
  const CalcResult(this.evaluation, this.expressionText, this.expressionLatex);
  final Evaluation evaluation;
  final String expressionText;
  final String expressionLatex;
}

/// Notifications the UI shows as snack bars.
enum CalcNotice { none, stored, memoryStored, memoryCleared, functionSaved, functionLimit, cancelled }

class CalculatorState {
  const CalculatorState({
    this.tokens = const [],
    this.cursor = 0,
    this.allSelected = false,
    this.shift = false,
    this.alpha = false,
    this.storePending = false,
    this.result,
    this.view = ResultView.standard,
    this.error,
    this.preview,
    this.calculating = false,
    this.justEvaluated = false,
    this.notice = CalcNotice.none,
    this.noticeArg = '',
    this.canUndo = false,
    this.canRedo = false,
  });

  final List<EdToken> tokens;
  final int cursor;
  final bool allSelected;
  final bool shift;
  final bool alpha;

  /// STO was pressed; the next variable key stores the answer.
  final bool storePending;
  final CalcResult? result;
  final ResultView view;
  final MathError? error;
  final Evaluation? preview;
  final bool calculating;

  /// The display shows a finished result; typing a digit starts over and
  /// typing an operator continues from Ans.
  final bool justEvaluated;
  final CalcNotice notice;
  final String noticeArg;
  final bool canUndo;
  final bool canRedo;

  bool get isEmpty => tokens.isEmpty;

  CalculatorState copyWith({
    List<EdToken>? tokens,
    int? cursor,
    bool? allSelected,
    bool? shift,
    bool? alpha,
    bool? storePending,
    CalcResult? Function()? result,
    ResultView? view,
    MathError? Function()? error,
    Evaluation? Function()? preview,
    bool? calculating,
    bool? justEvaluated,
    CalcNotice? notice,
    String? noticeArg,
    bool? canUndo,
    bool? canRedo,
  }) =>
      CalculatorState(
        tokens: tokens ?? this.tokens,
        cursor: cursor ?? this.cursor,
        allSelected: allSelected ?? this.allSelected,
        shift: shift ?? this.shift,
        alpha: alpha ?? this.alpha,
        storePending: storePending ?? this.storePending,
        result: result != null ? result() : this.result,
        view: view ?? this.view,
        error: error != null ? error() : this.error,
        preview: preview != null ? preview() : this.preview,
        calculating: calculating ?? this.calculating,
        justEvaluated: justEvaluated ?? this.justEvaluated,
        notice: notice ?? this.notice,
        noticeArg: noticeArg ?? this.noticeArg,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
      );
}

const memoryVariable = 'M';
const _storeTargets = {'A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'};

class CalculatorController extends Notifier<CalculatorState> {
  late ExpressionEditor _editor;
  Timer? _previewTimer;
  Timer? _persistTimer;
  Computation<Evaluation>? _running;

  static const _restoreKey = 'calc.editor';

  @override
  CalculatorState build() {
    ref.onDispose(() {
      _previewTimer?.cancel();
      _persistTimer?.cancel();
      _running?.cancel();
    });
    final saved = ref.read(settingsStoreProvider).getString(_restoreKey);
    final tokens = saved == null ? const <EdToken>[] : ExpressionEditor.tokensFromJson(saved);
    _editor = ExpressionEditor(tokens);
    return CalculatorState(tokens: _editor.tokens, cursor: _editor.cursor);
  }

  ExpressionEditor get editor => _editor;

  // ------------------------------------------------------------------ sync

  void _sync({bool clearResult = true, bool schedulePreview = true}) {
    state = state.copyWith(
      tokens: _editor.tokens,
      cursor: _editor.cursor,
      allSelected: _editor.allSelected,
      canUndo: _editor.canUndo,
      canRedo: _editor.canRedo,
      result: clearResult ? () => null : null,
      error: () => null,
      justEvaluated: clearResult ? false : state.justEvaluated,
      view: clearResult ? ResultView.standard : state.view,
    );
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), () {
      ref.read(settingsStoreProvider).setString(_restoreKey, _editor.toJson());
    });
    if (schedulePreview) _schedulePreview();
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    if (!ref.read(settingsProvider).livePreview || _editor.isEmpty) {
      if (state.preview != null) state = state.copyWith(preview: () => null);
      return;
    }
    _previewTimer = Timer(const Duration(milliseconds: 150), _runPreview);
  }

  void _runPreview() {
    final text = _editor.toEngineText();
    if (text.isEmpty) return;
    final s = ref.read(settingsProvider);
    final r = ref.read(engineServiceProvider).preview(text, s.calcSettings, ref.read(environmentProvider));
    final v = r.valueOrNull;
    final showable = v != null &&
        v.assignedName == null &&
        v.definedFunction == null &&
        v.solution == null &&
        v.ast is! EquationNode &&
        (v.value is NumberValue || v.value is MatrixValue || v.value is VectorValue);
    // Do not preview a bare number that equals what was typed.
    final trivial = v != null && v.ast is NumberNode;
    state = state.copyWith(preview: () => showable && !trivial ? v : null);
  }

  void clearNotice() => state = state.copyWith(notice: CalcNotice.none);

  // ------------------------------------------------------------------ keys

  /// Handles a key press (after SHIFT/ALPHA resolution in [resolve]).
  void press(CalcKey key) => perform(resolve(key));

  KeyAction resolve(CalcKey key) {
    KeyAction action = key.action;
    if (state.shift && key.shift != null) action = key.shift!.action;
    if (state.alpha && key.alpha != null) action = key.alpha!.action;
    final isModifier = action is Command && (action.command == CalcCommand.shift || action.command == CalcCommand.alpha);
    if (!isModifier && (state.shift || state.alpha)) {
      state = state.copyWith(shift: false, alpha: false);
    }
    return action;
  }

  void perform(KeyAction action) {
    // STO → variable stores the last answer.
    if (state.storePending) {
      if (action is InsertAtom && _storeTargets.contains(action.text)) {
        state = state.copyWith(storePending: false);
        _storeAnswer(action.text);
        return;
      }
      if (!(action is Command && (action.command == CalcCommand.alpha || action.command == CalcCommand.shift))) {
        state = state.copyWith(storePending: false);
      }
    }
    switch (action) {
      case InsertText(:final text):
        _beginInsert(isOperator: _startsWithOperator(text));
        _editor.insertText(text);
        _sync();
      case InsertAtom(:final text):
        _beginInsert(isOperator: text == 'nCr' || text == 'nPr');
        _editor.insertAtom(text);
        _sync();
      case InsertFunc(:final name):
        _beginInsert(isOperator: false);
        _editor.insertFunction(name);
        _sync();
      case InsertTemplate():
        final continuesAnswer = action.type == TemplateType.pow && action.prefix.isEmpty ||
            (action.type == TemplateType.frac && action.wrapPrevious);
        _beginInsert(isOperator: continuesAnswer);
        if (action.prefix.isNotEmpty) _editor.insertText(action.prefix);
        if (action.closed) {
          _editor.insertClosedTemplate(action.type, action.prefill);
        } else {
          _editor.insertTemplate(action.type, prefill: action.prefill, wrapPrevious: action.wrapPrevious);
        }
        _sync();
      case Command(:final command):
        _command(command);
    }
  }

  bool _startsWithOperator(String t) => t.isNotEmpty && '+-×÷*/^!%²³°'.contains(t[0]) && t != '-' || t == '-' && state.justEvaluated;

  /// After a result: operators continue from Ans; anything else starts a
  /// new expression.
  void _beginInsert({required bool isOperator}) {
    if (!state.justEvaluated) return;
    if (isOperator) {
      _editor.setTokens([const EdToken.text('Ans')]);
    } else {
      _editor.setTokens(const []);
    }
    state = state.copyWith(justEvaluated: false, result: () => null);
  }

  void _command(CalcCommand c) {
    switch (c) {
      case CalcCommand.shift:
        state = state.copyWith(shift: !state.shift, alpha: false);
      case CalcCommand.alpha:
        state = state.copyWith(alpha: !state.alpha, shift: false);
      case CalcCommand.del:
        if (state.justEvaluated) {
          state = state.copyWith(justEvaluated: false, result: () => null);
        }
        _editor.backspace();
        _sync();
      case CalcCommand.ac:
        _running?.cancel();
        _editor.clear();
        state = state.copyWith(calculating: false, storePending: false);
        _sync();
      case CalcCommand.left:
        if (state.justEvaluated) state = state.copyWith(justEvaluated: false, result: () => null);
        _editor.moveLeft();
        _sync(schedulePreview: false);
      case CalcCommand.right:
        if (state.justEvaluated) {
          state = state.copyWith(justEvaluated: false, result: () => null);
          _editor.moveToStart();
        } else {
          _editor.moveRight();
        }
        _sync(schedulePreview: false);
      case CalcCommand.equals:
        evaluate();
      case CalcCommand.approx:
        evaluate(view: ResultView.decimal);
      case CalcCommand.store:
        state = state.copyWith(storePending: !state.storePending, alpha: true);
      case CalcCommand.memClear:
        ref.read(variablesProvider.notifier).remove(memoryVariable);
        state = state.copyWith(notice: CalcNotice.memoryCleared);
      case CalcCommand.memRecall:
        perform(const InsertAtom(memoryVariable));
      case CalcCommand.memAdd:
      case CalcCommand.memSub:
      case CalcCommand.memStore:
        _memory(c);
      case CalcCommand.formatToggle:
        toggleView();
      case CalcCommand.undo:
        _editor.undo();
        _sync();
      case CalcCommand.redo:
        _editor.redo();
        _sync();
      case CalcCommand.menu:
      case CalcCommand.catalog:
      case CalcCommand.constants:
      case CalcCommand.history:
        // Handled by the screen (opens sheets).
        break;
    }
  }

  void toggleView() {
    final r = state.result;
    if (r == null) {
      // No result yet: evaluate and show the alternative form directly.
      evaluate(view: ResultView.exact);
      return;
    }
    final presenter = ResultPresenter(ref.read(settingsProvider));
    state = state.copyWith(view: presenter.nextView(r.evaluation, state.view));
  }

  // ------------------------------------------------------------ evaluation

  EditorLatexRenderer get _plainRenderer => const EditorLatexRenderer(cursorColor: '#000000', placeholderColor: '#9e9e9e', showCursor: false);

  Future<void> evaluate({ResultView view = ResultView.standard}) async {
    if (state.calculating) return;
    var text = _editor.toEngineText();
    if (text.isEmpty) {
      if (state.result != null) return;
      state = state.copyWith(error: () => const MathError(MathErrorCode.emptyInput));
      return;
    }
    _previewTimer?.cancel();
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider);
    final comp = ref.read(engineServiceProvider).evaluate(text, settings.calcSettings, env);
    _running = comp;
    state = state.copyWith(calculating: true, error: () => null);
    final r = await comp.result;
    if (!identical(_running, comp)) return; // superseded
    _running = null;
    state = state.copyWith(calculating: false);
    switch (r) {
      case Success(:final value):
        await _onSuccess(value, text, view);
      case Failure(:final error):
        ref.read(feedbackServiceProvider).error(settings);
        state = state.copyWith(error: () => error, preview: () => null);
      case Cancelled():
        state = state.copyWith(notice: CalcNotice.cancelled);
    }
  }

  void cancel() {
    _running?.cancel();
    _running = null;
    state = state.copyWith(calculating: false, notice: CalcNotice.cancelled);
  }

  Future<void> _onSuccess(Evaluation e, String text, ResultView view) async {
    final vars = ref.read(variablesProvider.notifier);
    if (e.definedFunction != null) {
      final ok = await _saveDefinition(e);
      state = state.copyWith(
        notice: ok ? CalcNotice.functionSaved : CalcNotice.functionLimit,
        noticeArg: e.definedFunction,
      );
    }
    if (e.assignedName != null) {
      await vars.set(e.assignedName!, e.value);
      state = state.copyWith(notice: CalcNotice.stored, noticeArg: e.assignedName);
    }
    final answer = _answerValue(e);
    if (answer != null) {
      final prev = ref.read(variablesProvider)['Ans'];
      if (prev != null) await vars.set('PreAns', prev);
      await vars.set('Ans', answer);
    }
    final latex = _plainRenderer.render(_editor.tokens, -1);
    final result = CalcResult(e, text, latex);
    state = state.copyWith(
      result: () => result,
      view: view,
      justEvaluated: true,
      preview: () => null,
      error: () => null,
    );
    await _addHistory(result, view);
  }

  Value? _answerValue(Evaluation e) {
    final v = e.value;
    if (v is NumberValue || v is MatrixValue || v is VectorValue || v is ListValue) return v;
    if (v is SolutionsValue && v.solutions.length == 1) return NumberValue(v.solutions.first);
    return null;
  }

  Future<bool> _saveDefinition(Evaluation e) async {
    final def = e.ast as FunctionDefNode;
    final params = def.params;
    Node body = def.body;
    // Store single-variable functions in terms of x.
    if (params.length == 1 && params.first != 'x') {
      body = substituteNodes(body, {params.first: const VariableNode('x')});
    }
    final expr = const TextPrinter().print(body);
    final name = params.length == 1 ? def.name : '${def.name}(${params.join(',')})';
    final funcs = ref.read(functionsProvider);
    final existing = funcs.where((f) => f.name == name || f.name.split('(').first == def.name).firstOrNull;
    final notifier = ref.read(functionsProvider.notifier);
    final colorIndex = existing?.color ?? funcs.length;
    return notifier.save(SavedFunction(
      id: existing?.id,
      name: name,
      expression: expr,
      color: colorIndex,
      visible: existing?.visible ?? true,
      sortOrder: existing?.sortOrder ?? 0,
    ));
  }

  Future<void> _addHistory(CalcResult r, ResultView view) async {
    final settings = ref.read(settingsProvider);
    if (!settings.saveHistory) return;
    final presenter = ResultPresenter(settings);
    final shown = presenter.main(r.evaluation, view);
    final display = shown.plain;
    try {
      await ref.read(historyRepositoryProvider).insert(
            HistoryEntry(
              expression: r.expressionText,
              expressionLatex: r.expressionLatex,
              result: display,
              resultLatex: shown.latex,
              resultValue: _encodable(r.evaluation.value) ? ValueCodec.encode(r.evaluation.value) : null,
              mode: 'calculator',
              angleMode: settings.angleMode.name,
              format: settings.resultFormat.name,
              createdAt: DateTime.now(),
              editorState: _editor.toJson(),
            ),
            limit: settings.historyLimit,
          );
      ref.invalidate(historyListProvider);
    } catch (e) {
      AppLogger.error('history insert', e);
    }
  }

  bool _encodable(Value v) => v is NumberValue || v is MatrixValue || v is VectorValue || v is ListValue || v is BoolValue;

  // --------------------------------------------------------------- memory

  Future<void> _storeAnswer(String name) async {
    final value = state.result != null ? _answerValue(state.result!.evaluation) : await _currentValue();
    if (value == null) return;
    await ref.read(variablesProvider.notifier).set(name, value);
    state = state.copyWith(notice: CalcNotice.stored, noticeArg: name, alpha: false);
  }

  Future<Value?> _currentValue() async {
    if (state.result != null) return _answerValue(state.result!.evaluation);
    final text = _editor.toEngineText();
    if (text.isEmpty) return null;
    final s = ref.read(settingsProvider);
    final r = await ref.read(engineServiceProvider).evaluate(text, s.calcSettings, ref.read(environmentProvider)).result;
    switch (r) {
      case Success(:final value):
        return _answerValue(value);
      case Failure(:final error):
        state = state.copyWith(error: () => error);
        return null;
      case Cancelled():
        return null;
    }
  }

  Future<void> _memory(CalcCommand c) async {
    final v = await _currentValue();
    if (v is! NumberValue) return;
    final vars = ref.read(variablesProvider.notifier);
    final current = ref.read(variablesProvider)[memoryVariable];
    final a = Arith(precision: ref.read(settingsProvider).precision, allowComplex: true);
    Num base = current is NumberValue ? current.n : Rat.zero;
    final Num next = switch (c) {
      CalcCommand.memAdd => a.add(base, v.n),
      CalcCommand.memSub => a.sub(base, v.n),
      _ => v.n,
    };
    await vars.set(memoryVariable, NumberValue(next));
    state = state.copyWith(notice: CalcNotice.memoryStored);
  }

  // ------------------------------------------------------------ external

  /// Loads an expression (history reuse, formula insert, paste).
  void loadExpression(String text, {String? editorJson}) {
    final toks = editorJson != null ? ExpressionEditor.tokensFromJson(editorJson) : const <EdToken>[];
    _editor.setTokens(toks.isNotEmpty ? toks : ExpressionEditor.tokenizeText(text));
    state = state.copyWith(justEvaluated: false, result: () => null);
    _sync();
  }

  /// Inserts text at the cursor (paste, catalog, constants).
  void insertText(String text) {
    _beginInsert(isOperator: false);
    _editor.insertText(text);
    _sync();
  }

  void insertAtom(String atom) => perform(InsertAtom(atom));
  void insertFunction(String name) => perform(InsertFunc(name));

  void selectAll() {
    _editor.selectAll();
    _sync(clearResult: false, schedulePreview: false);
  }
}

final calculatorProvider = NotifierProvider<CalculatorController, CalculatorState>(CalculatorController.new);

/// History list (refreshed after each calculation).
final historyListProvider = FutureProvider.autoDispose<List<HistoryEntry>>(
    (ref) => ref.watch(historyRepositoryProvider).list(limit: 2000));
