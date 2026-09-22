import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../core/error_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clipboard_service.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/math_view.dart';
import 'solve_common.dart';

/// Simultaneous linear equations (URS §23): 2–6 unknowns, exact
/// Gauss–Jordan elimination with steps.
class SystemScreen extends ConsumerStatefulWidget {
  const SystemScreen({super.key, this.initialSize = 2});

  /// Number of unknowns shown when the screen opens (2–6).
  final int initialSize;

  @override
  ConsumerState<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends ConsumerState<SystemScreen> with EngineRunner {
  static const maxSize = 6;
  static const variables = ['x', 'y', 'z', 'w', 'v', 'u'];

  late int _n = widget.initialSize.clamp(2, maxSize);
  final _a = List.generate(maxSize, (_) => List.generate(maxSize, (_) => TextEditingController()));
  final _b = List.generate(maxSize, (_) => TextEditingController());

  LinearSystemSolution? _solution;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    for (final c in [..._a.expand((r) => r), ..._b]) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final c in [..._a.expand((r) => r), ..._b]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  String _rowLatex(int r, Environment env) {
    final lhs = linearComboLatex([for (var c = 0; c < _n; c++) (_a[r][c].text, varLatex(variables[c]))], env);
    final rhs = linearComboLatex([(_b[r].text, '')], env);
    return '$lhs=$rhs';
  }

  void _fill(int n, List<List<String>> rows) {
    setState(() {
      _n = n;
      for (var r = 0; r < maxSize; r++) {
        for (var c = 0; c < maxSize; c++) {
          _a[r][c].text = r < rows.length && c < n ? rows[r][c] : '';
        }
        _b[r].text = r < rows.length ? rows[r][n] : '';
      }
      _solution = null;
      _message = null;
    });
  }

  void _showMessage(String text, {bool error = true}) => setState(() {
    _message = text;
    _messageIsError = error;
    _solution = null;
  });

  Future<void> _solve() async {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final a = [
      for (var r = 0; r < _n; r++) [for (var c = 0; c < _n; c++) ClipboardService.sanitize(_a[r][c].text)],
    ];
    final b = [for (var r = 0; r < _n; r++) ClipboardService.sanitize(_b[r].text)];
    if (a.every((row) => row.every((c) => c.isEmpty)) && b.every((c) => c.isEmpty)) {
      _showMessage(l.solveSystemEnterCoefficients);
      return;
    }
    final settings = ref.read(settingsProvider);
    final env = ref.read(environmentProvider).copy();
    final vars = variables.sublist(0, _n);
    final rowsTex = [for (var r = 0; r < _n; r++) _rowLatex(r, env)];
    final r = await runEngine(linearSystemTask(a, b, vars, settings.calcSettings, env));
    if (r == null || !mounted) return;
    switch (r) {
      case Success(:final value):
        setState(() {
          _solution = value;
          _message = null;
        });
        final (plain, tex) = systemSummary(value, settings.formatOptions(), l);
        final expr = [
          for (var i = 0; i < _n; i++)
            '${[for (var c = 0; c < _n; c++) '(${a[i][c].isEmpty ? '0' : a[i][c]})${vars[c]}'].join('+')}=${b[i].isEmpty ? '0' : b[i]}',
        ].join('; ');
        await recordSolveHistory(
          ref,
          mode: 'system',
          expression: expr,
          expressionLatex: rowsTex.join(r',\quad '),
          result: plain,
          resultLatex: tex,
        );
      case Failure(:final error):
        _showMessage(errorText(l, error));
      case Cancelled():
        _showMessage(l.errCancelled, error: false);
    }
  }

  void _cancel() {
    cancelEngine();
    _showMessage(AppLocalizations.of(context).errCancelled, error: false);
  }

  Widget _grid(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    const cellWidth = 76.0;
    Widget cell(TextEditingController c, Key key, String semantics) => SizedBox(
      width: cellWidth,
      child: Semantics(
        label: semantics,
        child: TextField(
          key: key,
          controller: c,
          textAlign: TextAlign.center,
          autocorrect: false,
          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
          decoration: const InputDecoration(
            hintText: '0',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
    Widget header(String tex) => SizedBox(
      width: cellWidth,
      child: Center(child: MathView(tex, style: theme.textTheme.titleMedium)),
    );
    const gap = SizedBox(width: 6);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var c = 0; c < _n; c++) ...[header(varLatex(variables[c])), gap],
              const SizedBox(width: 24),
              gap,
              header(r'b'),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < _n; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (var c = 0; c < _n; c++) ...[
                    cell(_a[r][c], Key('solve-sys-a-$r-$c'), l.solveSystemCoefficient(r + 1, variables[c])),
                    gap,
                  ],
                  SizedBox(
                    width: 24,
                    child: Center(child: Text('=', style: theme.textTheme.titleMedium)),
                  ),
                  gap,
                  cell(_b[r], Key('solve-sys-b-$r'), l.solveSystemConstant(r + 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final env = ref.watch(environmentProvider);

    final input = <Widget>[
      Text(l.solveSystemUnknowns, style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<int>(
          key: const Key('solve-sys-size'),
          showSelectedIcon: false,
          segments: [
            for (var n = 2; n <= maxSize; n++)
              ButtonSegment(value: n, label: Text('$n'), tooltip: l.solveSystemSize(n)),
          ],
          selected: {_n},
          onSelectionChanged: (s) => setState(() {
            _n = s.first;
            _solution = null;
          }),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ActionChip(
            key: const Key('solve-sys-example'),
            avatar: const Icon(Icons.lightbulb_outline, size: 18),
            label: Text(l.solvePolyExample),
            onPressed: () => _fill(2, const [
              ['2', '1', '5'],
              ['1', '-1', '1'],
            ]),
          ),
          ActionChip(
            avatar: const Icon(Icons.lightbulb_outline, size: 18),
            label: Text(l.solveSystemExample3),
            onPressed: () => _fill(3, const [
              ['1', '1', '1', '6'],
              ['2', '-1', '1', '3'],
              ['1', '2', '-1', '2'],
            ]),
          ),
          ActionChip(
            avatar: const Icon(Icons.clear, size: 18),
            label: Text(l.actionClear),
            onPressed: () => _fill(_n, const []),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _grid(context, l),
      SolveNote(l.solveSystemFieldHelp),
      const SizedBox(height: 12),
      Text(l.solvePreview, style: theme.textTheme.labelLarge),
      for (var r = 0; r < _n; r++) MathLine(_rowLatex(r, env)),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('solve-sys-solve'),
        onPressed: busy ? null : _solve,
        icon: const Icon(Icons.play_arrow),
        label: Text(l.actionSolve),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ];

    final output = <Widget>[
      if (busy) SolveBusy(onCancel: _cancel),
      if (_message != null) SolveMessage(_message!, error: _messageIsError),
      if (_solution != null) LinearSystemResultView(solution: _solution!, settings: settings),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.toolSystem), actions: const [AppMenuButton()]),
      body: SolveLayout(input: input, output: output),
    );
  }
}
