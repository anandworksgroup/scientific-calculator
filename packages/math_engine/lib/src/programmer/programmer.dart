/// Programmer (base-N) calculator: integer arithmetic and bitwise logic in
/// a fixed word size with signed (two's complement) or unsigned wrapping.
library;

import '../core/errors.dart';

enum IntBase {
  bin(2),
  oct(8),
  dec(10),
  hex(16);

  const IntBase(this.radix);
  final int radix;
}

class ProgrammerCalc {
  ProgrammerCalc({this.bits = 64, this.signed = true}) {
    if (![8, 16, 32, 64].contains(bits)) throw ArgumentError('word size must be 8, 16, 32 or 64');
  }

  final int bits;
  final bool signed;

  BigInt get _mask => (BigInt.one << bits) - BigInt.one;
  BigInt get minValue => signed ? -(BigInt.one << (bits - 1)) : BigInt.zero;
  BigInt get maxValue => signed ? (BigInt.one << (bits - 1)) - BigInt.one : _mask;

  /// Wraps [v] into the word size (two's complement for signed mode).
  BigInt wrap(BigInt v) {
    var u = v & _mask;
    if (signed && u >= (BigInt.one << (bits - 1))) u -= BigInt.one << bits;
    return u;
  }

  /// Unsigned bit pattern of [v].
  BigInt pattern(BigInt v) => v & _mask;

  /// Formats [v] in [base]. Non-decimal bases show the two's complement
  /// bit pattern; decimal shows the signed/unsigned value.
  String format(BigInt v, IntBase base, {bool group = false}) {
    final w = wrap(v);
    String s;
    if (base == IntBase.dec) {
      s = w.toString();
    } else {
      s = pattern(w).toRadixString(base.radix).toUpperCase();
    }
    if (!group || base == IntBase.dec) return s;
    final size = base == IntBase.bin ? 4 : (base == IntBase.hex ? 4 : 3);
    final out = StringBuffer();
    for (var k = 0; k < s.length; k++) {
      if (k > 0 && (s.length - k) % size == 0) out.write(' ');
      out.write(s[k]);
    }
    return out.toString();
  }

  /// Bits of [v], most significant first.
  List<bool> bitList(BigInt v) {
    final p = pattern(wrap(v));
    return [for (var k = bits - 1; k >= 0; k--) ((p >> k) & BigInt.one) == BigInt.one];
  }

  BigInt toggleBit(BigInt v, int index) => wrap(pattern(wrap(v)) ^ (BigInt.one << index));

  /// Parses a literal in [base] (prefixes 0x, 0b, 0o override the base).
  BigInt parseLiteral(String text, IntBase base) {
    var s = text.trim().replaceAll(' ', '').replaceAll('_', '');
    var radix = base.radix;
    if (s.length > 2 && s[0] == '0') {
      final p = s[1].toLowerCase();
      if (p == 'x') radix = 16;
      if (p == 'b' && base != IntBase.hex) radix = 2;
      if (p == 'o') radix = 8;
      if ('xbo'.contains(p) && !(p == 'b' && base == IntBase.hex)) s = s.substring(2);
    }
    final v = BigInt.tryParse(s, radix: radix);
    if (v == null) {
      throw MathError(MathErrorCode.invalidExpression, {'detail': "'$text' is not a valid ${_baseName(radix)} number"});
    }
    return v;
  }

  static String _baseName(int radix) => switch (radix) {
        2 => 'binary',
        8 => 'octal',
        16 => 'hexadecimal',
        _ => 'decimal',
      };

  /// Evaluates an integer expression. Operators (C precedence, low→high):
  /// `|`/OR/NOR, `^`/XOR/XNOR, `&`/AND/NAND, `<<` `>>`, `+` `−`,
  /// `*` `/` `%`/MOD, unary `−` `~`/NOT. Division truncates toward zero.
  BigInt evaluate(String expression, IntBase base) {
    final p = _PParser(this, expression, base);
    final v = p.parse();
    return wrap(v);
  }
}

class _PTok {
  _PTok(this.kind, this.text, [this.value]);
  final String kind; // num, op, lp, rp, eof
  final String text;
  final BigInt? value;
}

class _PParser {
  _PParser(this.calc, String src, this.base) : _toks = _lex(calc, src, base);

  final ProgrammerCalc calc;
  final IntBase base;
  final List<_PTok> _toks;
  int _i = 0;

  static const _words = {'AND', 'OR', 'XOR', 'NOT', 'NAND', 'NOR', 'XNOR', 'MOD', 'SHL', 'SHR'};

