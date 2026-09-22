import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/settings/app_settings.dart';
import '../../../themes/app_theme.dart';
import '../../../widgets/math_view.dart';
import 'key_specs.dart';

typedef KeyCallback = void Function(CalcKey key);
typedef AltCallback = void Function(KeyAlt alt);

/// A grid of calculator keys.
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.rows,
    required this.onKey,
    required this.onAlt,
    this.shiftActive = false,
    this.alphaActive = false,
    this.storeActive = false,
    this.gap = 6,
  });

  final List<List<CalcKey>> rows;
  final KeyCallback onKey;
  final AltCallback onAlt;
  final bool shiftActive;
  final bool alphaActive;
  final bool storeActive;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) SizedBox(width: gap),
                  Expanded(
                    flex: rows[r][c].flex,
                    child: CalcKeyButton(
                      spec: rows[r][c],
                      onKey: onKey,
                      onAlt: onAlt,
                      active: (rows[r][c].id == 'shift' && shiftActive) ||
                          (rows[r][c].id == 'alpha' && alphaActive) ||
                          (rows[r][c].id == 'sto' && storeActive),
                      shiftActive: shiftActive,
                      alphaActive: alphaActive,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class CalcKeyButton extends ConsumerWidget {
  const CalcKeyButton({
    super.key,
    required this.spec,
    required this.onKey,
    required this.onAlt,
    this.active = false,
    this.shiftActive = false,
    this.alphaActive = false,
  });

  final CalcKey spec;
  final KeyCallback onKey;
  final AltCallback onAlt;
  final bool active;
  final bool shiftActive;
  final bool alphaActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CalcColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final (bg, fg) = switch (spec.style) {
      KeyStyle.number => (c.keyNumber, c.onKeyNumber),
      KeyStyle.function => (c.keyFunction, c.onKeyFunction),
      KeyStyle.operator => (c.keyOperator, c.onKeyOperator),
      KeyStyle.action => (c.keyAction, c.onKeyAction),
      KeyStyle.equals => (c.keyEquals, c.onKeyEquals),
      KeyStyle.modifier => (Colors.transparent, scheme.onSurfaceVariant),
    };
    final activeBg = active ? (spec.id == 'alpha' ? c.alphaLabel : c.shiftLabel).withValues(alpha: 0.25) : bg;
    // The label shown depends on the active modifier.
    final alt = shiftActive && spec.shift != null ? spec.shift : (alphaActive && spec.alpha != null ? spec.alpha : null);
    final showSecondary = settings.showSecondaryLabels;
    final radius = BorderRadius.circular(switch (settings.buttonSize) {
      ButtonSize.compact => 10,
      ButtonSize.normal => 14,
      ButtonSize.large => 18,
    });

    return Semantics(
      button: true,
      label: alt?.semantic ?? spec.semantic,
      excludeSemantics: true,
      child: Material(
        color: activeBg,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            ref.read(feedbackServiceProvider).keyPress(settings);
            onKey(spec);
          },
          onLongPress: spec.longPress.isEmpty ? null : () => _showLongPress(context, ref),
          child: LayoutBuilder(builder: (context, box) {
            final base = math.min(box.maxHeight * 0.4, box.maxWidth * 0.34) * settings.fontScale;
            final small = math.max(8.0, base * 0.42);
            final mainStyle = TextStyle(
              fontSize: base,
              color: alt != null ? (shiftActive ? c.shiftLabel : c.alphaLabel) : fg,
              fontWeight: spec.style == KeyStyle.number || spec.style == KeyStyle.equals ? FontWeight.w500 : FontWeight.w400,
            );
            final label = alt ?? KeyAlt(spec.label, spec.action, spec.semantic, tex: spec.tex);
            Widget main = alt == null && spec.icon != null
                ? Icon(spec.icon, size: base * 1.25, color: mainStyle.color)
                : label.tex
                ? FittedBox(fit: BoxFit.scaleDown, child: MathView(label.label, style: mainStyle, fallback: label.label))
                : FittedBox(fit: BoxFit.scaleDown, child: Text(label.label, style: mainStyle, maxLines: 1));
            if (!showSecondary || box.maxHeight < 34 || (spec.shift == null && spec.alpha == null) || alt != null) {
              return Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: main));
            }
            return Stack(
              children: [
                Positioned.fill(
                  top: small * 0.9,
                  child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: main)),
                ),
                if (spec.shift != null)
                  Positioned(
                    left: 4,
                    top: 2,
                    right: box.maxWidth / 2,
                    child: _Secondary(spec.shift!, TextStyle(fontSize: small, color: c.shiftLabel)),
                  ),
                if (spec.alpha != null)
                  Positioned(
                    right: 4,
                    top: 2,
                    left: box.maxWidth / 2,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _Secondary(spec.alpha!, TextStyle(fontSize: small, color: c.alphaLabel)),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _showLongPress(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay)),
      Offset.zero & overlay.size,
    );
    final style = Theme.of(context).textTheme.titleMedium;
    final chosen = await showMenu<KeyAlt>(
      context: context,
      position: pos,
      items: [
        for (final a in spec.longPress)
          PopupMenuItem(
            value: a,
            child: Semantics(
              label: a.semantic,
              excludeSemantics: true,
              child: Row(children: [
                SizedBox(width: 64, child: a.tex ? MathView(a.label, style: style) : Text(a.label, style: style)),
                const SizedBox(width: 12),
                Flexible(child: Text(a.semantic, style: Theme.of(context).textTheme.bodySmall)),
              ]),
            ),
          ),
      ],
    );
    if (chosen != null) onAlt(chosen);
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary(this.alt, this.style);
  final KeyAlt alt;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: alt.tex ? MathView(alt.label, style: style, fallback: alt.label) : Text(alt.label, style: style),
        ),
      );
}
