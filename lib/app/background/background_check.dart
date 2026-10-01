import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/auth/session_controller.dart';
import '../../core/auth/session_store.dart';
import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../core/notifications/local_notification_service.dart';
import '../../core/storage/preferences.dart';
import '../../features/messaging/application/message_event_handler.dart';
import '../../features/messaging/application/own_message.dart';
import '../../features/messaging/data/messaging_repository.dart';
import '../../features/notifications/data/notification_feed.dart';
import '../../features/notifications/domain/app_notification.dart';
import '../sync/sync_service.dart';
import 'background_scheduler.dart';

/// Résultat d'une vérification en arrière-plan.
enum BackgroundCheckResult {
  /// Données vérifiées, notifications publiées si nécessaire.
  done,

  /// L'application est au premier plan : elle s'en charge elle-même.
  skippedForeground,

  /// Plus de session : la tâche périodique n'a plus lieu d'être.
  signedOut,
}

/// Vérification lancée par WorkManager, application fermée ou en
/// arrière-plan : mêmes contrôles que la synchronisation au premier plan,
/// plus les nouveaux messages, publiés en notifications Android.
///
/// Le backend n'envoie pas de push : sans FCM, c'est le seul moyen de
/// prévenir le conducteur quand l'app n'est pas ouverte (au mieux toutes
/// les 15 minutes, selon Android).
class BackgroundCheck {
  BackgroundCheck(this._ref);

  final Ref _ref;

  /// Au-delà, le marqueur « au premier plan » est considéré comme périmé
  /// (app tuée sans passer en pause).
  static const foregroundMarkerValidity = Duration(hours: 1);

  /// Messages plus anciens ignorés à la première vérification : pas de
  /// rafale de notifications pour des messages d'hier.
  static const firstCheckWindow = Duration(hours: 1);

  /// Messages lus par conversation (les plus récents).
  static const maxMessagesPerConversation = 5;

  Future<BackgroundCheckResult> run() async {
    final controller = _ref.read(sessionControllerProvider.notifier);
    await controller.restore();
    final session = controller.session;
    if (session == null) return BackgroundCheckResult.signedOut;
    if (await _appInForeground()) {
      AppLogger.debug('Arrière-plan', 'App au premier plan : rien à faire');
      return BackgroundCheckResult.skippedForeground;
    }

    AppLogger.debug('Arrière-plan', 'Vérification');
    await _ref.read(notificationFeedProvider.notifier).ensureLoaded();
    await SyncService(_ref).run();
    await _checkMessages(session.idConducteur);
    return BackgroundCheckResult.done;
  }

  Future<bool> _appInForeground() async {
    final raw = await _ref
        .read(preferencesProvider)
        .getString(PreferenceKeys.foregroundSince);
    final since = raw == null ? null : DateTime.tryParse(raw);
    return since != null &&
        DateTime.now().difference(since) < foregroundMarkerValidity;
  }

  /// Messages reçus depuis la dernière vérification, dans les conversations
  /// non lues. Même identifiant qu'en temps réel : jamais de doublon.
  Future<void> _checkMessages(int driverId) async {
    final prefs = _ref.read(preferencesProvider);
    final key = 'sync.$driverId.messagesCheckedAt';
    final startedAt = DateTime.now();
    final stored = await prefs.getString(key);
    final since =
        (stored == null ? null : DateTime.tryParse(stored)) ??
        startedAt.subtract(firstCheckWindow);

    final repository = _ref.read(messagingRepositoryProvider);
    final isMine = _ref.read(ownMessageMatcherProvider);
    final found = <AppNotification>[];
    try {
      final conversations = await repository.conversations();
      for (final conversation in conversations) {
        final last = conversation.dateDernierMessage;
        if (conversation.nonLus == 0 ||
            (last != null && last.isBefore(since))) {
          continue;
        }
        try {
          final messages = await repository.messages(
            conversation.idConversation,
            limite: math.min(conversation.nonLus, maxMessagesPerConversation),
          );
          for (final message in messages) {
            if (isMine(message) || message.dateEnvoi.isBefore(since)) continue;
            found.add(messageNotification(message, conversation));
          }
        } on AppException catch (e) {
          AppLogger.debug(
            'Arrière-plan',
            'Messages de ${conversation.idConversation} non lus : $e',
          );
        }
      }
    } on AppException catch (e) {
      AppLogger.debug('Arrière-plan', 'Conversations non lues : $e');
      return;
    }

    if (found.isNotEmpty) {
      await _ref.read(notificationFeedProvider.notifier).addAll(found);
    }
    await prefs.setString(key, startedAt.toIso8601String());
  }
}

final backgroundCheckProvider = Provider<BackgroundCheck>(BackgroundCheck.new);

/// Point d'entrée de WorkManager (moteur Flutter séparé, sans interface).
@pragma('vm:entry-point')
void backgroundCheckDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != WorkmanagerBackgroundScheduler.taskName) return true;
    final result = await runBackgroundCheck();
    if (result == BackgroundCheckResult.signedOut) {
      await Workmanager().cancelByUniqueName(
        WorkmanagerBackgroundScheduler.uniqueName,
      );
    }
    // Un échec réseau n'est pas réessayé : la prochaine période suffit.
    return true;
  });
}

/// Prépare l'isolat d'arrière-plan comme `main`, puis vérifie.
Future<BackgroundCheckResult> runBackgroundCheck() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'fr';
  await initializeDateFormatting('fr');

  final notifications = PluginLocalNotificationService();
  await notifications.initialize();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      preferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      sessionStoreProvider.overrideWithValue(SecureSessionStore()),
      localNotificationServiceProvider.overrideWithValue(notifications),
    ],
  );
  try {
    return await container.read(backgroundCheckProvider).run();
  } on Object catch (e, stack) {
    AppLogger.error('Arrière-plan', 'Vérification interrompue', e, stack);
    return BackgroundCheckResult.done;
  } finally {
    container.dispose();
  }
}
