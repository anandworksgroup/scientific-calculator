/// Graph engine: parses plot definitions, samples curves adaptively in
/// screen space, detects discontinuities, and provides analysis (roots,
/// extrema, intersections, tangents, areas).
///
/// Everything here is pure Dart and works on plain data, so sampling can
/// run inside a background isolate. The UI only draws the returned
/// polylines with a CustomPainter.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../ast/ast.dart';
import '../core/errors.dart';
import '../engine.dart';
import '../eval/double_eval.dart';
import '../eval/evaluator.dart';
import '../parser/parser.dart';

enum GraphType { cartesian, polar, parametric, implicit }

/// A user-entered plot, serializable (strings and numbers only).
class GraphSpec {
  const GraphSpec({
    required this.id,
    required this.type,
    required this.expression,
    this.expressionY = '',
    this.tMin = 0,
    this.tMax = 2 * math.pi,
  });

  final String id;
  final GraphType type;

  /// cartesian: f(x) or `y = f(x)`; polar: r(θ) or `r = …`;
  /// parametric: x(t); implicit: `F(x, y) = G(x, y)`.
  final String expression;

  /// parametric: y(t).
  final String expressionY;
  final double tMin;
  final double tMax;
}

class Viewport {
  const Viewport(this.xMin, this.xMax, this.yMin, this.yMax, this.widthPx, this.heightPx);
  final double xMin, xMax, yMin, yMax;
  final double widthPx, heightPx;

  double get xRange => xMax - xMin;
  double get yRange => yMax - yMin;
  double toPx(double x) => (x - xMin) / xRange * widthPx;
  double toPy(double y) => (yMax - y) / yRange * heightPx;
  double fromPx(double px) => xMin + px / widthPx * xRange;
  double fromPy(double py) => yMax - py / heightPx * yRange;
}

/// Sampled curve: a list of polylines stored as interleaved x,y doubles in
/// world coordinates. Breaks between polylines mark discontinuities.
class CurveSamples {
  const CurveSamples(this.polylines, {this.segmentsOnly = false});
  final List<Float64List> polylines;

  /// Implicit curves: each polyline is a set of independent 2-point segments.
  final bool segmentsOnly;
}

typedef RealFn = double Function(double);
typedef RealFn2 = double Function(double, double);

/// A plot definition compiled to fast double closures.
class CompiledGraph {
  CompiledGraph._(this.spec, {this.f, this.fx, this.fy, this.implicitFn});

  final GraphSpec spec;
  final RealFn? f; // cartesian y(x) or polar r(θ)
  final RealFn? fx; // parametric x(t)
  final RealFn? fy; // parametric y(t)
  final RealFn2? implicitFn;

  /// Compiles [spec]. Trigonometric functions use radians (standard for
  /// graphs) unless [angleMode] says otherwise.
  static CompiledGraph compile(GraphSpec spec, Environment env, {AngleMode angleMode = AngleMode.rad}) {
    final funcs = env.compileFunctions();
    ParseScope scope(Set<String> bound) => ParseScope(
          variables: env.variables.keys.toSet(),
          userFunctions: funcs.keys.toSet(),
          boundVariables: bound,
          allowDefinitions: false,
        );
    DoubleFn compileExpr(Node n, List<String> params) => DoubleCompiler(
          parameters: params,
          angleMode: angleMode,
          variables: env.variables,
          functions: funcs,
        ).compile(n);

    switch (spec.type) {
      case GraphType.cartesian:
        final node = _parseRhs(spec.expression, const ['y', 'f(x)'], scope({'x'}));
        final c = compileExpr(node, const ['x']);
        return CompiledGraph._(spec, f: (x) => c([x]));
      case GraphType.polar:
        final node = _parseRhs(spec.expression.replaceAll('theta', 'θ'), const ['r'], scope({'θ'}));
        final c = compileExpr(node, const ['θ']);
        return CompiledGraph._(spec, f: (t) => c([t]));
      case GraphType.parametric:
        final nx = _parseRhs(spec.expression, const ['x'], scope({'t'}));
        final ny = _parseRhs(spec.expressionY, const ['y'], scope({'t'}));
        final cx = compileExpr(nx, const ['t']), cy = compileExpr(ny, const ['t']);
        return CompiledGraph._(spec, fx: (t) => cx([t]), fy: (t) => cy([t]));
      case GraphType.implicit:
        final node = Parser.parse(spec.expression, scope: scope({'x', 'y'}));
        final Node diff = node is EquationNode ? BinaryNode(BinaryOp.sub, node.left, node.right) : node;
        final c = compileExpr(diff, const ['x', 'y']);
        return CompiledGraph._(spec, implicitFn: (x, y) => c([x, y]));
    }
  }

