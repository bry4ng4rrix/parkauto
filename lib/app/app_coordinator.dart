import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session_controller.dart';
import '../core/logging/app_logger.dart';
import '../core/network/network_status.dart';
import '../core/notifications/local_notification_service.dart';
import '../core/notifications/notification_payload.dart';
import '../core/notifications/push_service.dart';
import '../core/storage/preferences.dart';
import '../core/websocket/realtime_service.dart';
import '../core/widgets/feedback.dart';
import '../features/home/data/moi_repository.dart';
import '../features/messaging/application/message_event_handler.dart';
import '../features/messaging/application/realtime.dart';
import '../features/messaging/application/unread_counter.dart';
import '../features/messaging/data/conversations_provider.dart';
import '../features/messaging/domain/realtime_event.dart';
import '../features/notifications/data/notification_feed.dart';
import 'background/background_scheduler.dart';
import 'config/app_config.dart';
import 'router/app_router.dart';
import 'sync/sync_service.dart';

/// Orchestration hors écrans : session, temps réel, synchronisation,
/// cycle de vie, connectivité et notifications. Vit à la racine de l'app
/// (jamais mise en pause par Riverpod).
class AppCoordinator {
  AppCoordinator(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];
  late final SyncService _sync = SyncService(_ref);
  late final MessageEventHandler _messages = MessageEventHandler(_ref);

  DateTime? _pausedAt;
  Timer? _backgroundTimer;
  NotificationPayload? _pendingPayload;

  AppConfig get _config => _ref.read(appConfigProvider);

  bool get _authenticated =>
      _ref.read(sessionControllerProvider).isAuthenticated;

  void init() {
    _ref.listen(
      sessionControllerProvider.select((s) => s.status),
      (_, status) => unawaited(_onAuthStatus(status)),
      fireImmediately: true,
    );
    _ref.listen(connectivityProvider, (previous, next) {
      if (next.value == true && previous?.value == false) _onBackOnline();
    });
    // Le total non lu de l'accueil sert de valeur serveur fraîche.
    _ref.listen(moiProvider, (_, next) {
      final data = next.value;
      if (data == null || data.isStale) return;
      _ref
          .read(unreadCountProvider.notifier)
          .applyServer(data.value.messagesNonLus, data.updatedAt);
    });

    final realtime = _ref.read(realtimeServiceProvider);
    _subscriptions
      ..add(realtime.events.listen(_onRealtimeEvent))
      ..add(realtime.statusChanges.listen(_onRealtimeStatus))
      ..add(
        _ref.read(localNotificationServiceProvider).taps.listen(openPayload),
      );
  }

