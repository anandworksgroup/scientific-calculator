import 'dart:async';
import 'dart:isolate';

import 'package:math_engine/math_engine.dart';

import 'app_logger.dart';

/// A running engine computation that can be cancelled.
class Computation<T> {
  Computation(this.result, this._cancel);
  final Future<EngineResult<T>> result;
  final void Function() _cancel;
  void cancel() => _cancel();
}

/// Runs math-engine work off the UI thread.
///
/// Simple calculator evaluations run synchronously with a short time
/// budget (so they feel instant); anything slower is retried in a
/// background isolate that can be killed immediately on cancel.
class EngineService {
  const EngineService();

  static const MathEngine engine = DefaultMathEngine();

  /// Synchronous budget before falling back to an isolate.
  static const quickBudget = Duration(milliseconds: 120);

  /// Evaluates calculator input; sync first, isolate if it is slow.
  Computation<Evaluation> evaluate(String input, CalcSettings settings, Environment env) {
    final sw = Stopwatch()..start();
    final quick = engine.evaluate(input, settings, env, budget: Budget(timeLimit: quickBudget));
    if (quick is! Failure<Evaluation> || quick.error.code != MathErrorCode.timeout) {
      AppLogger.timing('evaluate', sw.elapsed);
      return Computation(Future.value(quick), () {});
    }
    final envCopy = env.copy();
    return run(() => engine.evaluate(input, settings, envCopy));
  }

  /// Synchronous evaluation with a strict budget (live preview while typing).
  EngineResult<Evaluation> preview(String input, CalcSettings settings, Environment env) =>
      engine.evaluate(input, settings, env, budget: Budget(timeLimit: const Duration(milliseconds: 40)));

  /// Runs [task] in a background isolate. [task] must only capture
  /// sendable data (strings, numbers, engine values).
  Computation<T> run<T>(EngineResult<T> Function() task) {
    final completer = Completer<EngineResult<T>>();
    final port = ReceivePort();
    Isolate? isolate;
    var cancelled = false;
    final sw = Stopwatch()..start();

    void finish(EngineResult<T> r) {
      if (!completer.isCompleted) completer.complete(r);
      port.close();
    }

    port.listen((msg) {
      if (msg is List && msg.length == 1) {
        AppLogger.timing('isolate task', sw.elapsed);
        finish(msg.first as EngineResult<T>);
      } else {
        finish(const Failure(MathError(MathErrorCode.invalidExpression, {'detail': 'the calculation failed'})));
      }
    });

    Isolate.spawn<(SendPort, EngineResult<T> Function())>(
      _entry,
      (port.sendPort, task),
      onError: port.sendPort,
      errorsAreFatal: true,
    ).then((iso) {
      isolate = iso;
      if (cancelled) iso.kill(priority: Isolate.immediate);
    }).catchError((Object e) {
      // Spawning failed (e.g. unsendable capture): run synchronously.
      AppLogger.error('isolate spawn failed', e);
      if (!cancelled) finish(task());
    });

    return Computation(completer.future, () {
      cancelled = true;
      isolate?.kill(priority: Isolate.immediate);
      finish(Cancelled<T>());
    });
  }

  static void _entry<T>((SendPort, EngineResult<T> Function()) msg) {
    final (port, task) = msg;
    EngineResult<T> r;
    try {
      r = task();
    } catch (e) {
      r = Failure(MathError(MathErrorCode.invalidExpression, {'detail': '$e'}));
    }
    port.send([r]);
  }
}
