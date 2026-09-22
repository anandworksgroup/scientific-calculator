import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter/material.dart' show Icons;

import '../../../l10n/generated/app_localizations.dart';
import '../editor/expression_editor.dart';

/// What a key does.
sealed class KeyAction {
  const KeyAction();
}

final class InsertText extends KeyAction {
  const InsertText(this.text);
  final String text;
}

/// An indivisible token such as `Ans`, `nCr` or a constant `@c`.
final class InsertAtom extends KeyAction {
  const InsertAtom(this.text);
  final String text;
}

final class InsertFunc extends KeyAction {
  const InsertFunc(this.name);
  final String name;
}

final class InsertTemplate extends KeyAction {
  const InsertTemplate(this.type, {this.prefill = const {}, this.closed = false, this.wrapPrevious = false, this.prefix = ''});
  final TemplateType type;
  final Map<int, String> prefill;

  /// Leave the cursor after the finished structure (x², x⁻¹).
  final bool closed;

  /// Use the operand before the cursor as the first slot (a/b).
  final bool wrapPrevious;

  /// Text inserted before the template (e.g. `10` for 10ˣ).
  final String prefix;
}

enum CalcCommand {
  shift,
  alpha,
  del,
  ac,
  equals,
  approx,
  left,
  right,
  store,
  memClear,
  memRecall,
  memAdd,
  memSub,
  memStore,
  formatToggle,
  menu,
  catalog,
  constants,
  history,
  undo,
  redo,
}

final class Command extends KeyAction {
  const Command(this.command);
  final CalcCommand command;
}

enum KeyStyle { number, function, operator, action, equals, modifier }

/// A labelled alternative (SHIFT/ALPHA layer or long-press menu entry).
class KeyAlt {
  const KeyAlt(this.label, this.action, this.semantic, {this.tex = true});
  final String label;
  final KeyAction action;
  final String semantic;
  final bool tex;
}

class CalcKey {
  const CalcKey({
    required this.id,
    required this.label,
    required this.action,
    required this.semantic,
    this.style = KeyStyle.function,
    this.tex = true,
    this.shift,
    this.alpha,
    this.longPress = const [],
    this.flex = 1,
    this.icon,
  });

  final String id;

  /// LaTeX (when [tex]) or plain label.
  final String label;
  final KeyAction action;
  final String semantic;
  final KeyStyle style;
  final bool tex;
  final KeyAlt? shift;
  final KeyAlt? alpha;
  final List<KeyAlt> longPress;
  final int flex;

  /// Material icon drawn instead of [label] (cursor and menu keys).
  final IconData? icon;
}

/// Key definitions shared by all layouts.
class CalcKeySet {
  CalcKeySet(this.l);
  final AppLocalizations l;

  CalcKey digit(String d, {KeyAlt? shift, KeyAlt? alpha}) => CalcKey(
        id: 'd$d',
        label: d,
        action: InsertText(d),
        semantic: l.keyDigit(d),
        style: KeyStyle.number,
        tex: false,
        shift: shift,
        alpha: alpha,
      );

  KeyAlt v(String name) => KeyAlt(name, InsertAtom(name), l.keyVariable(name));

  late final shift = CalcKey(id: 'shift', label: 'SHIFT', action: const Command(CalcCommand.shift), semantic: l.keyShift, style: KeyStyle.modifier, tex: false);
  late final alpha = CalcKey(id: 'alpha', label: 'ALPHA', action: const Command(CalcCommand.alpha), semantic: l.keyAlpha, style: KeyStyle.modifier, tex: false);
  late final left = CalcKey(id: 'left', label: '<', icon: Icons.chevron_left, action: const Command(CalcCommand.left), semantic: l.calcCursorLeft, style: KeyStyle.modifier, tex: false);
  late final right = CalcKey(id: 'right', label: '>', icon: Icons.chevron_right, action: const Command(CalcCommand.right), semantic: l.calcCursorRight, style: KeyStyle.modifier, tex: false);
  late final sd = CalcKey(
    id: 'sd',
    label: r'S\Leftrightarrow D',
    action: const Command(CalcCommand.formatToggle),
    semantic: l.keyFormatToggle,
    style: KeyStyle.modifier,
    shift: KeyAlt(r'\approx', const Command(CalcCommand.approx), l.calcDecimalForm),
  );
  late final menu = CalcKey(id: 'menu', label: '...', icon: Icons.more_horiz, action: const Command(CalcCommand.menu), semantic: l.calcModeMenu, style: KeyStyle.modifier, tex: false);

