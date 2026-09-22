import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:math_engine/math_engine.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../data/settings/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../services/backup_service.dart';
import '../../services/purchase_service.dart';
import '../../themes/app_theme.dart';
import '../calculator/calculator_controller.dart';

const appVersion = '1.0.0';

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

/// Tappable row that opens a choice dialog.
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({required this.title, required this.value, required this.options, required this.onChanged});
  final String title;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((o) => o.$1 == value, orElse: () => options.first).$2;
    return ListTile(
      title: Text(title),
      subtitle: Text(current),
      onTap: () async {
        final picked = await showDialog<T>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(title),
            children: [
              for (final (v, label) in options)
                RadioListTile<T>(
                  value: v,
                  groupValue: value,
                  title: Text(label),
                  onChanged: (x) => Navigator.pop(context, x),
                ),
            ],
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Settings hub (§61).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.calculate_outlined),
          title: Text(l.settingsCalculator),
          subtitle: Text('${_angleLabel(l, s.angleMode)} · ${l.settingsPrecisionDigits(s.precision)}'),
          onTap: () => context.push(Routes.settingsCalculator),
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(l.settingsAppearance),
          subtitle: Text(_themeLabel(l, s.themeMode)),
          onTap: () => context.push(Routes.settingsAppearance),
        ),
        ListTile(
          leading: const Icon(Icons.show_chart),
          title: Text(l.settingsGraph),
          onTap: () => context.push(Routes.settingsGraph),
        ),
        _Header(l.settingsInput),
        SwitchListTile(
          title: Text(l.settingsKeyboard),
          subtitle: Text(s.keyboardLayout == KeyboardLayout.scientific ? l.settingsKeyboardScientific : l.settingsKeyboardBasic),
          value: s.keyboardLayout == KeyboardLayout.scientific,
          onChanged: (v) => set.update((x) => x.copyWith(keyboardLayout: v ? KeyboardLayout.scientific : KeyboardLayout.basic)),
        ),
        SwitchListTile(
          title: Text(l.settingsLivePreview),
          value: s.livePreview,
          onChanged: (v) => set.update((x) => x.copyWith(livePreview: v)),
        ),
        _ChoiceTile<HapticLevel>(
          title: l.settingsHaptics,
          value: s.haptics,
          options: [
            (HapticLevel.off, l.settingsHapticsOff),
            (HapticLevel.light, l.settingsHapticsLight),
            (HapticLevel.medium, l.settingsHapticsMedium),
          ],
          onChanged: (v) => set.update((x) => x.copyWith(haptics: v)),
        ),
        SwitchListTile(
          title: Text(l.settingsSound),
          subtitle: Text(l.settingsSoundSub),
          value: s.keySound,
          onChanged: (v) => set.update((x) => x.copyWith(keySound: v)),
        ),
        _Header(l.settingsHistory),
        SwitchListTile(
          title: Text(l.settingsSaveHistory),
          value: s.saveHistory,
          onChanged: (v) => set.update((x) => x.copyWith(saveHistory: v)),
        ),
        _ChoiceTile<int>(
          title: l.settingsHistoryLimit(s.historyLimit),
          value: s.historyLimit,
          options: [for (final n in const [100, 500, 1000, 5000, 20000]) (n, l.settingsHistoryLimit(n))],
          onChanged: (v) async {
            set.update((x) => x.copyWith(historyLimit: v));
            await ref.read(historyRepositoryProvider).trimTo(v);
            ref.invalidate(historyListProvider);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: Text(l.historyClearAll),
          onTap: () async {
            if (await _confirm(context, l.historyClearAll, l.historyClearConfirm)) {
              await ref.read(historyRepositoryProvider).clear();
              ref.invalidate(historyListProvider);
            }
          },
        ),
        _Header(l.settingsPrivacy),
        ListTile(leading: const Icon(Icons.save_alt), title: Text(l.settingsBackup), onTap: () => context.push(Routes.backup)),
        ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: Text(l.privacyTitle), onTap: () => context.push(Routes.privacy)),
        ListTile(
          leading: const Icon(Icons.delete_forever_outlined),
          title: Text(l.settingsClearData),
          onTap: () async {
            if (!await _confirm(context, l.settingsClearData, l.settingsClearDataConfirm)) return;
            await ref.read(appDatabaseProvider).clearAll();
            ref.invalidate(variablesProvider);
            await ref.read(functionsProvider.notifier).reload();
            ref.invalidate(historyListProvider);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.deletedItem)));
          },
        ),
        _Header(l.settingsAbout),
        ListTile(leading: const Icon(Icons.workspace_premium_outlined), title: Text(l.premiumTitle), onTap: () => context.push(Routes.premium)),
        ListTile(leading: const Icon(Icons.info_outline), title: Text(l.aboutTitle), subtitle: Text(l.aboutVersion(appVersion)), onTap: () => context.push(Routes.about)),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: Text(l.settingsResetAll),
          onTap: () async {
            if (await _confirm(context, l.settingsResetAll, l.settingsResetConfirm)) await set.reset();
          },
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

