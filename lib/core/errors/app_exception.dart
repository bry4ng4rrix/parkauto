import 'api_error.dart';

/// Erreurs applicatives. Chaque variante sait produire un message lisible.
sealed class AppException implements Exception {
  const AppException();

  String get userMessage;

  @override
  String toString() => userMessage;
}

/// Réponse d'erreur du backend au format [ApiError] : son `message`
/// est affiché tel quel (règles métier 409 comprises).
final class ApiException extends AppException {
  const ApiException(this.error, this.statusCode);

  final ApiError error;
  final int statusCode;

  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isForbidden => statusCode == 403;

  @override
  String get userMessage => error.message;

  /// Détails 400 rattachés à leur champ (`kilometrage`, `quantiteLitres`…).
  Map<String, String> get fieldErrors => error.fieldErrors;
}

/// Erreur HTTP dont le corps n'est pas une [ApiError].
final class HttpStatusException extends AppException {
  const HttpStatusException(this.statusCode);

  final int statusCode;

  @override
  String get userMessage => switch (statusCode) {
    401 => 'Votre session a expiré. Veuillez vous reconnecter.',
    403 => 'Accès refusé.',
    404 => 'Ressource introuvable.',
    413 => 'Le fichier envoyé est trop volumineux.',
    >= 500 => 'Le serveur rencontre un problème. Réessayez plus tard.',
    _ => 'La requête a échoué (code $statusCode).',
  };
}

enum NetworkFailure { offline, timeout }

final class NetworkException extends AppException {
  const NetworkException(this.failure);

  final NetworkFailure failure;

  @override
  String get userMessage => switch (failure) {
    NetworkFailure.offline =>
      'Connexion impossible. Vérifiez votre connexion internet.',
    NetworkFailure.timeout =>
      'Le serveur met trop de temps à répondre. Réessayez.',
  };
}

/// Session absente, ou jeton de rafraîchissement refusé.
final class SessionExpiredException extends AppException {
  const SessionExpiredException();

  @override
  String get userMessage =>
      'Votre session a expiré. Veuillez vous reconnecter.';
}

/// Réponse qui ne respecte pas le contrat (champ absent ou mal typé).
final class ContractException extends AppException {
  const ContractException(this.field, this.problem);

  final String field;
  final String problem;

  @override
  String get userMessage =>
      'Réponse inattendue du serveur. Réessayez plus tard.';

  @override
  String toString() => 'ContractException($field: $problem)';
}

final class CancelledException extends AppException {
  const CancelledException();

  @override
  String get userMessage => 'Opération annulée.';
}

final class UnexpectedException extends AppException {
  const UnexpectedException([this.cause]);

  final Object? cause;

  @override
  String get userMessage => 'Une erreur inattendue est survenue.';

  @override
  String toString() => 'UnexpectedException($cause)';
}
