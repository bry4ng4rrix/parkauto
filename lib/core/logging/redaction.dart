/// Masque les secrets avant toute écriture dans les logs de développement.
abstract final class Redactor {
  static const mask = '***';

  static const _sensitiveKeys = {
    'motdepasse',
    'password',
    'jetonacces',
    'jetonrafraichissement',
    'authorization',
    'ticket',
  };

  static bool isSensitiveKey(String key) =>
      _sensitiveKeys.contains(key.toLowerCase());

  /// Copie profonde de [value] où les clés sensibles sont masquées.
  static Object? redact(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          '${entry.key}': isSensitiveKey('${entry.key}')
              ? mask
              : redact(entry.value),
      };
    }
    if (value is List) {
      return [for (final item in value) redact(item)];
    }
    return value;
  }

  /// Masque les paramètres de requête sensibles (ex. `?ticket=`).
  static String redactUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.queryParameters.isEmpty) return url;
    final query = {
      for (final entry in uri.queryParameters.entries)
        entry.key: isSensitiveKey(entry.key) ? mask : entry.value,
    };
    return uri.replace(queryParameters: query).toString();
  }

  /// Masque les secrets présents dans du texte libre (JWT, jetons nommés).
  static String redactText(String text) => text
      .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        mask,
      )
      .replaceAllMapped(
        RegExp(
          r'"(motDePasse|jetonAcces|jetonRafraichissement|ticket)"\s*:\s*"[^"]*"',
          caseSensitive: false,
        ),
        (m) => '"${m[1]}":"$mask"',
      );
}
