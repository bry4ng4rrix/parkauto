import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../notifications/data/notification_feed.dart';
import '../data/conversations_provider.dart';
import '../data/messaging_repository.dart';
import 'unread_counter.dart';

/// Marque une conversation comme lue : badge local immédiatement à zéro,
/// `POST /lu` (groupé), puis réconciliation du total.
class ConversationReadService {
  ConversationReadService(this._ref);

  final Ref _ref;
  final _timers = <int, Timer>{};

  void markRead(
    int idConversation, {
    Duration delay = const Duration(milliseconds: 400),
  }) {
    _timers.remove(idConversation)?.cancel();
    _timers[idConversation] = Timer(delay, () {
      _timers.remove(idConversation);
      unawaited(_markRead(idConversation));
    });
  }

  Future<void> _markRead(int idConversation) async {
    final conversations = _ref.read(conversationsProvider.notifier);
    final unread = _ref.read(unreadCountProvider.notifier);
    final previous = conversations.find(idConversation)?.nonLus ?? 0;
    if (previous > 0) {
      conversations.setUnread(idConversation, 0);
      unread.decrement(previous);
    }
    _ref
        .read(notificationFeedProvider.notifier)
        .markConversationRead(idConversation);
    try {
      await _ref.read(messagingRepositoryProvider).marquerLu(idConversation);
    } on AppException catch (e) {
      AppLogger.warning('Messagerie', 'Lecture non enregistrée', e);
      unawaited(conversations.refresh());
    }
    unread.scheduleReconcile();
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

final conversationReadServiceProvider = Provider<ConversationReadService>((
  ref,
) {
  final service = ConversationReadService(ref);
  ref.onDispose(service.dispose);
  return service;
});
