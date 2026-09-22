import 'dart:convert';

import 'package:math_engine/math_engine.dart';

/// Two-dimensional templates the editor can hold.
enum TemplateType {
  frac(2),
  mixed(3),
  pow(1),
  sqrt(1),
  root(2),
  abs(1),
  logb(2),
  integral(3),
  deriv(2),
  sum(3),
  prod(3),
  lim(2);

  const TemplateType(this.slots);
  final int slots;
}

enum TokKind { text, func, open, sep, close }

/// One editor token. Structures are encoded as `open`, `sep`…, `close`
/// markers sharing a [group] id, so the cursor can step into and out of
/// fraction numerators, exponents, integral bounds and so on.
class EdToken {
  const EdToken._(this.kind, this.text, this.template, this.group, this.slot);

  const EdToken.text(String text) : this._(TokKind.text, text, null, 0, 0);
  const EdToken.func(String name) : this._(TokKind.func, name, null, 0, 0);
  const EdToken.open(TemplateType t, int group) : this._(TokKind.open, '', t, group, 0);
  const EdToken.sep(TemplateType t, int group, int slot) : this._(TokKind.sep, '', t, group, slot);
  const EdToken.close(TemplateType t, int group) : this._(TokKind.close, '', t, group, 0);

  final TokKind kind;

  /// Text tokens: the literal text (digit, operator, variable, `Ans`,
  /// `@c`); func tokens: the function name (rendered with an opening
  /// parenthesis).
  final String text;
  final TemplateType? template;
  final int group;
  final int slot;

  bool get isStructural => kind == TokKind.open || kind == TokKind.sep || kind == TokKind.close;

  Map<String, Object> toJson() => {
        'k': kind.index,
        if (text.isNotEmpty) 't': text,
        if (template != null) 'p': template!.index,
        if (group != 0) 'g': group,
        if (slot != 0) 's': slot,
      };

