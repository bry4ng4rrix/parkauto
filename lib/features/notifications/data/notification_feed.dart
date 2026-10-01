import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/notifications/notification_payload.dart';
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

  /// Enregistre [items] fusionnées avec l'historique déjà enregistré : la
  /// vérification en arrière-plan (autre isolat) a pu en ajouter.
  Future<List<AppNotification>> merge(
    int driverId,
    List<AppNotification> items,
  ) async {
    final merged = mergeNotifications(items, await read(driverId));
    await write(driverId, merged);
    return merged;
  }
}

/// Union par `id` (lue si l'une des copies l'est), de la plus récente à la
/// plus ancienne, limitée à [NotificationFeed.maxItems].
List<AppNotification> mergeNotifications(
  Iterable<AppNotification> a,
  Iterable<AppNotification> b,
) {
  final byId = <String, AppNotification>{};
  for (final n in [...a, ...b]) {
    final known = byId[n.id];
    byId[n.id] = known == null
        ? n
        : (n.read && !known.read ? known.asRead() : known);
  }
  final items = byId.values.toList()
    ..sort((x, y) => y.createdAt.compareTo(x.createdAt));
  return List.unmodifiable(items.take(NotificationFeed.maxItems));
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
/// synchronisation et les alertes. Chaque nouvelle notification est publiée
/// dans la barre de notifications Android ; la liste sert d'historique.
class NotificationFeed extends Notifier<List<AppNotification>> {
  static const maxItems = 100;

  int? _driverId;
  Future<void>? _loading;
  Future<void> _persisting = Future<void>.value();

  @override
  List<AppNotification> build() {
    final driverId = ref.watch(currentDriverIdProvider);
    _driverId = driverId;
    _loading = driverId == null ? null : _persist();
    return const [];
  }

  /// Historique enregistré chargé (nécessaire au dédoublonnage).
  Future<void> ensureLoaded() => _loading ?? Future<void>.value();

  /// Reprend les notifications ajoutées entre-temps par la vérification en
  /// arrière-plan (retour au premier plan).
  Future<void> reloadStored() => _persist();

  Future<void> add(AppNotification notification) => addAll([notification]);

  /// Ajoute et publie les notifications inconnues (dédoublonnage par `id`,
  /// y compris avec l'historique enregistré).
  Future<void> addAll(Iterable<AppNotification> notifications) async {
    await ensureLoaded();
    if (!ref.mounted) return;
    final known = {for (final n in state) n.id};
    final fresh = [
      for (final n in notifications)
        if (known.add(n.id)) n,
    ];
    if (fresh.isEmpty) return;
    _set([...fresh, ...state]);
    _publish(fresh);
    await _persisting;
  }

  /// Notification lue dans l'app : elle quitte aussi la barre système.
  void markRead(String id) {
    unawaited(
      ref
          .read(localNotificationServiceProvider)
          .cancel(stableNotificationId(id)),
    );
    _set([for (final n in state) n.id == id ? n.asRead() : n]);
  }

  void markAllRead() {
    unawaited(ref.read(localNotificationServiceProvider).cancelAll());
    _set([for (final n in state) n.asRead()]);
  }

  /// Conversation lue : ses notifications de message le sont aussi, et
  /// quittent la barre de notifications.
  void markConversationRead(int idConversation) {
    final concerned = [
      for (final n in state)
        if (n.conversationId == idConversation && !n.read) n,
    ];
    if (concerned.isEmpty) return;
    final service = ref.read(localNotificationServiceProvider);
    for (final n in concerned) {
      unawaited(service.cancel(stableNotificationId(n.id)));
    }
    _set([
      for (final n in state)
        n.conversationId == idConversation ? n.asRead() : n,
    ]);
  }

  void _publish(List<AppNotification> fresh) {
    final service = ref.read(localNotificationServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    for (final n in fresh) {
      unawaited(
        service.show(
          id: stableNotificationId(n.id),
          title: n.title,
          body: n.body,
          channel: switch (n.kind) {
            AppNotificationKind.message => NotificationChannel.messages,
            AppNotificationKind.mission => NotificationChannel.missions,
            _ => NotificationChannel.alertes,
          },
          payload: NotificationPayload(
            route: n.route ?? AppRoutes.notifications,
            userId: userId,
          ),
        ),
      );
    }
  }

  void _set(List<AppNotification> items) {
    state = mergeNotifications(items, const []);
    unawaited(_persist());
  }

  /// Enregistrements en file : chacun fusionne l'état courant avec
  /// l'historique enregistré, puis reprend ce que l'autre isolat a ajouté.
  Future<void> _persist() {
    final driverId = _driverId;
    if (driverId == null) return _persisting;
    return _persisting = _persisting.then((_) async {
      if (!ref.mounted || _driverId != driverId) return;
      try {
        final stored = await ref
            .read(notificationStoreProvider)
            .merge(driverId, state);
        if (!ref.mounted || _driverId != driverId) return;
        final merged = mergeNotifications(state, stored);
        if (!_sameItems(merged, state)) state = merged;
      } on Object catch (e) {
        // La file doit rester utilisable après un échec.
        AppLogger.warning('Notifications', 'Enregistrement impossible', e);
      }
    });
  }

  static bool _sameItems(List<AppNotification> a, List<AppNotification> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].read != b[i].read) return false;
    }
    return true;
  }
}
