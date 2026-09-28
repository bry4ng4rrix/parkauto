import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/state/cached_resource.dart';
import '../domain/vehicule.dart';

/// `GET /api/moi/vehicule`. Le 404 « aucun véhicule » est une donnée,
/// pas une erreur.
final vehicleQuery = CachedQuery<VehicleState>(
  key: 'vehicule',
  fetch: (api) async {
    try {
      return await api.getRaw(ApiEndpoints.vehicule);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  },
  parse: (json) => json == null
      ? const NoVehicle()
      : VehicleAssigned(VehiculeDetails.fromJson(json)),
);

final vehicleProvider =
    AsyncNotifierProvider<VehicleNotifier, Cached<VehicleState>>(
      VehicleNotifier.new,
    );

class VehicleNotifier extends CachedResourceNotifier<VehicleState> {
  @override
  CachedQuery<VehicleState> get query => vehicleQuery;
}
