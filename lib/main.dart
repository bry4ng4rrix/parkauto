import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/background/background_scheduler.dart';
import 'core/auth/session_controller.dart';
import 'core/auth/session_store.dart';
import 'core/logging/app_logger.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/storage/preferences.dart';
import 'features/settings/data/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    AppLogger.error(
      'Flutter',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };

  Intl.defaultLocale = 'fr';
  await initializeDateFormatting('fr');

  final prefs = SharedPreferencesAsync();
  final sessionStore = SecureSessionStore();
  await _wipeKeychainOnFirstRun(prefs, sessionStore);

  final themeMode = ThemeModeController.parse(
    await prefs.getString(PreferenceKeys.themeMode),
  );
  final notifications = PluginLocalNotificationService();
  await notifications.initialize();
  // Vérification périodique app fermée (Android) : notifications système
  // même sans push serveur.
  final backgroundScheduler = createBackgroundScheduler();
  await backgroundScheduler.initialize();

  runApp(
    ProviderScope(
      // Pas de nouvel essai automatique : les erreurs réseau sont gérées
      // par le cache et les boutons « Réessayer ».
      retry: (_, _) => null,
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        sessionStoreProvider.overrideWithValue(sessionStore),
        localNotificationServiceProvider.overrideWithValue(notifications),
        backgroundSchedulerProvider.overrideWithValue(backgroundScheduler),
        initialThemeModeProvider.overrideWithValue(themeMode),
      ],
      child: const ParkAutoApp(),
    ),
  );
}

/// Le Keychain iOS survit à la désinstallation : on repart d'une session
/// vide au premier lancement.
Future<void> _wipeKeychainOnFirstRun(
  SharedPreferencesAsync prefs,
  SessionStore store,
) async {
  try {
    if (await prefs.getBool(PreferenceKeys.installed) ?? false) return;
    await store.wipe();
    await prefs.setBool(PreferenceKeys.installed, true);
  } on Exception catch (e) {
    AppLogger.warning('App', 'Initialisation du stockage', e);
  }
}
