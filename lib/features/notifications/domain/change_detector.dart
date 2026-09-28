import 'package:flutter/foundation.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/domain/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../incidents/domain/incident.dart';
import '../../missions/domain/mission.dart';
import '../../profile/domain/conducteur_profile.dart';
import '../../vehicle/domain/vehicule.dart';
import 'app_notification.dart';

/// État mémorisé d'une mission pour détecter ses changements.
@immutable
class MissionSnapshot {
  const MissionSnapshot({
    required this.statut,
    required this.debut,
    required this.fin,
    required this.motif,
  });

  factory MissionSnapshot.of(Mission m) => MissionSnapshot(
    statut: m.statut.apiValue,
    debut: m.dateDebutPrevue.toIso8601String(),
    fin: m.dateFinPrevue.toIso8601String(),
    motif: m.motif,
  );

  static MissionSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final (statut, debut, fin, motif) = (
      json['statut'],
      json['debut'],
      json['fin'],
      json['motif'],
    );
    if (statut is! String ||
        debut is! String ||
        fin is! String ||
        motif is! String) {
      return null;
    }
    return MissionSnapshot(
      statut: statut,
      debut: debut,
      fin: fin,
      motif: motif,
    );
  }

  final String statut;
  final String debut;
  final String fin;
  final String motif;

  Map<String, Object?> toJson() => {
    'statut': statut,
    'debut': debut,
    'fin': fin,
    'motif': motif,
  };
}

/// Notifications déduites des données : le backend n'émet d'événement
/// temps réel que pour les messages. Les changements sont détectés à la
/// synchronisation (pas en temps réel). La première synchronisation sert
/// de référence et ne produit aucune notification.
abstract final class ChangeDetector {
  static Map<int, MissionSnapshot> snapshotMissions(List<Mission> missions) => {
    for (final m in missions) m.idMission: MissionSnapshot.of(m),
  };

  static List<AppNotification> missionChanges(
    Map<int, MissionSnapshot>? previous,
    List<Mission> current, {
    required DateTime now,
  }) {
    if (previous == null) return const [];
    final result = <AppNotification>[];
    for (final m in current) {
      final before = previous[m.idMission];
      final when = AppFormat.dateTime(m.dateDebutPrevue);
      if (before == null) {
        if (m.statut == StatutMission.planifiee) {
          result.add(
            AppNotification(
              id: 'mission:nouvelle:${m.idMission}',
              kind: AppNotificationKind.mission,
              title: 'Nouvelle mission',
              body: '${m.motif} · $when',
              createdAt: now,
              route: AppRoutes.mission(m.idMission),
            ),
          );
        }
        continue;
      }
      final after = MissionSnapshot.of(m);
      if (before.statut != after.statut && m.statut == StatutMission.annulee) {
        result.add(
          AppNotification(
            id: 'mission:annulee:${m.idMission}',
            kind: AppNotificationKind.mission,
            title: 'Mission annulée',
            body: m.motif,
            createdAt: now,
            route: AppRoutes.mission(m.idMission),
          ),
        );
      } else if (m.statut == StatutMission.planifiee &&
          (before.debut != after.debut ||
              before.fin != after.fin ||
              before.motif != after.motif)) {
        result.add(
          AppNotification(
            id: 'mission:modifiee:${m.idMission}:${after.debut}:${after.fin}',
            kind: AppNotificationKind.mission,
            title: 'Mission modifiée',
            body: '${m.motif} · $when',
            createdAt: now,
            route: AppRoutes.mission(m.idMission),
          ),
        );
      }
    }
    return result;
  }

  static Map<int, String> snapshotIncidents(List<Incident> incidents) => {
    for (final i in incidents) i.idIncident: i.statut.apiValue,
  };

  static List<AppNotification> incidentChanges(
    Map<int, String>? previous,
    List<Incident> current, {
    required DateTime now,
  }) {
    if (previous == null) return const [];
    final result = <AppNotification>[];
    for (final i in current) {
      final before = previous[i.idIncident];
      if (before == null || before == i.statut.apiValue) continue;
      final title = switch (i.statut) {
        StatutIncident.enTraitement => 'Incident pris en charge',
        StatutIncident.cloture => 'Incident clôturé',
        _ => null,
      };
      if (title == null) continue;
      result.add(
        AppNotification(
          id: 'incident:${i.idIncident}:${i.statut.apiValue}',
          kind: AppNotificationKind.incident,
          title: title,
          body: '${i.type.label} · ${_short(i.description)}',
          createdAt: now,
          route: AppRoutes.incident(i.idIncident),
        ),
      );
    }
    return result;
  }

  static List<AppNotification> vehicleAlerts(List<VehiculeAlert> alerts) => [
    for (final a in alerts)
      AppNotification(
        id: 'alerte:${a.type.apiValue}:${a.premiereOccurrence.toIso8601String()}',
        kind: AppNotificationKind.vehicleAlert,
        title: 'Alerte véhicule · ${a.type.label}',
        body: a.description,
        createdAt: a.derniereOccurrence,
        route: AppRoutes.vehicle,
      ),
  ];

  static List<AppNotification> documentExpiries(
    List<VehiculeDocument> documents, {
    required DateTime now,
  }) => [
    for (final d in documents)
      if (d.niveau.needsAttention)
        AppNotification(
          id:
              'echeance:document:${d.type.apiValue}:'
              '${d.dateExpiration?.toIso8601String()}:${d.niveau.apiValue}',
          kind: AppNotificationKind.expiry,
          title: d.niveau == NiveauEcheance.expire
              ? 'Document expiré · ${d.type.label}'
              : 'Document bientôt expiré · ${d.type.label}',
          body: _remaining(d.joursRestants, d.dateExpiration),
          createdAt: now,
          route: AppRoutes.vehicle,
        ),
  ];

  static List<AppNotification> qualificationExpiry(
    Qualification? qualification, {
    required DateTime now,
  }) {
    if (qualification == null || !qualification.niveau.needsAttention) {
      return const [];
    }
    return [
      AppNotification(
        id:
            'echeance:qualification:${qualification.numero}:'
            '${qualification.dateExpiration?.toIso8601String()}:'
            '${qualification.niveau.apiValue}',
        kind: AppNotificationKind.expiry,
        title: qualification.niveau == NiveauEcheance.expire
            ? '${qualification.type.label} expiré'
            : '${qualification.type.label} bientôt expiré',
        body: _remaining(
          qualification.joursRestants,
          qualification.dateExpiration,
        ),
        createdAt: now,
        route: AppRoutes.profile,
      ),
    ];
  }

  static String _remaining(int? days, DateTime? date) {
    if (days != null) return AppFormat.remainingDays(days);
    if (date != null) return 'Échéance le ${AppFormat.date(date)}';
    return 'Échéance à vérifier';
  }

  static String _short(String text) =>
      text.length <= 80 ? text : '${text.substring(0, 79)}…';
}
