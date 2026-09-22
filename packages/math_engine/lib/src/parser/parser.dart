/// Tokenizer and recursive-descent parser: text → [Node] AST.
///
/// Grammar (lowest to highest precedence):
///   statement   := funcdef | assignment | relation ('→' name)?
///   relation    := additive (('=' | '<' | '>' | '≤' | '≥' | '≠') additive)?
///   additive    := multiplicative (('+' | '−') multiplicative)*
///   multiplicative := combination (('×' | '÷' | '·' | implicit) combination)*
///   combination := unary (('nCr' | 'nPr' | '∠') unary)*
///   unary       := ('−' | '+' | '√' | '∛') unary | power
///   power       := postfix ('^' unary)?
///   postfix     := primary ('!' | '%' | '°' | 'ʳ' | 'ᵍ' | '²' | '³' | '⁻¹')*
///   primary     := number | name | call | '(' expr ')' | '(' list ')' | '[' … ']'
///
/// No dynamic evaluation of any kind is used: input is only ever turned
/// into this tree.
library;

import '../ast/ast.dart';
import '../core/errors.dart';
import '../functions/catalog.dart';
import '../numbers/num.dart';

enum TokType { number, ident, constRef, op, lparen, rparen, lbrack, rbrack, comma, semicolon, eof }

class Token {
  Token(this.type, this.text, this.pos, {this.value, this.isDecimal = false});
  final TokType type;
  final String text;
  final int pos;
  final Rat? value;
  final bool isDecimal;

  @override
  String toString() => '$type($text)';
}

/// Maximum accepted input length; longer text is rejected up front.
const int maxExpressionLength = 5000;

const _superscriptDigits = {
  '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
  '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
};

bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

bool _isIdentStart(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || c == '_' ||
      // Greek letters (θ, λ, μ, σ, …) except π and φ which are constants.
      (u >= 0x3B1 && u <= 0x3C9 && c != 'π' && c != 'φ') ||
      (u >= 0x391 && u <= 0x3A9);
}

bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);

