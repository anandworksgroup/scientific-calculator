import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Viewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_engine/math_engine.dart';

import '../../app/providers.dart';
import '../../themes/app_theme.dart';
import 'graph_controller.dart';
import 'graph_painter.dart';

/// Interactive graph canvas: pinch zoom, pan, double-tap zoom, trace.
class GraphView extends ConsumerStatefulWidget {
  const GraphView({super.key});

  @override
  ConsumerState<GraphView> createState() => _GraphViewState();
}

class _CacheEntry {
  _CacheEntry(this.key, this.samples);
  final String key;
  final CurveSamples samples;
}

class _GraphViewState extends ConsumerState<GraphView> {
  final _cache = <int, _CacheEntry>{};
  final _pendingImplicit = <int, String>{};
  Size _size = Size.zero;

  // Gesture state
  GraphWindow? _startWindow;
  Offset _startFocal = Offset.zero;
  bool _tracing = false;

  String _key(CompiledPlot p, GraphWindow w, Size s) =>
      '${p.function.expression}|${p.function.expressionY}|${p.function.graphType.name}|${p.function.tMin}|${p.function.tMax}|'
      '${w.xMin},${w.xMax},${w.yMin},${w.yMax}|${s.width.round()}x${s.height.round()}';

  Viewport _vp(GraphWindow w, Size s) => Viewport(w.xMin, w.xMax, w.yMin, w.yMax, s.width, s.height);

  CurveSamples? _samplesFor(CompiledPlot p, GraphWindow w, Size s) {
    final id = p.function.id ?? -1;
    final key = _key(p, w, s);
    final cached = _cache[id];
    if (cached != null && cached.key == key) return cached.samples;
    if (p.graph == null) return null;
    if (p.function.graphType == GraphType.implicit) {
      // Marching squares is the heaviest sampler: run it in a background
      // isolate and keep showing the previous samples meanwhile; results
      // for superseded windows are discarded.
      if (_pendingImplicit[id] != key) {
        _pendingImplicit[id] = key;
        final spec = p.function.toSpec();
        final env = ref.read(environmentProvider).copy();
        final degrees = ref.read(settingsProvider).graphDegrees;
        final vp = _vp(w, s);
        sampleInIsolate(spec, env, degrees, vp).then((samples) {
          if (!mounted || _pendingImplicit[id] != key) return;
          setState(() => _cache[id] = _CacheEntry(key, samples));
        }).catchError((Object _) {});
      }
      return cached?.samples;
    }
    try {
      final samples = GraphSampler(_vp(w, s)).sample(p.graph!);
      _cache[id] = _CacheEntry(key, samples);
      return samples;
    } catch (_) {
      return null;
    }
  }

