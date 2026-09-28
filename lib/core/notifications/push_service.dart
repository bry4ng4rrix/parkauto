import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifications push (FCM). Architecture seulement : le backend n'expose
/// aucun endpoint d'enregistrement du jeton FCM.
///
/// Pour activer FCM plus tard :
/// 1. ajouter `firebase_core` et `firebase_messaging`, lancer
///    `flutterfire configure` (google-services.json / plist) ;
/// 2. créer `FcmPushService implements PushService` : `initialize` appelle
///    `Firebase.initializeApp`, `FirebaseMessaging.instance.getToken()` et
///    écoute `onMessage` / `onMessageOpenedApp` ;
/// 3. envoyer le jeton au backend quand l'endpoint existera ;
/// 4. remplacer [NoopPushService] dans [pushServiceProvider].
abstract interface class PushService {
  /// Prépare le service après connexion.
  Future<void> initialize();

  /// Jeton de l'appareil (null tant que le push n'est pas configuré).
  Future<String?> deviceToken();

  /// Retire le jeton à la déconnexion.
  Future<void> unregister();
}

class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> deviceToken() async => null;

  @override
  Future<void> unregister() async {}
}

final pushServiceProvider = Provider<PushService>(
  (ref) => const NoopPushService(),
);
