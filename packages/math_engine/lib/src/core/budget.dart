import 'errors.dart';

/// Cooperative computation limits.
///
/// Long-running loops call [tick]; once the deadline passes or the
/// operation is cancelled a [MathError] is thrown and turned into a
/// structured result by [guard]. This bounds evaluation time, iteration
/// counts and recursion depth so malformed or pathological input can
/// never hang the app.
class Budget {
  Budget({Duration? timeLimit, this.maxDepth = 400})
      : _deadline = timeLimit == null ? null : DateTime.now().add(timeLimit);

  /// A budget without a time limit (still enforces depth and cancellation).
  factory Budget.unlimited() => Budget();

  final DateTime? _deadline;
  final int maxDepth;
  bool _cancelled = false;
  int _ticks = 0;
  int _depth = 0;

  void cancel() => _cancelled = true;
  bool get isCancelled => _cancelled;

  /// Call periodically from loops. Checking the clock is relatively costly,
  /// so it is only done every 256 ticks.
  void tick([int weight = 1]) {
    _ticks += weight;
    if (_cancelled) throw const MathError(MathErrorCode.cancelled);
    if (_deadline != null && (_ticks & 0xff) < weight) {
      if (DateTime.now().isAfter(_deadline)) {
        throw const MathError(MathErrorCode.timeout);
      }
    }
  }

  /// Checks the deadline immediately (for coarse-grained, expensive steps).
  void check() {
    if (_cancelled) throw const MathError(MathErrorCode.cancelled);
    final d = _deadline;
    if (d != null && DateTime.now().isAfter(d)) {
      throw const MathError(MathErrorCode.timeout);
    }
  }

  T nest<T>(T Function() body) {
    if (++_depth > maxDepth) {
      _depth--;
      throw const MathError(MathErrorCode.recursionLimit);
    }
    try {
      return body();
    } finally {
      _depth--;
    }
  }
}
