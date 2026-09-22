import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../data/repositories/history_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/clipboard_service.dart';
import '../calculator/calculator_controller.dart' show historyListProvider;
import '../converter/converter_screen.dart' show unitTexText;

/// Groups a decimal integer in threes (sign kept in front).
String groupDecimal(String s) {
  final neg = s.startsWith('-');
  final digits = neg ? s.substring(1) : s;
  final out = StringBuffer(neg ? '−' : '');
  for (var k = 0; k < digits.length; k++) {
    if (k > 0 && (digits.length - k) % 3 == 0) out.write(' ');
    out.write(digits[k]);
  }
  return out.toString();
}

/// Short base label (BIN/OCT/DEC/HEX); a technical abbreviation.
String baseShort(IntBase b) => b.name.toUpperCase();

String baseLong(AppLocalizations l, IntBase b) => switch (b) {
      IntBase.bin => l.progBin,
      IntBase.oct => l.progOct,
      IntBase.dec => l.progDec,
      IntBase.hex => l.progHex,
    };

/// A programmer keypad key: [label] is shown, [insert] goes into the field.
class _Key {
  const _Key(this.label, this.insert, {this.digit});
  final String label;
  final String insert;

  /// Digit value for base-dependent enabling.
  final int? digit;
}

/// Programmer calculator (URS §45–46): integer and bitwise arithmetic in a
/// fixed word size, shown in all four bases at once.
class ProgrammerScreen extends ConsumerStatefulWidget {
  const ProgrammerScreen({super.key});

  @override
  ConsumerState<ProgrammerScreen> createState() => _ProgrammerScreenState();
}