  late final frac = CalcKey(
    id: 'frac',
    label: r'\frac{\square}{\square}',
    action: const InsertTemplate(TemplateType.frac, wrapPrevious: true),
    semantic: l.keyFraction,
    shift: KeyAlt(r'\square\frac{\square}{\square}', const InsertTemplate(TemplateType.mixed), l.keyMixedFraction),
    alpha: v('A'),
  );
  late final sqrt = CalcKey(
    id: 'sqrt',
    label: r'\sqrt{\square}',
    action: const InsertTemplate(TemplateType.sqrt),
    semantic: l.keySqrt,
    shift: KeyAlt(r'\sqrt[3]{\square}', const InsertTemplate(TemplateType.root, prefill: {0: '3'}), l.keyCbrt),
    alpha: v('B'),
    longPress: [
      KeyAlt(r'\sqrt{\square}', const InsertTemplate(TemplateType.sqrt), l.keySqrt),
      KeyAlt(r'\sqrt[3]{\square}', const InsertTemplate(TemplateType.root, prefill: {0: '3'}), l.keyCbrt),
      KeyAlt(r'\sqrt[\square]{\square}', const InsertTemplate(TemplateType.root), l.keyNthRoot),
    ],
  );
  late final square = CalcKey(
    id: 'sq',
    label: r'x^{2}',
    action: const InsertTemplate(TemplateType.pow, prefill: {0: '2'}, closed: true),
    semantic: l.keySquare,
    shift: KeyAlt(r'x^{3}', const InsertTemplate(TemplateType.pow, prefill: {0: '3'}, closed: true), l.keyCube),
    alpha: v('C'),
  );
  late final power = CalcKey(
    id: 'pow',
    label: r'x^{\square}',
    action: const InsertTemplate(TemplateType.pow),
    semantic: l.keyPower,
    shift: KeyAlt(r'\sqrt[\square]{x}', const InsertTemplate(TemplateType.root), l.keyNthRoot),
    alpha: v('D'),
    longPress: [
      KeyAlt(r'x^{\square}', const InsertTemplate(TemplateType.pow), l.keyPower),
      KeyAlt(r'x^{2}', const InsertTemplate(TemplateType.pow, prefill: {0: '2'}, closed: true), l.keySquare),
      KeyAlt(r'x^{3}', const InsertTemplate(TemplateType.pow, prefill: {0: '3'}, closed: true), l.keyCube),
      KeyAlt(r'x^{-1}', const InsertTemplate(TemplateType.pow, prefill: {0: '-1'}, closed: true), l.keyInverse),
      KeyAlt(r'\sqrt[\square]{x}', const InsertTemplate(TemplateType.root), l.keyNthRoot),
      KeyAlt(r'10^{\square}', const InsertTemplate(TemplateType.pow, prefix: '10'), l.keyTenPower),
      KeyAlt(r'e^{\square}', const InsertTemplate(TemplateType.pow, prefix: 'e'), l.keyExpPower),
    ],
  );
  late final log = CalcKey(
    id: 'log',
    label: r'\log',
    action: const InsertFunc('log'),
    semantic: l.keyLog,
    shift: KeyAlt(r'10^{\square}', const InsertTemplate(TemplateType.pow, prefix: '10'), l.keyTenPower),
    alpha: v('E'),
    longPress: [
      KeyAlt(r'\log', const InsertFunc('log'), l.keyLog),
      KeyAlt(r'\log_{\square}\square', const InsertTemplate(TemplateType.logb), l.keyLogBase),
      KeyAlt(r'\log_{2}', const InsertFunc('log2'), l.keyLogBase),
      KeyAlt(r'10^{\square}', const InsertTemplate(TemplateType.pow, prefix: '10'), l.keyTenPower),
    ],
  );
  late final ln = CalcKey(
    id: 'ln',
    label: r'\ln',
    action: const InsertFunc('ln'),
    semantic: l.keyLn,
    shift: KeyAlt(r'e^{\square}', const InsertTemplate(TemplateType.pow, prefix: 'e'), l.keyExpPower),
    alpha: v('F'),
  );
  late final pi = CalcKey(
    id: 'pi',
    label: r'\pi',
    action: const InsertText('π'),
    semantic: l.keyPi,
    shift: KeyAlt('e', const InsertText('e'), l.keyE),
    alpha: v('X'),
    longPress: [
      KeyAlt(r'\pi', const InsertText('π'), l.keyPi),
      KeyAlt('e', const InsertText('e'), l.keyE),
      KeyAlt('i', const InsertText('i'), l.keyI),
      KeyAlt(r'\text{⋯}', const Command(CalcCommand.constants), l.calcConstants),
    ],
  );

