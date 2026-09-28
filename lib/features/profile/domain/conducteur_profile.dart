import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/json/json_reader.dart';

/// Permis (conducteur routier) ou CACES (conducteur d'engin).
@immutable
class Qualification {
  const Qualification({
    required this.type,
    required this.numero,
    required this.categorie,
    required this.dateExpiration,
    required this.joursRestants,
    required this.niveau,
  });

  factory Qualification.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Qualification');
    return Qualification(
      type: j.reqEnum(
        'type',
        TypeQualification.values,
        TypeQualification.inconnu,
      ),
      numero: j.reqString('numero'),
      categorie: j.optString('categorie'),
      dateExpiration: j.optDate('dateExpiration'),
      joursRestants: j.optInt('joursRestants'),
      niveau: j.reqEnum('niveau', NiveauEcheance.values, NiveauEcheance.inconnu),
    );
  }

  final TypeQualification type;
  final String numero;
  final String? categorie;
  final DateTime? dateExpiration;
  final int? joursRestants;
  final NiveauEcheance niveau;
}

/// `GET /api/moi/profil` et `profil` de `GET /api/moi`.
@immutable
class ConducteurProfile {
  const ConducteurProfile({
    required this.idConducteur,
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.email,
    required this.categorie,
    required this.statut,
    required this.qualification,
  });

  factory ConducteurProfile.fromJson(Object? json) {
    final j = JsonReader.of(json, 'ConducteurProfile');
    return ConducteurProfile(
      idConducteur: j.reqInt('idConducteur'),
      matricule: j.reqString('matricule'),
      nom: j.reqString('nom'),
      prenom: j.reqString('prenom'),
      telephone: j.optString('telephone'),
      email: j.optString('email'),
      categorie: j.reqEnum(
        'categorie',
        CategorieEngin.values,
        CategorieEngin.inconnu,
      ),
      statut: j.reqEnum(
        'statut',
        StatutConducteur.values,
        StatutConducteur.inconnu,
      ),
      qualification: j.optObject('qualification', Qualification.fromJson),
    );
  }

  final int idConducteur;
  final String matricule;
  final String nom;
  final String prenom;
  final String? telephone;
  final String? email;
  final CategorieEngin categorie;
  final StatutConducteur statut;
  final Qualification? qualification;

  String get nomComplet => '$prenom $nom';
}
