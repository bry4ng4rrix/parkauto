import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:parkauto/app/app.dart';
import 'package:parkauto/core/api/api_endpoints.dart';

import '../test/helpers/fake_backend.dart';
import '../test/helpers/test_app.dart';

/// Faux backend avec état : la mission 91 passe de PLANIFIEE à EN_COURS
/// puis TERMINEE. Les formes JSON suivent `appli-conducteur-reponses.json`.
class _FleetBackend {
  _FleetBackend() {
    backend
      ..json('POST', ApiEndpoints.connexion, 200, _auth)
      ..on('GET', ApiEndpoints.moi, (_) => FakeReply.json(200, _moi()))
      ..on('GET', ApiEndpoints.missions, (_) => FakeReply.json(200, [_mission]))
      ..on('POST', ApiEndpoints.demarrerMission(91), (r) {
        final km = (r.json! as Map<String, Object?>)['kilometrage'];
        _mission = {
          ..._mission,
          'statut': 'EN_COURS',
          'dateDebutReelle': '2026-09-29T06:34:18',
          'kilometrageDepart': km,
        };
        return FakeReply.json(200, _mission);
      })
      ..on('POST', ApiEndpoints.terminerMission(91), (r) {
        final km = (r.json! as Map<String, Object?>)['kilometrage'];
        _mission = {
          ..._mission,
          'statut': 'TERMINEE',
          'dateFinReelle': '2026-09-29T11:52:03',
          'kilometrageRetour': km,
        };
        return FakeReply.json(200, _mission);
      })
      ..json('GET', ApiEndpoints.vehicule, 404, {
        'horodatage': '2026-09-28T09:31:02.418Z',
        'statut': 404,
        'erreur': 'Ressource introuvable',
        'message': 'Aucun véhicule ne vous est affecté actuellement',
        'details': <String>[],
      })
      ..json('GET', ApiEndpoints.pleins, 200, <Object?>[])
      ..json('GET', ApiEndpoints.incidents, 200, <Object?>[])
      ..json('GET', ApiEndpoints.conversations, 200, <Object?>[])
      ..json('GET', ApiEndpoints.nonLus, 200, {'total': 0})
      ..json('POST', ApiEndpoints.ticketTempsReel, 200, {
        'ticket': 'ticket-test',
        'expireDansSecondes': 30,
      });
  }

  final backend = FakeBackend();

  Map<String, Object?> _mission = {
    'idMission': 91,
    'motif': 'Transport équipe chantier Ambohidratrimo',
    'statut': 'PLANIFIEE',
    'dateDebutPrevue': '2026-09-29T06:30:00',
    'dateFinPrevue': '2026-09-29T12:00:00',
    'dateDebutReelle': null,
    'dateFinReelle': null,
    'kilometrageDepart': null,
    'kilometrageRetour': null,
    'idEngin': 4,
    'vehicule': '1234 TAB — Toyota Hilux',
  };

  static const _auth = {
    'jetonAcces': 'access-test',
    'typeJeton': 'Bearer',
    'expireDans': 3600,
    'jetonRafraichissement': 'refresh-test',
    'expirationRafraichissement': '2026-10-28T09:30:00Z',
    'role': 'CONDUCTEUR',
    'idConducteur': 12,
    'nomComplet': 'Tiana RABE',
  };

  Map<String, Object?> _moi() => {
    'profil': {
      'idConducteur': 12,
      'matricule': 'C-012',
      'nom': 'RABE',
      'prenom': 'Tiana',
      'telephone': '034 12 345 67',
      'email': 'conducteur@exemple.mg',
      'categorie': 'VEHICULE_ROUTIER',
      'statut': 'EN_SERVICE',
      'qualification': null,
    },
    'vehicule': null,
    'missionEnCours': _mission['statut'] == 'EN_COURS' ? _mission : null,
    'prochainesMissions': _mission['statut'] == 'PLANIFIEE' ? [_mission] : [],
    'messagesNonLus': 0,
    'alertesVehicule': 0,
  };
}

Future<void> _settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _completeMissionAction(
  WidgetTester tester, {
  required String openLabel,
  required String sheetLabel,
  required String confirmLabel,
  required String kilometrage,
}) async {
  await tester.tap(find.text(openLabel));
  await _settle(tester);
  await tester.enterText(find.byType(TextFormField).last, kilometrage);
  await tester.tap(find.widgetWithText(FilledButton, sheetLabel).last);
  await _settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, confirmLabel).last);
  await _settle(tester, 30);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connexion → accueil → démarrer → terminer une mission', (
    tester,
  ) async {
    Intl.defaultLocale = 'fr';
    await initializeDateFormatting('fr');
    useInMemoryPreferences();
    final fleet = _FleetBackend();

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: testOverrides(
          backend: fleet.backend,
          store: InMemorySessionStore(),
        ),
        child: const ParkAutoApp(),
      ),
    );
    await _settle(tester);

    // Connexion
    expect(find.text('Connexion'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'conducteur@exemple.mg',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'mot-de-passe');
    await tester.tap(find.text('Se connecter'));
    await _settle(tester, 40);

    // Accueil
    expect(find.text('Bonjour Tiana'), findsOneWidget);
    expect(find.text('Transport équipe chantier Ambohidratrimo'), findsWidgets);

    // Démarrer
    await _completeMissionAction(
      tester,
      openLabel: 'Démarrer la mission',
      sheetLabel: 'Démarrer la mission',
      confirmLabel: 'Démarrer',
      kilometrage: '84360',
    );
    expect(
      fleet.backend.calls('POST', ApiEndpoints.demarrerMission(91)).single.json,
      {'kilometrage': 84360.0},
    );
    expect(find.text('Mission en cours'), findsOneWidget);

    // Terminer
    await _completeMissionAction(
      tester,
      openLabel: 'Terminer la mission',
      sheetLabel: 'Terminer la mission',
      confirmLabel: 'Terminer',
      kilometrage: '84512',
    );
    expect(
      fleet.backend.calls('POST', ApiEndpoints.terminerMission(91)).single.json,
      {'kilometrage': 84512.0},
    );
    expect(find.text('Aucune mission en cours ni planifiée.'), findsOneWidget);
  });
}
