import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/json/json_reader.dart';

/// `vehicule` de `GET /api/moi` et de `GET /api/moi/vehicule`.
@immutable
class VehiculeSummary {
  const VehiculeSummary({
    required this.idEngin,
    required this.identifiant,
    required this.libelle,
    required this.marque,
    required this.modele,
    required this.categorie,
    required this.statut,
    required this.kilometrage,
    required this.compteurHeures,
    required this.source,
  });

  factory VehiculeSummary.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Vehicule');
    return VehiculeSummary(
      idEngin: j.reqInt('idEngin'),
      identifiant: j.reqString('identifiant'),
      libelle: j.reqString('libelle'),
      marque: j.optString('marque'),
      modele: j.optString('modele'),
      categorie: j.reqEnum(
        'categorie',
        CategorieEngin.values,
        CategorieEngin.inconnu,
      ),
      statut: j.reqEnum('statut', StatutEngin.values, StatutEngin.inconnu),
      kilometrage: j.optDouble('kilometrage'),
      compteurHeures: j.optDouble('compteurHeures'),
      source: j.reqEnum('source', SourceVehicule.values, SourceVehicule.inconnu),
    );
  }

  final int idEngin;
  final String identifiant;
  final String libelle;
  final String? marque;
  final String? modele;
  final CategorieEngin categorie;
  final StatutEngin statut;
  final double? kilometrage;
  final double? compteurHeures;
  final SourceVehicule source;

  bool get isEngin => categorie == CategorieEngin.enginChantier;

  String? get marqueModele {
    final parts = [marque, modele].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}

@immutable
class VehiculeDocument {
  const VehiculeDocument({
    required this.type,
    required this.numeroReference,
    required this.dateExpiration,
    required this.joursRestants,
    required this.niveau,
  });

  factory VehiculeDocument.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Document');
    return VehiculeDocument(
      type: j.reqEnum('type', TypeDocument.values, TypeDocument.inconnu),
      numeroReference: j.optString('numeroReference'),
      dateExpiration: j.optDate('dateExpiration'),
      joursRestants: j.optInt('joursRestants'),
      niveau: j.reqEnum('niveau', NiveauEcheance.values, NiveauEcheance.inconnu),
    );
  }

  final TypeDocument type;
  final String? numeroReference;
  final DateTime? dateExpiration;
  final int? joursRestants;
  final NiveauEcheance niveau;
}

@immutable
class VehiculeAlert {
  const VehiculeAlert({
    required this.type,
    required this.priorite,
    required this.description,
    required this.nombreOccurrences,
    required this.premiereOccurrence,
    required this.derniereOccurrence,
  });

  factory VehiculeAlert.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Alerte');
    return VehiculeAlert(
      type: j.reqEnum('type', TypeAlerte.values, TypeAlerte.inconnu),
      priorite: j.reqEnum('priorite', Gravite.values, Gravite.inconnu),
      description: j.reqString('description'),
      nombreOccurrences: j.reqInt('nombreOccurrences'),
      premiereOccurrence: j.reqDateTime('premiereOccurrence'),
      derniereOccurrence: j.reqDateTime('derniereOccurrence'),
    );
  }

  final TypeAlerte type;
  final Gravite priorite;
  final String description;
  final int nombreOccurrences;
  final DateTime premiereOccurrence;
  final DateTime derniereOccurrence;
}

@immutable
class DernierPlein {
  const DernierPlein({
    required this.dateHeure,
    required this.kilometrageAuPlein,
    required this.quantiteLitres,
    required this.typeApprovisionnement,
  });

  factory DernierPlein.fromJson(Object? json) {
    final j = JsonReader.of(json, 'DernierPlein');
    return DernierPlein(
      dateHeure: j.reqDateTime('dateHeure'),
      kilometrageAuPlein: j.reqDouble('kilometrageAuPlein'),
      quantiteLitres: j.reqDouble('quantiteLitres'),
      typeApprovisionnement: j.optEnum(
        'typeApprovisionnement',
        TypeApprovisionnement.values,
        TypeApprovisionnement.inconnu,
      ),
    );
  }

  final DateTime dateHeure;
  final double kilometrageAuPlein;
  final double quantiteLitres;
  final TypeApprovisionnement? typeApprovisionnement;
}

/// Réponse 200 de `GET /api/moi/vehicule`.
@immutable
class VehiculeDetails {
  const VehiculeDetails({
    required this.vehicule,
    required this.energie,
    required this.capaciteReservoirLitres,
    required this.idMissionEnCours,
    required this.documents,
    required this.alertes,
    required this.dernierPlein,
  });

  factory VehiculeDetails.fromJson(Object? json) {
    final j = JsonReader.of(json, 'VehiculeDetails');
    return VehiculeDetails(
      vehicule: j.reqObject('vehicule', VehiculeSummary.fromJson),
      energie: j.optEnum('energie', Energie.values, Energie.inconnu),
      capaciteReservoirLitres: j.optDouble('capaciteReservoirLitres'),
      idMissionEnCours: j.optInt('idMissionEnCours'),
      documents: j.list('documents', VehiculeDocument.fromJson),
      alertes: j.list('alertes', VehiculeAlert.fromJson),
      dernierPlein: j.optObject('dernierPlein', DernierPlein.fromJson),
    );
  }

  final VehiculeSummary vehicule;
  final Energie? energie;
  final double? capaciteReservoirLitres;
  final int? idMissionEnCours;
  final List<VehiculeDocument> documents;
  final List<VehiculeAlert> alertes;
  final DernierPlein? dernierPlein;
}

/// Véhicule affecté, ou aucun (404 « Aucun véhicule ne vous est affecté »).
sealed class VehicleState {
  const VehicleState();
}

final class VehicleAssigned extends VehicleState {
  const VehicleAssigned(this.details);

  final VehiculeDetails details;
}

final class NoVehicle extends VehicleState {
  const NoVehicle();

  /// Message du contrat (404).
  static const message = 'Aucun véhicule ne vous est affecté actuellement';
}