  Offset _toWorld(Offset local) {
    final w = ref.read(graphProvider).window;
    return Offset(w.xMin + local.dx / _size.width * w.width, w.yMax - local.dy / _size.height * w.height);
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(graphProvider);
    final plots = ref.watch(compiledPlotsProvider);
    final settings = ref.watch(settingsProvider);
    final colors = CalcColors.of(context);
    final theme = Theme.of(context);
    final ctl = ref.read(graphProvider.notifier);

    return LayoutBuilder(builder: (context, c) {
      _size = Size(c.maxWidth, c.maxHeight);
      final layers = <PlotLayer>[];
      for (final p in plots) {
        if (!p.function.visible) continue;
        final samples = _samplesFor(p, g.window, _size);
        if (samples == null) continue;
        layers.add(PlotLayer(
          samples: samples,
          color: colors.graphPalette[p.function.color % colors.graphPalette.length],
          width: settings.graphLineWidth,
          selected: p.function.id == g.selectedId,
        ));
      }
      final selected = plots.where((p) => p.function.id == g.selectedId && p.graph != null).firstOrNull;
      Offset? tracePoint;
      TangentLine? tangent;
      if (g.tool != GraphTool.none && g.traceX != null && selected?.graph?.f != null &&
          selected!.function.graphType == GraphType.cartesian) {
        final f = selected.graph!.f!;
        final y = f(g.traceX!);
        if (y.isFinite) tracePoint = Offset(g.traceX!, y);
        if (g.tool == GraphTool.tangent && y.isFinite) {
          try {
            tangent = GraphAnalysis.tangent(f, g.traceX!);
          } on MathError {
            tangent = null;
          }
        }
      }
      Float64List? area;
      final a = g.analysis;
      if (a != null && a.areaRange != null && selected?.graph?.f != null) {
        final f = selected!.graph!.f!;
        final (lo, hi) = a.areaRange!;
        final pts = <double>[lo, 0];
        const n = 300;
        for (var k = 0; k <= n; k++) {
          final x = lo + (hi - lo) * k / n;
          final y = f(x);
          pts.addAll([x, y.isFinite ? y : 0]);
        }
        pts.addAll([hi, 0]);
        area = Float64List.fromList(pts);
      }
      final selColor = selected == null ? null : colors.graphPalette[selected.function.color % colors.graphPalette.length];

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) {
          _startWindow = g.window;
          _startFocal = d.localFocalPoint;
          _tracing = g.tool != GraphTool.none && d.pointerCount == 1;
          if (_tracing) ctl.trace(_toWorld(d.localFocalPoint).dx);
        },
        onScaleUpdate: (d) {
          final w0 = _startWindow;
          if (w0 == null) return;
          if (_tracing && d.pointerCount == 1) {
            ctl.trace(_toWorld(d.localFocalPoint).dx);
            return;
          }
          // Combined pinch-zoom and pan relative to the gesture start.
          final scale = d.scale.clamp(0.02, 50.0);
          final fx = w0.xMin + _startFocal.dx / _size.width * w0.width;
          final fy = w0.yMax - _startFocal.dy / _size.height * w0.height;
          final newW = w0.width / scale, newH = w0.height / scale;
          final dx = (d.localFocalPoint.dx - _startFocal.dx) / _size.width * newW;
          final dy = (d.localFocalPoint.dy - _startFocal.dy) / _size.height * newH;
          final xMin = fx - (_startFocal.dx / _size.width) * newW - dx;
          final yMax = fy + (_startFocal.dy / _size.height) * newH + dy;
          ctl.setWindow(GraphWindow(xMin, xMin + newW, yMax - newH, yMax));
        },
        onScaleEnd: (_) {
          _startWindow = null;
          _tracing = false;
        },
        onDoubleTapDown: (d) {
          final p = _toWorld(d.localPosition);
          ctl.zoom(2, p.dx, p.dy);
        },
        onTapUp: (d) {
          if (g.tool != GraphTool.none) ctl.trace(_toWorld(d.localPosition).dx);
        },
        child: Semantics(
          label: plots.where((p) => p.function.visible).map((p) => p.function.expression).join(', '),
          child: CustomPaint(
            size: Size.infinite,
            painter: GraphPainter(
              window: g.window,
              layers: layers,
              showGrid: settings.graphGrid,
              showAxes: settings.graphAxes,
              showLabels: settings.graphLabels,
              gridMinor: colors.gridMinor,
              gridMajor: colors.gridMajor,
              axisColor: colors.axis,
              labelStyle: theme.textTheme.labelSmall!.copyWith(color: colors.axis, fontSize: 10.5),
              tracePoint: tracePoint,
              traceColor: selColor,
              tangent: tangent,
              markers: a?.points ?? const [],
              areaPolygon: area,
              areaColor: selColor,
            ),
          ),
        ),
      );
    });
  }
}

/// Samples a plot in a background isolate. Top-level so the closure only
/// captures sendable plain data.
Future<CurveSamples> sampleInIsolate(GraphSpec spec, Environment env, bool degrees, Viewport vp) => Isolate.run(() {
      final g = CompiledGraph.compile(spec, env, angleMode: degrees ? AngleMode.deg : AngleMode.rad);
      return GraphSampler(vp).sample(g);
    });
