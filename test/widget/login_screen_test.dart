import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/core/auth/session_controller.dart';
import 'package:parkauto/features/authentication/presentation/login_screen.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/pump.dart';

void main() {
  testWidgets('validation des champs', (tester) async {
    await pumpScreen(tester, const LoginScreen(), backend: FakeBackend());

    await tester.tap(find.text('Se connecter'));
    await settle(tester);

    expect(find.text("L'email est obligatoire"), findsOneWidget);
    expect(find.text('Le mot de passe est obligatoire'), findsOneWidget);
  });

  testWidgets('identifiants refusés : message du backend affiché', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..json(
        'POST',
        ApiEndpoints.connexion,
        401,
        Contract.response('Connexion', '401'),
      );
    await pumpScreen(tester, const LoginScreen(), backend: backend);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'tiana@parcauto.local',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'mauvais');
    await tester.tap(find.text('Se connecter'));
    await settle(tester);

    expect(find.text('Email ou mot de passe incorrect'), findsOneWidget);
  });

  testWidgets('connexion réussie : session ouverte, appareil envoyé', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..json(
        'POST',
        ApiEndpoints.connexion,
        200,
        Contract.response('Connexion', '200'),
      );
    final container = await pumpScreen(
      tester,
      const LoginScreen(),
      backend: backend,
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      ' tiana.rabe@parcauto.local ',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('Se connecter'));
    await settle(tester);

    expect(backend.calls('POST', ApiEndpoints.connexion).single.json, {
      'email': 'tiana.rabe@parcauto.local',
      'motDePasse': 'secret',
      'appareil': 'Flutter',
    });
    final session = container.read(sessionControllerProvider).session;
    expect(session?.idConducteur, 12);
    expect(session?.idUtilisateur, 27);
  });
}
