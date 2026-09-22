import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../data/settings/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_menu_button.dart';
import '../history/history_panel.dart';
import 'calculator_controller.dart';
import 'keypad/key_specs.dart';
import 'keypad/keypad.dart';
import 'widgets/calc_sheets.dart';
import 'widgets/calculator_display.dart';

/// Routes a key action: UI commands open sheets, everything else goes to
/// the controller.
void handleCalcAction(BuildContext context, WidgetRef ref, KeyAction action) {
  if (action is Command) {
    switch (action.command) {
      case CalcCommand.menu:
        showCalculatorMenu(context, ref);
        return;
      case CalcCommand.catalog:
        showFunctionCatalog(context, ref);
        return;
      case CalcCommand.constants:
        showConstantPicker(context, ref);
        return;
      case CalcCommand.history:
        context.go(Routes.history);
        return;
      default:
        break;
    }
  }
  ref.read(calculatorProvider.notifier).perform(action);
}

void handleCalcKey(BuildContext context, WidgetRef ref, CalcKey key) =>
    handleCalcAction(context, ref, ref.read(calculatorProvider.notifier).resolve(key));

/// Shows snack bars for controller notices (stored values, limits…).
class CalcNoticeListener extends ConsumerWidget {
  const CalcNoticeListener({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(calculatorProvider.select((s) => (s.notice, s.noticeArg)), (prev, next) {
      final (notice, arg) = next;
      if (notice == CalcNotice.none) return;
      final l = AppLocalizations.of(context);
      final text = switch (notice) {
        CalcNotice.stored => l.calcStoredIn(arg),
        CalcNotice.memoryStored => l.calcMemoryStored,
        CalcNotice.memoryCleared => l.calcMemoryClear,
        CalcNotice.functionSaved => l.calcFunctionDefined(arg),
        CalcNotice.functionLimit => l.functionsLimitReached(freeFunctionLimit),
        CalcNotice.cancelled => l.calculationCancelled,
        CalcNotice.none => '',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
        action: notice == CalcNotice.functionLimit
            ? SnackBarAction(label: l.premiumTitle, onPressed: () => context.push(Routes.premium))
            : null,
      ));
      ref.read(calculatorProvider.notifier).clearNotice();
    });
    return child;
  }
}

class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navCalculator),
        actions: [
          IconButton(tooltip: l.actionSearch, icon: const Icon(Icons.search), onPressed: () => context.push(Routes.search)),
          const AppMenuButton(),
        ],
      ),
      body: const CalcNoticeListener(child: SafeArea(top: false, child: _CalculatorBody())),
    );
  }
}

class _CalculatorBody extends ConsumerWidget {
  const _CalculatorBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return LayoutBuilder(builder: (context, c) {
      // Tablets get calculator + history side by side; landscape phones
      // get the expanded scientific keyboard instead.
      final wide = c.maxWidth >= 840 && c.maxHeight >= 560;
      final landscape = c.maxWidth > c.maxHeight * 1.15;
      if (wide) {
        return Row(children: [
          SizedBox(width: (c.maxWidth * 0.55).clamp(420.0, 640.0), child: _CalculatorPane(landscape: false, settings: settings)),
          const VerticalDivider(width: 1),
          const Expanded(child: HistoryPanel(compact: true)),
        ]);
      }
      return _CalculatorPane(landscape: landscape, settings: settings);
    });
  }
}

class _CalculatorPane extends ConsumerWidget {
  const _CalculatorPane({required this.landscape, required this.settings});
  final bool landscape;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final keys = CalcKeySet(l);
    final s = ref.watch(calculatorProvider);
    final gap = switch (settings.buttonSize) {
      ButtonSize.compact => 4.0,
      ButtonSize.normal => 6.0,
      ButtonSize.large => 8.0,
    };
    void onKey(CalcKey k) => handleCalcKey(context, ref, k);
    void onAlt(KeyAlt a) => handleCalcAction(context, ref, a.action);
    Keypad pad(List<List<CalcKey>> rows) => Keypad(
          rows: rows,
          onKey: onKey,
          onAlt: onAlt,
          shiftActive: s.shift,
          alphaActive: s.alpha,
          storeActive: s.storePending,
          gap: gap,
        );

    const pad8 = EdgeInsets.fromLTRB(10, 4, 10, 10);
    if (landscape) {
      return Padding(
        padding: pad8,
        child: Row(children: [
          Expanded(
            flex: 11,
            child: Column(children: [
              const Expanded(flex: 4, child: CalculatorDisplay(compact: true)),
              SizedBox(height: gap),
              Expanded(flex: 7, child: pad(keys.landscapeFunctionRows())),
            ]),
          ),
          SizedBox(width: gap * 1.5),
          Expanded(flex: 7, child: pad(keys.numberRows())),
        ]),
      );
    }
    if (settings.keyboardLayout == KeyboardLayout.basic) {
      return Padding(
        padding: pad8,
        child: Column(children: [
          const Expanded(flex: 30, child: CalculatorDisplay()),
          SizedBox(height: gap),
          Expanded(flex: 8, child: pad([keys.basicExtraRow()])),
          SizedBox(height: gap),
          Expanded(flex: 55, child: pad(keys.basicRows())),
        ]),
      );
    }
    return Padding(
      padding: pad8,
      child: Column(children: [
        const Expanded(flex: 26, child: CalculatorDisplay()),
        SizedBox(height: gap),
        Expanded(flex: 5, child: pad([keys.memoryRow()])),
        SizedBox(height: gap),
        Expanded(flex: 23, child: pad(keys.portraitFunctionRows())),
        SizedBox(height: gap * 1.5),
        Expanded(flex: 40, child: pad(keys.numberRows())),
      ]),
    );
  }
}