  static EdToken fromJson(Map<String, Object?> j) {
    final kind = TokKind.values[(j['k'] as int).clamp(0, TokKind.values.length - 1)];
    final text = j['t'] as String? ?? '';
    final tpl = j['p'] is int ? TemplateType.values[(j['p'] as int).clamp(0, TemplateType.values.length - 1)] : null;
    final g = j['g'] as int? ?? 0;
    final s = j['s'] as int? ?? 0;
    return switch (kind) {
      TokKind.text => EdToken.text(text),
      TokKind.func => EdToken.func(text),
      TokKind.open => EdToken.open(tpl!, g),
      TokKind.sep => EdToken.sep(tpl!, g, s),
      TokKind.close => EdToken.close(tpl!, g),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is EdToken &&
      other.kind == kind &&
      other.text == text &&
      other.template == template &&
      other.group == group &&
      other.slot == slot;

  @override
  int get hashCode => Object.hash(kind, text, template, group, slot);
}

class EditorSnapshot {
  const EditorSnapshot(this.tokens, this.cursor);
  final List<EdToken> tokens;
  final int cursor;
}

/// Pure editing logic (no Flutter). Keeps undo/redo history.
class ExpressionEditor {
  ExpressionEditor([List<EdToken>? tokens, int? cursor])
      : _tokens = List.of(tokens ?? const []),
        _cursor = cursor ?? (tokens?.length ?? 0) {
    _nextGroup = _tokens.fold(0, (m, t) => t.group > m ? t.group : m) + 1;
  }

  List<EdToken> _tokens;
  int _cursor;
  int _nextGroup = 1;
  bool _allSelected = false;
  final _undo = <EditorSnapshot>[];
  final _redo = <EditorSnapshot>[];

  static const maxTokens = 1500;

  List<EdToken> get tokens => List.unmodifiable(_tokens);
  int get cursor => _cursor;
  bool get isEmpty => _tokens.isEmpty;
  bool get allSelected => _allSelected;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void _snapshot() {
    _undo.add(EditorSnapshot(List.of(_tokens), _cursor));
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(EditorSnapshot(List.of(_tokens), _cursor));
    final s = _undo.removeLast();
    _tokens = List.of(s.tokens);
    _cursor = s.cursor.clamp(0, _tokens.length);
    _allSelected = false;
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(EditorSnapshot(List.of(_tokens), _cursor));
    final s = _redo.removeLast();
    _tokens = List.of(s.tokens);
    _cursor = s.cursor.clamp(0, _tokens.length);
    _allSelected = false;
  }

  void selectAll() => _allSelected = _tokens.isNotEmpty;
  void clearSelection() => _allSelected = false;

  /// Replaces everything (used by history "edit", paste into empty input).
  void setTokens(List<EdToken> tokens, {bool recordUndo = true}) {
    if (recordUndo) _snapshot();
    _tokens = List.of(tokens);
    _cursor = _tokens.length;
    _nextGroup = _tokens.fold(0, (m, t) => t.group > m ? t.group : m) + 1;
    _allSelected = false;
  }

  void clear() {
    if (_tokens.isEmpty) return;
    _snapshot();
    _tokens = [];
    _cursor = 0;
    _allSelected = false;
  }

  bool _deleteSelection() {
    if (!_allSelected) return false;
    _snapshot();
    _tokens = [];
    _cursor = 0;
    _allSelected = false;
    return true;
  }

  // ------------------------------------------------------------- movement

  void moveLeft() {
    _allSelected = false;
    if (_cursor > 0) _cursor--;
  }

  void moveRight() {
    _allSelected = false;
    if (_cursor < _tokens.length) _cursor++;
  }

  void moveToStart() => _cursor = 0;
  void moveToEnd() => _cursor = _tokens.length;

  void setCursor(int c) => _cursor = c.clamp(0, _tokens.length);

  // ------------------------------------------------------------ insertion

  void _insertAll(List<EdToken> toks, {int? cursorOffset}) {
    if (_tokens.length + toks.length > maxTokens) return;
    _tokens.insertAll(_cursor, toks);
    _cursor += cursorOffset ?? toks.length;
  }

  /// Inserts literal text as individual tokens (digits, operators, names).
  void insertText(String text) {
    _deleteSelection();
    _snapshot();
    _insertAll(_renumber(tokenizeText(text)));
  }

  /// Gives structures in [toks] fresh group ids from this editor.
  List<EdToken> _renumber(List<EdToken> toks) {
    final map = <int, int>{};
    return [
      for (final t in toks)
        if (!t.isStructural)
          t
        else
          switch (t.kind) {
            TokKind.open => EdToken.open(t.template!, map.putIfAbsent(t.group, () => _nextGroup++)),
            TokKind.sep => EdToken.sep(t.template!, map[t.group] ?? t.group, t.slot),
            _ => EdToken.close(t.template!, map[t.group] ?? t.group),
          },
    ];
  }

  /// Inserts a single atomic token (e.g. `Ans`, `@c`, `nCr`).
  void insertAtom(String text) {
    _deleteSelection();
    _snapshot();
    _insertAll([EdToken.text(text)]);
  }

  /// Inserts `name(`.
  void insertFunction(String name) {
    _deleteSelection();
    _snapshot();
    _insertAll([EdToken.func(name)]);
  }

  /// Inserts a structure; the cursor lands in the first empty slot.
  /// [prefill] pre-fills slots (by index) with text.
  void insertTemplate(TemplateType t, {Map<int, String> prefill = const {}, bool wrapPrevious = false, int? cursorSlot}) {
    _deleteSelection();
    _snapshot();
    final g = _nextGroup++;
    final slots = List.generate(t.slots, (k) => tokenizeText(prefill[k] ?? ''));
    if (wrapPrevious) {
      final start = _operandStart(_cursor);
      if (start < _cursor) {
        slots[0] = _tokens.sublist(start, _cursor);
        _tokens.removeRange(start, _cursor);
        _cursor = start;
        cursorSlot ??= 1;
      }
    }
    final out = <EdToken>[EdToken.open(t, g)];
    final slotStarts = <int>[];
    for (var k = 0; k < t.slots; k++) {
      if (k > 0) out.add(EdToken.sep(t, g, k));
      slotStarts.add(out.length);
      out.addAll(slots[k]);
    }
    out.add(EdToken.close(t, g));
    var target = cursorSlot;
    if (target == null) {
      target = 0;
      for (var k = 0; k < t.slots; k++) {
        if (slots[k].isEmpty) {
          target = k;
          break;
        }
        target = k;
      }
    }
    final slotEnd = slotStarts[target!] + slots[target].length;
    _insertAll(out, cursorOffset: slotEnd);
  }

  /// Inserts a complete structure and leaves the cursor after it
  /// (e.g. x² = pow template containing 2).
  void insertClosedTemplate(TemplateType t, Map<int, String> content) {
    insertTemplate(t, prefill: content);
    // Move to after the matching close token.
    final g = _nextGroup - 1;
    final close = _tokens.indexWhere((x) => x.kind == TokKind.close && x.group == g);
    if (close >= 0) _cursor = close + 1;
  }

  /// Start index of the operand directly before [pos]: a run of digits,
  /// decimal point, letters, a closed structure, or a parenthesized group.
  int _operandStart(int pos) {
    var i = pos;
    if (i == 0) return 0;
    final prev = _tokens[i - 1];
    if (prev.kind == TokKind.close) {
      final open = _tokens.lastIndexWhere((t) => t.kind == TokKind.open && t.group == prev.group, i - 1);
      return open >= 0 ? open : i;
    }
    if (prev.kind == TokKind.text && prev.text == ')') {
      var depth = 0;
      for (var j = i - 1; j >= 0; j--) {
        final t = _tokens[j];
        if (t.kind == TokKind.text && t.text == ')') depth++;
        if ((t.kind == TokKind.text && t.text == '(') || t.kind == TokKind.func) {
          depth--;
          if (depth == 0) return j;
        }
        if (t.isStructural && t.kind != TokKind.close && t.kind != TokKind.open) {
          // Do not cross slot boundaries.
          return i;
        }
      }
      return i;
    }
    while (i > 0) {
      final t = _tokens[i - 1];
      if (t.kind != TokKind.text) break;
      final s = t.text;
      final isOperand = RegExp(r'^([0-9.]|[A-Za-zθπ]|Ans|PreAns|@\w+)$').hasMatch(s) && s != 'ᴇ';
      if (!isOperand) break;
      i--;
    }
    return i;
  }

  // ------------------------------------------------------------- deletion

  /// Backspace with structure awareness:
  /// - inside the first slot at its start: removes the structure's markers
  ///   (keeping its contents);
  /// - at the start of a later slot: moves into the previous slot;
  /// - right after a structure: steps inside it.
  void backspace() {
    if (_deleteSelection()) return;
    if (_cursor == 0) return;
    final prev = _tokens[_cursor - 1];
    switch (prev.kind) {
      case TokKind.text:
      case TokKind.func:
        _snapshot();
        _tokens.removeAt(_cursor - 1);
        _cursor--;
      case TokKind.close:
      case TokKind.sep:
        _cursor--;
      case TokKind.open:
        _snapshot();
        final g = prev.group;
        final before = _tokens.sublist(0, _cursor - 1);
        final rest = _tokens.sublist(_cursor - 1);
        final kept = [for (final t in rest) if (!(t.isStructural && t.group == g)) t];
        _tokens = [...before, ...kept];
        _cursor--;
    }
  }

  // ------------------------------------------------------------- queries

  /// Serializes tokens for storage (history re-edit, state restoration).
  String toJson() => jsonEncode([for (final t in _tokens) t.toJson()]);

  static List<EdToken> tokensFromJson(String s) {
    try {
      final list = jsonDecode(s) as List;
      if (list.length > maxTokens) return const [];
      final toks = [for (final e in list) EdToken.fromJson(Map<String, Object?>.from(e as Map))];
      return _validStructure(toks) ? toks : const [];
    } on Object {
      return const [];
    }
  }

  static bool _validStructure(List<EdToken> toks) {
    final stack = <(int, TemplateType, int)>[];
    for (final t in toks) {
      switch (t.kind) {
        case TokKind.open:
          stack.add((t.group, t.template!, 0));
        case TokKind.sep:
          if (stack.isEmpty || stack.last.$1 != t.group || t.slot != stack.last.$3 + 1) return false;
          final top = stack.removeLast();
          stack.add((top.$1, top.$2, t.slot));
        case TokKind.close:
          if (stack.isEmpty || stack.last.$1 != t.group || stack.last.$3 != t.template!.slots - 1) return false;
          stack.removeLast();
        default:
          break;
      }
    }
    return stack.isEmpty;
  }

  /// Group ids for templates created while tokenizing text; kept far from
  /// the editor's own small ids (setTokens recomputes the next id anyway).
  static int _tokenizeGroup = 1 << 20;

  /// Splits a function argument list at top-level commas.
  static List<String> _splitArgs(String s) {
    final out = <String>[];
    var depth = 0, start = 0;
    for (var k = 0; k < s.length; k++) {
      final c = s[k];
      if (c == '(' || c == '[') depth++;
      if (c == ')' || c == ']') depth--;
      if (c == ',' && depth == 0) {
        out.add(s.substring(start, k));
        start = k + 1;
      }
    }
    out.add(s.substring(start));
    return out;
  }

  /// Index of the ')' matching the '(' at [open], or -1.
  static int _matchingParen(String s, int open) {
    var depth = 0;
    for (var k = open; k < s.length; k++) {
      if (s[k] == '(') depth++;
      if (s[k] == ')') {
        depth--;
        if (depth == 0) return k;
      }
    }
    return -1;
  }

  /// Converts plain text into editor tokens (paste, history, formulas).
  static List<EdToken> tokenizeText(String text) {
    final out = <EdToken>[];
    var i = 0;
    while (i < text.length) {
      final c = text[i];
      if (c == ' ') {
        i++;
        continue;
      }
      if (c == '@') {
        var j = i + 1;
        while (j < text.length && RegExp(r'\w').hasMatch(text[j])) {
          j++;
        }
        out.add(EdToken.text(text.substring(i, j)));
        i = j;
        continue;
      }
      if (RegExp(r'[A-Za-z_]').hasMatch(c)) {
        var j = i;
        while (j < text.length && RegExp(r'[A-Za-z_0-9]').hasMatch(text[j])) {
          j++;
        }
        final word = text.substring(i, j);
        final followedByParen = j < text.length && text[j] == '(';
        final fname = functionAliases[word] ?? word;
        // sqrt(…), cbrt(…), abs(…) become textbook templates when their
        // argument is a single balanced group.
        const templated = {'sqrt': TemplateType.sqrt, 'cbrt': TemplateType.root, 'abs': TemplateType.abs};
        // integral(f,x,a,b), sum/prod(f,x,a,b), deriv(f,x,a), lim(f,x,a)
        // become ∫ Σ Π d/dx lim templates when the bound variable is x.
        const calculus = {'integral': TemplateType.integral, 'sum': TemplateType.sum, 'prod': TemplateType.prod, 'deriv': TemplateType.deriv, 'lim': TemplateType.lim};
        if (followedByParen && calculus.containsKey(fname)) {
          final close = _matchingParen(text, j);
          final args = close > 0 ? _splitArgs(text.substring(j + 1, close)) : const <String>[];
          final t = calculus[fname];
          final okArity = (t == TemplateType.deriv || t == TemplateType.lim) ? args.length == 3 : args.length == 4;
          if (t != null && okArity && args[1].trim() == 'x') {
            // Slot order follows the template layout.
            final slots = switch (t) {
              TemplateType.deriv => [args[0], args[2]],
              TemplateType.lim => [args[2], args[0]],
              _ => [args[2], args[3], args[0]],
            };
            final g = _tokenizeGroup++;
            out.add(EdToken.open(t, g));
            for (var s = 0; s < slots.length; s++) {
              if (s > 0) out.add(EdToken.sep(t, g, s));
              out.addAll(tokenizeText(slots[s].trim()));
            }
            out.add(EdToken.close(t, g));
            i = close + 1;
            continue;
          }
        }
        if (followedByParen && templated.containsKey(fname)) {
          final close = _matchingParen(text, j);
          if (close > 0) {
            final inner = text.substring(j + 1, close);
            final t = templated[fname]!;
            final g = _tokenizeGroup++;
            out.add(EdToken.open(t, g));
            if (t == TemplateType.root) {
              out.add(const EdToken.text('3'));
              out.add(EdToken.sep(t, g, 1));
            }
            out.addAll(tokenizeText(inner));
            out.add(EdToken.close(t, g));
            i = close + 1;
            continue;
          }
        }
        if (followedByParen && functionIndex.containsKey(fname)) {
          out.add(EdToken.func(fname));
          i = j + 1;
          continue;
        }
        if (word == 'Ans' || word == 'PreAns' || word == 'nCr' || word == 'nPr' || word == 'pi' || word == 'inf') {
          out.add(EdToken.text(word == 'pi' ? 'π' : (word == 'inf' ? '∞' : word)));
          i = j;
          continue;
        }
        if (followedByParen && word.length > 1 && !functionIndex.containsKey(fname)) {
          // User function call such as area(…)
          out.add(EdToken.func(word));
          i = j + 1;
          continue;
        }
        // Individual letters/digits (x·y implicit products stay editable).
        for (final ch in word.split('')) {
          out.add(EdToken.text(ch));
        }
        i = j;
        continue;
      }
      // x^2, x^-1, x^(n+1) → exponent template.
      if (c == '^') {
        var k = i + 1;
        String? exponent;
        var end = k;
        if (k < text.length && text[k] == '(') {
          final close = _matchingParen(text, k);
          if (close > 0) {
            exponent = text.substring(k + 1, close);
            end = close + 1;
          }
        } else {
          if (k < text.length && (text[k] == '-' || text[k] == '−')) k++;
          var m = k;
          while (m < text.length && RegExp(r'[0-9.A-Za-zπθ]').hasMatch(text[m])) {
            m++;
          }
          if (m > k) {
            exponent = text.substring(i + 1, m);
            end = m;
          }
        }
        if (exponent != null && exponent.trim().isNotEmpty) {
          final g = _tokenizeGroup++;
          out.add(EdToken.open(TemplateType.pow, g));
          out.addAll(tokenizeText(exponent));
          out.add(EdToken.close(TemplateType.pow, g));
          i = end;
          continue;
        }
      }
      out.add(EdToken.text(switch (c) {
        '*' => '×',
        '−' => '-',
        _ => c,
      }));
      i++;
    }
    return out;
  }

  // ---------------------------------------------------------- engine text

  String toEngineText() {
    var i = 0;
    String seq(int? group) {
      final b = StringBuffer();
      while (i < _tokens.length) {
        final t = _tokens[i];
        if ((t.kind == TokKind.sep || t.kind == TokKind.close) && t.group == group) return b.toString();
        i++;
        switch (t.kind) {
          case TokKind.text:
            b.write(switch (t.text) {
              '×' => '*',
              '÷' => '/',
              'ᴇ' => 'E',
              _ => t.text,
            });
            // "2ᴇ" must stay glued to its exponent digits; "E" letter
            // variable is written with a space to avoid ambiguity.
            if (t.text == 'E') b.write(' ');
          case TokKind.func:
            b.write('${t.text}(');
          case TokKind.open:
            final g = t.group;
            final slots = <String>[];
            for (var k = 0; k < t.template!.slots; k++) {
              slots.add(seq(g));
              if (i < _tokens.length) i++; // consume sep/close
            }
            b.write(_templateText(t.template!, slots));
          case TokKind.sep:
          case TokKind.close:
            // Stray marker (should not happen); ignore.
            break;
        }
      }
      return b.toString();
    }

    return seq(null).trim();
  }

  static String _templateText(TemplateType t, List<String> s) {
    String w(String x) => '($x)';
    return switch (t) {
      TemplateType.frac => '(${w(s[0])}/${w(s[1])})',
      TemplateType.mixed => '(${w(s[0])}+${w(s[1])}/${w(s[2])})',
      TemplateType.pow => '^${w(s[0])}',
      TemplateType.sqrt => 'sqrt(${s[0]})',
      TemplateType.root => 'nroot(${s[0]},${s[1]})',
      TemplateType.abs => 'abs(${s[0]})',
      TemplateType.logb => 'log(${s[0]},${s[1]})',
      TemplateType.integral => 'integral(${s[2]},x,${s[0]},${s[1]})',
      TemplateType.deriv => 'deriv(${s[0]},x,${s[1]})',
      TemplateType.sum => 'sum(${s[2]},x,${s[0]},${s[1]})',
      TemplateType.prod => 'prod(${s[2]},x,${s[0]},${s[1]})',
      TemplateType.lim => 'lim(${s[1]},x,${s[0]})',
    };
  }

  /// Plain one-line text for copying (engine syntax, human readable).
  String toPlainText() => toEngineText();
}