  List<KeyAlt> _trigMenu(String f) => [
        KeyAlt('\\$f', InsertFunc(f), _sem(f)),
        KeyAlt('\\$f^{-1}', InsertFunc('a$f'), _sem('a$f')),
        KeyAlt('\\${f}h', InsertFunc('${f}h'), _sem('${f}h')),
        KeyAlt('\\${f}h^{-1}', InsertFunc('a${f}h'), _sem('a${f}h')),
      ];

  String _sem(String f) => switch (f) {
        'sin' => l.keySin,
        'cos' => l.keyCos,
        'tan' => l.keyTan,
        'asin' => l.keyAsin,
        'acos' => l.keyAcos,
        'atan' => l.keyAtan,
        'sinh' => l.keySinh,
        'cosh' => l.keyCosh,
        'tanh' => l.keyTanh,
        'asinh' => l.keyAsinh,
        'acosh' => l.keyAcosh,
        'atanh' => l.keyAtanh,
        _ => f,
      };

  CalcKey trig(String f, String alphaName) => CalcKey(
        id: f,
        label: '\\$f',
        action: InsertFunc(f),
        semantic: _sem(f),
        shift: KeyAlt('\\$f^{-1}', InsertFunc('a$f'), _sem('a$f')),
        alpha: alphaName == 'i' ? KeyAlt('i', const InsertText('i'), l.keyI) : v(alphaName),
        longPress: _trigMenu(f),
      );

  late final openParen = CalcKey(
    id: 'lp',
    label: '(',
    action: const InsertText('('),
    semantic: l.keyOpenParen,
    tex: false,
    shift: KeyAlt(r'\%', const InsertText('%'), l.keyPercent),
    alpha: KeyAlt('x', const InsertText('x'), l.keyVariableX),
    longPress: [
      KeyAlt(r'\left|\square\right|', const InsertTemplate(TemplateType.abs), l.keyAbs),
      KeyAlt(r'\lfloor x\rfloor', const InsertFunc('floor'), l.keyFloor),
      KeyAlt(r'\lceil x\rceil', const InsertFunc('ceil'), l.keyCeil),
      KeyAlt(r'\mathrm{round}', const InsertFunc('round'), l.keyRound),
    ],
  );
  late final closeParen = CalcKey(
    id: 'rp',
    label: ')',
    action: const InsertText(')'),
    semantic: l.keyCloseParen,
    tex: false,
    shift: KeyAlt(',', const InsertText(','), l.keyComma),
    alpha: KeyAlt('=', const InsertText('='), l.keyEquation),
  );

