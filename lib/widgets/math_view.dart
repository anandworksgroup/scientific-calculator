import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders LaTeX in textbook notation, falling back to plain text if the
/// expression cannot be typeset (never throws into the UI).
class MathView extends StatelessWidget {
  const MathView(
    this.tex, {
    super.key,
    this.style,
    this.fallback,
    this.display = false,
    this.semanticsLabel,
    this.selectable = false,
  });

  final String tex;
  final TextStyle? style;

  /// Plain-text fallback (defaults to the raw LaTeX).
  final String? fallback;

  /// Display style (larger operators, limits above/below).
  final bool display;
  final String? semanticsLabel;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final ts = style ?? DefaultTextStyle.of(context).style;
    Widget child;
    if (selectable) {
      child = SelectableMath.tex(
        tex,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        textStyle: ts,
        onErrorFallback: (e) => SelectableText(fallback ?? tex, style: ts),
      );
    } else {
      child = Math.tex(
        tex,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        textStyle: ts,
        onErrorFallback: (e) => Text(fallback ?? tex, style: ts),
      );
    }
    if (semanticsLabel != null) {
      return Semantics(label: semanticsLabel, excludeSemantics: true, child: child);
    }
    return child;
  }
}

/// Horizontally scrollable math that keeps its right end visible.
class ScrollingMath extends StatelessWidget {
  const ScrollingMath(this.tex, {super.key, this.style, this.fallback, this.semanticsLabel, this.alignRight = true});

  final String tex;
  final TextStyle? style;
  final String? fallback;
  final String? semanticsLabel;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: alignRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: Align(
            alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
            child: MathView(tex, style: style, fallback: fallback, semanticsLabel: semanticsLabel),
          ),
        ),
      ),
    );
  }
}
