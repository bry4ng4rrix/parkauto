import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/lifecycle/app_lifecycle.dart';
import '../../../core/websocket/realtime_service.dart';
import '../application/own_message.dart';
import '../application/read_service.dart';
import '../application/realtime.dart';
import '../data/conversations_provider.dart';
import '../data/messaging_repository.dart';
import '../domain/local_attachment.dart';
import '../domain/messaging_models.dart';
import '../domain/realtime_event.dart';

enum PendingStatus { sending, failed }

/// Message envoyé depuis l'appareil, pas encore confirmé par le serveur.
@immutable
class PendingMessage {
  const PendingMessage({
    required this.localId,
    required this.contenu,
    required this.fichiers,
    required this.createdAt,
    this.status = PendingStatus.sending,
    this.error,
  });

  final String localId;
  final String? contenu;
  final List<LocalAttachment> fichiers;
  final DateTime createdAt;
  final PendingStatus status;
  final AppException? error;

  PendingMessage copyWith({PendingStatus? status, AppException? error}) =>
      PendingMessage(
        localId: localId,
        contenu: contenu,
        fichiers: fichiers,
        createdAt: createdAt,
        status: status ?? this.status,
        error: error,
      );
}

@immutable
class ChatState {
  const ChatState({
    required this.messages,
    this.pending = const [],
    this.hasMore = true,
    this.loadingOlder = false,
    this.olderError,
  });

  /// Du plus ancien au plus récent, sans doublon (`idMessage`).
  final List<Message> messages;
  final List<PendingMessage> pending;
  final bool hasMore;
  final bool loadingOlder;
  final AppException? olderError;

  ChatState copyWith({
    List<Message>? messages,
    List<PendingMessage>? pending,
    bool? hasMore,
    bool? loadingOlder,
    AppException? olderError,
  }) => ChatState(
    messages: messages ?? this.messages,
    pending: pending ?? this.pending,
    hasMore: hasMore ?? this.hasMore,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    olderError: olderError,
  );
}

final chatControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChatController, ChatState, int>(ChatController.new);

/// Fil d'une conversation : `GET …/messages?limite=` (pagination `avant`),
/// envoi multipart et messages temps réel.
class ChatController extends AsyncNotifier<ChatState> {
  ChatController(this.idConversation);

  final int idConversation;
  int _sequence = 0;
  bool _wasDisconnected = false;

  int get _pageSize => ref.read(appConfigProvider).messagesPageSize;

  MessagingRepository get _repository => ref.read(messagingRepositoryProvider);

  @override
  Future<ChatState> build() async {
    // Abonnements directs au flux : ils ne sont pas mis en pause quand
    // l'écran est recouvert (visionneuse, sélecteur de fichiers).
    final realtime = ref.read(realtimeServiceProvider);
    final events = realtime.events.listen(_onEvent);
    final statuses = realtime.statusChanges.listen(_onStatus);
    ref.onDispose(() {
      unawaited(events.cancel());
      unawaited(statuses.cancel());
    });

    final page = await _repository.messages(
      idConversation,
      limite: _pageSize,
    );
    _recordPreview(page);
    return ChatState(messages: _sorted(page), hasMore: page.length >= _pageSize);
  }

