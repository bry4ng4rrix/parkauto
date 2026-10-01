import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/core/lifecycle/app_lifecycle.dart';
import 'package:parkauto/core/notifications/local_notification_service.dart';
import 'package:parkauto/features/messaging/application/message_event_handler.dart';
import 'package:parkauto/features/messaging/application/read_service.dart';
import 'package:parkauto/features/messaging/application/realtime.dart';
import 'package:parkauto/features/messaging/application/unread_counter.dart';
import 'package:parkauto/features/messaging/data/conversations_provider.dart';
import 'package:parkauto/features/messaging/domain/realtime_event.dart';
import 'package:parkauto/features/notifications/data/notification_feed.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

/// Événement MESSAGE du contrat, avec un auteur et une conversation donnés.
MessageRealtimeEvent _event({
  required int idConversation,
  required int authorId,
  int idMessage = 500,
}) {
  final json = Contract.realtimeMessage;
  json['idConversation'] = idConversation;
  final message = json['message']! as Map<String, Object?>;
  message
    ..['idConversation'] = idConversation
    ..['idMessage'] = idMessage;
  (message['auteur']! as Map<String, Object?>)['idUtilisateur'] = authorId;
  return MessageRealtimeEvent.fromJson(json);
}

final _handlerProvider = Provider<MessageEventHandler>(MessageEventHandler.new);

/// Laisse le flux de notifications charger son historique et publier.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeBackend backend;
  late FakeLocalNotifications notifications;

  setUp(() {
    notifications = FakeLocalNotifications();
    backend = FakeBackend()
      ..json(
        'GET',
        ApiEndpoints.conversations,
        200,
        Contract.response('Mes conversations', '200'),
      )
      ..json('GET', ApiEndpoints.nonLus, 200, {'total': 3})
      ..on(
        'POST',
        ApiEndpoints.marquerLu(5),
        (_) => const FakeReply.noContent(),
      );
  });

  Future<(MessageEventHandler, ProviderContainer)> setUpHandler() async {
    final container = await createContainer(
      backend: backend,
      session: testSession(),
      notifications: notifications,
    );
    await container.read(conversationsProvider.future);
    await container.read(unreadCountProvider.notifier).reconcile();
    return (container.read(_handlerProvider), container);
  }

  test(
    'message reçu au premier plan : badges et notification système',
    () async {
      final (handler, container) = await setUpHandler();
      container
          .read(appLifecycleProvider.notifier)
          .update(AppLifecycleState.resumed);

      handler.handle(_event(idConversation: 5, authorId: 2));
      await _settle();

      expect(container.read(unreadCountProvider), 4);
      final conversation = container
          .read(conversationsProvider.notifier)
          .find(5);
      expect(conversation?.nonLus, 3);
      expect(
        conversation?.dateDernierMessage,
        DateTime.utc(2026, 9, 28, 10, 20, 5),
      );
      expect(container.read(unreadNotificationCountProvider), 1);
      final shown = notifications.shown.single;
      expect(shown.title, startsWith('Tiana RABE'));
      expect(shown.body, 'Déchargement terminé.');
      expect(shown.channel, NotificationChannel.messages);
      expect(shown.payload.route, '/chat/5');
      expect(shown.payload.userId, 27);
    },
  );

  test('en arrière-plan : notification système ouvrant le chat', () async {
    final (handler, container) = await setUpHandler();
    container
        .read(appLifecycleProvider.notifier)
        .update(AppLifecycleState.paused);

    handler.handle(_event(idConversation: 5, authorId: 2));
    await _settle();

    expect(notifications.shown.single.payload.route, '/chat/5');
    expect(notifications.shown.single.payload.userId, 27);
  });

  test('même message reçu deux fois : une seule notification', () async {
    final (handler, container) = await setUpHandler();

    handler
      ..handle(_event(idConversation: 5, authorId: 2))
      ..handle(_event(idConversation: 5, authorId: 2));
    await _settle();

    expect(notifications.shown, hasLength(1));
    expect(container.read(notificationFeedProvider), hasLength(1));
  });

  test('conversation ouverte : pas de badge ni de notification', () async {
    final (handler, container) = await setUpHandler();
    container
        .read(appLifecycleProvider.notifier)
        .update(AppLifecycleState.resumed);
    container.read(activeConversationProvider.notifier).enter(5);

    handler.handle(_event(idConversation: 5, authorId: 2));
    await _settle();

    expect(container.read(unreadCountProvider), 3);
    expect(container.read(conversationsProvider.notifier).find(5)?.nonLus, 2);
    expect(notifications.shown, isEmpty);
  });

  test('son propre message (écho WebSocket) : aucune notification', () async {
    final (handler, container) = await setUpHandler();

    handler.handle(_event(idConversation: 5, authorId: 27));
    await _settle();

    expect(container.read(unreadCountProvider), 3);
    expect(container.read(unreadNotificationCountProvider), 0);
    expect(notifications.shown, isEmpty);
  });

  test('marquer comme lu : badge à zéro puis POST /lu', () async {
    final (_, container) = await setUpHandler();
    backend.json('GET', ApiEndpoints.nonLus, 200, {'total': 1});

    container
        .read(conversationReadServiceProvider)
        .markRead(5, delay: Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(conversationsProvider.notifier).find(5)?.nonLus, 0);
    expect(container.read(unreadCountProvider), 1);
    expect(backend.calls('POST', ApiEndpoints.marquerLu(5)), hasLength(1));
  });

  test('conversation lue : sa notification quitte la barre système', () async {
    final (handler, container) = await setUpHandler();
    handler.handle(_event(idConversation: 5, authorId: 2));
    await _settle();
    expect(notifications.shown, hasLength(1));

    container.read(notificationFeedProvider.notifier).markConversationRead(5);
    await _settle();

    expect(notifications.shown, isEmpty);
    expect(container.read(unreadNotificationCountProvider), 0);
  });
}
