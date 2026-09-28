import 'decimal_input.dart';
import 'formatters.dart';

/// Validations de formulaire. Chaque fonction renvoie le message d'erreur
/// à afficher sous le champ, ou `null` si la valeur est valide.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? required(String? value, {String? message}) =>
      (value == null || value.trim().isEmpty)
      ? (message ?? 'Ce champ est obligatoire')
      : null;

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return "L'email est obligatoire";
    return _email.hasMatch(text) ? null : 'Adresse email invalide';
  }

  static String? password(String? value) =>
      required(value, message: 'Le mot de passe est obligatoire');

  /// Nombre strictement positif (litres, prix).
  static String? positive(String? value, {required String label}) {
    final missing = required(value, message: '$label est obligatoire');
    if (missing != null) return missing;
    final number = DecimalInput.parse(value);
    if (number == null) return 'Nombre invalide';
    if (number <= 0) return '$label doit être supérieur à 0';
    return null;
  }

  /// Kilométrage > 0 et, si connu, au moins égal au compteur de référence.
  /// [minimumLabel] complète « Ne peut pas être inférieur … »
  /// (ex. « au kilométrage de départ »).
  static String? kilometrage(
    String? value, {
    double? minimum,
    String minimumLabel = 'au kilométrage actuel',
  }) {
    final missing = required(
      value,
      message: 'Le kilométrage est obligatoire',
    );
    if (missing != null) return missing;
    final number = DecimalInput.parse(value);
    if (number == null) return 'Kilométrage invalide';
    if (number <= 0) return 'Le kilométrage doit être supérieur à 0';
    if (minimum != null && number < minimum) {
      return 'Ne peut pas être inférieur $minimumLabel '
          '(${AppFormat.km(minimum)})';
    }
    return null;
  }
}