  /// Accepts `rhs`, `y = rhs` or `f(x) = rhs`.
  static Node _parseRhs(String text, List<String> lhsNames, ParseScope scope) {
    final src = text.trim();
    final eq = src.indexOf('=');
    if (eq >= 0) {
      final lhs = src.substring(0, eq).replaceAll(' ', '');
      final rhs = src.substring(eq + 1);
      final isLhsOk = lhsNames.contains(lhs) || RegExp(r'^[A-Za-z]\w*\([A-Za-zθ]\)$').hasMatch(lhs);
      if (!isLhsOk) {
        throw const MathError(MathErrorCode.invalidExpression,
            {'detail': 'use the implicit graph type for equations in x and y'});
      }
      return Parser.parseExpression(rhs, scope: scope);
    }
    return Parser.parseExpression(src, scope: scope);
  }

  /// Detects the most likely graph type of free-form input.
  static GraphType detectType(String input) {
    final s = input.replaceAll(' ', '');
    if (s.startsWith('r=') || s.contains('θ') || s.contains('theta')) return GraphType.polar;
    if (s.startsWith('y=') || RegExp(r'^[A-Za-z]\w*\(x\)=').hasMatch(s)) return GraphType.cartesian;
    if (s.contains('=') || RegExp(r'(^|[^a-z])y($|[^a-z])').hasMatch(s)) return GraphType.implicit;
    return GraphType.cartesian;
  }
}

// ------------------------------------------------------------------ sampling

class _PolyBuffer {
  final polylines = <Float64List>[];
  var _current = <double>[];

  void add(double x, double y) => _current
    ..add(x)
    ..add(y);

  void flush() {
    if (_current.length >= 4) polylines.add(Float64List.fromList(_current));
    _current = <double>[];
  }
}

class GraphSampler {
  GraphSampler(this.vp, {this.pixelTolerance = 0.4, this.maxDepth = 9});

  final Viewport vp;
  final double pixelTolerance;
  final int maxDepth;

  CurveSamples sample(CompiledGraph g) => switch (g.spec.type) {
        GraphType.cartesian => _cartesian(g.f!),
        GraphType.polar => _parametric((t) => g.f!(t) * math.cos(t), (t) => g.f!(t) * math.sin(t),
            g.spec.tMin, g.spec.tMax),
        GraphType.parametric => _parametric(g.fx!, g.fy!, g.spec.tMin, g.spec.tMax),
        GraphType.implicit => _implicit(g.implicitFn!),
      };

  // Cartesian curves ---------------------------------------------------------

  CurveSamples _cartesian(RealFn f) {
    final buf = _PolyBuffer();
    final n = math.max(64, (vp.widthPx / 3).ceil());
    final dx = vp.xRange / n;
    // Evaluate slightly beyond the edges so lines reach the border.
    var x0 = vp.xMin - dx;
    var y0 = _safe(f, x0);
    if (y0.isFinite) buf.add(x0, y0);
    for (var k = 0; k <= n + 1; k++) {
      final x1 = vp.xMin + k * dx;
      final y1 = _safe(f, x1);
      _segment(f, x0, y0, x1, y1, 0, buf);
      x0 = x1;
      y0 = y1;
    }
    buf.flush();
    return CurveSamples(buf.polylines);
  }

  double _safe(RealFn f, double x) {
    final y = f(x);
    return y.isFinite ? y : double.nan;
  }

