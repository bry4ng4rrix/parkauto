import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/preferences.dart';
import '../../features/home/data/moi_repository.dart';
import '../../features/incidents/data/incidents_repository.dart';
import '../../features/messaging/application/unread_counter.dart';
import '../../features/missions/data/missions_repository.dart';
import '../../features/notifications/data/notification_feed.dart';
import '../../features/notifications/domain/app_notification.dart';
import '../../features/notifications/domain/change_detector.dart';
import '../../features/vehicle/data/vehicle_repository.dart';
import '../../features/vehicle/domain/vehicule.dart';

/// Synchronisation au premier plan : au login, au retour dans l'app et
/// périodiquement. Alimente les données et les notifications déduites.
class SyncService {
  SyncService(this._ref);

  final Ref _ref;
  Timer? _timer;
  bool _running = false;

  void start(Duration interval) {
    stop();
    _timer = Timer.periodic(interval, (_) => unawaited(run()));
    unawaited(run());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> run() async {
    if (_running) return;
    final driverId = _ref.read(currentDriverIdProvider);
    if (driverId == null) return;
    _running = true;
    try {
      AppLogger.debug('Sync', 'Synchronisation');
      final errors = await Future.wait([
        _ref.read(moiProvider.notifier).refresh(),
        _ref.read(missionsProvider.notifier).refresh(),
        _ref.read(incidentsProvider.notifier).refresh(),
        _ref.read(vehicleProvider.notifier).refresh(),
      ]);
      unawaited(_ref.read(unreadCountProvider.notifier).reconcile());
      if (_ref.read(currentDriverIdProvider) != driverId) return;
      await _detectChanges(
        driverId,
        moiOk: errors[0] == null,
        missionsOk: errors[1] == null,
        incidentsOk: errors[2] == null,
        vehicleOk: errors[3] == null,
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _detectChanges(
    int driverId, {
    required bool moiOk,
    required bool missionsOk,
    required bool incidentsOk,
    required bool vehicleOk,
  }) async {
    final prefs = _ref.read(preferencesProvider);
    final now = DateTime.now();
    final found = <AppNotification>[];

    final missions = _ref.read(missionsProvider).value;
    if (missionsOk && missions != null) {
      final key = 'sync.$driverId.missions';
      final previous = await _readMap(key, MissionSnapshot.fromJson);
      found.addAll(
        ChangeDetector.missionChanges(previous, missions.value, now: now),
      );
      await prefs.setString(
        key,
        jsonEncode({
          for (final e in ChangeDetector.snapshotMissions(
            missions.value,
          ).entries)
            '${e.key}': e.value.toJson(),
        }),
      );
    }

    final incidents = _ref.read(incidentsProvider).value;
    if (incidentsOk && incidents != null) {
      final key = 'sync.$driverId.incidents';
      final previous = await _readMap(key, (v) => v is String ? v : null);
      found.addAll(
        ChangeDetector.incidentChanges(previous, incidents.value, now: now),
      );
      await prefs.setString(
        key,
        jsonEncode({
          for (final e in ChangeDetector.snapshotIncidents(
            incidents.value,
          ).entries)
            '${e.key}': e.value,
        }),
      );
    }

    if (vehicleOk) {
      if (_ref.read(vehicleProvider).value?.value case VehicleAssigned(
        :final details,
      )) {
        found
          ..addAll(ChangeDetector.vehicleAlerts(details.alertes))
          ..addAll(
            ChangeDetector.documentExpiries(details.documents, now: now),
          );
      }
    }

    final moi = _ref.read(moiProvider).value;
    if (moiOk && moi != null) {
      found.addAll(
        ChangeDetector.qualificationExpiry(
          moi.value.profil.qualification,
          now: now,
        ),
      );
    }

    if (found.isNotEmpty) {
      await _ref.read(notificationFeedProvider.notifier).addAll(found);
    }
  }

  /// Référence mémorisée, ou `null` à la première synchronisation.
  Future<Map<int, T>?> _readMap<T>(
    String key,
    T? Function(Object? json) parse,
  ) async {
    final raw = await _ref.read(preferencesProvider).getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final result = <int, T>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse('${entry.key}');
        final value = parse(entry.value);
        if (id != null && value != null) result[id] = value;
      }
      return result;
    } on FormatException {
      return null;
    }
  }
}
