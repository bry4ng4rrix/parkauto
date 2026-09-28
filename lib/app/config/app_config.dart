import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Environnement d'exécution, fourni par `--dart-define-from-file=env/<env>.json`.
enum AppEnvironment {
  dev('DEV', 'Développement'),
  staging('STAGING', 'Recette'),
  production('PRODUCTION', 'Production');

  const AppEnvironment(this.key, this.label);

  final String key;
  final String label;

  static AppEnvironment parse(String value) => AppEnvironment.values.firstWhere(
    (e) => e.key == value.trim().toUpperCase(),
    orElse: () => AppEnvironment.dev,
  );
}

/// Configuration globale. Aucune URL n'est codée en dur ailleurs.
@immutable
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    this.deviceName = 'Flutter',
    this.currencyLabel = 'Ar',
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 60),
    this.messagesPageSize = 30,
    this.realtimeBackgroundGrace = const Duration(minutes: 10),
    this.resumeRefreshThreshold = const Duration(seconds: 60),
    this.syncInterval = const Duration(minutes: 5),
  });

  /// Lit `APP_ENV`, `API_BASE_URL` et `WS_BASE_URL` (facultatif).
  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'DEV');
    const api = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.88.20:8080',
    );
    const ws = String.fromEnvironment('WS_BASE_URL');
    final apiBaseUrl = _trimTrailingSlash(api);
    return AppConfig(
      environment: AppEnvironment.parse(env),
      apiBaseUrl: apiBaseUrl,
      wsBaseUrl: ws.isEmpty
          ? deriveWsBaseUrl(apiBaseUrl)
          : _trimTrailingSlash(ws),
    );
  }

  final AppEnvironment environment;

  /// Ex. `http://192.168.88.20:8080`.
  final String apiBaseUrl;

  /// Ex. `ws://192.168.88.20:8080` (dérivée de [apiBaseUrl] par défaut).
  final String wsBaseUrl;

  /// Valeur envoyée dans le champ `appareil` de la connexion.
  final String deviceName;

  /// Le contrat ne précise pas la devise des montants.
  final String currencyLabel;

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// `limite` des messages (le backend accepte 100 au plus).
  final int messagesPageSize;

  /// Durée pendant laquelle le WebSocket reste ouvert après la mise en pause.
  final Duration realtimeBackgroundGrace;

  /// Absence minimale avant de recharger les données au retour.
  final Duration resumeRefreshThreshold;

  /// Période de synchronisation au premier plan.
  final Duration syncInterval;

  /// `ws(s)://SERVEUR/ws/messagerie?ticket=<ticket>`.
  Uri realtimeUri(String ticket) => Uri.parse(
    '$wsBaseUrl/ws/messagerie',
  ).replace(queryParameters: {'ticket': ticket});

  static String deriveWsBaseUrl(String apiBaseUrl) {
    final uri = Uri.parse(apiBaseUrl);
    return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws').toString();
  }

  static String _trimTrailingSlash(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