/// Converts expression text to tokens.
List<Token> tokenize(String src) {
  if (src.length > maxExpressionLength) {
    throw const MathError(MathErrorCode.tooLarge, {'function': 'the expression', 'limit': '$maxExpressionLength characters'});
  }
  final out = <Token>[];
  var i = 0;
  final n = src.length;
  while (i < n) {
    final c = src[i];
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ' ') {
      i++;
      continue;
    }
    // Numbers: 12, 1.5, .5, 1.2E8, 1.2ᴇ-3
    if (_isDigit(c) || (c == '.' && i + 1 < n && _isDigit(src[i + 1]))) {
      final start = i;
      var isDecimal = false;
      while (i < n && _isDigit(src[i])) {
        i++;
      }
      if (i < n && src[i] == '.') {
        isDecimal = true;
        i++;
        while (i < n && _isDigit(src[i])) {
          i++;
        }
        if (i < n && src[i] == '.') {
          throw MathError(MathErrorCode.invalidExpression, {'detail': 'a number has more than one decimal point'}, i);
        }
      }
      var text = src.substring(start, i);
      // Exponent: 'E' or 'ᴇ' followed by optional sign and digits.
      if (i < n && (src[i] == 'E' || src[i] == 'ᴇ')) {
        var j = i + 1;
        if (j < n && (src[j] == '+' || src[j] == '-' || src[j] == '−')) j++;
        if (j < n && _isDigit(src[j])) {
          final expStart = i + 1;
          while (j < n && _isDigit(src[j])) {
            j++;
          }
          final expText = src.substring(expStart, j).replaceAll('−', '-');
          final ev = int.parse(expText);
          if (ev.abs() > maxDecimalExponent) throw MathError(MathErrorCode.overflow, const {}, i);
          text = '${text}E$expText';
          isDecimal = true;
          i = j;
        } else if (src[i] == 'ᴇ') {
          throw MathError(MathErrorCode.missingArgument, const {'after': '×10'}, i);
        }
      }
      if (text.startsWith('.')) text = '0$text';
      if (text.endsWith('.')) text = '${text}0';
      out.add(Token(TokType.number, text, start, value: Rat.parseDecimal(text), isDecimal: isDecimal));
      continue;
    }
    // Physical constant reference: @name
    if (c == '@') {
      final start = i;
      i++;
      while (i < n && _isIdentPart(src[i])) {
        i++;
      }
      if (i == start + 1) throw MathError(MathErrorCode.unexpectedToken, const {'token': '@'}, start);
      out.add(Token(TokType.constRef, src.substring(start + 1, i), start));
      continue;
    }
    if (_isIdentStart(c)) {
      final start = i;
      // Infix combination operators written as nCr / nPr.
      if (src.startsWith('nCr', i) || src.startsWith('nPr', i)) {
        final prevIsValue = out.isNotEmpty &&
            (out.last.type == TokType.number || out.last.type == TokType.rparen || out.last.type == TokType.ident);
        final nextIsParen = i + 3 < n && src[i + 3] == '(';
        if (prevIsValue && !nextIsParen) {
          out.add(Token(TokType.op, src.substring(i, i + 3), i));
          i += 3;
          continue;
        }
      }
      while (i < n && _isIdentPart(src[i])) {
        i++;
      }
      out.add(Token(TokType.ident, src.substring(start, i), start));
      continue;
    }
    switch (c) {
      case '(':
        out.add(Token(TokType.lparen, c, i));
      case ')':
        out.add(Token(TokType.rparen, c, i));
      case '[':
        out.add(Token(TokType.lbrack, c, i));
      case ']':
        out.add(Token(TokType.rbrack, c, i));
      case ',':
        out.add(Token(TokType.comma, c, i));
      case ';':
        out.add(Token(TokType.semicolon, c, i));
      case 'π':
        out.add(Token(TokType.ident, 'pi', i));
      case 'φ':
        out.add(Token(TokType.ident, 'phi', i));
      case 'ℯ':
        out.add(Token(TokType.ident, 'e', i));
      case '∞':
        out.add(Token(TokType.ident, 'inf', i));
      case '+' || '*' || '/' || '^' || '!' || '%' || '°' || 'ʳ' || 'ᵍ' || '=' || '∠' || '√' || '∛' || '·' || '≤' || '≥' || '≠':
        out.add(Token(TokType.op, c, i));
      case '-' || '−' || '–':
        out.add(Token(TokType.op, '-', i));
      case '×':
        out.add(Token(TokType.op, '×', i));
      case '÷' || '⁄' || '∕':
        out.add(Token(TokType.op, '/', i));
      case '<':
        if (i + 1 < n && src[i + 1] == '=') {
          out.add(Token(TokType.op, '≤', i));
          i++;
        } else {
          out.add(Token(TokType.op, '<', i));
        }
      case '>':
        if (i + 1 < n && src[i + 1] == '=') {
          out.add(Token(TokType.op, '≥', i));
          i++;
        } else {
          out.add(Token(TokType.op, '>', i));
        }
      case '→':
        out.add(Token(TokType.op, '→', i));
      case '⁻':
        // ⁻¹ (inverse) or a negative superscript exponent ⁻²
        var j = i + 1;
        final sb = StringBuffer('-');
        while (j < n && _superscriptDigits.containsKey(src[j])) {
          sb.write(_superscriptDigits[src[j]]);
          j++;
        }
        if (sb.length == 1) throw MathError(MathErrorCode.unexpectedToken, const {'token': '⁻'}, i);
        out.add(Token(TokType.op, '^sup', i, value: Rat.parseDecimal(sb.toString())));
        i = j;
        continue;
      default:
        if (_superscriptDigits.containsKey(c)) {
          var j = i;
          final sb = StringBuffer();
          while (j < n && _superscriptDigits.containsKey(src[j])) {
            sb.write(_superscriptDigits[src[j]]);
            j++;
          }
          out.add(Token(TokType.op, '^sup', i, value: Rat.parseDecimal(sb.toString())));
          i = j;
          continue;
        }
        throw MathError(MathErrorCode.unexpectedToken, {'token': c}, i);
    }
    i++;
  }
  out.add(Token(TokType.eof, '', n));
  return out;
}

