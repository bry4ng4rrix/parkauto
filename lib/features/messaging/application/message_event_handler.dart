import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/lifecycle/app_lifecycle.dart';
import '../../notifications/data/notification_feed.dart';
import '../../notifications/domain/app_notification.dart';
import '../data/conversations_provider.dart';
import '../domain/messaging_models.dart';
import '../domain/realtime_event.dart';
import 'own_message.dart';
import 'realtime.dart';
import 'unread_counter.dart';

/// Traitement global d'un événement `MESSAGE` (hors écran de chat, qui
/// ajoute lui-même le message à son fil) : badges, puis notification Android.
class MessageEventHandler {
  MessageEventHandler(this._ref);

  final Ref _ref;

  void handle(MessageRealtimeEvent event) {
    final message = event.message;
    final isMine = _ref.read(ownMessageMatcherProvider)(message);
    final isOpen =
        _ref.read(appLifecycleProvider).isForeground &&
        _ref.read(activeConversationProvider) == event.idConversation;

    _ref.read(conversationPreviewsProvider.notifier).record(message);
    final conversations = _ref.read(conversationsProvider.notifier);
    final countAsUnread = !isMine && !isOpen;
    if (!conversations.applyIncoming(message, countAsUnread: countAsUnread)) {
      unawaited(conversations.refresh());
    }
    // Propre message, ou conversation à l'écran : pas de notification.
    if (!countAsUnread) return;

    _ref.read(unreadCountProvider.notifier)
      ..increment()
      ..scheduleReconcile();

    // Publiée dans la barre de notifications Android par le flux.
    unawaited(
      _ref
          .read(notificationFeedProvider.notifier)
          .add(
            messageNotification(
              message,
              conversations.find(event.idConversation),
            ),
          ),
    );
  }
}

/// Notification d'un message reçu (temps réel ou vérification en
/// arrière-plan : même identifiant, donc jamais en double).
AppNotification messageNotification(
  Message message,
  Conversation? conversation,
) {
  final author = message.auteur.nomComplet;
  final title = conversation != null && conversation.type.isGroup
      ? '$author · ${conversation.titre}'
      : author;
  return AppNotification(
    id: 'message:${message.idMessage}',
    kind: AppNotificationKind.message,
    title: title,
    body: message.preview.isEmpty ? 'Nouveau message' : message.preview,
    createdAt: message.dateEnvoi,
    route: AppRoutes.chat(message.idConversation),
    conversationId: message.idConversation,
  );
}
