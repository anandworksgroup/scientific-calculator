import 'package:flutter/foundation.dart';

/// Development logging only. Release builds log nothing, so calculation
/// contents never leave the device through logs (§105).
abstract final class AppLogger {
  static void timing(String what, Duration d) {
    if (kDebugMode) debugPrint('[timing] $what: ${d.inMicroseconds / 1000} ms');
  }

  static void error(String what, Object error, [StackTrace? st]) {
    if (kDebugMode) debugPrint('[error] $what: $error${st == null ? '' : '\n$st'}');
  }

  static void info(String message) {
    if (kDebugMode) debugPrint('[info] $message');
  }
}