String _angleLabel(AppLocalizations l, AngleMode a) => switch (a) {
      AngleMode.deg => l.angleDegLong,
      AngleMode.rad => l.angleRadLong,
      AngleMode.grad => l.angleGradLong,
    };

String _themeLabel(AppLocalizations l, AppThemeMode m) => switch (m) {
      AppThemeMode.system => l.settingsThemeSystem,
      AppThemeMode.light => l.settingsThemeLight,
      AppThemeMode.dark => l.settingsThemeDark,
      AppThemeMode.amoled => l.settingsThemeAmoled,
    };

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.actionOk)),
          ],
        ),
      ) ??
      false;
}

/// Calculator settings (§62).
class CalculatorSettingsScreen extends ConsumerWidget {
  const CalculatorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier);
    final sample = NumberFormatter(s.formatOptions()).format(Rat.parseDecimal('1234567.891'), preferDecimal: true).display;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsCalculator)),
      body: ListView(children: [
        _ChoiceTile<AngleMode>(
          title: l.settingsAngleUnit,
          value: s.angleMode,
          options: [for (final a in AngleMode.values) (a, _angleLabel(l, a))],
          onChanged: (v) => set.update((x) => x.copyWith(angleMode: v)),
        ),
        _ChoiceTile<ResultFormat>(
          title: l.settingsResultFormat,
          value: s.resultFormat,
          options: [
            (ResultFormat.auto, l.formatAuto),
            (ResultFormat.decimal, l.formatDecimal),
            (ResultFormat.fraction, l.formatFraction),
            (ResultFormat.mixed, l.formatMixed),
            (ResultFormat.exact, l.formatExact),
          ],
          onChanged: (v) => set.update((x) => x.copyWith(resultFormat: v)),
        ),
        _ChoiceTile<NumberNotation>(
          title: l.settingsNumberFormat,
          value: s.notation,
          options: [
            (NumberNotation.normal, l.notationNormal),
            (NumberNotation.scientific, l.notationScientific),
            (NumberNotation.engineering, l.notationEngineering),
          ],
          onChanged: (v) => set.update((x) => x.copyWith(notation: v)),
        ),
        _ChoiceTile<int>(
          title: l.settingsPrecision,
          value: s.precision,
          options: [for (final p in AppSettings.precisionChoices) (p, l.settingsPrecisionDigits(p))],
          onChanged: (v) => set.update((x) => x.copyWith(precision: v)),
        ),
        _Header(l.settingsDisplay),
        ListTile(title: Text(sample, style: Theme.of(context).textTheme.titleLarge)),
        SwitchListTile(
          title: Text(l.settingsThousands),
          value: s.thousandsSeparator,
          onChanged: (v) => set.update((x) => x.copyWith(thousandsSeparator: v)),
        ),
        _ChoiceTile<bool>(
          title: l.settingsDecimalSeparator,
          value: s.decimalComma,
          options: [(false, l.settingsDecimalPoint), (true, l.settingsDecimalComma)],
          onChanged: (v) => set.update((x) => x.copyWith(decimalComma: v)),
        ),
        SwitchListTile(
          title: Text(l.settingsEngSymbols),
          subtitle: Text(l.settingsEngSymbolsSub),
          value: s.engineeringSymbols,
          onChanged: (v) => set.update((x) => x.copyWith(engineeringSymbols: v)),
        ),
        _ChoiceTile<ComplexFormat>(
          title: l.settingsComplexFormat,
          value: s.complexFormat,
          options: [(ComplexFormat.rectangular, l.complexRect), (ComplexFormat.polar, l.complexPolar)],
          onChanged: (v) => set.update((x) => x.copyWith(complexFormat: v)),
        ),
        SwitchListTile(
          title: Text(l.settingsComplexResults),
          subtitle: Text(l.settingsComplexResultsSub),
          value: s.complexResults,
          onChanged: (v) => set.update((x) => x.copyWith(complexResults: v)),
        ),
        SwitchListTile(
          title: Text(l.settingsMemoryPersists),
          value: s.memoryPersists,
          onChanged: (v) => set.update((x) => x.copyWith(memoryPersists: v)),
        ),
      ]),
    );
  }
}