  late final del = CalcKey(id: 'del', label: 'DEL', action: const Command(CalcCommand.del), semantic: l.keyDel, style: KeyStyle.action, tex: false,
      shift: KeyAlt(r'\text{UNDO}', const Command(CalcCommand.undo), l.actionUndo));
  late final ac = CalcKey(id: 'ac', label: 'AC', action: const Command(CalcCommand.ac), semantic: l.keyAc, style: KeyStyle.action, tex: false,
      shift: KeyAlt(r'\text{REDO}', const Command(CalcCommand.redo), l.actionRedo));
  late final times = CalcKey(id: 'mul', label: r'\times', action: const InsertText('×'), semantic: l.keyTimes, style: KeyStyle.operator,
      shift: KeyAlt(r'n\mathrm{P}r', const InsertAtom('nPr'), l.keyNpr));
  late final divide = CalcKey(id: 'div', label: r'\div', action: const InsertText('÷'), semantic: l.keyDivide, style: KeyStyle.operator,
      shift: KeyAlt(r'n\mathrm{C}r', const InsertAtom('nCr'), l.keyNcr));
  late final plus = CalcKey(id: 'add', label: '+', action: const InsertText('+'), semantic: l.keyPlus, style: KeyStyle.operator,
      shift: KeyAlt('x!', const InsertText('!'), l.keyFactorial));
  late final minus = CalcKey(id: 'sub', label: '-', action: const InsertText('-'), semantic: l.keyMinus, style: KeyStyle.operator,
      shift: KeyAlt(r'\angle', const InsertText('∠'), l.keyAngle));
  late final dot = CalcKey(id: 'dot', label: '.', action: const InsertText('.'), semantic: l.keyDecimal, style: KeyStyle.number, tex: false,
      shift: KeyAlt(r'\mathrm{Ran\#}', const InsertFunc('rand'), l.keyRandom));
  late final exp = CalcKey(id: 'exp', label: r'\times10^{x}', action: const InsertText('ᴇ'), semantic: l.keyExp, style: KeyStyle.number,
      shift: KeyAlt(r'{}^{\circ}', const InsertText('°'), l.keyDegree));
  late final ans = CalcKey(id: 'ans', label: 'Ans', action: const InsertAtom('Ans'), semantic: l.keyAns, style: KeyStyle.number, tex: false,
      shift: KeyAlt(r'\text{STO}', const Command(CalcCommand.store), l.keyStore),
      longPress: [KeyAlt(r'\text{History}', const Command(CalcCommand.history), l.navHistory)]);
  late final equals = CalcKey(id: 'eq', label: '=', action: const Command(CalcCommand.equals), semantic: l.keyEquals, style: KeyStyle.equals, tex: false,
      shift: KeyAlt(r'\approx', const Command(CalcCommand.approx), l.calcDecimalForm));

  // Memory strip
  late final mc = CalcKey(id: 'mc', label: 'MC', action: const Command(CalcCommand.memClear), semantic: l.keyMemoryClear, style: KeyStyle.modifier, tex: false);
  late final mr = CalcKey(id: 'mr', label: 'MR', action: const Command(CalcCommand.memRecall), semantic: l.keyMemoryRecall, style: KeyStyle.modifier, tex: false);
  late final mPlus = CalcKey(id: 'mplus', label: 'M+', action: const Command(CalcCommand.memAdd), semantic: l.keyMemoryAdd, style: KeyStyle.modifier, tex: false);
  late final mMinus = CalcKey(id: 'mminus', label: 'M−', action: const Command(CalcCommand.memSub), semantic: l.keyMemorySubtract, style: KeyStyle.modifier, tex: false);
  late final ms = CalcKey(id: 'ms', label: 'MS', action: const Command(CalcCommand.memStore), semantic: l.keyMemoryStore, style: KeyStyle.modifier, tex: false);
  late final sto = CalcKey(id: 'sto', label: 'STO', action: const Command(CalcCommand.store), semantic: l.keyStore, style: KeyStyle.modifier, tex: false);

  // Extended (landscape / scientific tab)
  CalcKey fn(String name, String tex, String semantic, {KeyAlt? shift}) =>
      CalcKey(id: 'f_$name', label: tex, action: InsertFunc(name), semantic: semantic, shift: shift);

  CalcKey tpl(String id, String tex, TemplateType t, String semantic, {Map<int, String> prefill = const {}}) =>
      CalcKey(id: id, label: tex, action: InsertTemplate(t, prefill: prefill), semantic: semantic);

  CalcKey text(String id, String tex, String insert, String semantic, {bool atom = false}) =>
      CalcKey(id: id, label: tex, action: atom ? InsertAtom(insert) : InsertText(insert), semantic: semantic);

