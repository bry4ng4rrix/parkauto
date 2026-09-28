import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/features/incidents/presentation/incident_create_screen.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/pump.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('boutons photo : caméra directe et galerie', (tester) async {
    await pumpScreen(
      tester,
      const IncidentCreateScreen(),
      backend: FakeBackend(),
      session: testSession(),
    );

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Galerie'), findsOneWidget);
  });

  testWidgets('description obligatoire', (tester) async {
    final backend = FakeBackend();
    await pumpScreen(
      tester,
      const IncidentCreateScreen(),
      backend: backend,
      session: testSession(),
    );

    final submit = find.text("Déclarer l'incident");
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await settle(tester);

    expect(find.text("Décrivez ce qui s'est passé"), findsOneWidget);
    expect(backend.calls('POST', ApiEndpoints.incidents), isEmpty);
  });

  testWidgets('déclaration envoyée puis ouverture du détail', (tester) async {
    final backend = FakeBackend()
      ..json(
        'POST',
        ApiEndpoints.incidents,
        201,
        Contract.response('Déclarer un incident', '201'),
      )
      ..json('GET', ApiEndpoints.incidents, 200, Contract.response('Mes incidents', '200'));
    await pumpScreen(
      tester,
      const IncidentCreateScreen(),
      backend: backend,
      session: testSession(),
    );

    await tester.tap(find.text('Accident'));
    await tester.tap(find.text('Critique'));
    await tester.enterText(
      find.byType(TextFormField),
      'Choc à l’arrière au feu rouge',
    );
    final submit = find.text("Déclarer l'incident");
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await settle(tester);

    expect(backend.calls('POST', ApiEndpoints.incidents).single.json, {
      'type': 'ACCIDENT',
      'gravite': 'CRITIQUE',
      'description': 'Choc à l’arrière au feu rouge',
    });
    expect(find.text('route:/incidents/57'), findsOneWidget);
  });

  testWidgets('erreur 403 affichée telle quelle', (tester) async {
    final backend = FakeBackend()
      ..json(
        'POST',
        ApiEndpoints.incidents,
        403,
        Contract.response('Déclarer un incident', '403'),
      );
    await pumpScreen(
      tester,
      const IncidentCreateScreen(),
      backend: backend,
      session: testSession(),
    );

    await tester.enterText(find.byType(TextFormField), 'Pneu crevé');
    final submit = find.text("Déclarer l'incident");
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await settle(tester);
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await settle(tester);

    expect(
      find.text('Ce véhicule ne vous est pas affecté actuellement'),
      findsOneWidget,
    );
  });
}
