import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/app/background/background_check.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/core/notifications/local_notification_service.dart';
import 'package:parkauto/core/storage/preferences.dart';
import 'package:parkauto/features/notifications/data/notification_feed.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

/// Clé de la dernière vérification des messages (conducteur 12).
const _messagesCheckedAt = 'sync.12.messagesCheckedAt';

void main() {
  late FakeBackend backend;
  late FakeLocalNotifications notifications;

  setUp(() {
    notifications = FakeLocalNotifications();
    backend = FakeBackend()
      ..json('GET', ApiEndpoints.moi, 200, Contract.response('Accueil', '200'))
      ..json(
        'GET',
        ApiEndpoints.missions,
        200,
        Contract.response('Mes missions', '200'),
      )
      ..json(
        'GET',
        ApiEndpoints.incidents,
        200,
        Contract.response('Mes incidents', '200'),
      )
      ..json(
        'GET',
        ApiEndpoints.vehicule,
        200,
        Contract.response('Mon véhicule', '200'),
      )
      ..json('GET', ApiEndpoints.nonLus, 200, {'total': 3})
      ..json(
        'GET',
        ApiEndpoints.conversations,
        200,
        Contract.response('Mes conversations', '200'),
      )
      ..json(
        'GET',
        ApiEndpoints.messages(5),
        200,
        Contract.response("Messages d'une conversation", '200'),
      );
  });

  /// Nouvel isolat d'arrière-plan : nouveau conteneur, mêmes préférences.
  Future<BackgroundCheckResult> runCheck({
    bool freshPreferences = false,
  }) async {
    final container = await createContainer(
      backend: backend,
      session: testSession(),
      notifications: notifications,
      freshPreferences: freshPreferences,
    );
    addTearDown(container.dispose);
    return container.read(backgroundCheckProvider).run();
  }

  test('messages reçus depuis la dernière vérification : notifiés', () async {
    useInMemoryPreferences();
    await SharedPreferencesAsync().setString(
      _messagesCheckedAt,
      '2026-09-28T07:00:00Z',
    );

    expect(await runCheck(), BackgroundCheckResult.done);

    final messages = notifications.shown
        .where((n) => n.channel == NotificationChannel.messages)
        .toList();
    // 410 est antérieur à la dernière vérification, 411 est le sien.
    expect(messages, hasLength(1));
    expect(messages.single.title, 'Hery RAKOTO');
    expect(messages.single.body, contains('bon de livraison'));
    expect(messages.single.payload.route, '/chat/5');
    expect(messages.single.payload.userId, 27);
    // Seuls les messages non lus de la conversation 5 sont demandés ; le
    // canal 3 n'a rien reçu depuis.
    final requests = backend.calls('GET', ApiEndpoints.messages(5));
    expect(requests.single.query['limite'], '2');
    expect(backend.calls('GET', ApiEndpoints.messages(3)), isEmpty);
    expect(
      DateTime.parse(
        (await SharedPreferencesAsync().getString(_messagesCheckedAt))!,
      ).isAfter(DateTime.utc(2026, 10)),
      isTrue,
    );
  });

  test(
    'première vérification : pas de rafale pour de vieux messages',
    () async {
      await runCheck(freshPreferences: true);

      expect(
        notifications.shown.where(
          (n) => n.channel == NotificationChannel.messages,
        ),
        isEmpty,
      );
    },
  );

  test('nouvelle mission détectée app fermée, sans doublon ensuite', () async {
    useInMemoryPreferences();
    // Première vérification : état de référence.
    await runCheck();
    expect(
      notifications.shown.where(
        (n) => n.channel == NotificationChannel.missions,
      ),
      isEmpty,
    );
    final alerts = notifications.shown.length;

    final missions = Contract.response('Mes missions', '200')! as List<Object?>;
    final added = Map<String, Object?>.of(missions[1]! as Map<String, Object?>)
      ..['idMission'] = 120;
    backend.json('GET', ApiEndpoints.missions, 200, [added, ...missions]);

    await runCheck();

    final missionNotifications = notifications.shown
        .where((n) => n.channel == NotificationChannel.missions)
        .toList();
    expect(missionNotifications, hasLength(1));
    expect(missionNotifications.single.payload.route, contains('120'));
    // Alertes véhicule déjà notifiées : pas republiées.
    expect(notifications.shown, hasLength(alerts + 1));

    // L'app rouverte retrouve l'historique écrit en arrière-plan.
    final app = await createContainer(
      backend: backend,
      session: testSession(),
      freshPreferences: false,
    );
    addTearDown(app.dispose);
    await app.read(notificationFeedProvider.notifier).ensureLoaded();
    expect(
      app.read(notificationFeedProvider).map((n) => n.id),
      contains('mission:nouvelle:120'),
    );
  });

  test('app au premier plan : la vérification ne fait rien', () async {
    useInMemoryPreferences();
    await SharedPreferencesAsync().setString(
      PreferenceKeys.foregroundSince,
      DateTime.now().toIso8601String(),
    );

    expect(await runCheck(), BackgroundCheckResult.skippedForeground);
    expect(backend.requests, isEmpty);
    expect(notifications.shown, isEmpty);
  });

  test('sans session : tâche à annuler', () async {
    final container = await createContainer(
      backend: backend,
      notifications: notifications,
    );
    addTearDown(container.dispose);

    expect(
      await container.read(backgroundCheckProvider).run(),
      BackgroundCheckResult.signedOut,
    );
    expect(backend.requests, isEmpty);
  });
}
