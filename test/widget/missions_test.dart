import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/core/domain/enums.dart';
import 'package:parkauto/features/missions/data/missions_repository.dart';
import 'package:parkauto/features/missions/presentation/mission_list_screen.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/pump.dart';
import '../helpers/test_app.dart';

FakeBackend _backend() => FakeBackend()
  ..json(
    'GET',
    ApiEndpoints.missions,
    200,
    Contract.response('Mes missions', '200'),
  )
  ..json(
    'GET',
    ApiEndpoints.vehicule,
    200,
    Contract.response('Mon véhicule', '200'),
  )
  ..json('GET', ApiEndpoints.moi, 200, Contract.response('Accueil', '200'));

Future<void> _openStartSheet(WidgetTester tester) async {
  final start = find.widgetWithText(FilledButton, 'Démarrer').first;
  await tester.ensureVisible(start);
  await tester.tap(start);
  await settle(tester);
}

void main() {
  testWidgets('filtres avec compteurs', (tester) async {
    await pumpScreen(
      tester,
      const MissionListScreen(),
      backend: _backend(),
      session: testSession(),
    );

    expect(find.text('Toutes · 5'), findsOneWidget);
    expect(find.text('Livraison ciment chantier Tanjombato'), findsOneWidget);

    await tester.tap(find.text('Planifiées · 2'));
    await settle(tester);

    expect(
      find.text('Transport équipe chantier Ambohidratrimo'),
      findsOneWidget,
    );
    expect(find.text('Livraison ciment chantier Tanjombato'), findsNothing);
    expect(find.text('Livraison matériaux chantier Ivato'), findsNothing);
  });

  testWidgets('démarrer : kilométrage validé avant envoi', (tester) async {
    final backend = _backend();
    await pumpScreen(
      tester,
      const MissionListScreen(),
      backend: backend,
      session: testSession(),
    );
    await _openStartSheet(tester);

    expect(find.text('Démarrer la mission'), findsWidgets);
    final field = find.byType(TextFormField);
    await tester.enterText(field, '84100');
    await tester.tap(find.widgetWithText(FilledButton, 'Démarrer la mission'));
    await settle(tester);

    expect(
      find.text(
        'Ne peut pas être inférieur au kilométrage actuel du véhicule '
        '(84 230 km)',
      ),
      findsOneWidget,
    );
    expect(backend.calls('POST', ApiEndpoints.demarrerMission(91)), isEmpty);
  });

  testWidgets('démarrer : confirmation puis 409 affiché tel quel', (
    tester,
  ) async {
    final backend = _backend()
      ..json(
        'POST',
        ApiEndpoints.demarrerMission(91),
        409,
        Contract.response('Démarrer une mission', '409 (assurance)'),
      );
    await pumpScreen(
      tester,
      const MissionListScreen(),
      backend: backend,
      session: testSession(),
    );
    await _openStartSheet(tester);

    await tester.enterText(find.byType(TextFormField), '84360');
    await tester.tap(find.widgetWithText(FilledButton, 'Démarrer la mission'));
    await settle(tester);
    expect(find.text('Démarrer la mission'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Démarrer').last);
    await settle(tester);

    expect(
      backend.calls('POST', ApiEndpoints.demarrerMission(91)).single.json,
      {'kilometrage': 84360.0},
    );
    expect(
      find.text(
        "L'engin '1234 TAB — Toyota Hilux' n'a pas d'assurance valide, la "
        'mission ne peut pas démarrer (règle 11.20)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('démarrer : succès, mission mise à jour', (tester) async {
    final backend = _backend()
      ..json(
        'POST',
        ApiEndpoints.demarrerMission(91),
        200,
        Contract.response('Démarrer une mission', '200'),
      );
    final container = await pumpScreen(
      tester,
      const MissionListScreen(),
      backend: backend,
      session: testSession(),
    );
    await _openStartSheet(tester);
    await tester.enterText(find.byType(TextFormField), '84360');
    await tester.tap(find.widgetWithText(FilledButton, 'Démarrer la mission'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Démarrer').last);
    await settle(tester, 20);

    expect(find.text('Mission démarrée'), findsOneWidget);
    // La réponse du serveur remplace la mission dans la liste.
    final missions = container.read(missionsProvider).value?.value ?? [];
    expect(
      missions.firstWhere((m) => m.idMission == 91).statut,
      StatutMission.enCours,
    );
  });
}
