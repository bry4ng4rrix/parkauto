import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/state/cached_resource.dart';
import '../domain/messaging_models.dart';

/// `GET /api/messagerie/conversations`.
final conversationsQuery = CachedQuery<List<Conversation>>(
  key: 'conversations',
  fetch: (api) => api.getRaw(ApiEndpoints.conversations),
  parse: (json) => sortConversations(Conversation.listFromJson(json)),
);

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, Cached<List<Conversation>>>(
      ConversationsNotifier.new,
    );

/// Plus récentes d'abord ; conversations sans message en dernier.
List<Conversation> sortConversations(List<Conversation> conversations) {
  final sorted = [...conversations];
  sorted.sort((a, b) {
    final (da, db) = (a.dateDernierMessage, b.dateDernierMessage);
    if (da == null && db == null) return a.titre.compareTo(b.titre);
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return sorted;
}

class ConversationsNotifier extends CachedResourceNotifier<List<Conversation>> {
  @override
  CachedQuery<List<Conversation>> get query => conversationsQuery;

  Conversation? find(int idConversation) {
    for (final c in state.value?.value ?? const <Conversation>[]) {
      if (c.idConversation == idConversation) return c;
    }
    return null;
  }

  /// Nouveau message : date mise à jour et, si demandé, non-lus + 1.
  /// Renvoie `false` si la conversation n'est pas encore connue.
  bool applyIncoming(Message message, {required bool countAsUnread}) {
    if (find(message.idConversation) == null) return false;
    mutate(
      (conversations) => sortConversations([
        for (final c in conversations)
          c.idConversation == message.idConversation
              ? c.copyWith(
                  dateDernierMessage: message.dateEnvoi,
                  nonLus: countAsUnread ? c.nonLus + 1 : c.nonLus,
                )
              : c,
      ]),
    );
    return true;
  }

  void setUnread(int idConversation, int count) => mutate(
    (conversations) => [
      for (final c in conversations)
        c.idConversation == idConversation ? c.copyWith(nonLus: count) : c,
    ],
  );

  /// Conversation ouverte via `POST /privee`.
  void upsert(Conversation conversation) => mutate(
    (conversations) => sortConversations([
      conversation,
      for (final c in conversations)
        if (c.idConversation != conversation.idConversation) c,
    ]),
  );
}

/// Dernier message connu localement (le contrat ne fournit pas d'aperçu).
final conversationPreviewsProvider =
    NotifierProvider<ConversationPreviews, Map<int, Message>>(
      ConversationPreviews.new,
    );

class ConversationPreviews extends Notifier<Map<int, Message>> {
  @override
  Map<int, Message> build() {
    ref.watch(currentDriverIdProvider);
    return const {};
  }

  void record(Message message) {
    final current = state[message.idConversation];
    if (current != null && current.idMessage >= message.idMessage) return;
    state = {...state, message.idConversation: message};
  }
}
