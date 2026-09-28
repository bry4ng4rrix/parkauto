import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'redaction.dart';

/// Logger de développement : silencieux en release, masque toujours les secrets.
abstract final class AppLogger {
  static void debug(String tag, String message) {
    if (!kDebugMode) return;
    developer.log(Redactor.redactText(message), name: 'ParkAuto.$tag');
  }

  static void warning(String tag, String message, [Object? error]) {
    if (!kDebugMode) return;
    final details = error == null ? '' : ' — ${_describe(error)}';
    developer.log(
      Redactor.redactText('$message$details'),
      name: 'ParkAuto.$tag',
      level: 900,
    );
  }

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!kDebugMode) return;
    developer.log(
      Redactor.redactText(message),
      name: 'ParkAuto.$tag',
      level: 1000,
      error: error == null ? null : Redactor.redactText(_describe(error)),
      stackTrace: stackTrace,
    );
  }

  static String _describe(Object error) => Redactor.redactText('$error');
}