/// Names known to the parser besides built-ins.
class ParseScope {
  const ParseScope({
    this.variables = const {},
    this.userFunctions = const {},
    this.allowDefinitions = true,
    this.boundVariables = const {},
  });

  /// Defined variable names (e.g. A, radius, Ans).
  final Set<String> variables;

  /// User function names (f, g, area…).
  final Set<String> userFunctions;

  final bool allowDefinitions;

  /// Names that act as variables in this context even if undefined
  /// (e.g. x in a graph, θ in polar mode).
  final Set<String> boundVariables;
}

/// Standard single-letter calculator variables that are always valid names.
const Set<String> memoryVariableNames = {'A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'};

class Parser {
  Parser(String source, {this.scope = const ParseScope()})
      : _tokens = tokenize(source) {
    _expandIdentifiers();
  }

  final ParseScope scope;
  List<Token> _tokens;
  int _pos = 0;
  int _depth = 0;

  /// Parses a complete statement.
  static Node parse(String source, {ParseScope scope = const ParseScope()}) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) throw const MathError(MathErrorCode.emptyInput);
    final p = Parser(trimmed, scope: scope);
    return p._statement();
  }

  /// Parses a bare expression (no assignment, definition or relation).
  static Node parseExpression(String source, {ParseScope scope = const ParseScope()}) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) throw const MathError(MathErrorCode.emptyInput);
    final p = Parser(trimmed, scope: scope);
    final node = p._expr();
    p._expectEnd();
    return node;
  }

  Token get _cur => _tokens[_pos];
  Token _peek([int k = 1]) => _tokens[(_pos + k).clamp(0, _tokens.length - 1)];
  Token _advance() => _tokens[_pos++];

  bool _isOp(String s) => _cur.type == TokType.op && _cur.text == s;

  // ------------------------------------------------ identifier resolution

  bool _isKnownName(String w) =>
      functionIndex.containsKey(w) ||
      functionAliases.containsKey(w) ||
      builtinConstantNames.contains(w) ||
      scope.variables.contains(w) ||
      scope.userFunctions.contains(w) ||
      scope.boundVariables.contains(w) ||
      memoryVariableNames.contains(w) ||
      w == 'Ans' ||
      w == 'PreAns';

  /// Splits words like `sinx`, `2pix`, `xy` into known names.
  void _expandIdentifiers() {
    final out = <Token>[];
    for (var k = 0; k < _tokens.length; k++) {
      final t = _tokens[k];
      if (t.type != TokType.ident || _isKnownName(t.text) || t.text.length == 1) {
        out.add(t);
        continue;
      }
      // Assignment / definition targets keep their whole name.
      final next = k + 1 < _tokens.length ? _tokens[k + 1] : null;
      final isTarget = (k == 0 && next != null && next.type == TokType.op && next.text == '=') ||
          (k > 0 && _tokens[k - 1].type == TokType.op && _tokens[k - 1].text == '→') ||
          (k == 0 && next != null && next.type == TokType.lparen && scope.allowDefinitions && _looksLikeDefinition(k));
      if (isTarget) {
        out.add(t);
        continue;
      }
      var pieces = _split(t.text);
      // "foo(" is an unknown function, not f·o·o(…) — unless the word ends
      // in a known function name ("xsin(" = x·sin(…)).
      if (pieces != null && next != null && next.type == TokType.lparen) {
        final lastName = functionAliases[pieces.last] ?? pieces.last;
        if (!functionIndex.containsKey(lastName) && !scope.userFunctions.contains(lastName)) pieces = null;
      }
      if (pieces == null) {
        out.add(t);
        continue;
      }
      var offset = t.pos;
      for (final p in pieces) {
        if (_isDigit(p[0])) {
          out.add(Token(TokType.number, p, offset, value: Rat.parseDecimal(p)));
        } else {
          out.add(Token(TokType.ident, p, offset));
        }
        offset += p.length;
      }
    }
    _tokens = out;
  }

  bool _looksLikeDefinition(int k) {
    // name ( ident (, ident)* ) =
    var j = k + 2;
    while (j < _tokens.length) {
      if (_tokens[j].type != TokType.ident) return false;
      j++;
      if (j < _tokens.length && _tokens[j].type == TokType.comma) {
        j++;
        continue;
      }
      break;
    }
    return j + 1 < _tokens.length &&
        _tokens[j].type == TokType.rparen &&
        _tokens[j + 1].type == TokType.op &&
        _tokens[j + 1].text == '=';
  }

  List<String>? _split(String w) {
    final pieces = <String>[];
    var i = 0;
    var hasMultiLetterKnown = false;
    while (i < w.length) {
      if (_isDigit(w[i])) {
        var j = i;
        while (j < w.length && _isDigit(w[j])) {
          j++;
        }
        pieces.add(w.substring(i, j));
        i = j;
        continue;
      }
      String? best;
      for (var j = w.length; j > i + 1; j--) {
        final cand = w.substring(i, j);
        if (_isKnownName(cand)) {
          best = cand;
          break;
        }
      }
      if (best != null) {
        hasMultiLetterKnown = true;
        pieces.add(best);
        i += best.length;
      } else {
        pieces.add(w[i]);
        i++;
      }
    }
    final letters = pieces.where((p) => !_isDigit(p[0])).length;
    if (!hasMultiLetterKnown && letters > 3) return null;
    return pieces;
  }

  // ------------------------------------------------------------ statements

  Node _statement() {
    // f(x, y) = body
    if (scope.allowDefinitions &&
        _cur.type == TokType.ident &&
        _peek().type == TokType.lparen &&
        !functionIndex.containsKey(_cur.text) &&
        !builtinConstantNames.contains(_cur.text) &&
        _looksLikeDefinition(_pos)) {
      final name = _advance().text;
      _advance(); // (
      final params = <String>[];
      while (_cur.type == TokType.ident) {
        params.add(_advance().text);
        if (_cur.type == TokType.comma) _advance();
      }
      _advance(); // )
      _advance(); // =
      final body = _expr();
      _expectEnd();
      if (params.toSet().length != params.length) {
        throw const MathError(MathErrorCode.invalidExpression, {'detail': 'parameter names must be different'});
      }
      return FunctionDefNode(name, params, body);
    }
    // name = expr   (assignment when the name does not appear on the right)
    if (_cur.type == TokType.ident && _peek().type == TokType.op && _peek().text == '=') {
      final name = _cur.text;
      final save = _pos;
      _pos += 2;
      final rhs = _expr();
      if (_cur.type == TokType.eof &&
          !functionIndex.containsKey(name) &&
          !builtinConstantNames.contains(name) &&
          !freeVariables(rhs).contains(name) &&
          _isAssignableName(name)) {
        return AssignmentNode(name, rhs);
      }
      _pos = save;
    }
    final left = _expr();
    if (_cur.type == TokType.op) {
      final rel = switch (_cur.text) {
        '=' => RelOp.eq,
        '<' => RelOp.lt,
        '>' => RelOp.gt,
        '≤' => RelOp.le,
        '≥' => RelOp.ge,
        '≠' => RelOp.ne,
        _ => null,
      };
      if (rel != null) {
        _advance();
        final right = _expr();
        _expectEnd();
        return EquationNode(left, right, rel);
      }
      if (_cur.text == '→') {
        _advance();
        if (_cur.type != TokType.ident) {
          throw MathError(MathErrorCode.missingArgument, const {'after': '→'}, _cur.pos);
        }
        final name = _advance().text;
        _expectEnd();
        if (!_isAssignableName(name)) {
          throw MathError(MathErrorCode.invalidAssignment, {'name': name});
        }
        return AssignmentNode(name, left);
      }
    }
    _expectEnd();
    return left;
  }

  bool _isAssignableName(String name) =>
      name != 'Ans' && name != 'PreAns' && !builtinConstantNames.contains(name) && !functionIndex.containsKey(name);

  void _expectEnd() {
    if (_cur.type == TokType.eof) return;
    if (_cur.type == TokType.rparen || _cur.type == TokType.rbrack) {
      throw MathError(MathErrorCode.mismatchedParentheses, const {'missing': 'open'}, _cur.pos);
    }
    throw MathError(MathErrorCode.unexpectedToken, {'token': _cur.text}, _cur.pos);
  }

  // ----------------------------------------------------------- expressions

  Node _expr() {
    if (++_depth > 200) throw const MathError(MathErrorCode.recursionLimit);
    try {
      return _additive();
    } finally {
      _depth--;
    }
  }

  Node _additive() {
    var left = _multiplicative();
    while (_cur.type == TokType.op && (_cur.text == '+' || _cur.text == '-')) {
      final op = _advance().text == '+' ? BinaryOp.add : BinaryOp.sub;
      final right = _multiplicative();
      left = BinaryNode(op, left, right);
    }
    return left;
  }

  bool _startsOperand(Token t, Token prev) {
    switch (t.type) {
      case TokType.number:
        // "2 3" is not implicit multiplication; ")3" or "x2" is.
        return prev.type != TokType.number;
      case TokType.ident:
      case TokType.constRef:
      case TokType.lparen:
      case TokType.lbrack:
        return true;
      case TokType.op:
        return t.text == '√' || t.text == '∛';
      default:
        return false;
    }
  }

  Node _multiplicative() {
    var left = _combination();
    while (true) {
      if (_cur.type == TokType.op && (_cur.text == '*' || _cur.text == '×' || _cur.text == '·' || _cur.text == '/')) {
        final t = _advance().text;
        final right = _combination();
        left = switch (t) {
          '/' => BinaryNode(BinaryOp.div, left, right),
          '×' => BinaryNode(BinaryOp.mul, left, right, mulStyle: MulStyle.times),
          '·' => BinaryNode(BinaryOp.mul, left, right, mulStyle: MulStyle.dot),
          _ => BinaryNode(BinaryOp.mul, left, right),
        };
      } else if (_startsOperand(_cur, _tokens[_pos - 1])) {
        final right = _combination();
        left = BinaryNode(BinaryOp.mul, left, right, mulStyle: MulStyle.implicit);
      } else {
        return left;
      }
    }
  }

  Node _combination() {
    var left = _unary();
    while (_cur.type == TokType.op && (_cur.text == 'nCr' || _cur.text == 'nPr' || _cur.text == '∠')) {
      final t = _advance().text;
      final right = _unary();
      left = BinaryNode(t == 'nCr' ? BinaryOp.nCr : (t == 'nPr' ? BinaryOp.nPr : BinaryOp.polar), left, right);
    }
    return left;
  }

  Node _unary() {
    if (_cur.type == TokType.op) {
      switch (_cur.text) {
        case '-':
          _advance();
          _requireOperand('−');
          return UnaryNode(UnaryOp.negate, _unary());
        case '+':
          _advance();
          _requireOperand('+');
          return _unary();
        case '√':
          _advance();
          _requireOperand('√');
          return FunctionNode('sqrt', [_unary()]);
        case '∛':
          _advance();
          _requireOperand('∛');
          return FunctionNode('cbrt', [_unary()]);
      }
    }
    return _power();
  }

  void _requireOperand(String after) {
    if (_cur.type == TokType.eof || _cur.type == TokType.rparen || _cur.type == TokType.comma) {
      throw MathError(MathErrorCode.missingArgument, {'after': after}, _cur.pos);
    }
  }

  Node _power() {
    final base = _postfix();
    if (_isOp('^')) {
      _advance();
      _requireOperand('^');
      final exponent = _unary();
      return BinaryNode(BinaryOp.pow, base, exponent);
    }
    return base;
  }

  Node _postfix() {
    var node = _primary();
    while (_cur.type == TokType.op) {
      switch (_cur.text) {
        case '!':
          _advance();
          node = UnaryNode(UnaryOp.factorial, node);
        case '%':
          _advance();
          node = UnaryNode(UnaryOp.percent, node);
        case '°':
          _advance();
          node = UnaryNode(UnaryOp.degrees, node);
        case 'ʳ':
          _advance();
          node = UnaryNode(UnaryOp.radians, node);
        case 'ᵍ':
          _advance();
          node = UnaryNode(UnaryOp.gradians, node);
        case '^sup':
          final v = _advance().value!;
          final exp = v.isNegative
              ? UnaryNode(UnaryOp.negate, NumberNode(-v))
              : NumberNode(v) as Node;
          node = BinaryNode(BinaryOp.pow, node, exp);
        default:
          return node;
      }
    }
    return node;
  }

  List<Node> _argumentList(String fname) {
    // Assumes '(' consumed. Auto-closes at end of input.
    final args = <Node>[];
    if (_cur.type == TokType.rparen) {
      _advance();
      return args;
    }
    if (_cur.type == TokType.eof) {
      throw MathError(MathErrorCode.missingArgument, {'after': '$fname('}, _cur.pos);
    }
    while (true) {
      if (_cur.type == TokType.comma) {
        throw MathError(MathErrorCode.missingArgument, {'after': '$fname('}, _cur.pos);
      }
      args.add(_argument());
      if (_cur.type == TokType.comma) {
        _advance();
        if (_cur.type == TokType.eof || _cur.type == TokType.rparen) {
          throw MathError(MathErrorCode.missingArgument, const {'after': ','}, _cur.pos);
        }
        continue;
      }
      if (_cur.type == TokType.rparen) {
        _advance();
        return args;
      }
      if (_cur.type == TokType.eof) return args; // auto-close
      throw MathError(MathErrorCode.unexpectedToken, {'token': _cur.text}, _cur.pos);
    }
  }

  /// Function arguments may be equations (e.g. solve(x^2=4, x)).
  Node _argument() {
    final left = _expr();
    if (_isOp('=')) {
      _advance();
      return EquationNode(left, _expr());
    }
    return left;
  }

  Node _primary() {
    final t = _cur;
    switch (t.type) {
      case TokType.number:
        _advance();
        return NumberNode(t.value!, isDecimal: t.isDecimal);
      case TokType.constRef:
        _advance();
        return ConstantNode('@${t.text}');
      case TokType.ident:
        return _identifier();
      case TokType.lparen:
        _advance();
        if (_cur.type == TokType.rparen) {
          throw MathError(MathErrorCode.missingArgument, const {'after': '('}, _cur.pos);
        }
        if (_cur.type == TokType.eof) {
          throw MathError(MathErrorCode.missingArgument, const {'after': '('}, _cur.pos);
        }
        final first = _expr();
        if (_cur.type == TokType.comma) {
          // (a, b, c) → vector
          final items = [first];
          while (_cur.type == TokType.comma) {
            _advance();
            items.add(_expr());
          }
          _closeParen();
          return VectorNode(items);
        }
        _closeParen();
        return first;
      case TokType.lbrack:
        return _bracketLiteral();
      case TokType.eof:
        throw MathError(MathErrorCode.missingArgument,
            {if (_pos > 0) 'after': _tokens[_pos - 1].text}, t.pos);
      case TokType.rparen:
        if (_pos > 0 && _tokens[_pos - 1].type == TokType.lparen) {
          throw MathError(MathErrorCode.missingArgument, const {'after': '('}, t.pos);
        }
        throw MathError(MathErrorCode.mismatchedParentheses, const {'missing': 'open'}, t.pos);
      case TokType.op:
        if (t.text == '^sup' || t.text == '!' || t.text == '%') {
          throw MathError(MathErrorCode.missingArgument, const {}, t.pos);
        }
        throw MathError(MathErrorCode.unexpectedToken, {'token': t.text == '^sup' ? '^' : t.text}, t.pos);
      default:
        throw MathError(MathErrorCode.unexpectedToken, {'token': t.text}, t.pos);
    }
  }

  void _closeParen() {
    if (_cur.type == TokType.rparen) {
      _advance();
      return;
    }
    if (_cur.type == TokType.eof) return; // auto-close trailing brackets
    throw MathError(MathErrorCode.unexpectedToken, {'token': _cur.text}, _cur.pos);
  }

  Node _identifier() {
    final t = _advance();
    var name = functionAliases[t.text] ?? t.text;
    // Built-in function
    final spec = functionIndex[name];
    if (spec != null) {
      List<Node> args;
      if (_cur.type == TokType.lparen) {
        _advance();
        args = _argumentList(name);
      } else if (spec.maxArgs == 0) {
        args = const [];
      } else {
        // "sin 30" / "sin x": the argument is the following power-level operand.
        _requireOperand(name);
        args = [_power()];
      }
      _checkArity(spec, args.length, t.pos);
      return FunctionNode(name, args);
    }
    if (builtinConstantNames.contains(name)) return ConstantNode(name);
    // User-defined function call
    if (scope.userFunctions.contains(name) && _cur.type == TokType.lparen) {
      _advance();
      return FunctionNode(name, _argumentList(name));
    }
    if (_isKnownName(name) || name.length == 1) return VariableNode(name);
    // Unknown multi-letter word: still a variable; the evaluator reports it
    // as undefined if it has no value (lets users name variables freely).
    if (_cur.type == TokType.lparen) {
      throw MathError(MathErrorCode.unknownIdentifier, {'name': name}, t.pos);
    }
    return VariableNode(name);
  }

  void _checkArity(FunctionSpec spec, int got, int pos) {
    if (got < spec.minArgs || (spec.maxArgs >= 0 && got > spec.maxArgs)) {
      final expected = spec.maxArgs < 0
          ? 'at least ${spec.minArgs}'
          : spec.minArgs == spec.maxArgs
              ? '${spec.minArgs}'
              : '${spec.minArgs}–${spec.maxArgs}';
      throw MathError(MathErrorCode.wrongArgumentCount, {'name': spec.name, 'expected': expected, 'got': got}, pos);
    }
  }

  Node _bracketLiteral() {
    _advance(); // [
    if (_cur.type == TokType.lbrack) {
      // [[a,b],[c,d]]
      final rows = <List<Node>>[];
      while (_cur.type == TokType.lbrack) {
        _advance();
        final row = <Node>[];
        if (_cur.type != TokType.rbrack) {
          row.add(_expr());
          while (_cur.type == TokType.comma) {
            _advance();
            row.add(_expr());
          }
        }
        _expectBracket();
        rows.add(row);
        if (_cur.type == TokType.comma) _advance();
      }
      _expectBracket();
      return _matrixFromRows(rows);
    }
    // [a, b, c] vector, or [a, b; c, d] matrix
    final rows = <List<Node>>[[]];
    if (_cur.type == TokType.rbrack) {
      throw const MathError(MathErrorCode.emptyMatrix);
    }
    rows.last.add(_expr());
    while (_cur.type == TokType.comma || _cur.type == TokType.semicolon) {
      if (_advance().type == TokType.semicolon) rows.add([]);
      rows.last.add(_expr());
    }
    _expectBracket();
    if (rows.length == 1) return VectorNode(rows.first);
    return _matrixFromRows(rows);
  }

  Node _matrixFromRows(List<List<Node>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) throw const MathError(MathErrorCode.emptyMatrix);
    final c = rows.first.length;
    for (final r in rows) {
      if (r.length != c) {
        throw const MathError(MathErrorCode.dimensionMismatch, {'detail': 'every matrix row needs the same number of entries'});
      }
    }
    return MatrixNode(rows);
  }

  void _expectBracket() {
    if (_cur.type == TokType.rbrack) {
      _advance();
      return;
    }
    if (_cur.type == TokType.eof) return; // auto-close
    throw MathError(MathErrorCode.unexpectedToken, {'token': _cur.text}, _cur.pos);
  }
}
