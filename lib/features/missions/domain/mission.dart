import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/json/json_reader.dart';

/// Élément de `GET /api/moi/missions`, réponse de `demarrer` / `terminer`.
@immutable
class Mission {
  const Mission({
    required this.idMission,
    required this.motif,
    required this.statut,
    required this.dateDebutPrevue,
    required this.dateFinPrevue,
    required this.dateDebutReelle,
    required this.dateFinReelle,
    required this.kilometrageDepart,
    required this.kilometrageRetour,
    required this.idEngin,
    required this.vehicule,
  });

  factory Mission.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Mission');
    return Mission(
      idMission: j.reqInt('idMission'),
      motif: j.reqString('motif'),
      statut: j.reqEnum('statut', StatutMission.values, StatutMission.inconnu),
      dateDebutPrevue: j.reqDateTime('dateDebutPrevue'),
      dateFinPrevue: j.reqDateTime('dateFinPrevue'),
      dateDebutReelle: j.optDateTime('dateDebutReelle'),
      dateFinReelle: j.optDateTime('dateFinReelle'),
      kilometrageDepart: j.optDouble('kilometrageDepart'),
      kilometrageRetour: j.optDouble('kilometrageRetour'),
      idEngin: j.reqInt('idEngin'),
      vehicule: j.reqString('vehicule'),
    );
  }

  static List<Mission> listFromJson(Object? json) =>
      JsonReader.listOf(json, 'Mission[]', Mission.fromJson);

  final int idMission;
  final String motif;
  final StatutMission statut;
  final DateTime dateDebutPrevue;
  final DateTime dateFinPrevue;
  final DateTime? dateDebutReelle;
  final DateTime? dateFinReelle;
  final double? kilometrageDepart;
  final double? kilometrageRetour;
  final int idEngin;

  /// Libellé du véhicule, ex. « 1234 TAB — Toyota Hilux ».
  final String vehicule;

  bool get canStart => statut == StatutMission.planifiee;

  bool get canFinish => statut == StatutMission.enCours;

  /// Distance parcourue, si départ et retour sont connus.
  double? get distance {
    final (depart, retour) = (kilometrageDepart, kilometrageRetour);
    if (depart == null || retour == null) return null;
    return retour - depart;
  }
}
