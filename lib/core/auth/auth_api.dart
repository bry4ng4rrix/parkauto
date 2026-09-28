import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../api/api_endpoints.dart';
import '../api/api_log_interceptor.dart';
import '../api/dio_factory.dart';
import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';
import 'auth_response.dart';

/// Endpoints de session : client sans Bearer ni rafraîchissement automatique.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResponse> connexion({
    required String email,
    required String motDePasse,
    required String appareil,
  }) => _authenticate(ApiEndpoints.connexion, {
    'email': email,
    'motDePasse': motDePasse,
    'appareil': appareil,
  });

  Future<AuthResponse> rafraichir(String jetonRafraichissement) =>
      _authenticate(ApiEndpoints.rafraichir, {
        'jetonRafraichissement': jetonRafraichissement,
      });

  /// Réponse attendue : 204 No Content.
  Future<void> deconnexion(String jetonRafraichissement) async {
    try {
      await _dio.post<Object?>(
        ApiEndpoints.deconnexion,
        data: {'jetonRafraichissement': jetonRafraichissement},
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<AuthResponse> _authenticate(
    String path,
    Map<String, Object?> body,
  ) async {
    final Response<Object?> response;
    try {
      response = await _dio.post<Object?>(path, data: body);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
    return AuthResponse.fromJson(response.data);
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = createDio(
    ref.watch(appConfigProvider),
    adapter: ref.watch(httpClientAdapterProvider),
  )..interceptors.add(ApiLogInterceptor());
  ref.onDispose(dio.close);
  return AuthApi(dio);
});

/// Statuts qui signifient que le jeton de rafraîchissement est refusé.
bool isRefreshRejected(AppException error) => switch (error) {
  ApiException(:final statusCode) || HttpStatusException(:final statusCode) =>
    const {400, 401, 403}.contains(statusCode),
  SessionExpiredException() => true,
  _ => false,
};
