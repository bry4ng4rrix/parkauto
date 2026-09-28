import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/state/cached_resource.dart';
import '../domain/conducteur_profile.dart';

/// `GET /api/moi/profil`.
final profileQuery = CachedQuery<ConducteurProfile>(
  key: 'profil',
  fetch: (api) => api.getRaw(ApiEndpoints.profil),
  parse: ConducteurProfile.fromJson,
);

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Cached<ConducteurProfile>>(
      ProfileNotifier.new,
    );

class ProfileNotifier extends CachedResourceNotifier<ConducteurProfile> {
  @override
  CachedQuery<ConducteurProfile> get query => profileQuery;
}
