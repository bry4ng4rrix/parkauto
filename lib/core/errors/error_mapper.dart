import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'api_error.dart';
import 'app_exception.dart';

/// Convertit une [DioException] en [AppException]. Seul `ApiClient` et les
/// clients d'authentification l'utilisent.
AppException mapDioException(DioException exception) {
  final inner = exception.error;
  if (inner is AppException) return inner;

  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkException(NetworkFailure.timeout);
    case DioExceptionType.connectionError:
      return const NetworkException(NetworkFailure.offline);
    case DioExceptionType.cancel:
      return const CancelledException();
    case DioExceptionType.badResponse:
      return mapErrorResponse(exception.response);
    case DioExceptionType.badCertificate:
      return UnexpectedException(exception.message);
    case DioExceptionType.unknown:
      if (inner is SocketException ||
          inner is HttpException ||
          inner is HandshakeException) {
        return const NetworkException(NetworkFailure.offline);
      }
      if (exception.response != null) {
        return mapErrorResponse(exception.response);
      }
      return UnexpectedException(inner ?? exception.message);
  }
}

/// Réponse HTTP en erreur : [ApiException] si le corps suit le contrat.
AppException mapErrorResponse(Response<Object?>? response) {
  final status = response?.statusCode ?? 0;
  final apiError = ApiError.tryParse(decodeBody(response?.data));
  if (apiError != null) return ApiException(apiError, status);
  return HttpStatusException(status);
}

/// Les réponses binaires (`ResponseType.bytes`) portent aussi des erreurs
/// JSON : on les décode avant analyse.
Object? decodeBody(Object? data) {
  if (data is List<int>) {
    try {
      return jsonDecode(utf8.decode(data));
    } on FormatException {
      return null;
    }
  }
  if (data is String && data.isNotEmpty) {
    try {
      return jsonDecode(data);
    } on FormatException {
      return null;
    }
  }
  return data;
}
