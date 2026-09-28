import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/json/json_reader.dart';
import '../../../core/utils/app_date_time.dart';

/// Élément de `GET /api/moi/pleins`, réponse 201 de `POST /api/moi/pleins`.
@immutable
class FuelEntry {
  const FuelEntry({
    required this.idCarburant,
    required this.dateHeure,
    required this.kilometrageAuPlein,
    required this.quantiteLitres,
    required this.prixUnitaire,
    required this.montantTotal,
    required this.station,
    required this.typeApprovisionnement,
    required this.idEngin,
    required this.vehicule,
  });

  factory FuelEntry.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Plein');
    return FuelEntry(
      idCarburant: j.reqInt('idCarburant'),
      dateHeure: j.reqDateTime('dateHeure'),
      kilometrageAuPlein: j.reqDouble('kilometrageAuPlein'),
      quantiteLitres: j.reqDouble('quantiteLitres'),
      prixUnitaire: j.reqDouble('prixUnitaire'),
      montantTotal: j.reqDouble('montantTotal'),
      station: j.optString('station'),
      // Absent sur le backend de dev actuel : nullable.
      typeApprovisionnement: j.optEnum(
        'typeApprovisionnement',
        TypeApprovisionnement.values,
        TypeApprovisionnement.inconnu,
      ),
      idEngin: j.reqInt('idEngin'),
      vehicule: j.reqString('vehicule'),
    );
  }

  static List<FuelEntry> listFromJson(Object? json) =>
      JsonReader.listOf(json, 'Plein[]', FuelEntry.fromJson);

  final int idCarburant;
  final DateTime dateHeure;
  final double kilometrageAuPlein;
  final double quantiteLitres;
  final double prixUnitaire;
  final double montantTotal;
  final String? station;
  final TypeApprovisionnement? typeApprovisionnement;
  final int idEngin;
  final String vehicule;
}

/// Corps de `POST /api/moi/pleins`. Les champs `null` sont omis.
@immutable
class CreateFuelRequest {
  const CreateFuelRequest({
    required this.typeApprovisionnement,
    required this.kilometrageAuPlein,
    required this.quantiteLitres,
    required this.prixUnitaire,
    this.station,
    this.idEngin,
    this.dateHeure,
  });

  final TypeApprovisionnement typeApprovisionnement;
  final double kilometrageAuPlein;
  final double quantiteLitres;
  final double prixUnitaire;
  final String? station;
  final int? idEngin;
  final DateTime? dateHeure;

  Map<String, Object?> toJson() => {
    'idEngin': ?idEngin,
    if (dateHeure case final date?) 'dateHeure': AppDateTime.toApi(date),
    'typeApprovisionnement': typeApprovisionnement.apiValue,
    'kilometrageAuPlein': kilometrageAuPlein,
    'quantiteLitres': quantiteLitres,
    'prixUnitaire': prixUnitaire,
    if (station case final name? when name.trim().isNotEmpty)
      'station': name.trim(),
  };
}
