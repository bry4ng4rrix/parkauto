import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/features/home/presentation/home_screen.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/pump.dart';
import '../helpers/test_app.dart';

FakeBackend _backend(Object? moi, {int moiStatus = 200}) => FakeBackend()
  ..json('GET', ApiEndpoints.moi, moiStatus, moi)
  ..json('GET', ApiEndpoints.pleins, 200, Contract.response('Mes saisies carburant', '200'))
  ..json('GET', ApiEndpoints.incidents, 200, Contract.response('Mes incidents', '200'))
  ..json('GET', ApiEndpoints.vehicule, 200, Contract.response('Mon véhicule', '200'))
  ..json('GET', ApiEndpoints.nonLus, 200, {'total': 3});

void main() {
  testWidgets('tableau de bord complet', (tester) async {
    await pumpScreen(
      tester,
      const HomeScreen(),
      backend: _backend(Contract.response('Accueil', '200')),
      session: testSession(),
    );

    expect(find.text('Bonjour Tiana'), findsOneWidget);
    expect(find.text('Mission en cours'), findsOneWidget);
    expect(find.text('Livraison matériaux chantier Ivato'), findsOneWidget);
    expect(find.text('Terminer la mission'), findsOneWidget);
    expect(find.text('1234 TAB'), findsOneWidget);
    expect(find.text('2 alertes actives'), findsOneWidget);
    expect(find.text('2 missions à venir'), findsOneWidget);
    expect(find.textContaining('Permis de conduire · Expire dans 17'), findsOneWidget);
  });

  testWidgets('sans véhicule ni mission', (tester) async {
    await pumpScreen(
      tester,
      const HomeScreen(),
      backend: _backend(
        Contract.response('Accueil', '200 (sans véhicule ni mission)'),
      ),
      session: testSession(),
    );

    expect(find.text('Prochaine mission'), findsOneWidget);
    expect(find.text('Aucune mission en cours ni planifiée.'), findsOneWidget);
    expect(
      find.text('Aucun véhicule ne vous est affecté actuellement'),
      findsOneWidget,
    );
  });

  testWidgets('compte non relié (403) : écran bloquant', (tester) async {
    await pumpScreen(
      tester,
      const HomeScreen(),
      backend: _backend(
        Contract.response('Accueil', '403 (compte non relié)'),
        moiStatus: 403,
      ),
      session: testSession(),
    );

    expect(find.text('Accès impossible'), findsOneWidget);
    expect(
      find.text(
        "Votre compte n'est relié à aucune fiche conducteur : contactez le "
        'responsable du parc',
      ),
      findsOneWidget,
    );
    expect(find.text('Se déconnecter'), findsOneWidget);
  });
}
