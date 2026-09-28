import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/core/auth/auth_response.dart';
import 'package:parkauto/core/auth/session.dart';
import 'package:parkauto/core/auth/session_controller.dart';
import 'package:parkauto/core/errors/app_exception.dart';
import 'package:parkauto/features/missions/data/missions_repository.dart';
import 'package:parkauto/features/vehicle/data/vehicle_repository.dart';
import 'package:parkauto/features/vehicle/domain/vehicule.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

void main() {
  group('Session', () {
    test('construite depuis la connexion, sérialisable', () {
      final auth = AuthResponse.fromJson(Contract.response('Connexion', '200'));
      final now = DateTime.utc(2026, 9, 28, 9, 30);
      final session = Session.fromAuth(auth, now: now);

      expect(session.idUtilisateur, 27);
      expect(
        session.accessExpiresAt,
        now.add(const Duration(minutes: 59, seconds: 30)),
      );
      expect(session.isAccessExpired(now), isFalse);
      expect(
        session.isAccessExpired(now.add(const Duration(hours: 1))),
        isTrue,
      );

      final restored = Session.fromStorage(session.toStorage());
      expect(restored?.jetonRafraichissement, auth.jetonRafraichissement);
      expect(restored?.idUtilisateur, 27);
      expect(Session.fromStorage({'jetonAcces': 1}), isNull);
    });

    test('restauration : aucune session → connexion', () async {
      final container = await createContainer(backend: FakeBackend());
      expect(
        container.read(sessionControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test(
      'restauration : jeton de rafraîchissement expiré → connexion',
      () async {
        final expired = Session(
          jetonAcces: 'a',
          jetonRafraichissement: 'r',
          accessExpiresAt: DateTime.utc(2026),
          refreshExpiresAt: DateTime.utc(2026),
          idConducteur: 12,
          idUtilisateur: 27,
          nomComplet: 'Tiana RABE',
          role: 'CONDUCTEUR',
        );
        final container = await createContainer(
          backend: FakeBackend(),
          session: expired,
        );
        final state = container.read(sessionControllerProvider);
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.reason, SignOutReason.sessionExpired);
      },
    );

    test(
      'restauration hors ligne : session valide sans appel réseau',
      () async {
        final backend = FakeBackend();
        final container = await createContainer(
          backend: backend,
          session: testSession(accessExpired: true),
        );
        expect(
          container.read(sessionControllerProvider).status,
          AuthStatus.authenticated,
        );
        expect(backend.requests, isEmpty);
      },
    );
  });

  group('Cache hors connexion', () {
    test('réseau d’abord, puis données en cache si le réseau tombe', () async {
      final backend = FakeBackend()
        ..json(
          'GET',
          ApiEndpoints.missions,
          200,
          Contract.response('Mes missions', '200'),
        );
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );

      final first = await container.read(missionsProvider.future);
      expect(first.fromCache, isFalse);
      expect(first.value, hasLength(5));

      backend.on(
        'GET',
        ApiEndpoints.missions,
        (_) => const FakeReply.networkError(),
      );
      final error = await container.read(missionsProvider.notifier).refresh();
      expect(error, isA<NetworkException>());
      final kept = container.read(missionsProvider).value;
      expect(kept?.value, hasLength(5));
      expect(kept?.isOffline, isTrue);
    });

    test('redémarrage hors ligne : le cache est affiché', () async {
      final backend = FakeBackend()
        ..json(
          'GET',
          ApiEndpoints.missions,
          200,
          Contract.response('Mes missions', '200'),
        );
      final session = testSession();
      final online = await createContainer(backend: backend, session: session);
      await online.read(missionsProvider.future);

      backend.on(
        'GET',
        ApiEndpoints.missions,
        (_) => const FakeReply.networkError(),
      );
      // Même stockage de préférences, nouveau conteneur (redémarrage).
      final offline = await createContainer(
        backend: backend,
        session: session,
        freshPreferences: false,
      );
      final cached = await offline.read(missionsProvider.future);
      expect(cached.fromCache, isTrue);
      expect(cached.value, hasLength(5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(offline.read(missionsProvider).value?.isOffline, isTrue);
    });

    test('404 véhicule : donnée « aucun véhicule », pas une erreur', () async {
      final backend = FakeBackend()
        ..json(
          'GET',
          ApiEndpoints.vehicule,
          404,
          Contract.response('Mon véhicule', '404'),
        );
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      final vehicle = await container.read(vehicleProvider.future);
      expect(vehicle.value, isA<NoVehicle>());
    });
  });
}
