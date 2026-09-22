import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/routes.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_menu_button.dart';
import 'calculator_controller.dart';
import 'calculator_screen.dart';
import 'keypad/key_specs.dart';
import 'keypad/keypad.dart';
import 'widgets/calc_sheets.dart';
import 'widgets/calculator_display.dart';

/// The advanced scientific calculator: the same expression and display as
/// the Calculator tab, with categorized function palettes covering the
/// whole function catalog.
class ScientificScreen extends ConsumerStatefulWidget {
  const ScientificScreen({super.key});

  @override
  ConsumerState<ScientificScreen> createState() => _ScientificScreenState();
}

class _PaletteTab {
  const _PaletteTab(this.title, this.keys);
  final String title;
  final List<CalcKey> keys;
}

class _ScientificScreenState extends ConsumerState<ScientificScreen> with SingleTickerProviderStateMixin {
  TabController? _tabs;

  CalcKey _f(String name, String tex) {
    final spec = functionIndex[name];
    return CalcKey(id: 'sf_$name', label: tex, action: InsertFunc(name), semantic: spec?.spokenName ?? name);
  }

  List<_PaletteTab> _palettes(AppLocalizations l, CalcKeySet k) => [
        _PaletteTab(l.catTrigonometry, [
          _f('sin', r'\sin'), _f('cos', r'\cos'), _f('tan', r'\tan'), k.pi,
          _f('asin', r'\sin^{-1}'), _f('acos', r'\cos^{-1}'), _f('atan', r'\tan^{-1}'), k.degree,
          _f('sec', r'\sec'), _f('csc', r'\csc'), _f('cot', r'\cot'), _f('atan2', r'\mathrm{atan2}'),
          k.text('rad', 'r', 'ʳ', l.angleRadLong), k.text('grad', 'g', 'ᵍ', l.angleGradLong), k.openParen, k.closeParen,
        ]),
        _PaletteTab(l.catHyperbolic, [
          _f('sinh', r'\sinh'), _f('cosh', r'\cosh'), _f('tanh', r'\tanh'), k.euler,
          _f('asinh', r'\sinh^{-1}'), _f('acosh', r'\cosh^{-1}'), _f('atanh', r'\tanh^{-1}'), k.ePow,
        ]),
        _PaletteTab(l.catPowers, [
          k.square, k.cube, k.power, k.inverse,
          k.sqrt, k.cbrt, k.nroot, k.frac,
          k.tenPow, k.ePow, k.log, k.ln,
          k.logb, _f('log2', r'\log_{2}'), _f('exp', r'\exp'), k.euler,
        ]),
        _PaletteTab(l.catCalculus, [
          k.integral, k.derivative, k.sum, k.prod,
          k.lim, k.varX, k.text('inf', r'\infty', '∞', l.keyLimit), k.comma,
          _f('integral', r'\mathrm{integral}'), _f('deriv', r'\mathrm{deriv}'), _f('sum', r'\mathrm{sum}'), _f('lim', r'\mathrm{lim}'),
        ]),
        _PaletteTab(l.catNumberTheory, [
          k.factorial, k.nCr, k.nPr, k.abs,
          _f('gcd', r'\gcd'), _f('lcm', r'\mathrm{lcm}'), _f('mod', r'\mathrm{mod}'), _f('rem', r'\mathrm{rem}'),
          _f('quot', r'\mathrm{quot}'), _f('floor', r'\lfloor x\rfloor'), _f('ceil', r'\lceil x\rceil'), _f('round', r'\mathrm{round}'),
          _f('trunc', r'\mathrm{trunc}'), _f('fpart', r'\mathrm{frac}'), _f('sign', r'\mathrm{sign}'), _f('isprime', r'\mathrm{isprime}'),
          _f('factor', r'\mathrm{factor}'), _f('divisors', r'\mathrm{divisors}'), _f('totient', r'\varphi(n)'), _f('nextprime', r'\mathrm{nextprime}'),
          _f('gamma', r'\Gamma'), k.rand, k.randInt, k.percent,
        ]),
        _PaletteTab(l.catComplex, [
          k.imag, k.angle, _f('re', r'\mathrm{Re}'), _f('im', r'\mathrm{Im}'),
          _f('conj', r'\overline{z}'), _f('arg', r'\arg'), _f('abs', r'|z|'), _f('cis', r'\mathrm{cis}'),
        ]),
        _PaletteTab(l.catStatistics, [
          _f('mean', r'\bar{x}'), _f('median', r'\tilde{x}'), _f('stdev', r's_x'), _f('pstdev', r'\sigma_x'),
          _f('var', r's^2'), _f('pvar', r'\sigma^2'), _f('total', r'\Sigma x'), _f('min', r'\min'),
          _f('max', r'\max'), _f('normpdf', r'\mathrm{normpdf}'), _f('normcdf', r'\mathrm{normcdf}'), _f('invnorm', r'\mathrm{invnorm}'),
          _f('binompdf', r'\mathrm{binompdf}'), _f('binomcdf', r'\mathrm{binomcdf}'), _f('poissonpdf', r'\mathrm{poisspdf}'), _f('poissoncdf', r'\mathrm{poisscdf}'),
          k.text('lb', '[', '[', l.keyOpenParen), k.text('rb', ']', ']', l.keyCloseParen), k.comma, k.text('semi', ';', ';', l.keyComma),
        ]),
        _PaletteTab(l.catMatrix, [
          k.text('lb2', '[', '[', l.keyOpenParen), k.text('rb2', ']', ']', l.keyCloseParen), k.comma, k.text('semi2', ';', ';', l.keyComma),
          _f('det', r'\det'), _f('inv', r'A^{-1}'), _f('trn', r'A^{\mathsf{T}}'), _f('rank', r'\mathrm{rank}'),
          _f('trace', r'\mathrm{tr}'), _f('rref', r'\mathrm{rref}'), _f('ref', r'\mathrm{ref}'), _f('identity', r'I_n'),
          _f('eigvals', r'\lambda'), _f('dot', r'\cdot'), _f('cross', r'\times'), _f('norm', r'\|v\|'),
          _f('unit', r'\hat{v}'), _f('angle', r'\angle(u,v)'), _f('proj', r'\mathrm{proj}'), _f('dist', r'\mathrm{dist}'),
        ]),
        _PaletteTab(l.variablesTitle, [
          for (final v in const ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'])
            CalcKey(id: 'var_$v', label: v, action: InsertAtom(v), semantic: l.keyVariable(v)),
          k.text('ans2', r'\mathrm{Ans}', 'Ans', l.keyAns, atom: true),
          k.text('preans', r'\mathrm{PreAns}', 'PreAns', l.keyAns, atom: true),
          k.varX, k.text('y', 'y', 'y', l.keyVariable('y')), k.eq,
          k.sto, CalcKey(id: 'cat', label: r'\text{f(x)…}', action: const Command(CalcCommand.catalog), semantic: l.calcFunctionCatalog),
          CalcKey(id: 'const', label: r'\text{const}', action: const Command(CalcCommand.constants), semantic: l.calcConstants),
        ]),
      ];

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final keys = CalcKeySet(l);
    final palettes = _palettes(l, keys);
    _tabs ??= TabController(length: palettes.length, vsync: this);
    final s = ref.watch(calculatorProvider);
    void onKey(CalcKey k) => handleCalcKey(context, ref, k);
    void onAlt(KeyAlt a) => handleCalcAction(context, ref, a.action);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navScientific),
        actions: [
          IconButton(tooltip: l.calcFunctionCatalog, icon: const Icon(Icons.functions), onPressed: () => showFunctionCatalog(context, ref)),
          IconButton(tooltip: l.actionSearch, icon: const Icon(Icons.search), onPressed: () => context.push(Routes.search)),
          const AppMenuButton(),
        ],
      ),
      body: CalcNoticeListener(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, c) {
            final landscape = c.maxWidth > c.maxHeight * 1.15;
            final palette = Column(children: [
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final p in palettes) Tab(text: p.title)],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    for (final p in palettes)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: _PaletteGrid(keys: p.keys, onKey: onKey, onAlt: onAlt, shift: s.shift, alpha: s.alpha),
                      ),
                  ],
                ),
              ),
            ]);
            final numbers = Keypad(
              rows: [
                [keys.shift, keys.alpha, keys.left, keys.right, keys.sd],
                ...keys.numberRows(),
              ],
              onKey: onKey,
              onAlt: onAlt,
              shiftActive: s.shift,
              alphaActive: s.alpha,
              storeActive: s.storePending,
            );
            if (landscape) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                child: Row(children: [
                  Expanded(
                    flex: 11,
                    child: Column(children: [
                      const Expanded(flex: 3, child: CalculatorDisplay(compact: true)),
                      Expanded(flex: 7, child: palette),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(flex: 7, child: numbers),
                ]),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Column(children: [
                const Expanded(flex: 22, child: CalculatorDisplay(compact: true)),
                Expanded(flex: 34, child: palette),
                Expanded(flex: 40, child: numbers),
              ]),
            );
          }),
        ),
      ),
    );
  }
}

class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({required this.keys, required this.onKey, required this.onAlt, required this.shift, required this.alpha});
  final List<CalcKey> keys;
  final KeyCallback onKey;
  final AltCallback onAlt;
  final bool shift;
  final bool alpha;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const cols = 4;
      final rows = (keys.length / cols).ceil();
      final keyHeight = ((c.maxHeight - (rows - 1) * 6) / rows).clamp(36.0, 64.0);
      final keyWidth = (c.maxWidth - (cols - 1) * 6) / cols;
      return GridView.count(
        crossAxisCount: cols,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: keyWidth / keyHeight,
        children: [
          for (final k in keys)
            CalcKeyButton(spec: k, onKey: onKey, onAlt: onAlt, shiftActive: shift, alphaActive: alpha),
        ],
      );
    });
  }
}
