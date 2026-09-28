import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/features/incidents/domain/incident.dart';
import 'package:parkauto/features/missions/domain/mission.dart';
import 'package:parkauto/features/notifications/domain/app_notification.dart';
import 'package:parkauto/features/notifications/domain/change_detector.dart';
import 'package:parkauto/features/profile/domain/conducteur_profile.dart';
import 'package:parkauto/features/vehicle/domain/vehicule.dart';

import '../helpers/contract.dart';

List<Map<String, Object?>> _missionsJson() => [
  for (final m in Contract.response('Mes missions', '200')! as List<Object?>)
    m! as Map<String, Object?>,
];

void main() {
  final now = DateTime(2026, 9, 28, 12);

  group('Missions', () {
    test('première synchronisation : référence, aucune notification', () {
      final missions = Mission.listFromJson(_missionsJson());
      expect(ChangeDetector.missionChanges(null, missions, now: now), isEmpty);
    });

    test('nouvelle mission planifiée, annulation, modification', () {
      final before = ChangeDetector.snapshotMissions(
        Mission.listFromJson(_missionsJson()..removeAt(2)),
      );
      final json = _missionsJson();
      json[1]['statut'] = 'ANNULEE';
      json[0]['statut'] = 'TERMINEE'; // Transition faite par le conducteur.
      final after = Mission.listFromJson(json);

      final notifications = ChangeDetector.missionChanges(
        before,
        after,
        now: now,
      );
      expect(notifications.map((n) => n.title), [
        'Mission annulée',
        'Nouvelle mission',
      ]);
      expect(notifications.last.route, '/mission/94');

      final moved = _missionsJson();
      moved[2]['dateDebutPrevue'] = '2026-10-01T08:00:00';
      final modified = ChangeDetector.missionChanges(
        ChangeDetector.snapshotMissions(Mission.listFromJson(_missionsJson())),
        Mission.listFromJson(moved),
        now: now,
      );
      expect(modified.single.title, 'Mission modifiée');
    });
  });

  test('incident pris en charge puis clôturé', () {
    final incidents = Incident.listFromJson(
      Contract.response('Mes incidents', '200'),
    );
    final before = ChangeDetector.snapshotIncidents(incidents);
    final json = Contract.response('Mes incidents', '200')! as List<Object?>;
    (json.first! as Map<String, Object?>)['statut'] = 'EN_TRAITEMENT';

    final changes = ChangeDetector.incidentChanges(
      before,
      Incident.listFromJson(json),
      now: now,
    );
    expect(changes.single.title, 'Incident pris en charge');
    expect(changes.single.kind, AppNotificationKind.incident);
    expect(ChangeDetector.incidentChanges(null, incidents, now: now), isEmpty);
  });

  test('alertes et échéances : identifiants stables (dédoublonnage)', () {
    final vehicle = VehiculeDetails.fromJson(
      Contract.response('Mon véhicule', '200'),
    );
    final first = ChangeDetector.vehicleAlerts(vehicle.alertes);
    final second = ChangeDetector.vehicleAlerts(vehicle.alertes);
    expect(first.map((n) => n.id), second.map((n) => n.id));
    expect(first, hasLength(2));

    final documents = ChangeDetector.documentExpiries(
      vehicle.documents,
      now: now,
    );
    // ASSURANCE (BIENTOT) et CONFORMITE_FISCALE (EXPIRE).
    expect(documents.map((n) => n.title), [
      'Document bientôt expiré · Assurance',
      'Document expiré · Conformité fiscale',
    ]);

    final profile = ConducteurProfile.fromJson(
      Contract.response('Profil', '200'),
    );
    expect(
      ChangeDetector.qualificationExpiry(profile.qualification, now: now)
          .single
          .body,
      'Expire dans 17 jours',
    );
  });
}
