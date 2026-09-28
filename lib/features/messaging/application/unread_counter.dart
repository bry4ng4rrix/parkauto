import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../data/messaging_repository.dart';

/// Total des messages non lus (badge 💬).
///
/// Source : `GET /api/messagerie/non-lus` (ou `messagesNonLus` de
/// `/api/moi`), la plus récente l'emporte ; ajustée localement en temps
/// réel puis réconciliée avec le serveur.
final unreadCountProvider = NotifierProvider<UnreadCounter, int>(
  UnreadCounter.new,
);

class UnreadCounter extends Notifier<int> {
  DateTime? _serverObservedAt;
  Timer? _debounce;

  @override
  int build() {
    ref.watch(currentDriverIdProvider);
    _serverObservedAt = null;
    ref.onDispose(() => _debounce?.cancel());
    return 0;
  }

  /// Valeur serveur observée à [observedAt] ; ignorée si plus ancienne
  /// que la dernière appliquée.
  void applyServer(int total, DateTime observedAt) {
    final last = _serverObservedAt;
    if (last != null && observedAt.isBefore(last)) return;
    _serverObservedAt = observedAt;
    state = max(0, total);
  }

  void increment() => state = state + 1;

  void decrement(int count) => state = max(0, state - count);

  /// Réconciliation groupée (plusieurs événements rapprochés).
  void scheduleReconcile([Duration delay = const Duration(seconds: 2)]) {
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(reconcile()));
  }

  Future<void> reconcile() async {
    final startedAt = DateTime.now();
    try {
      final total = await ref.read(messagingRepositoryProvider).nonLus();
      if (!ref.mounted) return;
      applyServer(total, startedAt);
    } on AppException catch (e) {
      AppLogger.debug('Messagerie', 'Non-lus non actualisés : $e');
    }
  }
}
