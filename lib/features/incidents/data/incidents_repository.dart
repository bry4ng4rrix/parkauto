import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/state/cached_resource.dart';
import '../../../core/utils/file_names.dart';
import '../domain/incident.dart';

/// `GET /api/moi/incidents`.
final incidentsQuery = CachedQuery<List<Incident>>(
  key: 'incidents',
  fetch: (api) => api.getRaw(ApiEndpoints.incidents),
  parse: Incident.listFromJson,
);

final incidentsProvider =
    AsyncNotifierProvider<IncidentsNotifier, Cached<List<Incident>>>(
      IncidentsNotifier.new,
    );

class IncidentsNotifier extends CachedResourceNotifier<List<Incident>> {
  @override
  CachedQuery<List<Incident>> get query => incidentsQuery;

  void prepend(Incident incident) =>
      mutate((incidents) => [incident, ...incidents]);

  void updatePhotoCount(int idIncident, int count) => mutate(
    (incidents) => [
      for (final i in incidents)
        i.idIncident == idIncident ? i.withPhotoCount(count) : i,
    ],
  );
}

/// `GET /api/moi/incidents/{idIncident}/photos`.
final incidentPhotosProvider = FutureProvider.autoDispose
    .family<List<IncidentPhoto>, int>(
      (ref, idIncident) =>
          ref.watch(incidentsRepositoryProvider).photos(idIncident),
    );

class IncidentsRepository {
  IncidentsRepository(this._api);

  final ApiClient _api;

  /// `POST /api/moi/incidents` → 201.
  Future<Incident> declarer(CreateIncidentRequest request) => _api.post(
    ApiEndpoints.incidents,
    Incident.fromJson,
    body: request.toJson(),
  );

  Future<List<IncidentPhoto>> photos(int idIncident) => _api.get(
    ApiEndpoints.incidentPhotos(idIncident),
    IncidentPhoto.listFromJson,
  );

  /// `POST /api/moi/incidents/{idIncident}/photos` (multipart `fichier`,
  /// `legende`) → 201.
  Future<IncidentPhoto> ajouterPhoto(
    int idIncident, {
    required String path,
    String? legende,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final caption = legende?.trim() ?? '';
    final form = FormData.fromMap({
      'fichier': await MultipartFile.fromFile(path, filename: fileNameOf(path)),
      if (caption.isNotEmpty) 'legende': caption,
    });
    return _api.post(
      ApiEndpoints.incidentPhotos(idIncident),
      IncidentPhoto.fromJson,
      body: form,
      onSendProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}

final incidentsRepositoryProvider = Provider<IncidentsRepository>(
  (ref) => IncidentsRepository(ref.watch(apiClientProvider)),
);
