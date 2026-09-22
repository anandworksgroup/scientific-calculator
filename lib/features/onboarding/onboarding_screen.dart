import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/math_view.dart';

/// First launch: a simple welcome with Get Started, plus an optional short
/// tour. No account screen (§88).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingDone: true));
    context.go(Routes.calculator);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final slides = [
      (Icons.calculate_outlined, l.onboardingScientificTitle, l.onboardingScientificBody, r'\frac{1}{2}+\frac{3}{4}=\frac{5}{4}\qquad\sqrt{8}=2\sqrt{2}'),
      (Icons.functions, l.onboardingSolveTitle, l.onboardingSolveBody, r'x^{2}-5x+6=0\;\Rightarrow\;x=2,\,3'),
      (Icons.show_chart, l.onboardingGraphTitle, l.onboardingGraphBody, r'y=\sin x,\quad r=\sin 3\theta'),
      (Icons.cloud_off_outlined, l.onboardingOfflineTitle, l.onboardingOfflineBody, r'\int_{0}^{1}x^{2}\,dx=\frac{1}{3}'),
    ];
    final last = _index == slides.length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: _finish, child: Text(l.onboardingSkip)),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                // Welcome
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset('assets/icon/app_icon.png', width: 112, height: 112, excludeFromSemantics: true),
                    const SizedBox(height: 28),
                    Text(l.appTitle, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(l.appTagline, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                  ]),
                ),
                for (final (icon, title, body, tex) in slides)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 24),
                      Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(body, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      FittedBox(child: MathView(tex, style: theme.textTheme.titleLarge)),
                    ]),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(children: [
              for (var i = 0; i <= slides.length; i++)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: i == _index ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              const Spacer(),
              if (_index == 0)
                FilledButton(onPressed: _finish, child: Text(l.onboardingGetStarted))
              else if (last)
                FilledButton(onPressed: _finish, child: Text(l.onboardingGetStarted))
              else
                FilledButton.tonal(
                  onPressed: () => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  child: Text(l.onboardingNext),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
