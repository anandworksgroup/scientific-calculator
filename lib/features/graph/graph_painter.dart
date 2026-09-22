import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:math_engine/math_engine.dart';

import 'graph_controller.dart';

class PlotLayer {
  const PlotLayer({required this.samples, required this.color, required this.width, this.selected = false});
  final CurveSamples samples;
  final Color color;
  final double width;
  final bool selected;
}

class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.window,
    required this.layers,
    required this.showGrid,
    required this.showAxes,
    required this.showLabels,
    required this.gridMinor,
    required this.gridMajor,
    required this.axisColor,
    required this.labelStyle,
    this.tracePoint,
    this.traceColor,
    this.tangent,
    this.markers = const [],
    this.areaPolygon,
    this.areaColor,
  });

  final GraphWindow window;
  final List<PlotLayer> layers;
  final bool showGrid, showAxes, showLabels;
  final Color gridMinor, gridMajor, axisColor;
  final TextStyle labelStyle;
  final Offset? tracePoint; // world coordinates
  final Color? traceColor;
  final TangentLine? tangent;
  final List<GraphPoint> markers;
  final Float64List? areaPolygon; // world coords, closed polygon
  final Color? areaColor;

  double _sx(double x, Size s) => (x - window.xMin) / window.width * s.width;
  double _sy(double y, Size s) => (window.yMax - y) / window.height * s.height;

  static String formatTick(double v, double step) {
    if (v.abs() < step * 1e-9) return '0';
    final decimals = step >= 1 ? 0 : (-math.log(step) / math.ln10).ceil().clamp(0, 12);
    if (v.abs() >= 1e6 || (v.abs() < 1e-4 && v != 0)) {
      return v.toStringAsExponential(1).replaceAll('e+', 'e');
    }
    var s = v.toStringAsFixed(decimals);
    if (s.contains('.')) s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s.replaceAll('-', '−');
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final stepX = GraphAnalysis.niceStep(window.width, math.max(3, (size.width / 90).round()));
    final stepY = GraphAnalysis.niceStep(window.height, math.max(3, (size.height / 70).round()));

    if (showGrid) _grid(canvas, size, stepX, stepY);
    if (areaPolygon != null && areaPolygon!.length >= 6) _area(canvas, size);
    if (showAxes) _axes(canvas, size);
    if (showLabels) _labels(canvas, size, stepX, stepY);

    for (final layer in layers) {
      _curve(canvas, size, layer);
    }
    if (tangent != null) _tangent(canvas, size);
    for (final m in markers) {
      final p = Offset(_sx(m.x, size), _sy(m.y, size));
      if (!p.dx.isFinite || !p.dy.isFinite) continue;
      canvas.drawCircle(p, 6, Paint()..color = axisColor.withValues(alpha: 0.15));
      canvas.drawCircle(p, 5, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = traceColor ?? axisColor);
    }
    final t = tracePoint;
    if (t != null && t.dx.isFinite && t.dy.isFinite) {
      final p = Offset(_sx(t.dx, size), _sy(t.dy, size));
      final dash = Paint()
        ..color = (traceColor ?? axisColor).withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), dash);
      canvas.drawLine(Offset(0, p.dy), Offset(size.width, p.dy), dash);
      canvas.drawCircle(p, 7, Paint()..color = traceColor ?? axisColor);
      canvas.drawCircle(p, 3, Paint()..color = Colors.white);
    }
  }

  void _grid(Canvas canvas, Size size, double stepX, double stepY) {
    final minor = Paint()
      ..color = gridMinor
      ..strokeWidth = 1;
    final major = Paint()
      ..color = gridMajor
      ..strokeWidth = 1;
    void lines(double step, bool vertical, Paint paint) {
      final lo = vertical ? window.xMin : window.yMin, hi = vertical ? window.xMax : window.yMax;
      final pixels = (vertical ? size.width : size.height) / ((hi - lo) / step);
      if (pixels < 6) return;
      var v = (lo / step).floor() * step;
      var guard = 0;
      while (v <= hi && guard++ < 1000) {
        if (vertical) {
          final x = _sx(v, size);
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        } else {
          final y = _sy(v, size);
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        v += step;
      }
    }

    lines(stepX / 5, true, minor);
    lines(stepY / 5, false, minor);
    lines(stepX, true, major);
    lines(stepY, false, major);
  }

  void _axes(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5;
    if (window.yMin <= 0 && window.yMax >= 0) {
      final y = _sy(0, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    if (window.xMin <= 0 && window.xMax >= 0) {
      final x = _sx(0, size);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _labels(Canvas canvas, Size size, double stepX, double stepY) {
    final xAxisY = (window.yMin <= 0 && window.yMax >= 0) ? _sy(0, size) : size.height - 14;
    final yAxisX = (window.xMin <= 0 && window.xMax >= 0) ? _sx(0, size) : 4;
    void text(String s, Offset at, {bool alignRight = false}) {
      final tp = TextPainter(text: TextSpan(text: s, style: labelStyle), textDirection: TextDirection.ltr)..layout();
      var o = alignRight ? at - Offset(tp.width, 0) : at;
      o = Offset(o.dx.clamp(2, size.width - tp.width - 2), o.dy.clamp(2, size.height - tp.height - 2));
      tp.paint(canvas, o);
    }

    var v = (window.xMin / stepX).ceil() * stepX;
    var guard = 0;
    while (v <= window.xMax && guard++ < 200) {
      if (v.abs() > stepX * 1e-9) text(formatTick(v, stepX), Offset(_sx(v, size) + 3, xAxisY + 2));
      v += stepX;
    }
    v = (window.yMin / stepY).ceil() * stepY;
    guard = 0;
    while (v <= window.yMax && guard++ < 200) {
      if (v.abs() > stepY * 1e-9) text(formatTick(v, stepY), Offset(yAxisX - 4, _sy(v, size) - 7), alignRight: yAxisX > 20);
      v += stepY;
    }
  }

  void _curve(Canvas canvas, Size size, PlotLayer layer) {
    final paint = Paint()
      ..color = layer.color
      ..strokeWidth = layer.selected ? layer.width + 1.2 : layer.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final limit = size.height * 20;
    double cy(double y) => _sy(y, size).clamp(-limit, limit + size.height);
    if (layer.samples.segmentsOnly) {
      for (final pts in layer.samples.polylines) {
        final list = <Offset>[];
        for (var k = 0; k + 3 < pts.length; k += 4) {
          list
            ..add(Offset(_sx(pts[k], size), cy(pts[k + 1])))
            ..add(Offset(_sx(pts[k + 2], size), cy(pts[k + 3])));
        }
        canvas.drawPoints(ui.PointMode.lines, list, paint);
      }
      return;
    }
    for (final pts in layer.samples.polylines) {
      if (pts.length < 4) continue;
      final path = Path()..moveTo(_sx(pts[0], size), cy(pts[1]));
      for (var k = 2; k + 1 < pts.length; k += 2) {
        path.lineTo(_sx(pts[k], size), cy(pts[k + 1]));
      }
      canvas.drawPath(path, paint);
    }
  }

  void _tangent(Canvas canvas, Size size) {
    final t = tangent!;
    final paint = Paint()
      ..color = (traceColor ?? axisColor).withValues(alpha: 0.9)
      ..strokeWidth = 1.5;
    final x1 = window.xMin, x2 = window.xMax;
    final y1 = t.slope * (x1 - t.x0) + t.y0, y2 = t.slope * (x2 - t.x0) + t.y0;
    // Dashed line.
    final a = Offset(_sx(x1, size), _sy(y1, size)), b = Offset(_sx(x2, size), _sy(y2, size));
    final len = (b - a).distance;
    if (!len.isFinite || len == 0) return;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += 12) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 7, len), paint);
    }
  }

  void _area(Canvas canvas, Size size) {
    final pts = areaPolygon!;
    final path = Path()..moveTo(_sx(pts[0], size), _sy(pts[1], size));
    for (var k = 2; k + 1 < pts.length; k += 2) {
      path.lineTo(_sx(pts[k], size), _sy(pts[k + 1], size).clamp(-size.height * 10, size.height * 11));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = (areaColor ?? axisColor).withValues(alpha: 0.22));
  }

  @override
  bool shouldRepaint(covariant GraphPainter old) => true;
}
