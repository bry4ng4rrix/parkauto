import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/logging/app_logger.dart';
import 'background_check.dart';

/// Planification de la vérification périodique en arrière-plan.
abstract interface class BackgroundScheduler {
  /// À appeler une fois au démarrage, avant [schedule].
  Future<void> initialize();

  /// Session ouverte : vérification toutes les 15 minutes environ.
  Future<void> schedule();

  /// Déconnexion : plus aucune vérification.
  Future<void> cancel();
}

/// WorkManager Android : la tâche survit à la fermeture de l'app et au
/// redémarrage du téléphone ; Android décide du moment exact (économie de
/// batterie, réseau disponible).
class WorkmanagerBackgroundScheduler implements BackgroundScheduler {
  static const uniqueName = 'parkauto.verification';
  static const taskName = 'verificationNotifications';

  /// Minimum imposé par Android pour une tâche périodique.
  static const frequency = Duration(minutes: 15);

  bool _ready = false;

  @override
  Future<void> initialize() async {
    try {
      await Workmanager().initialize(backgroundCheckDispatcher);
      _ready = true;
    } on Object catch (e) {
      AppLogger.warning('Arrière-plan', 'WorkManager indisponible', e);
    }
  }

  @override
  Future<void> schedule() async {
    if (!_ready) return;
    try {
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: frequency,
        initialDelay: frequency,
        constraints: Constraints(networkType: NetworkType.connected),
        // Déjà planifiée (session restaurée) : on garde le rythme en cours.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      AppLogger.debug('Arrière-plan', 'Vérification périodique planifiée');
    } on Object catch (e) {
      AppLogger.warning('Arrière-plan', 'Planification impossible', e);
    }
  }

  @override
  Future<void> cancel() async {
    if (!_ready) return;
    try {
      await Workmanager().cancelByUniqueName(uniqueName);
    } on Object catch (e) {
      AppLogger.warning('Arrière-plan', 'Annulation impossible', e);
    }
  }
}

/// Autres plateformes (Linux de test) : rien en arrière-plan.
class NoopBackgroundScheduler implements BackgroundScheduler {
  const NoopBackgroundScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule() async {}

  @override
  Future<void> cancel() async {}
}

BackgroundScheduler createBackgroundScheduler() => !kIsWeb && Platform.isAndroid
    ? WorkmanagerBackgroundScheduler()
    : const NoopBackgroundScheduler();

final backgroundSchedulerProvider = Provider<BackgroundScheduler>(
  (ref) => const NoopBackgroundScheduler(),
);
