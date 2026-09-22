import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/engine_service.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/math_view.dart';
import 'linalg_common.dart';

enum ComplexOp {
  add,
  subtract,
  multiply,
  divide,
  powerN,
  powerZ,
  roots,
  modulus,
  argument,
  conjugate,
  real,
  imaginary,
  convert,
}

extension on ComplexOp {
  bool get needsZ2 =>
      const {ComplexOp.add, ComplexOp.subtract, ComplexOp.multiply, ComplexOp.divide, ComplexOp.powerZ}.contains(this);

  bool get needsN => this == ComplexOp.powerN || this == ComplexOp.roots;

  String label(AppLocalizations l) => switch (this) {
    ComplexOp.add => l.complexOpAdd,
    ComplexOp.subtract => l.complexOpSubtract,
    ComplexOp.multiply => l.complexOpMultiply,
    ComplexOp.divide => l.complexOpDivide,
    ComplexOp.powerN => l.complexOpPowerN,
    ComplexOp.powerZ => l.complexOpPowerZ,
    ComplexOp.roots => l.complexOpRoots,
    ComplexOp.modulus => l.complexOpModulus,
    ComplexOp.argument => l.complexOpArgument,
    ComplexOp.conjugate => l.complexOpConjugate,
    ComplexOp.real => l.complexOpReal,
    ComplexOp.imaginary => l.complexOpImaginary,
    ComplexOp.convert => l.complexOpConvert,
  };
}

/// Largest n accepted for listing n-th roots.
const complexMaxRoots = 100;

class _Outcome {
  const _Outcome({this.lines = const [], this.error, this.copyText, this.rootCount});
  final List<ResultLine> lines;
  final int? rootCount;
  final String? error;
  final String? copyText;
}

/// A complex number shown in both rectangular and polar form.
class _Forms {
  const _Forms(this.rectLatex, this.rectText, this.polarLatex, this.polarText, this.plain);
  final String rectLatex, rectText, polarLatex, polarText;

  /// Re-parseable rectangular text.
  final String plain;
}

/// Complex-number calculator (URS §24).
class ComplexScreen extends ConsumerStatefulWidget {
  const ComplexScreen({super.key});

  @override
  ConsumerState<ComplexScreen> createState() => _ComplexScreenState();
}

class _ComplexScreenState extends ConsumerState<ComplexScreen> {
  bool _polar = false;
  final _z1a = TextEditingController();
  final _z1b = TextEditingController();
  final _z2a = TextEditingController();
  final _z2b = TextEditingController();
  final _n = TextEditingController();
  ComplexOp _op = ComplexOp.modulus;
  _Outcome? _outcome;

  @override
  void initState() {
    super.initState();
    for (final c in [_z1a, _z1b, _z2a, _z2b]) {
      c.addListener(_onInput);
    }
  }

