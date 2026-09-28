import 'package:flutter/foundation.dart';

import '../utils/app_date_time.dart';

/// Corps d'erreur commun du backend :
/// `{horodatage, statut, erreur, message, details}`.
@immutable
class ApiError {
  const ApiError({
    required this.horodatage,
    required this.statut,
    required this.erreur,
    required this.message,
    this.details = const [],
  });

  /// Instant UTC.
  final DateTime horodatage;
  final int statut;
  final String erreur;

  /// Texte à afficher tel quel.
  final String message;

  /// Champs invalides (400), au format « champ : message ».
  final List<String> details;

  /// Renvoie `null` si [data] n'a pas la forme d'une [ApiError].
  static ApiError? tryParse(Object? data) {
    if (data is! Map) return null;
    final horodatage = data['horodatage'];
    final statut = data['statut'];
    final erreur = data['erreur'];
    final message = data['message'];
    if (horodatage is! String ||
        statut is! int ||
        erreur is! String ||
        message is! String) {
      return null;
    }
    final DateTime parsedHorodatage;
    try {
      parsedHorodatage = AppDateTime.parse(horodatage);
    } on FormatException {
      return null;
    }
    final rawDetails = data['details'];
    return ApiError(
      horodatage: parsedHorodatage,
      statut: statut,
      erreur: erreur,
      message: message,
      details: rawDetails is List
          ? [
              for (final d in rawDetails)
                if (d is String) d,
            ]
          : const [],
    );
  }

  /// Associe chaque détail « champ : message » à son champ.
  Map<String, String> get fieldErrors {
    final result = <String, String>{};
    for (final detail in details) {
      final index = detail.indexOf(' : ');
      if (index <= 0) continue;
      final field = detail.substring(0, index).trim();
      final text = detail.substring(index + 3).trim();
      result.putIfAbsent(field, () => text);
    }
    return result;
  }
}