  /// Adds the segment (x0,y0]..(x1,y1] to [buf], refining where the curve
  /// bends or breaks.
  void _segment(RealFn f, double x0, double y0, double x1, double y1, int depth, _PolyBuffer buf) {
    final okA = y0.isFinite, okB = y1.isFinite;
    final xm = (x0 + x1) / 2;
    final ym = _safe(f, xm);
    if (!okA && !okB && (!ym.isFinite || depth > 0)) {
      if (!okA && !okB && ym.isFinite && depth == 0) {
        // An isolated defined point inside an undefined region: refine.
      } else {
        buf.flush();
        return;
      }
    }
    if (depth >= maxDepth) {
      if (okA && okB && ym.isFinite && !_isJump(y0, ym, y1)) {
        buf.add(xm, ym);
        buf.add(x1, y1);
      } else if (okB && !okA) {
        buf.flush();
        if (ym.isFinite) buf.add(xm, ym);
        buf.add(x1, y1);
      } else if (okA && !okB) {
        if (ym.isFinite) buf.add(xm, ym);
        buf.flush();
      } else {
        // Jump discontinuity (asymptote / step): break the line.
        buf.flush();
        if (okB) buf.add(x1, y1);
      }
      return;
    }
    if (okA && okB && ym.isFinite) {
      // Screen-space deviation of the midpoint from the chord.
      final chordMid = (y0 + y1) / 2;
      final dev = (ym - chordMid).abs() / vp.yRange * vp.heightPx;
      final visible = _visible(y0) || _visible(y1) || _visible(ym);
      if (dev <= pixelTolerance || (!visible && depth >= 3 && _sameSide(y0, ym, y1))) {
        buf.add(x1, y1);
        return;
      }
    }
    _segment(f, x0, y0, xm, ym, depth + 1, buf);
    _segment(f, xm, ym, x1, y1, depth + 1, buf);
  }

  bool _visible(double y) => y >= vp.yMin - vp.yRange && y <= vp.yMax + vp.yRange;

  bool _sameSide(double a, double b, double c) =>
      (a > vp.yMax && b > vp.yMax && c > vp.yMax) || (a < vp.yMin && b < vp.yMin && c < vp.yMin);

  /// At maximum depth the interval is far below a pixel wide. A continuous
  /// curve splits its change between both halves; a jump (tan x, 1/x,
  /// floor x) concentrates it in one half, or the midpoint is not between
  /// the ends at all.
  bool _isJump(double a, double m, double b) {
    final dy = (b - a).abs() / vp.yRange * vp.heightPx;
    if (dy < 2) return false;
    final between = (m - a) * (b - m) >= 0;
    if (!between) return true;
    final d1 = (m - a).abs(), d2 = (b - m).abs();
    return math.max(d1, d2) > 0.9 * (d1 + d2);
  }

  // Parametric / polar -------------------------------------------------------

  CurveSamples _parametric(RealFn fx, RealFn fy, double tMin, double tMax) {
    if (!(tMax > tMin)) {
      throw const MathError(MathErrorCode.invalidExpression, {'detail': 'the parameter range is empty'});
    }
    final buf = _PolyBuffer();
    (double, double) p(double t) {
      final x = fx(t), y = fy(t);
      return (x.isFinite ? x : double.nan, y.isFinite ? y : double.nan);
    }

    double screenDist((double, double) a, (double, double) b) => math.sqrt(
        math.pow((b.$1 - a.$1) / vp.xRange * vp.widthPx, 2) + math.pow((b.$2 - a.$2) / vp.yRange * vp.heightPx, 2));

    const n = 720;
    final dt = (tMax - tMin) / n;
    var t0 = tMin;
    var p0 = p(t0);
    if (p0.$1.isFinite && p0.$2.isFinite) buf.add(p0.$1, p0.$2);
    var budget = 60000;
    void seg(double ta, (double, double) pa, double tb, (double, double) pb, int depth) {
      final okA = pa.$1.isFinite && pa.$2.isFinite, okB = pb.$1.isFinite && pb.$2.isFinite;
      if (!okB) {
        buf.flush();
        return;
      }
      if (!okA) {
        buf.flush();
        buf.add(pb.$1, pb.$2);
        return;
      }
      final tm = (ta + tb) / 2;
      final pm = p(tm);
      budget--;
      if (depth < maxDepth && budget > 0 && pm.$1.isFinite && pm.$2.isFinite) {
        final ex = ((pm.$1 - (pa.$1 + pb.$1) / 2) / vp.xRange * vp.widthPx).abs();
        final ey = ((pm.$2 - (pa.$2 + pb.$2) / 2) / vp.yRange * vp.heightPx).abs();
        if (ex + ey > pixelTolerance || screenDist(pa, pb) > 8) {
          seg(ta, pa, tm, pm, depth + 1);
          seg(tm, pm, tb, pb, depth + 1);
          return;
        }
      }
      if (depth >= maxDepth && screenDist(pa, pb) > vp.heightPx / 4) buf.flush();
      buf.add(pb.$1, pb.$2);
    }

    for (var k = 1; k <= n; k++) {
      final t1 = tMin + k * dt;
      final p1 = p(t1);
      seg(t0, p0, t1, p1, 0);
      t0 = t1;
      p0 = p1;
    }
    buf.flush();
    return CurveSamples(buf.polylines);
  }

