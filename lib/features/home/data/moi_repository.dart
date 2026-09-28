import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/state/cached_resource.dart';
import '../domain/moi_response.dart';

/// `GET /api/moi` — tableau de bord du conducteur.
final moiQuery = CachedQuery<MoiResponse>(
  key: 'moi',
  fetch: (api) => api.getRaw(ApiEndpoints.moi),
  parse: MoiResponse.fromJson,
);

final moiProvider = AsyncNotifierProvider<MoiNotifier, Cached<MoiResponse>>(
  MoiNotifier.new,
);

class MoiNotifier extends CachedResourceNotifier<MoiResponse> {
  @override
  CachedQuery<MoiResponse> get query => moiQuery;
}
