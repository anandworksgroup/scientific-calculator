import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../data/repositories/user_data_repositories.dart';

enum GraphTool { none, trace, tangent }

/// A world-space window.
class GraphWindow {
  const GraphWindow(this.xMin, this.xMax, this.yMin, this.yMax);
  final double xMin, xMax, yMin, yMax;

  static const standard = GraphWindow(-10, 10, -10, 10);

  double get width => xMax - xMin;
  double get height => yMax - yMin;

  Map<String, double> toJson() => {'a': xMin, 'b': xMax, 'c': yMin, 'd': yMax};

  static GraphWindow? fromJson(Object? j) {
    if (j is! Map) return null;
    final v = [j['a'], j['b'], j['c'], j['d']];
    if (v.any((e) => e is! num || !e.isFinite)) return null;
    final d = [for (final e in v) (e as num).toDouble()];
    final w = GraphWindow(d[0], d[1], d[2], d[3]);
    return w.width > 0 && w.height > 0 ? w : null;
  }
}

/// Analysis markers drawn on the graph.
class AnalysisResult {
  const AnalysisResult({required this.functionId, required this.points, this.area, this.areaRange});
  final int functionId;
  final List<GraphPoint> points;
  final double? area;
  final (double, double)? areaRange;
}

class GraphState {
  const GraphState({
    this.window = GraphWindow.standard,
    this.tool = GraphTool.none,
    this.selectedId,
    this.traceX,
    this.analysis,
    this.errors = const {},
  });

  final GraphWindow window;
  final GraphTool tool;

  /// Function being traced/analysed.
  final int? selectedId;
  final double? traceX;
  final AnalysisResult? analysis;

  /// Compile errors per function id.
  final Map<int, MathError> errors;

  GraphState copyWith({
    GraphWindow? window,
    GraphTool? tool,
    int? Function()? selectedId,
    double? Function()? traceX,
    AnalysisResult? Function()? analysis,
    Map<int, MathError>? errors,
  }) =>
      GraphState(
        window: window ?? this.window,
        tool: tool ?? this.tool,
        selectedId: selectedId != null ? selectedId() : this.selectedId,
        traceX: traceX != null ? traceX() : this.traceX,
        analysis: analysis != null ? analysis() : this.analysis,
        errors: errors ?? this.errors,
      );
}

/// Compiled plot cache keyed by function definition and environment.
class CompiledPlot {
  CompiledPlot(this.function, this.graph, this.error);
  final SavedFunction function;
  final CompiledGraph? graph;
  final MathError? error;
}

final compiledPlotsProvider = Provider<List<CompiledPlot>>((ref) {
  final funcs = ref.watch(functionsProvider);
  final env = ref.watch(environmentProvider);
  final degrees = ref.watch(settingsProvider.select((s) => s.graphDegrees));
  return [
    for (final f in funcs)
      () {
        try {
          return CompiledPlot(f, CompiledGraph.compile(f.toSpec(), env, angleMode: degrees ? AngleMode.deg : AngleMode.rad), null);
        } on MathError catch (e) {
          return CompiledPlot(f, null, e);
        } catch (e) {
          return CompiledPlot(f, null, MathError(MathErrorCode.invalidExpression, {'detail': '$e'}));
        }
      }(),
  ];
});

class GraphController extends Notifier<GraphState> {
  Timer? _persist;
  static const _key = 'graph.window';

  @override
  GraphState build() {
    ref.onDispose(() => _persist?.cancel());
    final saved = ref.read(settingsStoreProvider).getString(_key);
    GraphWindow? w;
    if (saved != null) {
      try {
        w = GraphWindow.fromJson(jsonDecode(saved));
      } on FormatException {
        w = null;
      }
    }
    return GraphState(window: w ?? GraphWindow.standard);
  }

