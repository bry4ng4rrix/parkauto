import 'package:flutter/foundation.dart';

import '../json/json_reader.dart';

/// Réponse 200 de `POST /api/auth/mobile/connexion` et `/rafraichir`.
@immutable
class AuthResponse {
  const AuthResponse({
    required this.jetonAcces,
    required this.typeJeton,
    required this.expireDans,
    required this.jetonRafraichissement,
    required this.expirationRafraichissement,
    required this.role,
    required this.idConducteur,
    required this.nomComplet,
  });

  factory AuthResponse.fromJson(Object? json) {
    final j = JsonReader.of(json, 'AuthResponse');
    return AuthResponse(
      jetonAcces: j.reqString('jetonAcces'),
      typeJeton: j.reqString('typeJeton'),
      expireDans: j.reqInt('expireDans'),
      jetonRafraichissement: j.reqString('jetonRafraichissement'),
      expirationRafraichissement: j.reqDateTime('expirationRafraichissement'),
      role: j.reqString('role'),
      idConducteur: j.reqInt('idConducteur'),
      nomComplet: j.reqString('nomComplet'),
    );
  }

  final String jetonAcces;
  final String typeJeton;

  /// Durée de validité du jeton d'accès, en secondes.
  final int expireDans;
  final String jetonRafraichissement;
  final DateTime expirationRafraichissement;
  final String role;
  final int idConducteur;
  final String nomComplet;
}
