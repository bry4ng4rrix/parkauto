import 'dart:convert';

/// Lecture (sans vérification de signature) des claims du jeton d'accès.
///
/// Le jeton porte `idUtilisateur`, distinct de `idConducteur` : c'est lui
/// qui identifie l'auteur des messages (`auteur.idUtilisateur`).
abstract final class JwtClaims {
  static Map<String, Object?>? payload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(decoded);
      return json is Map<String, Object?> ? json : null;
    } on FormatException {
      return null;
    }
  }

  static int? idUtilisateur(String jwt) {
    final value = payload(jwt)?['idUtilisateur'];
    return value is num ? value.toInt() : null;
  }
}
