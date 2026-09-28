import 'package:flutter/foundation.dart';

import 'auth_response.dart';
import 'jwt_claims.dart';

/// Session conducteur persistée dans le stockage sécurisé.
@immutable
class Session {
  const Session({
    required this.jetonAcces,
    required this.jetonRafraichissement,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.idConducteur,
    required this.idUtilisateur,
    required this.nomComplet,
    required this.role,
  });

  factory Session.fromAuth(AuthResponse auth, {required DateTime now}) {
    final lifetime = Duration(seconds: auth.expireDans);
    // Marge pour rafraîchir avant l'expiration réelle.
    final margin = lifetime > const Duration(minutes: 2)
        ? const Duration(seconds: 30)
        : Duration.zero;
    return Session(
      jetonAcces: auth.jetonAcces,
      jetonRafraichissement: auth.jetonRafraichissement,
      accessExpiresAt: now.toUtc().add(lifetime - margin),
      refreshExpiresAt: auth.expirationRafraichissement.toUtc(),
      idConducteur: auth.idConducteur,
      idUtilisateur: JwtClaims.idUtilisateur(auth.jetonAcces),
      nomComplet: auth.nomComplet,
      role: auth.role,
    );
  }

  final String jetonAcces;
  final String jetonRafraichissement;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
  final int idConducteur;

  /// Claim `idUtilisateur` du jeton (null s'il est absent).
  final int? idUtilisateur;
  final String nomComplet;
  final String role;

  bool isAccessExpired(DateTime now) => !now.isBefore(accessExpiresAt);

  bool isRefreshExpired(DateTime now) => !now.isBefore(refreshExpiresAt);

  /// Nouveaux jetons après `/rafraichir`.
  Session renewed(AuthResponse auth, {required DateTime now}) {
    final next = Session.fromAuth(auth, now: now);
    return next.idUtilisateur != null ? next : next._withUserId(idUtilisateur);
  }

  Session _withUserId(int? id) => Session(
    jetonAcces: jetonAcces,
    jetonRafraichissement: jetonRafraichissement,
    accessExpiresAt: accessExpiresAt,
    refreshExpiresAt: refreshExpiresAt,
    idConducteur: idConducteur,
    idUtilisateur: id,
    nomComplet: nomComplet,
    role: role,
  );

  Map<String, Object?> toStorage() => {
    'jetonAcces': jetonAcces,
    'jetonRafraichissement': jetonRafraichissement,
    'accessExpiresAt': accessExpiresAt.toUtc().toIso8601String(),
    'refreshExpiresAt': refreshExpiresAt.toUtc().toIso8601String(),
    'idConducteur': idConducteur,
    'idUtilisateur': idUtilisateur,
    'nomComplet': nomComplet,
    'role': role,
  };

  /// Renvoie `null` si l'entrée stockée est illisible.
  static Session? fromStorage(Object? json) {
    if (json is! Map) return null;
    final jetonAcces = json['jetonAcces'];
    final jetonRafraichissement = json['jetonRafraichissement'];
    final accessExpiresAt = DateTime.tryParse('${json['accessExpiresAt']}');
    final refreshExpiresAt = DateTime.tryParse('${json['refreshExpiresAt']}');
    final idConducteur = json['idConducteur'];
    final idUtilisateur = json['idUtilisateur'];
    final nomComplet = json['nomComplet'];
    final role = json['role'];
    if (jetonAcces is! String ||
        jetonRafraichissement is! String ||
        accessExpiresAt == null ||
        refreshExpiresAt == null ||
        idConducteur is! int ||
        (idUtilisateur != null && idUtilisateur is! int) ||
        nomComplet is! String ||
        role is! String) {
      return null;
    }
    return Session(
      jetonAcces: jetonAcces,
      jetonRafraichissement: jetonRafraichissement,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      idConducteur: idConducteur,
      idUtilisateur: idUtilisateur as int?,
      nomComplet: nomComplet,
      role: role,
    );
  }
}
