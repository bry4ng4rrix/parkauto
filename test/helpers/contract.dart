import 'dart:convert';
import 'dart:io';

/// Réponses du contrat `appli-conducteur-reponses.json` (sans les corps de
/// requête), extraites dans `test/fixtures/contract_responses.json`.
abstract final class Contract {
  static final Map<String, Object?> _json =
      jsonDecode(
            File('test/fixtures/contract_responses.json').readAsStringSync(),
          )
          as Map<String, Object?>;

  static List<Map<String, Object?>> get _endpoints => [
    for (final e in _json['endpoints']! as List<Object?>)
      e! as Map<String, Object?>,
  ];

  /// Réponse [status] (ex. `200`, `409 (assurance)`) de l'endpoint [nom].
  static Object? response(String nom, String status) {
    for (final endpoint in _endpoints) {
      if (endpoint['nom'] != nom) continue;
      final responses = endpoint['reponses']! as Map<String, Object?>;
      if (responses.containsKey(status)) return _copy(responses[status]);
    }
    throw ArgumentError('Réponse introuvable : $nom / $status');
  }

  /// Tous les exemples `[nom, statut, corps]` du contrat.
  static Iterable<(String, String, Object?)> get allResponses sync* {
    for (final endpoint in _endpoints) {
      final responses = endpoint['reponses']! as Map<String, Object?>;
      for (final entry in responses.entries) {
        yield (endpoint['nom']! as String, entry.key, _copy(entry.value));
      }
    }
  }

  static Map<String, Object?> get realtimeMessage =>
      _copy((_json['tempsReel']! as Map<String, Object?>)['evenement'])!
          as Map<String, Object?>;

  static Object? _copy(Object? value) => jsonDecode(jsonEncode(value));
}
