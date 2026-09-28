import 'package:flutter/foundation.dart';

import '../../../core/json/json_reader.dart';
import '../../missions/domain/mission.dart';
import '../../profile/domain/conducteur_profile.dart';
import '../../vehicle/domain/vehicule.dart';

/// Réponse 200 de `GET /api/moi` (accueil).
@immutable
class MoiResponse {
  const MoiResponse({
    required this.profil,
    required this.vehicule,
    required this.missionEnCours,
    required this.prochainesMissions,
    required this.messagesNonLus,
    required this.alertesVehicule,
  });

  factory MoiResponse.fromJson(Object? json) {
    final j = JsonReader.of(json, 'MoiResponse');
    return MoiResponse(
      profil: j.reqObject('profil', ConducteurProfile.fromJson),
      vehicule: j.optObject('vehicule', VehiculeSummary.fromJson),
      missionEnCours: j.optObject('missionEnCours', Mission.fromJson),
      prochainesMissions: j.list('prochainesMissions', Mission.fromJson),
      messagesNonLus: j.reqInt('messagesNonLus'),
      alertesVehicule: j.reqInt('alertesVehicule'),
    );
  }

  final ConducteurProfile profil;
  final VehiculeSummary? vehicule;
  final Mission? missionEnCours;
  final List<Mission> prochainesMissions;
  final int messagesNonLus;
  final int alertesVehicule;
}