  @override
  void dispose() {
    for (final c in [_z1a, _z1b, _z2a, _z2b, _n]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onInput() => setState(() {});

  CalcSettings get _calc => ref.read(settingsProvider).calcSettings.copyWith(complexResults: true);

  String _fieldLabel(AppLocalizations l) => _polar ? l.complexModulusField : l.complexRealPart;

  String _field2Label(AppLocalizations l) =>
      _polar ? l.complexAngleField(angleUnitName(l, ref.read(settingsProvider).angleMode)) : l.complexImaginaryPart;

  /// Reads z₁ or z₂ from its two fields.
  ({Num? z, String? error}) _readZ(AppLocalizations l, bool second) {
    final calc = _calc;
    final env = ref.read(environmentProvider);
    final name = second ? l.complexSecond : l.complexFirst;
    final a = second ? _z2a : _z1a, b = second ? _z2b : _z1b;
    final fa = evalNumberField(l, a.text, calc, env, notNumberMessage: l.complexNotReal, realOnly: true);
    if (!fa.isOk) {
      return (z: null, error: l.complexFieldError(l.complexFieldLabel(name, _fieldLabel(l)), fa.error!));
    }
    final fb = evalNumberField(l, b.text, calc, env, notNumberMessage: l.complexNotReal, realOnly: true);
    if (!fb.isOk) return (z: null, error: l.complexFieldError(l.complexFieldLabel(name, _field2Label(l)), fb.error!));
    final r = EngineService.engine.evaluate(
      _polar ? 'p∠q' : 'p+q*i',
      calc,
      Environment(variables: {'p': NumberValue(fa.value!), 'q': NumberValue(fb.value!)}),
    );
    switch (r) {
      case Success(:final value):
        final v = value.value;
        if (v is NumberValue) return (z: v.n, error: null);
        return (z: null, error: l.complexNotReal);
      case Failure(:final error):
        return (z: null, error: errorText(l, error));
      case Cancelled():
        return (z: null, error: l.errCancelled);
    }
  }

  Num? _eval(String expr, Map<String, Num> vars, {CalcSettings? settings}) {
    final r = EngineService.engine.evaluate(
      expr,
      settings ?? _calc,
      Environment(variables: {for (final e in vars.entries) e.key: NumberValue(e.value)}),
    );
    final v = r.valueOrNull?.value;
    return v is NumberValue ? v.n : null;
  }

  /// Rectangular and polar forms of [z].
  _Forms _forms(Num z) {
    final settings = ref.read(settingsProvider);
    final rect = formatValue(ref, NumberValue(z), complexFormat: ComplexFormat.rectangular);
    final isReal = z is! Cpx || z.im.isZero;
    String polarLatex, polarText;
    if (!isReal) {
      final p = formatValue(ref, NumberValue(z), complexFormat: ComplexFormat.polar);
      polarLatex = p.latex;
      polarText = p.display;
    } else if (z.isZero) {
      polarLatex = rect.latex;
      polarText = rect.display;
    } else {
      // The formatter shows real numbers without an angle; spell it out.
      final r = _eval('abs(z)', {'z': z}) ?? z;
      final t = _eval('arg(z)', {'z': z}) ?? Rat.zero;
      final rf = formatValue(ref, NumberValue(r)), tf = formatValue(ref, NumberValue(t), preferDecimal: true);
      polarLatex = '${rf.latex}\\angle ${tf.latex}${angleUnitLatex(settings.angleMode)}';
      polarText = '${rf.display}∠${tf.display}${angleUnitText(settings.angleMode)}';
    }
    return _Forms(rect.latex, rect.display, polarLatex, polarText, rect.plain);
  }

  List<ResultLine> _bothForms(String lhsTex, String lhsText, Num z) {
    final f = _forms(z);
    final polarFirst = ref.read(settingsProvider).complexFormat == ComplexFormat.polar;
    final rect = ResultLine('$lhsTex=${f.rectLatex}', '$lhsText = ${f.rectText}');
    final polar = ResultLine('$lhsTex=${f.polarLatex}', '$lhsText = ${f.polarText}');
    if (f.rectText == f.polarText) return [rect];
    return polarFirst ? [polar, rect] : [rect, polar];
  }

  void _toggleForm(bool polar) {
    if (polar == _polar) return;
    final l = AppLocalizations.of(context);
    final precision = ref.read(settingsProvider).precision;
    // Convert what was typed so the numbers keep their meaning.
    final pairs = [(false, _z1a, _z1b), (true, _z2a, _z2b)];
    final converted = <(TextEditingController, TextEditingController, String, String)>[];
    for (final (second, a, b) in pairs) {
      if (a.text.trim().isEmpty && b.text.trim().isEmpty) continue;
      final z = _readZ(l, second).z;
      if (z == null) continue;
      final x = polar ? _eval('abs(z)', {'z': z}) : _eval('re(z)', {'z': z});
      final y = polar ? (z.isZero ? Rat.zero : _eval('arg(z)', {'z': z})) : _eval('im(z)', {'z': z});
      if (x == null || y == null) continue;
      converted.add((a, b, numberSource(x, precision), numberSource(y, precision)));
    }
    setState(() {
      _polar = polar;
      _outcome = null;
      for (final (a, b, x, y) in converted) {
        a.text = x;
        b.text = y;
      }
    });
  }

  void _calculate() {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final settings = ref.read(settingsProvider);
    void fail(String e) => setState(() => _outcome = _Outcome(error: e));

    final z1 = _readZ(l, false);
    if (z1.error != null) return fail(z1.error!);
    final z = z1.z!;
    Num? w;
    if (_op.needsZ2) {
      final z2 = _readZ(l, true);
      if (z2.error != null) return fail(z2.error!);
      w = z2.z!;
    }
    Num? n;
    if (_op.needsN) {
      final f = evalNumberField(
        l,
        _n.text,
        _calc,
        ref.read(environmentProvider),
        notNumberMessage: l.complexNotReal,
        emptyIsZero: false,
      );
      if (!f.isOk) return fail(l.complexFieldError(l.complexExponentField, f.error!));
      n = f.value!;
      if (_op == ComplexOp.roots) {
        final k = Arith.asInt(n);
        if (k == null || k < 1 || k > complexMaxRoots) return fail(l.complexRootsRange);
      }
    }

    final zf = _forms(z);
    final wf = w == null ? null : _forms(w);
    final nf = n == null ? null : formatValue(ref, NumberValue(n));
    final operands = [..._bothForms('z_{1}', 'z₁', z), if (w != null) ..._bothForms('z_{2}', 'z₂', w)];
    final zP = '(${zf.plain})', wP = wf == null ? '' : '(${wf.plain})', nP = nf == null ? '' : '(${nf.plain})';

    if (_op == ComplexOp.convert) {
      setState(() => _outcome = _Outcome(lines: operands, copyText: '${zf.rectText} = ${zf.polarText}'));
      recordLinalgHistory(
        ref,
        mode: 'complex',
        expression: zf.plain,
        expressionLatex: zf.rectLatex,
        result: zf.polarText,
        resultLatex: zf.polarLatex,
        value: NumberValue(z),
      );
      return;
    }

    if (_op == ComplexOp.roots) {
      final count = Arith.asInt(n!)!;
      final rad = _calc.copyWith(angleMode: AngleMode.rad);
      final lines = <ResultLine>[];
      final texts = <String>[];
      final latex = <String>[];
      final values = <Value>[];
      for (var k = 0; k < count; k++) {
        final r = EngineService.engine.evaluate(
          'nroot($count,abs(z))*exp(i*(arg(z)+2*$k*pi)/$count)',
          rad,
          Environment(variables: {'z': NumberValue(z)}),
        );
        switch (r) {
          case Success(:final value) when value.value is NumberValue:
            final root = (value.value as NumberValue).n;
            lines.addAll(_bothForms('w_{$k}', 'w$k', root));
            final rf = _forms(root);
            texts.add(rf.rectText);
            latex.add('w_{$k}=${rf.rectLatex}');
            values.add(value.value);
          case Failure(:final error):
            return fail(errorText(l, error));
          default:
            return fail(l.errCancelled);
        }
      }
      setState(() => _outcome = _Outcome(lines: [...lines, ...operands], copyText: texts.join(', '), rootCount: count));
      final expr = 'nroot($count,$zP)';
      recordLinalgHistory(
        ref,
        mode: 'complex',
        expression: expr,
        expressionLatex: _latexOf(expr),
        result: texts.join(', '),
        resultLatex: latex.join(r',\quad '),
        value: ListValue(values),
      );
      return;
    }

    final expr = switch (_op) {
      ComplexOp.add => 'z+w',
      ComplexOp.subtract => 'z-w',
      ComplexOp.multiply => 'z*w',
      ComplexOp.divide => 'z/w',
      ComplexOp.powerN => 'z^n',
      ComplexOp.powerZ => 'z^w',
      ComplexOp.modulus => 'abs(z)',
      ComplexOp.argument => 'arg(z)',
      ComplexOp.conjugate => 'conj(z)',
      ComplexOp.real => 're(z)',
      ComplexOp.imaginary => 'im(z)',
      ComplexOp.roots || ComplexOp.convert => '',
    };
    final history = switch (_op) {
      ComplexOp.add => '$zP+$wP',
      ComplexOp.subtract => '$zP-$wP',
      ComplexOp.multiply => '$zP*$wP',
      ComplexOp.divide => '$zP/$wP',
      ComplexOp.powerN => '$zP^$nP',
      ComplexOp.powerZ => '$zP^$wP',
      ComplexOp.modulus => 'abs$zP',
      ComplexOp.argument => 'arg$zP',
      ComplexOp.conjugate => 'conj$zP',
      ComplexOp.real => 're$zP',
      ComplexOp.imaginary => 'im$zP',
      ComplexOp.roots || ComplexOp.convert => '',
    };
    final lhsTex = switch (_op) {
      ComplexOp.add => 'z_{1}+z_{2}',
      ComplexOp.subtract => 'z_{1}-z_{2}',
      ComplexOp.multiply => 'z_{1}\\cdot z_{2}',
      ComplexOp.divide => '\\frac{z_{1}}{z_{2}}',
      ComplexOp.powerN => '{z_{1}}^{${nf!.latex}}',
      ComplexOp.powerZ => '{z_{1}}^{z_{2}}',
      ComplexOp.modulus => '\\left|z_{1}\\right|',
      ComplexOp.argument => '\\arg z_{1}',
      ComplexOp.conjugate => '\\overline{z_{1}}',
      ComplexOp.real => '\\mathrm{Re}\\,z_{1}',
      ComplexOp.imaginary => '\\mathrm{Im}\\,z_{1}',
      ComplexOp.roots || ComplexOp.convert => '',
    };
    final lhsText = switch (_op) {
      ComplexOp.add => 'z₁ + z₂',
      ComplexOp.subtract => 'z₁ − z₂',
      ComplexOp.multiply => 'z₁ × z₂',
      ComplexOp.divide => 'z₁ ÷ z₂',
      ComplexOp.powerN => 'z₁^${nf!.display}',
      ComplexOp.powerZ => 'z₁^z₂',
      ComplexOp.modulus => '|z₁|',
      ComplexOp.argument => 'arg z₁',
      ComplexOp.conjugate => 'conj z₁',
      ComplexOp.real => 'Re z₁',
      ComplexOp.imaginary => 'Im z₁',
      ComplexOp.roots || ComplexOp.convert => '',
    };
    final r = EngineService.engine.evaluate(
      expr,
      _calc,
      Environment(
        variables: {'z': NumberValue(z), if (w != null) 'w': NumberValue(w), if (n != null) 'n': NumberValue(n)},
      ),
    );
    switch (r) {
      case Success(:final value):
        final v = value.value;
        if (v is! NumberValue) return fail(l.complexNotReal);
        final List<ResultLine> lines;
        String resultText, resultLatex;
        if (_op == ComplexOp.argument) {
          final f = formatValue(ref, v, preferDecimal: true);
          resultLatex = '${f.latex}${angleUnitLatex(settings.angleMode)}';
          resultText = '${f.display}${angleUnitText(settings.angleMode)}';
          lines = [ResultLine('$lhsTex=$resultLatex', '$lhsText = $resultText')];
        } else if (_op == ComplexOp.modulus || _op == ComplexOp.real || _op == ComplexOp.imaginary) {
          final f = formatValue(ref, v, preferDecimal: value.preferDecimal);
          resultLatex = f.latex;
          resultText = f.display;
          lines = [ResultLine('$lhsTex=${f.latex}', '$lhsText = ${f.display}')];
        } else {
          final f = _forms(v.n);
          resultLatex = f.rectLatex;
          resultText = f.rectText == f.polarText ? f.rectText : '${f.rectText} = ${f.polarText}';
          lines = _bothForms(lhsTex, lhsText, v.n);
        }
        setState(() => _outcome = _Outcome(lines: [...lines, ...operands], copyText: resultText));
        recordLinalgHistory(
          ref,
          mode: 'complex',
          expression: history,
          expressionLatex: _latexOf(history),
          result: resultText,
          resultLatex: resultLatex,
          value: v,
        );
      case Failure(:final error):
        fail(errorText(l, error));
      case Cancelled():
        fail(l.errCancelled);
    }
  }

  String _latexOf(String expr) {
    try {
      return const LatexPrinter().print(Parser.parse(expr));
    } on MathError {
      return expr;
    }
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.complexTitle), actions: const [AppMenuButton()]),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final inputs = _inputs(context, l);
            final ops = _operations(context, l);
            if (c.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: inputs),
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
                children: [inputs, const SizedBox(height: 8), ops],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _inputs(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l.complexInputForm),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.complexInputRectangular)),
            ButtonSegment(value: true, label: Text(l.complexInputPolar)),
          ],
          selected: {_polar},
          onSelectionChanged: (s) => _toggleForm(s.first),
        ),
        _numberInputs(context, l, false),
        _numberInputs(context, l, true),
      ],
    );
  }

  Widget _numberInputs(BuildContext context, AppLocalizations l, bool second) {
    final theme = Theme.of(context);
    final name = second ? l.complexSecond : l.complexFirst;
    final a = second ? _z2a : _z1a, b = second ? _z2b : _z1b;
    final key = second ? 'z2' : 'z1';
    Widget field(TextEditingController c, String label, String k) => Expanded(
      child: TextField(
        key: ValueKey('complex-$key-$k'),
        controller: c,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: l.complexFieldLabel(name, label),
          hintText: '0',
          border: const OutlineInputBorder(),
        ),
      ),
    );
    Widget? preview;
    if (a.text.trim().isNotEmpty || b.text.trim().isNotEmpty) {
      final z = _readZ(l, second);
      if (z.z != null) {
        final f = _forms(z.z!);
        final sub = second ? '2' : '1';
        preview = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MathView(
            f.rectText == f.polarText ? 'z_{$sub}=${f.rectLatex}' : 'z_{$sub}=${f.rectLatex}=${f.polarLatex}',
            semanticsLabel: '$name = ${f.rectText} = ${f.polarText}',
            style: theme.textTheme.bodyLarge,
          ),
        );
      } else {
        preview = Text(z.error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(name),
        Row(children: [field(a, _fieldLabel(l), 'a'), const SizedBox(width: 8), field(b, _field2Label(l), 'b')]),
        if (preview != null) Padding(padding: const EdgeInsets.only(top: 8), child: preview),
      ],
    );
  }

  Widget _operations(BuildContext context, AppLocalizations l) {
    final outcome = _outcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l.complexOperations),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final op in ComplexOp.values)
              ChoiceChip(
                key: ValueKey('complex-op-${op.name}'),
                label: Text(op.label(l)),
                selected: _op == op,
                onSelected: (_) => setState(() {
                  _op = op;
                  _outcome = null;
                }),
              ),
          ],
        ),
        if (_op.needsN) ...[
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('complex-n'),
            controller: _n,
            autocorrect: false,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            decoration: InputDecoration(labelText: l.complexExponentField, border: const OutlineInputBorder()),
            onSubmitted: (_) => _calculate(),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('complex-calculate'),
          onPressed: _calculate,
          icon: const Icon(Icons.calculate_outlined),
          label: Text(l.actionCalculate),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (outcome != null) ...[
          const SizedBox(height: 12),
          LinalgResultCard(
            key: const ValueKey('complex-result'),
            title: outcome.rootCount == null
                ? l.complexResult
                : '${l.complexResult} · ${l.complexRootsCount(outcome.rootCount!)}',
            lines: outcome.lines,
            error: outcome.error,
            copyText: outcome.copyText,
          ),
        ],
      ],
    );
  }
}