  /// Appelé par `AppEffects` à chaque changement de cycle de vie.
  void onLifecycle(AppLifecycleState state) {
    if (!_authenticated) return;
    switch (state) {
      case AppLifecycleState.paused:
        _pausedAt ??= DateTime.now();
        _sync.stop();
        unawaited(_markForeground(false));
        // Le WebSocket reste ouvert un moment : les messages reçus
        // donnent lieu à une notification locale.
        _backgroundTimer?.cancel();
        _backgroundTimer = Timer(_config.realtimeBackgroundGrace, () {
          AppLogger.debug('Realtime', 'Arrière-plan prolongé : fermeture');
          unawaited(_ref.read(realtimeServiceProvider).disconnect());
        });
      case AppLifecycleState.resumed:
        _backgroundTimer?.cancel();
        _backgroundTimer = null;
        final pausedAt = _pausedAt;
        _pausedAt = null;
        unawaited(_markForeground(true));
        // Notifications publiées entre-temps par la tâche d'arrière-plan.
        unawaited(_ref.read(notificationFeedProvider.notifier).reloadStored());
        _ref.read(realtimeServiceProvider).connect();
        final away = pausedAt == null
            ? Duration.zero
            : DateTime.now().difference(pausedAt);
        // Les sélecteurs de photo/fichier mettent aussi l'app en pause :
        // pas de rechargement pour une absence courte.
        if (away >= _config.resumeRefreshThreshold) {
          _sync.start(_config.syncInterval);
          unawaited(_ref.read(conversationsProvider.notifier).refresh());
        } else if (pausedAt != null) {
          _sync.start(_config.syncInterval);
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// « Réessayer » de la bannière hors connexion.
  void retryNow() {
    if (!_authenticated) return;
    _ref.read(realtimeServiceProvider).reconnect();
    unawaited(_sync.run());
  }

  /// Ouvre l'écran ciblé par une notification (après connexion si besoin).
  void openPayload(NotificationPayload payload) {
    final session = _ref.read(sessionControllerProvider).session;
    if (session == null) {
      _pendingPayload = payload;
      return;
    }
    final userId = payload.userId;
    if (userId != null && userId != session.idUtilisateur) {
      AppLogger.debug('Notifications', 'Notification d\'un autre compte');
      return;
    }
    _ref.read(routerProvider).push(payload.route);
  }

  Future<void> _onAuthStatus(AuthStatus status) async {
    switch (status) {
      case AuthStatus.authenticated:
        await _startSession();
      case AuthStatus.unauthenticated:
        await _endSession();
      case AuthStatus.unknown:
        break;
    }
  }

  Future<void> _startSession() async {
    AppLogger.debug('App', 'Session ouverte');
    _ref.read(realtimeServiceProvider).connect();
    _sync.start(_config.syncInterval);
    unawaited(_markForeground(true));
    unawaited(_ref.read(backgroundSchedulerProvider).schedule());
    unawaited(_ref.read(pushServiceProvider).initialize());
    unawaited(_askNotificationPermissionOnce());

    final notifications = _ref.read(localNotificationServiceProvider);
    final pending = _pendingPayload ?? notifications.takeLaunchPayload();
    _pendingPayload = null;
    if (pending != null) {
      // Laisse la redirection vers l'accueil se faire d'abord.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      openPayload(pending);
    }
  }

  Future<void> _endSession() async {
    AppLogger.debug('App', 'Session fermée : nettoyage');
    _sync.stop();
    _backgroundTimer?.cancel();
    _pausedAt = null;
    await _ref.read(realtimeServiceProvider).disconnect();
    await _ref.read(backgroundSchedulerProvider).cancel();
    await _markForeground(false);
    await _ref.read(localNotificationServiceProvider).cancelAll();
    await _ref.read(pushServiceProvider).unregister();
    await clearPreferencePrefixes(
      _ref.read(preferencesProvider),
      PreferenceKeys.userScopedPrefixes,
    );
    rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  }

  void _onBackOnline() {
    if (!_authenticated) return;
    AppLogger.debug('Réseau', 'Connexion rétablie');
    _ref.read(realtimeServiceProvider).reconnect();
    unawaited(_sync.run());
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    switch (event) {
      case MessageRealtimeEvent():
        _messages.handle(event);
      case RealtimePong():
        break;
      case UnknownRealtimeEvent(:final type):
        AppLogger.debug('Realtime', 'Événement ignoré : ${type ?? '?'}');
    }
  }

  void _onRealtimeStatus(RealtimeStatus status) {
    if (status != RealtimeStatus.connected || !_authenticated) return;
    // Rattrapage des messages manqués pendant la coupure.
    unawaited(_ref.read(unreadCountProvider.notifier).reconcile());
    unawaited(_ref.read(conversationsProvider.notifier).refresh());
  }

  /// Marqueur lu par la vérification en arrière-plan (autre isolat).
  Future<void> _markForeground(bool foreground) async {
    final prefs = _ref.read(preferencesProvider);
    try {
      if (foreground) {
        await prefs.setString(
          PreferenceKeys.foregroundSince,
          DateTime.now().toIso8601String(),
        );
      } else {
        await prefs.remove(PreferenceKeys.foregroundSince);
      }
    } on Exception catch (e) {
      AppLogger.warning('App', 'Marqueur de premier plan', e);
    }
  }

  Future<void> _askNotificationPermissionOnce() async {
    final prefs = _ref.read(preferencesProvider);
    if (await prefs.getBool(PreferenceKeys.permissionAsked) ?? false) return;
    await prefs.setBool(PreferenceKeys.permissionAsked, true);
    await _ref.read(localNotificationServiceProvider).requestPermission();
  }

  void dispose() {
    _backgroundTimer?.cancel();
    _sync.stop();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}

final appCoordinatorProvider = Provider<AppCoordinator>((ref) {
  final coordinator = AppCoordinator(ref)..init();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
