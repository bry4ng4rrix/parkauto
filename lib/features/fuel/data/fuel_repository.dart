import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/state/cached_resource.dart';
import '../domain/fuel_entry.dart';

/// `GET /api/moi/pleins`.
final fuelQuery = CachedQuery<List<FuelEntry>>(
  key: 'pleins',
  fetch: (api) => api.getRaw(ApiEndpoints.pleins),
  parse: FuelEntry.listFromJson,
);

final fuelEntriesProvider =
    AsyncNotifierProvider<FuelEntriesNotifier, Cached<List<FuelEntry>>>(
      FuelEntriesNotifier.new,
    );

class FuelEntriesNotifier extends CachedResourceNotifier<List<FuelEntry>> {
  @override
  CachedQuery<List<FuelEntry>> get query => fuelQuery;

  void prepend(FuelEntry entry) => mutate((entries) => [entry, ...entries]);
}

class FuelRepository {
  FuelRepository(this._api);

  final ApiClient _api;

  /// `POST /api/moi/pleins` → 201.
  Future<FuelEntry> declarer(CreateFuelRequest request) => _api.post(
    ApiEndpoints.pleins,
    FuelEntry.fromJson,
    body: request.toJson(),
  );
}

final fuelRepositoryProvider = Provider<FuelRepository>(
  (ref) => FuelRepository(ref.watch(apiClientProvider)),
);
