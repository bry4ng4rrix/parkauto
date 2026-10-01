# ParkAuto — application conducteur

Application Flutter des conducteurs ParkAuto (Android en priorité, Linux
desktop pris en charge), connectée à l'API décrite dans
`appli-conducteur-reponses.json`.

## Lancer

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json              # appareil Android
flutter run -d linux --dart-define-from-file=env/dev.json     # Linux
flutter build apk --release --dart-define-from-file=env/prod.json
```

## Environnements (`--dart-define-from-file`)

| Variable       | Obligatoire | Exemple                      |
|----------------|-------------|------------------------------|
| `APP_ENV`      | non         | `DEV`, `STAGING`, `PRODUCTION` |
| `API_BASE_URL` | oui         | `http://157.173.103.147:8088`  |
| `WS_BASE_URL`  | non         | dérivée de `API_BASE_URL` (`http`→`ws`, `https`→`wss`) |

`env/dev.json` est versionné. Copier `env/staging.example.json` /
`env/prod.example.json` en `staging.json` / `prod.json` (ignorés par Git).
Aucun identifiant ni jeton n'est stocké dans le dépôt.

## Tests

```bash
flutter analyze
flutter test                                        # unitaires + widgets
flutter test integration_test -d linux              # parcours complet (faux backend)
# Vérification contre le backend réel (ignorée sans identifiants) :
flutter test test/live --dart-define-from-file=env/dev.json \
  --dart-define=LIVE_EMAIL=… --dart-define=LIVE_PASSWORD=… [--dart-define=LIVE_WRITE=true]
```

## Architecture

- `lib/app` : configuration, thème (clair / sombre), routeur, coordination
  (session, temps réel, synchronisation, notifications).
- `lib/core` : client HTTP (Bearer, rafraîchissement unique, rejeu), erreurs
  du contrat, stockage sécurisé, cache hors connexion, WebSocket, médias.
- `lib/features/<fonction>` : `data` (endpoints), `domain` (modèles du
  contrat), `presentation` (écrans).

## Limites liées au backend

- Pas d'endpoint de notifications : le centre de notifications est local
  (messages temps réel, alertes véhicule, changements détectés lors des
  synchronisations toutes les 5 min et au retour dans l'app).
- Pas d'événement temps réel pour les missions/incidents (seulement
  `MESSAGE`).
- Pas d'aperçu du dernier message ni d'accusé de lecture par message.
- Pièces jointes de messages : JPEG, PNG, WEBP ou PDF uniquement.
- Plein et incident refusés si aucun véhicule n'est affecté.
- Sans FCM, les messages ne sont notifiés en arrière-plan que pendant
  10 minutes (WebSocket maintenu), puis au retour dans l'application.

## Activer les notifications push (FCM)

Architecture prête (`lib/core/notifications/push_service.dart`), aucune
dépendance Firebase installée. Quand le backend exposera un endpoint
d'enregistrement du jeton :

1. choisir l'`applicationId` définitif (`android/app/build.gradle.kts`,
   actuellement `com.example.parkauto`) ;
2. `flutter pub add firebase_core firebase_messaging` puis
   `flutterfire configure` (génère `google-services.json`) ;
3. implémenter `FcmPushService` (initialisation, `getToken`, `onMessage`,
   `onMessageOpenedApp`) et l'envoi du jeton à l'endpoint backend ;
4. remplacer `NoopPushService` dans `pushServiceProvider`.
