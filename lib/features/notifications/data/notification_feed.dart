import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/preferences.dart';
import '../domain/app_notification.dart';

/// Stockage local des notifications, par conducteur.
class NotificationStore {
  NotificationStore(this._prefs);

  static const _prefix = 'notifications.';

  final SharedPreferencesAsync _prefs;

  Future<List<AppNotification>> read(int driverId) async {
    try {
      final raw = await _prefs.getString('$_prefix$driverId');
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(AppNotification.fromJson)
          .whereType<AppNotification>()
          .toList();
    } on Exception catch (e) {
      AppLogger.warning('Notifications', 'Lecture impossible', e);
      return const [];
    }
  }

  Future<void> write(int driverId, List<AppNotification> items) async {
    try {
      await _prefs.setString(
        '$_prefix$driverId',
        jsonEncode([for (final n in items) n.toJson()]),
      );
    } on Exception catch (e) {
      AppLogger.warning('Notifications', 'Écriture impossible', e);
    }
  }
}

final notificationStoreProvider = Provider<NotificationStore>(
  (ref) => NotificationStore(ref.watch(preferencesProvider)),
);

final notificationFeedProvider =
    NotifierProvider<NotificationFeed, List<AppNotification>>(
      NotificationFeed.new,
    );

/// Nombre de notifications non lues (badge 🔔).
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(notificationFeedProvider).where((n) => !n.read).length,
);

/// Centralise les événements temps réel, les changements détectés à la
/// synchronisation et les alertes (et, plus tard, les push FCM).
class NotificationFeed extends Notifier<List<AppNotification>> {
  static const maxItems = 100;

  int? _driverId;

  @override
  List<AppNotification> build() {
    final driverId = ref.watch(currentDriverIdProvider);
    _driverId = driverId;
    if (driverId != null) unawaited(_load(driverId));
    return const [];
  }

  void add(AppNotification notification) => addAll([notification]);

  /// Ajoute les notifications inconnues (dédoublonnage par `id`).
  void addAll(Iterable<AppNotification> notifications) {
    final known = {for (final n in state) n.id};
    final fresh = [
      for (final n in notifications)
        if (known.add(n.id)) n,
    ];
    if (fresh.isEmpty) return;
    _set([...fresh, ...state]);
  }

  void markRead(String id) =>
      _set([for (final n in state) n.id == id ? n.asRead() : n]);

  void markAllRead() => _set([for (final n in state) n.asRead()]);

  /// Conversation lue : ses notifications de message le sont aussi.
  void markConversationRead(int idConversation) {
    if (!state.any((n) => n.conversationId == idConversation && !n.read)) {
      return;
    }
    _set([
      for (final n in state)
        n.conversationId == idConversation ? n.asRead() : n,
    ]);
  }

  Future<void> _load(int driverId) async {
    final stored = await ref.read(notificationStoreProvider).read(driverId);
    if (!ref.mounted || _driverId != driverId || stored.isEmpty) return;
    final known = {for (final n in state) n.id};
    _set([...state, ...stored.where((n) => !known.contains(n.id))]);
  }

  void _set(List<AppNotification> items) {
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = List.unmodifiable(items.take(maxItems));
    final driverId = _driverId;
    if (driverId != null) {
      unawaited(ref.read(notificationStoreProvider).write(driverId, state));
    }
  }
}