/// Appearance (§63).
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier);
    final premium = ref.watch(premiumProvider).isPremium;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAppearance)),
      body: ListView(children: [
        _Header(l.settingsTheme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in AppThemeMode.values)
              ChoiceChip(label: Text(_themeLabel(l, m)), selected: s.themeMode == m, onSelected: (_) => set.update((x) => x.copyWith(themeMode: m))),
          ]),
        ),
        _Header(l.settingsAccent),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            for (final p in accentPalettes)
              Semantics(
                button: true,
                selected: s.accent == p.id,
                label: '${l.settingsAccent} ${p.id}${p.premium ? ' (${l.settingsPremiumTheme})' : ''}',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (p.premium && !premium) {
                      context.push(Routes.premium);
                      return;
                    }
                    set.update((x) => x.copyWith(accent: p.id));
                  },
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: p.seed,
                        shape: BoxShape.circle,
                        border: s.accent == p.id ? Border.all(color: theme.colorScheme.onSurface, width: 3) : null,
                      ),
                    ),
                    if (p.premium && !premium) const Icon(Icons.lock, size: 18, color: Colors.white),
                  ]),
                ),
              ),
          ]),
        ),
        _Header(l.settingsDisplay),
        ListTile(
          title: Text(l.settingsFontSize),
          subtitle: Slider(
            value: s.fontScale,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            label: '${(s.fontScale * 100).round()}%',
            onChanged: (v) => set.update((x) => x.copyWith(fontScale: v)),
          ),
        ),
        _ChoiceTile<DisplaySize>(
          title: l.settingsDisplaySize,
          value: s.displaySize,
          options: [(DisplaySize.small, l.settingsSmall), (DisplaySize.medium, l.settingsMedium), (DisplaySize.large, l.settingsLarge)],
          onChanged: (v) => set.update((x) => x.copyWith(displaySize: v)),
        ),
        _ChoiceTile<ButtonSize>(
          title: l.settingsButtonSize,
          value: s.buttonSize,
          options: [(ButtonSize.compact, l.settingsCompact), (ButtonSize.normal, l.settingsNormal), (ButtonSize.large, l.settingsLarge)],
          onChanged: (v) => set.update((x) => x.copyWith(buttonSize: v)),
        ),
        SwitchListTile(
          title: Text(l.settingsButtonLabels),
          value: s.showSecondaryLabels,
          onChanged: (v) => set.update((x) => x.copyWith(showSecondaryLabels: v)),
        ),
        SwitchListTile(
          title: Text(l.settingsAnimations),
          value: s.animations,
          onChanged: (v) => set.update((x) => x.copyWith(animations: v)),
        ),
      ]),
    );
  }
}

