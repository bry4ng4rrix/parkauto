import '../domain/api_enum.dart';
import '../errors/app_exception.dart';
import '../utils/app_date_time.dart';

/// Lecture typée d'un objet JSON du contrat. Toute incohérence lève une
/// [ContractException] qui nomme le champ fautif.
class JsonReader {
  JsonReader(this.json, this.context);

  factory JsonReader.of(Object? data, String context) {
    if (data is Map<String, Object?>) return JsonReader(data, context);
    if (data is Map) {
      return JsonReader(
        {for (final e in data.entries) '${e.key}': e.value},
        context,
      );
    }
    throw ContractException(context, 'objet JSON attendu, reçu ${_kind(data)}');
  }

  final Map<String, Object?> json;
  final String context;

  /// Tableau JSON racine (ex. `GET /api/moi/missions`).
  static List<T> listOf<T>(
    Object? data,
    String context,
    T Function(Object? json) parse,
  ) {
    if (data is! List) {
      throw ContractException(
        context,
        'tableau JSON attendu, reçu ${_kind(data)}',
      );
    }
    return [for (final item in data) parse(item)];
  }

  Object? _value(String key) => json[key];

  ContractException _error(String key, String expected) => ContractException(
    '$context.$key',
    '$expected attendu, reçu ${_kind(_value(key))}',
  );

  int reqInt(String key) => optInt(key) ?? (throw _error(key, 'entier'));

  int? optInt(String key) {
    final value = _value(key);
    if (value == null) return null;
    if (value is int) return value;
    if (value is double && value == value.truncateToDouble()) {
      return value.toInt();
    }
    throw _error(key, 'entier');
  }

  /// Entier transmis sous forme de nombre ou de texte numérique.
  int? optIntLenient(String key) {
    final value = _value(key);
    if (value is String) return int.tryParse(value);
    if (value is num && value == value.truncate()) return value.toInt();
    return null;
  }

  double reqDouble(String key) =>
      optDouble(key) ?? (throw _error(key, 'nombre'));

  double? optDouble(String key) {
    final value = _value(key);
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw _error(key, 'nombre');
  }

  String reqString(String key) =>
      optString(key) ?? (throw _error(key, 'texte'));

  String? optString(String key) {
    final value = _value(key);
    if (value == null) return null;
    if (value is String) return value;
    throw _error(key, 'texte');
  }

  bool reqBool(String key) {
    final value = _value(key);
    if (value is bool) return value;
    throw _error(key, 'booléen');
  }

  DateTime reqDateTime(String key) =>
      optDateTime(key) ?? (throw _error(key, 'date'));

  DateTime? optDateTime(String key) {
    final value = optString(key);
    if (value == null) return null;
    try {
      return AppDateTime.parse(value);
    } on FormatException {
      throw _error(key, 'date ISO-8601');
    }
  }

  /// Date seule (`2026-10-15`).
  DateTime? optDate(String key) {
    final value = optString(key);
    if (value == null) return null;
    try {
      return AppDateTime.parseDate(value);
    } on FormatException {
      throw _error(key, 'date');
    }
  }

  T reqEnum<T extends ApiEnum>(String key, List<T> values, T unknown) =>
      optEnum(key, values, unknown) ?? (throw _error(key, 'valeur'));

  T? optEnum<T extends ApiEnum>(String key, List<T> values, T unknown) {
    final value = optString(key);
    if (value == null) return null;
    return ApiEnum.parse(values, value, unknown);
  }

  T reqObject<T>(String key, T Function(Object? json) parse) {
    final value = _value(key);
    if (value == null) throw _error(key, 'objet');
    return parse(value);
  }

  T? optObject<T>(String key, T Function(Object? json) parse) {
    final value = _value(key);
    return value == null ? null : parse(value);
  }

  /// Tableau d'objets ; absent ou `null` → liste vide.
  List<T> list<T>(String key, T Function(Object? json) parse) {
    final value = _value(key);
    if (value == null) return const [];
    if (value is! List) throw _error(key, 'tableau');
    return [for (final item in value) parse(item)];
  }

  static String _kind(Object? value) => switch (value) {
    null => 'null',
    bool() => 'booléen',
    num() => 'nombre',
    String() => 'texte',
    List() => 'tableau',
    Map() => 'objet',
    _ => 'valeur inconnue',
  };
}