  static List<_PTok> _lex(ProgrammerCalc calc, String src, IntBase base) {
    final out = <_PTok>[];
    var i = 0;
    bool isDigit(String c) {
      final u = c.toUpperCase();
      final code = u.codeUnitAt(0);
      final val = code >= 48 && code <= 57 ? code - 48 : (code >= 65 && code <= 70 ? code - 55 : 99);
      return val < base.radix;
    }

    while (i < src.length) {
      final c = src[i];
      if (c == ' ') {
        i++;
        continue;
      }
      // Word operators (checked before hex digits so "AND" is not hex A…).
      final rest = src.substring(i).toUpperCase();
      String? word;
      for (final w in _words) {
        if (rest.startsWith(w) && (rest.length == w.length || !RegExp(r'[A-Z0-9]').hasMatch(rest[w.length]))) {
          if (word == null || w.length > word.length) word = w;
        }
      }
      if (word != null) {
        out.add(_PTok('op', word));
        i += word.length;
        continue;
      }
      if (isDigit(c) || (c == '0' && i + 1 < src.length && 'xXbBoO'.contains(src[i + 1]))) {
        final start = i;
        i++;
        if (c == '0' && i < src.length && 'xXoO'.contains(src[i])) i++;
        if (c == '0' && i < src.length && 'bB'.contains(src[i]) && base != IntBase.hex) i++;
        while (i < src.length && (RegExp(r'[0-9A-Fa-f_]').hasMatch(src[i]))) {
          i++;
        }
        final text = src.substring(start, i);
        out.add(_PTok('num', text, calc.parseLiteral(text, base)));
        continue;
      }
      if (src.startsWith('<<', i) || src.startsWith('>>', i)) {
        out.add(_PTok('op', src.substring(i, i + 2)));
        i += 2;
        continue;
      }
      if ('+-−*×/÷%&|^~'.contains(c)) {
        out.add(_PTok('op', switch (c) { '−' => '-', '×' => '*', '÷' => '/', _ => c }));
        i++;
        continue;
      }
      if (c == '(') {
        out.add(_PTok('lp', c));
        i++;
        continue;
      }
      if (c == ')') {
        out.add(_PTok('rp', c));
        i++;
        continue;
      }
      throw MathError(MathErrorCode.unexpectedToken, {'token': c}, i);
    }
    out.add(_PTok('eof', ''));
    return out;
  }

  _PTok get _cur => _toks[_i];
  bool _op(Set<String> ops) => _cur.kind == 'op' && ops.contains(_cur.text);

  BigInt parse() {
    if (_cur.kind == 'eof') throw const MathError(MathErrorCode.emptyInput);
    final v = _or();
    if (_cur.kind == 'rp') throw const MathError(MathErrorCode.mismatchedParentheses, {'missing': 'open'});
    if (_cur.kind != 'eof') throw MathError(MathErrorCode.unexpectedToken, {'token': _cur.text});
    return v;
  }

  BigInt _w(BigInt v) => calc.wrap(v);
  BigInt _not(BigInt v) => _w(~v);

  BigInt _or() {
    var l = _xor();
    while (_op({'|', 'OR', 'NOR'})) {
      final op = _toks[_i++].text;
      final r = _xor();
      l = op == 'NOR' ? _not(l | r) : _w(l | r);
    }
    return l;
  }

  BigInt _xor() {
    var l = _and();
    while (_op({'^', 'XOR', 'XNOR'})) {
      final op = _toks[_i++].text;
      final r = _and();
      l = op == 'XNOR' ? _not(l ^ r) : _w(l ^ r);
    }
    return l;
  }

  BigInt _and() {
    var l = _shift();
    while (_op({'&', 'AND', 'NAND'})) {
      final op = _toks[_i++].text;
      final r = _shift();
      l = op == 'NAND' ? _not(l & r) : _w(l & r);
    }
    return l;
  }

  BigInt _shift() {
    var l = _add();
    while (_op({'<<', '>>', 'SHL', 'SHR'})) {
      final op = _toks[_i++].text;
      final r = _add();
      if (r.isNegative || r > BigInt.from(calc.bits * 2)) {
        throw const MathError(MathErrorCode.domainError, {'function': 'shift', 'value': 'negative or oversized amounts'});
      }
      final n = r.toInt();
      if (op == '<<' || op == 'SHL') {
        l = _w(l << n);
      } else {
        // Arithmetic shift in signed mode, logical in unsigned mode.
        l = calc.signed ? _w(calc.wrap(l) >> n) : _w(calc.pattern(l) >> n);
      }
    }
    return l;
  }

  BigInt _add() {
    var l = _mul();
    while (_op({'+', '-'})) {
      final op = _toks[_i++].text;
      final r = _mul();
      l = _w(op == '+' ? l + r : l - r);
    }
    return l;
  }

  BigInt _mul() {
    var l = _unary();
    while (_op({'*', '/', '%', 'MOD'})) {
      final op = _toks[_i++].text;
      final r = _unary();
      if (op != '*' && r == BigInt.zero) throw const MathError(MathErrorCode.divisionByZero);
      l = _w(switch (op) {
        '*' => l * r,
        '/' => l ~/ r,
        _ => l.remainder(r),
      });
    }
    return l;
  }

  BigInt _unary() {
    if (_op({'-'})) {
      _i++;
      return _w(-_unary());
    }
    if (_op({'+'})) {
      _i++;
      return _unary();
    }
    if (_op({'~', 'NOT'})) {
      _i++;
      return _not(_unary());
    }
    return _primary();
  }

  BigInt _primary() {
    final t = _cur;
    if (t.kind == 'num') {
      _i++;
      return _w(t.value!);
    }
    if (t.kind == 'lp') {
      _i++;
      final v = _or();
      if (_cur.kind == 'rp') {
        _i++;
      } else if (_cur.kind != 'eof') {
        throw MathError(MathErrorCode.unexpectedToken, {'token': _cur.text});
      }
      return v;
    }
    if (t.kind == 'eof') throw const MathError(MathErrorCode.missingArgument);
    throw MathError(MathErrorCode.unexpectedToken, {'token': t.text});
  }
}
