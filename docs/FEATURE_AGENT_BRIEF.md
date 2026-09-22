# Brief for feature-screen work (Advanced Calculator)

Flutter app: `D:\NEW AI WORK\advanced_calculator` (Flutter 3.32, Dart 3.8, Material 3,
Riverpod 3, go_router 17). Pure-Dart engine: `packages/math_engine`
(`import 'package:math_engine/math_engine.dart';`). Read `lib/features/calculator/`
and `lib/features/graph/` first to match style.

## Hard rules
- **No hardcoded user-visible strings in widgets.** Add keys to `lib/l10n/app_en.arb`
  (use your feature prefix, e.g. `matrix…`), then run `flutter gen-l10n`.
  Several people edit that ARB concurrently: always use the Edit tool, insert your
  block just before the final `}` (keep valid JSON: the previous last entry needs a
  trailing comma), and if the edit fails because the file changed, re-read and retry.
  Use `AppLocalizations.of(context)` from `lib/l10n/generated/app_localizations.dart`.
  Content catalogs from the engine (formula text, unit names, constant names,
  function descriptions) are data and may be shown directly.
- **No placeholders, TODOs, "coming soon", fake or hardcoded answers.** Every button works.
  All math goes through the engine.
- **Never let exceptions reach the UI.** Engine calls return `EngineResult`
  (`Success/Failure/Cancelled`); show failures with
  `errorText(l, error)` from `lib/core/error_text.dart`.
- Heavy engine work (solving, integrals, eigen, big stats) must not block the UI:
  use `ref.read(engineServiceProvider).run(() => someTopLevelFunction(args))`
  (`lib/services/engine_service.dart`) — the closure is sent to an isolate, so it must
  only capture plain data (strings, numbers, engine `Value`s, `CalcSettings`,
  `Environment`); call a **top-level** function to avoid capturing `this`/`ref`.
  Show a progress indicator with a Cancel button (`Computation.cancel()`).
- Use the Edit/Write tools for files. Never round-trip files through PowerShell
  `Get-Content`/`Set-Content` (corrupts UTF-8). Scripting: Python at
  `D:\NEW AI WORK\.venv\Scripts\python.exe` with `encoding="utf-8"`.
- Do **not** edit: `lib/app/router.dart`, `lib/app/secondary_routes.dart`,
  `lib/app/providers.dart`, anything in `packages/math_engine/lib`, or other features'
  folders. The integrator wires routes. If you find an engine bug, work around it in
  your UI only if trivial and report it with a minimal repro.
- Do not run the app on the emulator/phone (another session uses it). Verify with
  `flutter analyze` (zero issues in your files) and widget/unit tests under
  `test/features/` using `test/helpers/test_app.dart` (see `test/calculator_widget_test.dart`
  for how to pump a screen with an in-memory DB and find widgets by semantics label).

## Available building blocks
- Providers (`lib/app/providers.dart`): `settingsProvider` (AppSettings: `calcSettings`,
  `formatOptions()`, precision, angleMode…), `environmentProvider` (variables + saved
  functions → `Environment`), `variablesProvider` (+ `.notifier.set(name, Value)`),
  `engineServiceProvider`, `historyRepositoryProvider` (`HistoryEntry` insert — record
  finished calculations with a `mode` such as `'matrix'`), `favoritesRepositoryProvider`
  (`FavoriteType` formula/constant/converter/unit/tool), `matricesRepositoryProvider`
  (`SavedMatrix` with cell text), `conversionsRepositoryProvider` (recent conversions),
  `functionsProvider` (saved functions/plots).
- Widgets: `MathView(tex)`, `ScrollingMath(tex)` (`lib/widgets/math_view.dart`),
  `StepsView(steps)` (`lib/widgets/steps_view.dart`), `CalcColors.of(context)` theme
  extension, `ClipboardService.copy/share/sanitize` (`lib/services/clipboard_service.dart`).
- Formatting results: `ValueFormatter(settings.formatOptions()).format(value)` →
  `.latex` / `.plain` / `.display`; `NumberFormatter` for a single `Num`.
- Engine facade: `const DefaultMathEngine()` — `evaluate`, `simplify`, `expand`, `factor`,
  `collect`, `substitute`, `solve`, `solvePolynomial`, `solveLinearSystem`,
  `differentiate`, `integrate`, `limit`, `eigen`. Also `MatrixOps`, `Statistics`,
  `Probability`, `NumberTheory`, `ProgrammerCalc`, `UnitConverter`/`unitCategories`,
  `physicalConstants`, `formulas`/`searchFormulas`, `FunctionTable`, `ValueCodec`.
  Read the engine sources for exact signatures.
- Screens are pushed full-screen: build a `Scaffold` with an `AppBar` (title from l10n,
  back button automatic). Must work on phones (portrait + landscape) and tablets
  (use LayoutBuilder for 2-pane layouts ≥ 720 dp), light/dark/AMOLED themes, large text.
- Accessibility: tooltips on icon buttons, `Semantics` labels for custom controls,
  48 dp touch targets, results in a `Semantics(liveRegion: true)`.
- Inputs that accept math: plain `TextField`s are fine (users can type `1/3`, `sqrt(2)`,
  `pi`); sanitize with `ClipboardService.sanitize`, evaluate with the engine, show
  the value in textbook form with `MathView` next to the field when useful.

## Deliverable report
List files created, public screen class names and constructor params, any route
query parameters you expect, ARB keys prefix used, tests run and results, and any
engine issues found.
