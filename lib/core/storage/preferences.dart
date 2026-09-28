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
}
