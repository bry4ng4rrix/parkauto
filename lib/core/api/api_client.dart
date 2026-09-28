import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../auth/session_controller.dart';
import '../auth/token_refresher.dart';
import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';
import '../logging/app_logger.dart';
import '../network/network_status.dart';
import 'api_log_interceptor.dart';
import 'auth_interceptor.dart';
import 'dio_factory.dart';

typedef JsonParser<T> = T Function(Object? json);

/// Client HTTP authentifié. Point unique de conversion des erreurs Dio
/// en [AppException].
class ApiClient {
  ApiClient(this._dio, {this._onResult});

  final Dio _dio;
  final void Function({required bool reachable})? _onResult;

  Future<T> get<T>(
    String path,
    JsonParser<T> parse, {
    Map<String, Object?>? query,
  }) async => _parse(path, await getRaw(path, query: query), parse);

  /// Corps JSON brut (utilisé pour le cache).
  Future<Object?> getRaw(String path, {Map<String, Object?>? query}) async {
    final response = await _send(
      () => _dio.get<Object?>(path, queryParameters: query),
    );
    return response.data;
  }

  Future<T> post<T>(
    String path,
    JsonParser<T> parse, {
    Object? body,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      () => _dio.post<Object?>(
        path,
        data: body,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      ),
    );
    return _parse(path, response.data, parse);
  }

  /// POST sans corps de réponse attendu (204 No Content).
  Future<void> postNoContent(String path, {Object? body}) async {
    await _send(() => _dio.post<Object?>(path, data: body));
  }

  /// Fichier binaire (photo, pièce jointe).
  Future<Uint8List> getBytes(
    String path, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      () => _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      ),
    );
    final data = response.data;
    if (data == null) throw ContractException(path, 'fichier vide');
    return data is Uint8List ? data : Uint8List.fromList(data);
  }

  Future<Response<R>> _send<R>(Future<Response<R>> Function() call) async {
    try {
      final response = await call();
      _onResult?.call(reachable: true);
      return response;
    } on DioException catch (e) {
      final error = mapDioException(e);
      _onResult?.call(reachable: error is! NetworkException);
      throw error;
    }
  }

  T _parse<T>(String path, Object? data, JsonParser<T> parse) {
    try {
      return parse(data);
    } on ContractException catch (e) {
      AppLogger.error('API', 'Contrat non respecté sur $path : $e');
      rethrow;
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final adapter = ref.watch(httpClientAdapterProvider);
  final dio = createDio(config, adapter: adapter);
  // Rejeu après rafraîchissement : mêmes options et même adaptateur, sans
  // l'intercepteur d'authentification.
  final retryDio = dio.clone(
    interceptors: Interceptors()..add(ApiLogInterceptor()),
  );
  dio.interceptors
    ..add(
      AuthInterceptor(
        readSession: () => ref.read(sessionControllerProvider).session,
        refresher: ref.read(tokenRefresherProvider),
        retryDio: retryDio,
      ),
    )
    ..add(ApiLogInterceptor());
  ref.onDispose(() {
    dio.close();
    retryDio.close();
  });
  return ApiClient(
    dio,
    onResult: ({required reachable}) => ref
        .read(serverReachableProvider.notifier)
        .report(reachable: reachable),
  );
});