  Future<void> loadOlder() async {
    final current = state.value;
    if (current == null ||
        current.loadingOlder ||
        !current.hasMore ||
        current.messages.isEmpty) {
      return;
    }
    state = AsyncData(current.copyWith(loadingOlder: true));
    try {
      final page = await _repository.messages(
        idConversation,
        limite: _pageSize,
        avant: current.messages.first.idMessage,
      );
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          messages: _union(latest.messages, page),
          loadingOlder: false,
          hasMore: page.length >= _pageSize,
        ),
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(
        (state.value ?? current).copyWith(loadingOlder: false, olderError: e),
      );
    }
  }

  Future<void> send(String text, List<LocalAttachment> files) async {
    final content = text.trim();
    if (content.isEmpty && files.isEmpty) return;
    final pending = PendingMessage(
      localId: 'local-${_sequence++}',
      contenu: content.isEmpty ? null : content,
      fichiers: files,
      createdAt: DateTime.now(),
    );
    _setPending([...?state.value?.pending, pending]);
    await _deliver(pending);
  }

  Future<void> retry(String localId) async {
    final pending = state.value?.pending
        .where((p) => p.localId == localId)
        .firstOrNull;
    if (pending == null || pending.status == PendingStatus.sending) return;
    await _deliver(pending);
  }

  void discard(String localId) => _setPending([
    for (final p in state.value?.pending ?? const <PendingMessage>[])
      if (p.localId != localId) p,
  ]);

  /// Rattrapage après reconnexion : dernière page fusionnée ; en cas de
  /// trou (plus de `limite` nouveaux messages), on repart de cette page.
  Future<void> refreshLatest() async {
    try {
      final latest = await _repository.messages(
        idConversation,
        limite: _pageSize,
      );
      if (ref.mounted) _mergeLatest(latest);
    } on AppException {
      // Le fil actuel reste affiché.
    }
  }

  Future<void> _deliver(PendingMessage pending) async {
    _updatePending(
      pending.localId,
      (p) => p.copyWith(status: PendingStatus.sending),
    );
    try {
      final message = await _repository.envoyer(
        idConversation,
        contenu: pending.contenu,
        fichiers: pending.fichiers,
      );
      if (!ref.mounted) return;
      _confirm(pending.localId, message);
    } on NetworkException catch (e) {
      // Envoi incertain : vérification avant de proposer « Réessayer ».
      final delivered = await _findDelivered(pending);
      if (!ref.mounted) return;
      if (delivered != null) {
        _confirm(pending.localId, delivered);
      } else {
        _updatePending(
          pending.localId,
          (p) => p.copyWith(status: PendingStatus.failed, error: e),
        );
      }
    } on AppException catch (e) {
      if (!ref.mounted) return;
      _updatePending(
        pending.localId,
        (p) => p.copyWith(status: PendingStatus.failed, error: e),
      );
    }
  }

  Future<Message?> _findDelivered(PendingMessage pending) async {
    try {
      final latest = await _repository.messages(
        idConversation,
        limite: _pageSize,
      );
      if (!ref.mounted) return null;
      _mergeLatest(latest);
      final isMine = ref.read(ownMessageMatcherProvider);
      final since = pending.createdAt.subtract(const Duration(minutes: 2));
      return latest
          .where(
            (m) =>
                isMine(m) &&
                m.contenu == pending.contenu &&
                m.piecesJointes.length == pending.fichiers.length &&
                m.dateEnvoi.isAfter(since),
          )
          .lastOrNull;
    } on AppException {
      return null;
    }
  }

  void _confirm(String localId, Message message) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages: _union(current.messages, [message]),
        pending: [
          for (final p in current.pending)
            if (p.localId != localId) p,
        ],
      ),
    );
    _recordPreview([message]);
    ref
        .read(conversationsProvider.notifier)
        .applyIncoming(message, countAsUnread: false);
  }

  void _onEvent(RealtimeEvent event) {
    if (event is! MessageRealtimeEvent ||
        event.idConversation != idConversation) {
      return;
    }
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(messages: _union(current.messages, [event.message])),
    );
    final isMine = ref.read(ownMessageMatcherProvider)(event.message);
    if (!isMine && _isActive) {
      ref.read(conversationReadServiceProvider).markRead(idConversation);
    }
  }

  void _onStatus(RealtimeStatus status) {
    if (status == RealtimeStatus.disconnected) _wasDisconnected = true;
    if (status == RealtimeStatus.connected && _wasDisconnected) {
      _wasDisconnected = false;
      unawaited(refreshLatest());
    }
  }

  bool get _isActive =>
      ref.read(activeConversationProvider) == idConversation &&
      ref.read(appLifecycleProvider).isForeground;

  void _mergeLatest(List<Message> latest) {
    final current = state.value;
    if (current == null) return;
    final gap =
        latest.length >= _pageSize &&
        current.messages.isNotEmpty &&
        latest.first.idMessage > current.messages.last.idMessage;
    state = AsyncData(
      current.copyWith(
        messages: gap ? _sorted(latest) : _union(current.messages, latest),
        hasMore: gap ? true : current.hasMore,
      ),
    );
    _recordPreview(latest);
  }

  void _setPending(List<PendingMessage> pending) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(pending: pending));
  }

  void _updatePending(
    String localId,
    PendingMessage Function(PendingMessage) change,
  ) => _setPending([
    for (final p in state.value?.pending ?? const <PendingMessage>[])
      p.localId == localId ? change(p) : p,
  ]);

  void _recordPreview(List<Message> messages) {
    final last = messages.lastOrNull;
    if (last != null) {
      ref.read(conversationPreviewsProvider.notifier).record(last);
    }
  }

  static List<Message> _union(List<Message> a, List<Message> b) =>
      _sorted({for (final m in [...a, ...b]) m.idMessage: m}.values);

  static List<Message> _sorted(Iterable<Message> messages) =>
      messages.toList()..sort((x, y) => x.idMessage.compareTo(y.idMessage));
}