  late final integral = tpl('int', r'\int_{\square}^{\square}', TemplateType.integral, l.keyIntegral);
  late final derivative = tpl('deriv', r'\tfrac{d}{dx}', TemplateType.deriv, l.keyDerivative);
  late final sum = tpl('sum', r'\sum', TemplateType.sum, l.keySum);
  late final prod = tpl('prod', r'\prod', TemplateType.prod, l.keyProduct);
  late final lim = tpl('lim', r'\lim', TemplateType.lim, l.keyLimit);
  late final abs = tpl('abs', r'|x|', TemplateType.abs, l.keyAbs);
  late final logb = tpl('logb', r'\log_{\square}', TemplateType.logb, l.keyLogBase);
  late final factorial = text('fact', 'x!', '!', l.keyFactorial);
  late final nCr = text('ncr', r'n\mathrm{C}r', 'nCr', l.keyNcr, atom: true);
  late final nPr = text('npr', r'n\mathrm{P}r', 'nPr', l.keyNpr, atom: true);
  late final imag = text('i', 'i', 'i', l.keyI);
  late final euler = text('e', 'e', 'e', l.keyE);
  late final angle = text('angle', r'\angle', '∠', l.keyAngle);
  late final degree = text('deg', r'{}^{\circ}', '°', l.keyDegree);
  late final percent = text('pct', r'\%', '%', l.keyPercent);
  late final comma = text('comma', ',', ',', l.keyComma);
  late final varX = text('x', 'x', 'x', l.keyVariableX);
  late final eq = text('eqsign', '=', '=', l.keyEquation);
  late final inverse = CalcKey(id: 'inv', label: r'x^{-1}', action: const InsertTemplate(TemplateType.pow, prefill: {0: '-1'}, closed: true), semantic: l.keyInverse);
  late final tenPow = CalcKey(id: 'tenpow', label: r'10^{x}', action: const InsertTemplate(TemplateType.pow, prefix: '10'), semantic: l.keyTenPower);
  late final ePow = CalcKey(id: 'epow', label: r'e^{x}', action: const InsertTemplate(TemplateType.pow, prefix: 'e'), semantic: l.keyExpPower);
  late final cbrt = CalcKey(id: 'cbrt', label: r'\sqrt[3]{x}', action: const InsertTemplate(TemplateType.root, prefill: {0: '3'}), semantic: l.keyCbrt);
  late final nroot = CalcKey(id: 'nroot', label: r'\sqrt[n]{x}', action: const InsertTemplate(TemplateType.root), semantic: l.keyNthRoot);
  late final cube = CalcKey(id: 'cube', label: r'x^{3}', action: const InsertTemplate(TemplateType.pow, prefill: {0: '3'}, closed: true), semantic: l.keyCube);
  late final rand = fn('rand', r'\mathrm{Ran\#}', l.keyRandom);
  late final randInt = fn('randint', r'\mathrm{RanInt}', l.keyRandomInt);

  /// Portrait scientific keypad: modifier row, 2 function rows (6 columns)
  /// and a 4×5 number pad.
  List<List<CalcKey>> portraitFunctionRows() => [
        [shift, alpha, left, right, sd, menu],
        [frac, sqrt, square, power, log, ln],
        [pi, trig('sin', 'Y'), trig('cos', 'M'), trig('tan', 'i'), openParen, closeParen],
      ];

  List<List<CalcKey>> numberRows() => [
        [digit('7'), digit('8'), digit('9'), del, ac],
        [digit('4'), digit('5'), digit('6'), times, divide],
        [digit('1'), digit('2'), digit('3'), plus, minus],
        [digit('0'), dot, exp, ans, equals],
      ];

  List<CalcKey> memoryRow() => [mc, mr, mPlus, mMinus, ms, sto];

  /// Landscape: extra function columns to the left of the number pad.
  List<List<CalcKey>> landscapeFunctionRows() => [
        [shift, alpha, left, right, sd, menu, sto, mr],
        [frac, sqrt, square, power, log, ln, integral, derivative],
        [pi, trig('sin', 'Y'), trig('cos', 'M'), trig('tan', 'i'), openParen, closeParen, sum, prod],
        [fn('sinh', r'\sinh', l.keySinh), fn('cosh', r'\cosh', l.keyCosh), fn('tanh', r'\tanh', l.keyTanh), abs, factorial, nCr, lim, logb],
        [euler, imag, angle, degree, percent, comma, nPr, varX],
      ];

  /// Basic keypad (large keys).
  List<List<CalcKey>> basicRows() => [
        [ac, openParen, closeParen, divide],
        [digit('7'), digit('8'), digit('9'), times],
        [digit('4'), digit('5'), digit('6'), minus],
        [digit('1'), digit('2'), digit('3'), plus],
        [digit('0'), dot, del, equals],
      ];

  List<CalcKey> basicExtraRow() => [percent, frac, sqrt, square, sd];
}