  void _setWindow(GraphWindow w) {
    // Keep the window within sane numeric limits.
    if (!(w.width > 1e-12 && w.height > 1e-12 && w.width < 1e12 && w.height < 1e12)) return;
    if (w.xMin.abs() > 1e12 || w.yMin.abs() > 1e12) return;
    state = state.copyWith(window: w);
    _persist?.cancel();
    _persist = Timer(const Duration(milliseconds: 500), () {
      ref.read(settingsStoreProvider).setString(_key, jsonEncode(w.toJson()));
    });
  }

  void pan(double dxWorld, double dyWorld) {
    final w = state.window;
    _setWindow(GraphWindow(w.xMin - dxWorld, w.xMax - dxWorld, w.yMin - dyWorld, w.yMax - dyWorld));
  }

  /// Zooms by [factor] (> 1 zooms in) about a world point.
  void zoom(double factor, double cx, double cy, {bool xOnly = false, bool yOnly = false}) {
    final w = state.window;
    final fx = yOnly ? 1.0 : factor, fy = xOnly ? 1.0 : factor;
    _setWindow(GraphWindow(
      cx - (cx - w.xMin) / fx,
      cx + (w.xMax - cx) / fx,
      cy - (cy - w.yMin) / fy,
      cy + (w.yMax - cy) / fy,
    ));
  }

  void zoomCenter(double factor) {
    final w = state.window;
    zoom(factor, (w.xMin + w.xMax) / 2, (w.yMin + w.yMax) / 2);
  }

  void setWindow(GraphWindow w) => _setWindow(w);

  /// Keeps the aspect ratio square for the given pixel size.
  void reset(double widthPx, double heightPx) {
    final ratio = heightPx / math.max(1, widthPx);
    _setWindow(GraphWindow(-10, 10, -10 * ratio, 10 * ratio));
  }

  /// Fits the y-range to the visible cartesian curves.
  void autoFit(List<CompiledPlot> plots) {
    final w = state.window;
    final ys = <double>[];
    for (final p in plots) {
      if (!p.function.visible || p.graph == null) continue;
      final g = p.graph!;
      if (g.spec.type == GraphType.cartesian) {
        for (var k = 0; k <= 400; k++) {
          final y = g.f!(w.xMin + w.width * k / 400);
          if (y.isFinite) ys.add(y);
        }
      } else if (g.spec.type == GraphType.polar || g.spec.type == GraphType.parametric) {
        for (var k = 0; k <= 400; k++) {
          final t = g.spec.tMin + (g.spec.tMax - g.spec.tMin) * k / 400;
          final (x, y) = g.spec.type == GraphType.polar
              ? (g.f!(t) * math.cos(t), g.f!(t) * math.sin(t))
              : (g.fx!(t), g.fy!(t));
          if (y.isFinite && x.isFinite) ys.add(y);
        }
      }
    }
    if (ys.isEmpty) return;
    ys.sort();
    // Ignore extreme outliers (asymptotes) using the 2nd–98th percentile.
    final lo = ys[(ys.length * 0.02).floor()], hi = ys[math.min(ys.length - 1, (ys.length * 0.98).ceil())];
    var span = hi - lo;
    if (span < 1e-9) span = math.max(1, lo.abs());
    _setWindow(GraphWindow(w.xMin, w.xMax, lo - span * 0.1, hi + span * 0.1));
  }

  void setTool(GraphTool t) {
    final w = state.window;
    state = state.copyWith(
      tool: state.tool == t ? GraphTool.none : t,
      traceX: () => state.traceX ?? (w.xMin + w.xMax) / 2,
    );
  }

  void select(int? id) => state = state.copyWith(selectedId: () => id, analysis: () => null);

  void trace(double x) => state = state.copyWith(traceX: () => x);

  void clearAnalysis() => state = state.copyWith(analysis: () => null, tool: GraphTool.none);

  void setAnalysis(AnalysisResult? r) => state = state.copyWith(analysis: () => r);
}

final graphProvider = NotifierProvider<GraphController, GraphState>(GraphController.new);