/// Graph settings.
class GraphSettingsScreen extends ConsumerWidget {
  const GraphSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsGraph)),
      body: ListView(children: [
        SwitchListTile(title: Text(l.settingsGraphGrid), value: s.graphGrid, onChanged: (v) => set.update((x) => x.copyWith(graphGrid: v))),
        SwitchListTile(title: Text(l.settingsGraphAxes), value: s.graphAxes, onChanged: (v) => set.update((x) => x.copyWith(graphAxes: v))),
        SwitchListTile(title: Text(l.settingsGraphLabels), value: s.graphLabels, onChanged: (v) => set.update((x) => x.copyWith(graphLabels: v))),
        SwitchListTile(title: Text(l.settingsGraphDegrees), value: s.graphDegrees, onChanged: (v) => set.update((x) => x.copyWith(graphDegrees: v))),
        ListTile(
          title: Text(l.settingsGraphLineWidth),
          subtitle: Slider(
            value: s.graphLineWidth,
            min: 1,
            max: 6,
            divisions: 10,
            label: s.graphLineWidth.toStringAsFixed(1),
            onChanged: (v) => set.update((x) => x.copyWith(graphLineWidth: v)),
          ),
        ),
      ]),
    );
  }
}

/// Backup & restore (§103).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final text = await BackupService(ref.read(appDatabaseProvider)).export(ref.read(settingsProvider));
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
      final file = File('${dir.path}/advanced-calculator-backup-$stamp.json');
      await file.writeAsString(text);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: l.appTitle));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.backupExported)));
    } catch (e) {
      AppLogger.error('backup export', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null || !mounted) return;
    if (!await _confirm(context, l.backupImport, l.backupImportConfirm)) return;
    setState(() => _busy = true);
    try {
      if (bytes.length > BackupService.maxBytes) throw const BackupFormatException('too large');
      final text = String.fromCharCodes(bytes);
      final settings = await BackupService(ref.read(appDatabaseProvider)).import(_utf8(text, bytes));
      ref.read(settingsProvider.notifier).update((_) => settings);
      ref.invalidate(variablesProvider);
      await ref.read(functionsProvider.notifier).reload();
      ref.invalidate(historyListProvider);
      ref.invalidate(variablesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.backupImported)));
    } on BackupFormatException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.backupInvalid)));
    } catch (e) {
      AppLogger.error('backup import', e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.backupInvalid)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _utf8(String latin1, List<int> bytes) {
    try {
      return const Utf8Decoder().convert(bytes);
    } on FormatException {
      return latin1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.backupTitle)),
      body: Stack(children: [
        ListView(children: [
          ListTile(leading: const Icon(Icons.upload_file), title: Text(l.backupExport), subtitle: Text(l.backupExportSub), onTap: _busy ? null : _export),
          ListTile(leading: const Icon(Icons.download), title: Text(l.backupImport), subtitle: Text(l.backupImportSub), onTap: _busy ? null : _import),
        ]),
        if (_busy) const LinearProgressIndicator(),
      ]),
    );
  }
}

/// Privacy (§71).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyTitle)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(l.privacyBody, style: t.bodyLarge),
        const SizedBox(height: 16),
        Text(l.privacyPurchases, style: t.bodyLarge),
      ]),
    );
  }
}

/// About.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Icon(Icons.calculate, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.appTitle, style: t.titleLarge),
              Text(l.aboutVersion(appVersion), style: t.bodyMedium),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Text(l.aboutDescription, style: t.bodyLarge),
        const SizedBox(height: 12),
        Text(l.aboutEngine, style: t.bodyMedium),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          icon: const Icon(Icons.privacy_tip_outlined),
          label: Text(l.privacyTitle),
          onPressed: () => context.push(Routes.privacy),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.description_outlined),
          label: Text(l.aboutLicenses),
          onPressed: () => showLicensePage(context: context, applicationName: l.appTitle, applicationVersion: appVersion),
        ),
      ]),
    );
  }
}
