import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/json/json_reader.dart';
import '../../../core/utils/app_date_time.dart';

/// Élément de `GET /api/moi/incidents`, réponse 201 de la déclaration.
@immutable
class Incident {
  const Incident({
    required this.idIncident,
    required this.type,
    required this.gravite,
    required this.statut,
    required this.description,
    required this.dateSurvenue,
    required this.idEngin,
    required this.vehicule,
    required this.idMission,
    required this.nombrePhotos,
  });

  factory Incident.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Incident');
    return Incident(
      idIncident: j.reqInt('idIncident'),
      type: j.reqEnum('type', TypeIncident.values, TypeIncident.inconnu),
      gravite: j.reqEnum('gravite', Gravite.values, Gravite.inconnu),
      statut: j.reqEnum(
        'statut',
        StatutIncident.values,
        StatutIncident.inconnu,
      ),
      description: j.reqString('description'),
      dateSurvenue: j.reqDateTime('dateSurvenue'),
      idEngin: j.optInt('idEngin'),
      vehicule: j.optString('vehicule'),
      idMission: j.optInt('idMission'),
      nombrePhotos: j.reqInt('nombrePhotos'),
    );
  }

  static List<Incident> listFromJson(Object? json) =>
      JsonReader.listOf(json, 'Incident[]', Incident.fromJson);

  /// Contraintes du backend (409 / 413).
  static const maxPhotos = 10;
  static const maxPhotoBytes = 5 * 1024 * 1024;

  final int idIncident;
  final TypeIncident type;
  final Gravite gravite;
  final StatutIncident statut;
  final String description;
  final DateTime dateSurvenue;
  final int? idEngin;
  final String? vehicule;
  final int? idMission;
  final int nombrePhotos;

  /// « Cet incident est clôturé : on ne peut plus y ajouter de photo ».
  bool get acceptsPhotos => statut != StatutIncident.cloture;

  Incident withPhotoCount(int count) => Incident(
    idIncident: idIncident,
    type: type,
    gravite: gravite,
    statut: statut,
    description: description,
    dateSurvenue: dateSurvenue,
    idEngin: idEngin,
    vehicule: vehicule,
    idMission: idMission,
    nombrePhotos: count,
  );
}

/// Élément de `GET /api/moi/incidents/{id}/photos`, réponse 201 de l'ajout.
@immutable
class IncidentPhoto {
  const IncidentPhoto({
    required this.idPhoto,
    required this.legende,
    required this.dateAjout,
    required this.url,
  });

  factory IncidentPhoto.fromJson(Object? json) {
    final j = JsonReader.of(json, 'IncidentPhoto');
    return IncidentPhoto(
      idPhoto: j.reqInt('idPhoto'),
      legende: j.optString('legende'),
      dateAjout: j.reqDateTime('dateAjout'),
      url: j.reqString('url'),
    );
  }

  static List<IncidentPhoto> listFromJson(Object? json) =>
      JsonReader.listOf(json, 'IncidentPhoto[]', IncidentPhoto.fromJson);

  final int idPhoto;
  final String? legende;
  final DateTime dateAjout;

  /// Chemin relatif du fichier, ex. `/api/moi/incidents/photos/140/fichier`.
  final String url;
}

/// Corps de `POST /api/moi/incidents`. Les champs `null` sont omis.
@immutable
class CreateIncidentRequest {
  const CreateIncidentRequest({
    required this.type,
    required this.gravite,
    required this.description,
    this.idEngin,
    this.dateSurvenue,
  });

  final TypeIncident type;
  final Gravite gravite;
  final String description;
  final int? idEngin;
  final DateTime? dateSurvenue;

  Map<String, Object?> toJson() => {
    'idEngin': ?idEngin,
    'type': type.apiValue,
    'gravite': gravite.apiValue,
    'description': description.trim(),
    if (dateSurvenue case final date?) 'dateSurvenue': AppDateTime.toApi(date),
  };
}