  // Implicit (marching squares) -----------------------------------------------

  CurveSamples _implicit(RealFn2 f) {
    final cols = math.max(40, math.min(260, (vp.widthPx / 4).round()));
    final rows = math.max(40, math.min(260, (cols * vp.heightPx / vp.widthPx).round()));
    final dx = vp.xRange / cols, dy = vp.yRange / rows;
    final grid = Float64List((cols + 1) * (rows + 1));
    for (var j = 0; j <= rows; j++) {
      final y = vp.yMin + j * dy;
      for (var i = 0; i <= cols; i++) {
        final v = f(vp.xMin + i * dx, y);
        grid[j * (cols + 1) + i] = v.isFinite ? v : double.nan;
      }
    }
    final segs = <double>[];
    double g(int i, int j) => grid[j * (cols + 1) + i];
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final v0 = g(i, j), v1 = g(i + 1, j), v2 = g(i + 1, j + 1), v3 = g(i, j + 1);
        if (v0.isNaN || v1.isNaN || v2.isNaN || v3.isNaN) continue;
        final x0 = vp.xMin + i * dx, y0 = vp.yMin + j * dy;
        final pts = <double>[];
        void edge(double a, double b, double ax, double ay, double bx, double by) {
          if ((a < 0) != (b < 0)) {
            final t = a / (a - b);
            pts.addAll([ax + (bx - ax) * t, ay + (by - ay) * t]);
          }
        }

        edge(v0, v1, x0, y0, x0 + dx, y0);
        edge(v1, v2, x0 + dx, y0, x0 + dx, y0 + dy);
        edge(v2, v3, x0 + dx, y0 + dy, x0, y0 + dy);
        edge(v3, v0, x0, y0 + dy, x0, y0);
        if (pts.length == 4) {
          // Reject sign changes across poles (|F| huge everywhere in the cell).
          if (_poleCell(v0, v1, v2, v3)) continue;
          segs.addAll(pts);
        } else if (pts.length == 8) {
          // Saddle: resolve with the centre value.
          final c = f(x0 + dx / 2, y0 + dy / 2);
          if ((c < 0) == (v0 < 0)) {
            segs.addAll(pts);
          } else {
            segs.addAll([pts[0], pts[1], pts[6], pts[7], pts[2], pts[3], pts[4], pts[5]]);
          }
        }
      }
    }
    return CurveSamples([Float64List.fromList(segs)], segmentsOnly: true);
  }

  bool _poleCell(double a, double b, double c, double d) =>
      [a.abs(), b.abs(), c.abs(), d.abs()].reduce(math.min) > 1e6;
}

// ------------------------------------------------------------------ analysis

enum PointKind { root, minimum, maximum, intersection, yIntercept }

class GraphPoint {
  const GraphPoint(this.kind, this.x, this.y);
  final PointKind kind;
  final double x;
  final double y;
}

class TangentLine {
  const TangentLine(this.x0, this.y0, this.slope);
  final double x0, y0, slope;
  double get intercept => y0 - slope * x0;
}

