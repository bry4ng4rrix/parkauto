import 'package:dio/dio.dart';

import '../auth/session.dart';
import '../auth/token_refresher.dart';
import '../errors/app_exception.dart';
import 'api_endpoints.dart';

/// Ajoute le Bearer, rafraîchit le jeton avant expiration et, sur 401,
/// rafraîchit une seule fois puis rejoue la requête.
///
/// Le rejeu passe par [_retryDio] (sans cet intercepteur) : appeler
/// `fetch` sur le Dio principal depuis `onError` pourrait bloquer la file.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._readSession,
    required this._refresher,
    required this._retryDio,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const retriedKey = 'parkauto.retried';

  final Session? Function() _readSession;
  final TokenRefresher _refresher;
  final Dio _retryDio;
  final DateTime Function() _clock;

  static bool _isSessionEndpoint(RequestOptions options) =>
      options.path.startsWith(ApiEndpoints.authPrefix);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isSessionEndpoint(options)) return handler.next(options);

    var session = _readSession();
    if (session == null) {
      return handler.reject(_failure(options, const SessionExpiredException()));
    }
    if (session.isAccessExpired(_clock())) {
      try {
        session = await _refresher.refresh();
      } on AppException catch (e) {
        return handler.reject(_failure(options, e));
      }
    }
    options.headers['Authorization'] = 'Bearer ${session.jetonAcces}';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        _isSessionEndpoint(options) ||
        options.extra[retriedKey] == true) {
      return handler.next(err);
    }

    final Session session;
    try {
      final current = _readSession();
      final usedToken = _bearerOf(options);
      // Un autre appel a déjà obtenu un nouveau jeton : simple rejeu.
      session = (current != null && current.jetonAcces != usedToken)
          ? current
          : await _refresher.refresh();
    } on AppException catch (e) {
      return handler.next(_failure(options, e, response: err.response));
    }

    final data = options.data;
    final retry = options.copyWith(
      headers: {
        ...options.headers,
        'Authorization': 'Bearer ${session.jetonAcces}',
      },
      extra: {...options.extra, retriedKey: true},
      data: data is FormData ? data.clone() : data,
    );
    try {
      handler.resolve(await _retryDio.fetch<Object?>(retry));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  static String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }

  static DioException _failure(
    RequestOptions options,
    AppException error, {
    Response<dynamic>? response,
  }) => DioException(
    requestOptions: options,
    response: response,
    error: error,
    type: DioExceptionType.unknown,
    message: error.userMessage,
  );
}
