import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/lifecycle/app_lifecycle.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/notifications/notification_payload.dart';
import '../../notifications/data/notification_feed.dart';
import '../../notifications/domain/app_notification.dart';
import '../data/conversations_provider.dart';
import '../domain/realtime_event.dart';
import 'realtime.dart';
import 'unread_counter.dart';

/// Bannière in-app (application au premier plan).
typedef ForegroundMessageCallback =
    void Function({
      required String title,
      required String body,
      required int idConversation,
    });

/// Traitement global d'un événement `MESSAGE` (hors écran de chat, qui
/// ajoute lui-même le message à son fil).
class MessageEventHandler {
  MessageEventHandler(this._ref, {required this.onForegroundMessage});

  final Ref _ref;
  final ForegroundMessageCallback onForegroundMessage;

  void handle(MessageRealtimeEvent event) {
    final message = event.message;
    final me = _ref.read(currentUserIdProvider);
    final isMine = me != null && message.auteur.idUtilisateur == me;
    final foreground = _ref.read(appLifecycleProvider).isForeground;
    final isOpen =
        foreground &&
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

    final conversation = conversations.find(event.idConversation);
    final author = message.auteur.nomComplet;
    final title = conversation != null && conversation.type.isGroup
        ? '$author · ${conversation.titre}'
        : author;
    final body = message.preview.isEmpty ? 'Nouveau message' : message.preview;
    final route = AppRoutes.chat(event.idConversation);

    _ref
        .read(notificationFeedProvider.notifier)
        .add(
          AppNotification(
            id: 'message:${message.idMessage}',
            kind: AppNotificationKind.message,
            title: 'Nouveau message · $title',
            body: body,
            createdAt: message.dateEnvoi,
            route: route,
            conversationId: event.idConversation,
          ),
        );

    if (foreground) {
      onForegroundMessage(
        title: title,
        body: body,
        idConversation: event.idConversation,
      );
    } else {
      unawaited(
        _ref
            .read(localNotificationServiceProvider)
            .showMessage(
              id: message.idMessage,
              title: title,
              body: body,
              payload: NotificationPayload(route: route, userId: me),
            ),
      );
    }
  }
}