/// Numerical analysis of y = f(x) curves on an interval.
abstract final class GraphAnalysis {
  static const _samples = 2000;

  static double derivative(RealFn f, double x) {
    final h = 1e-4 * math.max(1.0, x.abs());
    double d(double hh) => (f(x + hh) - f(x - hh)) / (2 * hh);
    final d1 = d(h), d2 = d(h / 2);
    return (4 * d2 - d1) / 3;
  }

  static TangentLine tangent(RealFn f, double x) {
    final y = f(x);
    if (!y.isFinite) {
      throw const MathError(MathErrorCode.undefinedResult, {'detail': 'the function is not defined at this point'});
    }
    final m = derivative(f, x);
    if (!m.isFinite) {
      throw const MathError(MathErrorCode.undefinedResult, {'detail': 'the curve has no tangent here'});
    }
    return TangentLine(x, y, m);
  }

  static List<GraphPoint> roots(RealFn f, double a, double b) =>
      _zeros(f, a, b).map((x) => GraphPoint(PointKind.root, x, 0)).toList();

  static List<GraphPoint> intersections(RealFn f, RealFn g, double a, double b) =>
      _zeros((x) => f(x) - g(x), a, b).map((x) => GraphPoint(PointKind.intersection, x, f(x))).toList();

  static GraphPoint? yIntercept(RealFn f) {
    final y = f(0);
    return y.isFinite ? GraphPoint(PointKind.yIntercept, 0, y) : null;
  }

  static List<double> _zeros(RealFn f, double a, double b) {
    final out = <double>[];
    final h = (b - a) / _samples;
    var x0 = a, y0 = f(a);
    for (var k = 1; k <= _samples; k++) {
      final x1 = a + k * h;
      final y1 = f(x1);
      if (y0.isFinite && y1.isFinite) {
        if (y0 == 0) {
          out.add(x0);
        } else if ((y0 < 0) != (y1 < 0) && y1 != 0) {
          // Reject sign changes at poles: a true root has a tiny residual.
          final r = _bisect(f, x0, x1);
          if (r != null) out.add(r);
        } else if (k > 1) {
          final xm = (x0 + x1) / 2;
          final ym = f(xm);
          if (ym.isFinite && ym.abs() < y0.abs() && ym.abs() < y1.abs()) {
            final m = _goldenMin((x) => f(x).abs(), x0, x1);
            if (f(m).abs() < 1e-9 * math.max(1.0, math.max(y0.abs(), y1.abs()))) out.add(m);
          }
        }
      }
      x0 = x1;
      y0 = y1;
    }
    if (y0 == 0) out.add(x0);
    out.sort();
    final dedup = <double>[];
    for (final x in out) {
      if (dedup.isEmpty || (x - dedup.last).abs() > 1e-7 * math.max(1.0, x.abs())) dedup.add(x);
    }
    return dedup;
  }

  static double? _bisect(RealFn f, double a, double b) {
    final fa0 = f(a), fb0 = f(b);
    var fa = fa0;
    for (var k = 0; k < 200; k++) {
      final m = (a + b) / 2;
      if (m == a || m == b) break;
      final fm = f(m);
      if (!fm.isFinite) return null;
      if ((fm < 0) == (fa < 0)) {
        a = m;
        fa = fm;
      } else {
        b = m;
      }
    }
    final x = (a + b) / 2;
    final y = f(x);
    final scale = math.max(1.0, math.max(fa0.abs(), fb0.abs()));
    if (!y.isFinite || y.abs() > 1e-6 * scale) return null;
    return x;
  }

  static double _goldenMin(RealFn f, double a, double b) {
    const gr = 0.6180339887498949;
    var c = b - gr * (b - a), d = a + gr * (b - a);
    var fc = f(c), fd = f(d);
    for (var k = 0; k < 120; k++) {
      if (fc < fd) {
        b = d;
        d = c;
        fd = fc;
        c = b - gr * (b - a);
        fc = f(c);
      } else {
        a = c;
        c = d;
        fc = fd;
        d = a + gr * (b - a);
        fd = f(d);
      }
    }
    return (a + b) / 2;
  }

