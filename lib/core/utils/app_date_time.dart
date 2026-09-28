/// Conventions de dates du backend :
/// - avec `Z` (ou décalage) : instant UTC → affiché en heure locale ;
/// - sans fuseau : heure locale du serveur, conservée telle quelle
///   (l'appareil et le serveur sont supposés dans le même fuseau) ;
/// - `yyyy-MM-dd` : date seule.
abstract final class AppDateTime {
  static final _zoneSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  /// Lève une [FormatException] si [value] n'est pas une date ISO-8601.
  static DateTime parse(String value) {
    final trimmed = value.trim();
    final parsed = DateTime.parse(trimmed);
    return _zoneSuffix.hasMatch(trimmed) ? parsed.toUtc() : parsed;
  }

  /// Date seule (`2026-10-15`), à minuit local.
  static DateTime parseDate(String value) {
    final parsed = DateTime.parse(value.trim());
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Valeur à afficher : les instants UTC sont convertis en heure locale.
  static DateTime toDisplay(DateTime value) =>
      value.isUtc ? value.toLocal() : value;

  /// Format attendu par l'API pour les dates saisies : `2026-09-28T10:00:00`.
  static String toApi(DateTime value) {
    final local = toDisplay(value);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
        '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
        '${two(local.second)}';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    final x = toDisplay(a);
    final y = toDisplay(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
