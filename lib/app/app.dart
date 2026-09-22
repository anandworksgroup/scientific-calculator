import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings/app_settings.dart';
import '../l10n/generated/app_localizations.dart';
import '../themes/app_theme.dart';
import 'providers.dart';
import 'router.dart';

class AdvancedCalculatorApp extends ConsumerWidget {
  const AdvancedCalculatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.build(brightness: Brightness.light, accent: s.accent),
      darkTheme: AppTheme.build(brightness: Brightness.dark, accent: s.accent, amoled: s.themeMode == AppThemeMode.amoled),
      themeMode: AppTheme.themeMode(s.themeMode),
      themeAnimationDuration: s.animations ? const Duration(milliseconds: 200) : Duration.zero,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