  /// Local minima and maxima on [a, b].
  static List<GraphPoint> extrema(RealFn f, double a, double b) {
    final out = <GraphPoint>[];
    final h = (b - a) / _samples;
    var y0 = f(a), y1 = f(a + h);
    for (var k = 2; k <= _samples; k++) {
      final x2 = a + k * h;
      final y2 = f(x2);
      if (y0.isFinite && y1.isFinite && y2.isFinite) {
        final isMin = y1 < y0 && y1 <= y2;
        final isMax = y1 > y0 && y1 >= y2;
        if (isMin || isMax) {
          final lo = x2 - 2 * h, hi = x2;
          final x = isMin ? _goldenMin(f, lo, hi) : _goldenMin((t) => -f(t), lo, hi);
          final y = f(x);
          // Ignore spikes at discontinuities (derivative blows up).
          final slope = derivative(f, x).abs();
          if (y.isFinite && slope < 1e3 * math.max(1.0, (y2 - y0).abs() / (2 * h))) {
            out.add(GraphPoint(isMin ? PointKind.minimum : PointKind.maximum, x, y));
          }
        }
      }
      y0 = y1;
      y1 = y2;
    }
    return out;
  }

  /// ∫ f over [a, b] with adaptive Gauss–Kronrod; returns (value, error).
  static (double, double) area(RealFn f, double a, double b) {
    const nodes = [
      0.991455371120812639206854697526329, 0.949107912342758524526189684047851,
      0.864864423359769072789712788640926, 0.741531185599394439863864773280788,
      0.586087235467691130294144845693013, 0.405845151377397166906606412076961,
      0.207784955007898467600689403773245, 0.0,
    ];
    const wk = [
      0.022935322010529224963732008058970, 0.063092092629978553290700663189204,
      0.104790010322250183839876322541518, 0.140653259715525918745189590510238,
      0.169004726639267902826583426598550, 0.190350578064785409913256402421014,
      0.204432940075298892414161999234649, 0.209482141084727828012999174891714,
    ];
    const wg = [
      0.129484966168869693270611432679082, 0.279705391489276667901467771423780,
      0.381830050505118944950369775488975, 0.417959183673469387755102040816327,
    ];
    (double, double) seg(double l, double r) {
      final c = (l + r) / 2, h = (r - l) / 2;
      final fc = f(c);
      var k = fc * wk[7], g = fc * wg[3];
      for (var j = 0; j < 7; j++) {
        final dx = h * nodes[j];
        final s = f(c - dx) + f(c + dx);
        k += wk[j] * s;
        if (j.isOdd) g += wg[j ~/ 2] * s;
      }
      return (k * h, ((k - g) * h).abs());
    }

    final parts = <(double, double, double, double)>[];
    final s0 = seg(a, b);
    parts.add((a, b, s0.$1, s0.$2));
    for (var it = 0; it < 1000; it++) {
      final tot = parts.fold(0.0, (s, p) => s + p.$4);
      final val = parts.fold(0.0, (s, p) => s + p.$3);
      if (tot <= 1e-12 * math.max(1.0, val.abs()) || tot.isNaN) break;
      var w = 0;
      for (var k = 1; k < parts.length; k++) {
        if (parts[k].$4 > parts[w].$4) w = k;
      }
      final (l, r, _, _) = parts.removeAt(w);
      final m = (l + r) / 2;
      final s1 = seg(l, m), s2 = seg(m, r);
      parts.add((l, m, s1.$1, s1.$2));
      parts.add((m, r, s2.$1, s2.$2));
    }
    return (parts.fold(0.0, (s, p) => s + p.$3), parts.fold(0.0, (s, p) => s + p.$4));
  }

  /// Nice axis tick spacing (1, 2, 5 × 10^k) for [range] world units.
  static double niceStep(double range, [int targetTicks = 8]) {
    final raw = range / targetTicks;
    final p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final m = raw / p;
    final nice = m < 1.5 ? 1 : (m < 3.5 ? 2 : (m < 7.5 ? 5 : 10));
    return nice * p;
  }
}
