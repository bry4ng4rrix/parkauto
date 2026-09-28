import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';
import '../logging/redaction.dart';

/// Trace les requêtes en debug (méthode, chemin, statut, durée, corps
/// tronqué) sans jamais écrire de secret.
class ApiLogInterceptor extends Interceptor {
  static const _startKey = 'parkauto.startedAt';
  static const _maxBody = 1500;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra[_startKey] = DateTime.now();
      AppLogger.debug(
        'API',
        '→ ${options.method} ${_target(options)}${_body(options.data)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      final options = response.requestOptions;
      AppLogger.debug(
        'API',
        '← ${response.statusCode} ${options.method} ${_target(options)}'
            '${_elapsed(options)}${_body(response.data)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final options = err.requestOptions;
      final status = err.response?.statusCode ?? err.type.name;
      AppLogger.warning(
        'API',
        '✕ $status ${options.method} ${_target(options)}'
            '${_elapsed(options)}${_body(err.response?.data)}',
      );
    }
    handler.next(err);
  }

  static String _target(RequestOptions options) =>
      Redactor.redactUrl(options.uri.toString());

  static String _elapsed(RequestOptions options) {
    final start = options.extra[_startKey];
    if (start is! DateTime) return '';
    return ' (${DateTime.now().difference(start).inMilliseconds} ms)';
  }

  static String _body(Object? data) {
    if (data == null) return '';
    if (data is List<int>) return ' <${data.length} octets>';
    if (data is FormData) {
      final fields = [
        for (final f in data.fields) f.key,
        for (final f in data.files) '${f.key}(fichier)',
      ];
      return ' multipart[${fields.join(', ')}]';
    }
    String text;
    try {
      text = jsonEncode(Redactor.redact(data));
    } on Object {
      text = Redactor.redactText('$data');
    }
    if (text.length > _maxBody) text = '${text.substring(0, _maxBody)}…';
    return '\n$text';
  }
}
