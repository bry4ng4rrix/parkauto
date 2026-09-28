/// Énumération transmise par le backend en `SCREAMING_SNAKE_CASE`.
///
/// Chaque enum déclare une valeur `inconnu` (valeur côté client, jamais
/// envoyée) pour qu'une valeur ajoutée côté serveur ne casse pas une liste.
mixin ApiEnum on Enum {
  String get apiValue;
  String get label;

  bool get isUnknown => apiValue.isEmpty;

  static T parse<T extends ApiEnum>(List<T> values, String raw, T unknown) {
    for (final value in values) {
      if (value.apiValue == raw) return value;
    }
    return unknown;
  }

  /// Valeurs proposables dans un formulaire (sans `inconnu`).
  static List<T> selectable<T extends ApiEnum>(List<T> values) => [
    for (final value in values)
      if (!value.isUnknown) value,
  ];
}
