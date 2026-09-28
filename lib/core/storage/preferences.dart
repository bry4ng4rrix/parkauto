import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences non sensibles (thème, cache, notifications locales).
/// Les jetons ne sont jamais stockés ici.
final preferencesProvider = Provider<SharedPreferencesAsync>(
  (ref) => SharedPreferencesAsync(),
);

abstract final class PreferenceKeys {
  static const themeMode = 'settings.themeMode';
  static const installed = 'app.installed';
  static const permissionAsked = 'notifications.permissionAsked';

  /// Données propres au conducteur connecté, effacées à la déconnexion.
  static const userScopedPrefixes = ['cache.', 'notifications.', 'sync.'];
}

/// Supprime toutes les clés commençant par l'un des [prefixes].
Future<void> clearPreferencePrefixes(
  SharedPreferencesAsync prefs,
  List<String> prefixes,
) async {
  final keys = (await prefs.getKeys())
      .where((key) => prefixes.any(key.startsWith))
      .toSet();
  if (keys.isNotEmpty) await prefs.clear(allowList: keys);
}
