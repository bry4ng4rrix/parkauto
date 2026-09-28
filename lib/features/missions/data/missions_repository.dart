import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/state/cached_resource.dart';
import '../domain/mission.dart';

/// `GET /api/moi/missions`.
final missionsQuery = CachedQuery<List<Mission>>(
  key: 'missions',
  fetch: (api) => api.getRaw(ApiEndpoints.missions),
  parse: Mission.listFromJson,
);

final missionsProvider =
    AsyncNotifierProvider<MissionsNotifier, Cached<List<Mission>>>(
      MissionsNotifier.new,
    );

class MissionsNotifier extends CachedResourceNotifier<List<Mission>> {
  @override
  CachedQuery<List<Mission>> get query => missionsQuery;

  /// Remplace une mission par la version renvoyée par le serveur.
  void replace(Mission mission) => mutate(
    (missions) => [
      for (final m in missions) m.idMission == mission.idMission ? mission : m,
    ],
  );
}

class MissionsRepository {
  MissionsRepository(this._api);

  final ApiClient _api;

  /// `POST /api/moi/missions/{idMission}/demarrer`.
  Future<Mission> demarrer(int idMission, double kilometrage) => _api.post(
    ApiEndpoints.demarrerMission(idMission),
    Mission.fromJson,
    body: {'kilometrage': kilometrage},
  );

  /// `POST /api/moi/missions/{idMission}/terminer`.
  Future<Mission> terminer(int idMission, double kilometrage) => _api.post(
    ApiEndpoints.terminerMission(idMission),
    Mission.fromJson,
    body: {'kilometrage': kilometrage},
  );
}

final missionsRepositoryProvider = Provider<MissionsRepository>(
  (ref) => MissionsRepository(ref.watch(apiClientProvider)),
);