class _ProgrammerScreenState extends ConsumerState<ProgrammerScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  IntBase _base = IntBase.dec;
  int _bits = 64;
  bool _signed = true;
  BigInt? _value;
  MathError? _error;

  ProgrammerCalc get _calc => ProgrammerCalc(bits: _bits, signed: _signed);

  @override
  void initState() {
    super.initState();
    _input.addListener(_evaluate);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _evaluate() {
    final text = _input.text.trim();
    if (text.isEmpty) {
      setState(() {
        _value = null;
        _error = null;
      });
      return;
    }
    final calc = _calc;
    final r = guard(() => calc.evaluate(text, _base));
    setState(() {
      switch (r) {
        case Success(:final value):
          _value = value;
          _error = null;
        case Failure(:final error):
          _error = error;
        case Cancelled():
          _error = const MathError(MathErrorCode.cancelled);
      }
    });
  }

  void _setText(String s) {
    _input.value = TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }

  void _setBase(IntBase b) {
    final v = _error == null ? _value : null;
    _base = b;
    if (v != null) {
      _setText(_calc.format(v, b));
    } else {
      _evaluate();
    }
  }

  void _setWord({int? bits, bool? signed}) {
    _bits = bits ?? _bits;
    _signed = signed ?? _signed;
    final v = _error == null ? _value : null;
    if (v != null) {
      // Keep the bit pattern, re-read in the new word size.
      final calc = _calc;
      _setText(calc.format(calc.wrap(v), _base));
    } else {
      _evaluate();
    }
  }

  void _insert(String s) {
    final sel = _input.selection;
    final text = _input.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, s);
    _input.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: start + s.length));
  }

  void _backspace() {
    final sel = _input.selection;
    final text = _input.text;
    if (text.isEmpty) return;
    if (sel.isValid && !sel.isCollapsed) {
      _input.value = TextEditingValue(
          text: text.replaceRange(sel.start, sel.end, ''), selection: TextSelection.collapsed(offset: sel.start));
      return;
    }
    final pos = sel.isValid ? sel.start : text.length;
    if (pos == 0) return;
    // Remove a whole word operator (with its spaces) at once.
    final before = text.substring(0, pos);
    final m = RegExp(r'\s*(AND|NAND|OR|NOR|XOR|NOT|MOD|<<|>>)\s*$').firstMatch(before);
    final cut = m != null ? m.start : pos - 1;
    _input.value = TextEditingValue(text: text.replaceRange(cut, pos, ''), selection: TextSelection.collapsed(offset: cut));
  }

  Future<void> _equals() async {
    final v = _value;
    if (v == null || _error != null) return;
    final expr = _input.text.trim();
    final calc = _calc;
    final result = calc.format(v, _base);
    final settings = ref.read(settingsProvider);
    if (settings.saveHistory) {
      final summary = [for (final b in IntBase.values) '${baseShort(b)} ${calc.format(v, b)}'].join(' · ');
      try {
        await ref.read(historyRepositoryProvider).insert(
              HistoryEntry(
                expression: expr,
                expressionLatex: '{${unitTexText(expr)}}_{${_base.radix}}',
                result: summary,
                resultLatex: '${result.replaceAll('-', '−')}_{${_base.radix}}',
                resultValue: ValueCodec.encode(NumberValue(Rat(v))),
                mode: 'programmer',
                angleMode: settings.angleMode.name,
                format: '${baseShort(_base)}/$_bits${_signed ? 's' : 'u'}',
                createdAt: DateTime.now(),
              ),
              limit: settings.historyLimit,
            );
        ref.invalidate(historyListProvider);
      } catch (e) {
        AppLogger.error('programmer history', e);
      }
    }
    if (mounted) _setText(result);
  }

  void _toggleBit(int index) {
    final calc = _calc;
    final v = calc.toggleBit(_error == null ? (_value ?? BigInt.zero) : BigInt.zero, index);
    _setText(calc.format(v, _base));
  }

  Future<void> _copy(String text) async {
    await ClipboardService.copy(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.progTitle)),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 720) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                flex: 3,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  _setup(context),
                  const SizedBox(height: 12),
                  _inputField(context),
                  const SizedBox(height: 12),
                  _results(context),
                  const SizedBox(height: 12),
                  _bitGrid(context, perRow: 16),
                ]),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: _keypad(context)),
              ),
            ]);
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            _setup(context),
            const SizedBox(height: 12),
            _inputField(context),
            const SizedBox(height: 12),
            _results(context),
            const SizedBox(height: 12),
            _keypad(context),
            const SizedBox(height: 12),
            _bitGrid(context, perRow: 8),
          ]);
        }),
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final calc = _calc;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.progBase, style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      SegmentedButton<IntBase>(
        showSelectedIcon: false,
        segments: [
          for (final b in IntBase.values)
            ButtonSegment(value: b, label: Text(baseShort(b)), tooltip: baseLong(l, b)),
        ],
        selected: {_base},
        onSelectionChanged: (s) => _setBase(s.first),
      ),
      const SizedBox(height: 12),
      Text(l.progWordSize, style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [for (final b in const [8, 16, 32, 64]) ButtonSegment(value: b, label: Text('$b'), tooltip: l.progBitsLabel(b))],
        selected: {_bits},
        onSelectionChanged: (s) => _setWord(bits: s.first),
      ),
      const SizedBox(height: 4),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_signed ? l.progSigned : l.progUnsigned),
        subtitle: Text(l.progRange(groupDecimal(calc.minValue.toString()), groupDecimal(calc.maxValue.toString()))),
        value: _signed,
        onChanged: (v) => _setWord(signed: v),
      ),
    ]);
  }

  Widget _inputField(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return TextField(
      controller: _input,
      focusNode: _focus,
      style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'monospace'),
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (_) => _equals(),
      decoration: InputDecoration(
        labelText: '${l.progExpression} (${baseShort(_base)})',
        hintText: l.progExpressionHint,
        border: const OutlineInputBorder(),
        errorText: _error == null ? null : errorText(l, _error!),
        errorMaxLines: 3,
        suffixIcon: _input.text.isEmpty
            ? null
            : IconButton(tooltip: l.progAllClear, icon: const Icon(Icons.clear), onPressed: () => _setText('')),
      ),
    );
  }

  Widget _results(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final calc = _calc;
    final v = _error == null ? _value : null;
    return Card(
      child: Semantics(
        liveRegion: true,
        child: Column(children: [
          if (v == null)
            Padding(padding: const EdgeInsets.all(16), child: Text(l.progEmpty, style: theme.textTheme.bodyMedium)),
          if (v != null)
            for (final b in IntBase.values)
              Builder(builder: (context) {
                final raw = calc.format(v, b);
                final grouped = b == IntBase.dec ? groupDecimal(raw) : calc.format(v, b, group: true);
                final selected = b == _base;
                return Semantics(
                  label: '${baseLong(l, b)}: $raw',
                  child: ListTile(
                    selected: selected,
                    onTap: () => _setBase(b),
                    leading: SizedBox(
                      width: 40,
                      child: Text(baseShort(b), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                      grouped,
                      style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
                      softWrap: true,
                    ),
                    trailing: IconButton(
                      tooltip: l.progCopyBase(baseLong(l, b)),
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () => _copy(raw),
                    ),
                  ),
                );
              }),
        ]),
      ),
    );
  }

  static const _hexKeys = [
    _Key('A', 'A', digit: 10), _Key('B', 'B', digit: 11), _Key('C', 'C', digit: 12),
    _Key('D', 'D', digit: 13), _Key('E', 'E', digit: 14), _Key('F', 'F', digit: 15),
  ];

  static const _rows = [
    [_Key('7', '7', digit: 7), _Key('8', '8', digit: 8), _Key('9', '9', digit: 9), _Key('÷', ' / '), _Key('AND', ' AND '), _Key('OR', ' OR ')],
    [_Key('4', '4', digit: 4), _Key('5', '5', digit: 5), _Key('6', '6', digit: 6), _Key('×', ' * '), _Key('XOR', ' XOR '), _Key('NOT', 'NOT ')],
    [_Key('1', '1', digit: 1), _Key('2', '2', digit: 2), _Key('3', '3', digit: 3), _Key('−', ' - '), _Key('NAND', ' NAND '), _Key('NOR', ' NOR ')],
    [_Key('0', '0', digit: 0), _Key('(', '('), _Key(')', ')'), _Key('+', ' + '), _Key('<<', ' << '), _Key('>>', ' >> ')],
  ];

  Widget _keypad(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget key(_Key k, {Color? color, Color? onColor}) {
      final enabled = k.digit == null || k.digit! < _base.radix;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Semantics(
            button: true,
            enabled: enabled,
            label: k.digit != null ? k.label : l.progKeyLabel(k.label),
            excludeSemantics: true,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                padding: EdgeInsets.zero,
                backgroundColor: color,
                foregroundColor: onColor,
              ),
              onPressed: enabled ? () => _insert(k.insert) : null,
              child: FittedBox(child: Text(k.label, style: const TextStyle(fontWeight: FontWeight.w600))),
            ),
          ),
        ),
      );
    }

    Widget action(String label, String semantics, VoidCallback onTap, {bool primary = false, int flex = 1}) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Semantics(
              button: true,
              label: semantics,
              excludeSemantics: true,
              child: primary
                  ? FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 52), padding: EdgeInsets.zero),
                      onPressed: onTap,
                      child: Text(label, style: const TextStyle(fontSize: 20)))
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), padding: EdgeInsets.zero),
                      onPressed: onTap,
                      child: FittedBox(child: Text(label))),
            ),
          ),
        );

    final opColor = theme.colorScheme.secondaryContainer;
    final onOp = theme.colorScheme.onSecondaryContainer;
    return Column(children: [
      Row(children: [for (final k in _hexKeys) key(k)]),
      for (final row in _rows)
        Row(children: [for (final k in row) k.digit == null && k.label != '(' && k.label != ')' ? key(k, color: opColor, onColor: onOp) : key(k)]),
      Row(children: [
        key(const _Key('MOD', ' MOD '), color: opColor, onColor: onOp),
        action('AC', l.progAllClear, () => _setText('')),
        action('⌫', l.progBackspace, _backspace),
        action('=', l.progEquals, _equals, primary: true, flex: 3),
      ]),
    ]);
  }

  Widget _bitGrid(BuildContext context, {required int perRow}) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final calc = _calc;
    final bits = calc.bitList(_error == null ? (_value ?? BigInt.zero) : BigInt.zero);
    final rows = <Widget>[];
    for (var start = 0; start < bits.length; start += perRow) {
      final cells = <Widget>[];
      for (var k = start; k < start + perRow && k < bits.length; k++) {
        final index = bits.length - 1 - k;
        final on = bits[k];
        cells.add(Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: (k - start) % 4 == 0 && k != start ? 6 : 1, right: 1),
            child: Semantics(
              button: true,
              label: l.progBitLabel(index, on ? 1 : 0),
              excludeSemantics: true,
              child: Material(
                color: on ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _toggleBit(index),
                  child: SizedBox(
                    height: 48,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(on ? '1' : '0',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: on ? FontWeight.bold : FontWeight.normal,
                            color: on ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                          )),
                      FittedBox(child: Text('$index', style: theme.textTheme.labelSmall?.copyWith(fontSize: 9))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
      rows.add(Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: cells)));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.progBits, style: theme.textTheme.titleSmall),
          Text(l.progBitsHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          ...rows,
        ]),
      ),
    );
  }
}
