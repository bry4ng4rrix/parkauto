import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_client.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/core/auth/session_controller.dart';
import 'package:parkauto/core/errors/app_exception.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

Map<String, Object?> _tokens(String access, String refresh) =>
    (Contract.response('Rafraîchir les jetons', '200')! as Map<String, Object?>)
      ..['jetonAcces'] = access
      ..['jetonRafraichissement'] = refresh;

Object? _unauthorized() => Contract.response('Accueil', '401');

Object? _identity(Object? json) => json;

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend()
      ..on(
        'POST',
        ApiEndpoints.deconnexion,
        (_) => const FakeReply.noContent(),
      );
  });

  test('ajoute le jeton Bearer', () async {
    final container = await createContainer(
      backend: backend,
      session: testSession(),
    );
    backend.json('GET', ApiEndpoints.moi, 200, <String, Object?>{});

    await container.read(apiClientProvider).get(ApiEndpoints.moi, _identity);

    expect(
      backend.calls('GET', ApiEndpoints.moi).single.authorization,
      'Bearer access-1',
    );
  });

  test('rafraîchit avant l’envoi si le jeton a expiré', () async {
    final container = await createContainer(
      backend: backend,
      session: testSession(accessExpired: true),
    );
    backend
      ..json(
        'POST',
        ApiEndpoints.rafraichir,
        200,
        _tokens('access-2', 'refresh-2'),
      )
      ..json('GET', ApiEndpoints.moi, 200, <String, Object?>{});

    await container.read(apiClientProvider).get(ApiEndpoints.moi, _identity);

    final refresh = backend.calls('POST', ApiEndpoints.rafraichir).single;
    expect(refresh.json, {'jetonRafraichissement': 'refresh-1'});
    expect(
      backend.calls('GET', ApiEndpoints.moi).single.authorization,
      'Bearer access-2',
    );
    expect(
      container.read(sessionControllerProvider).session?.jetonRafraichissement,
      'refresh-2',
    );
  });

  test('401 : un seul rafraîchissement puis rejeu de la requête', () async {
    final container = await createContainer(
      backend: backend,
      session: testSession(),
    );
    backend
      ..json(
        'POST',
        ApiEndpoints.rafraichir,
        200,
        _tokens('access-2', 'refresh-2'),
      )
      ..on(
        'GET',
        ApiEndpoints.moi,
        (r) => r.authorization == 'Bearer access-2'
            ? const FakeReply.json(200, {'ok': true})
            : FakeReply.json(401, _unauthorized()),
      );

    final result = await container
        .read(apiClientProvider)
        .get(ApiEndpoints.moi, _identity);

    expect(result, {'ok': true});
    expect(backend.calls('POST', ApiEndpoints.rafraichir), hasLength(1));
    expect(backend.calls('GET', ApiEndpoints.moi).map((r) => r.authorization), [
      'Bearer access-1',
      'Bearer access-2',
    ]);
    expect(
      container.read(sessionControllerProvider).session?.jetonAcces,
      'access-2',
    );
  });

  test('deux 401 simultanées : un seul rafraîchissement', () async {
    final container = await createContainer(
      backend: backend,
      session: testSession(),
    );
    backend
      ..on(
        'POST',
        ApiEndpoints.rafraichir,
        (_) => FakeReply.delayed(
          200,
          _tokens('access-2', 'refresh-2'),
          const Duration(milliseconds: 50),
        ),
      )
      ..on(
        'GET',
        ApiEndpoints.moi,
        (r) => r.authorization == 'Bearer access-2'
            ? const FakeReply.json(200, {'ok': true})
            : FakeReply.json(401, _unauthorized()),
      );
    final api = container.read(apiClientProvider);

    await Future.wait([
      api.get(ApiEndpoints.moi, _identity),
      api.get(ApiEndpoints.moi, _identity),
    ]);

    expect(backend.calls('POST', ApiEndpoints.rafraichir), hasLength(1));
    expect(backend.calls('GET', ApiEndpoints.moi), hasLength(4));
  });

  test('pas de boucle : un second 401 après rejeu est remonté', () async {
    final container = await createContainer(
      backend: backend,
      session: testSession(),
    );
    backend
      ..json(
        'POST',
        ApiEndpoints.rafraichir,
        200,
        _tokens('access-2', 'refresh-2'),
      )
      ..json('GET', ApiEndpoints.moi, 401, _unauthorized());

    await expectLater(
      container.read(apiClientProvider).get(ApiEndpoints.moi, _identity),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statut', 401)),
    );
    expect(backend.calls('GET', ApiEndpoints.moi), hasLength(2));
    expect(backend.calls('POST', ApiEndpoints.rafraichir), hasLength(1));
  });

  test(
    'rafraîchissement refusé : session expirée, retour à la connexion',
    () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      backend
        ..json(
          'POST',
          ApiEndpoints.rafraichir,
          401,
          Contract.response('Rafraîchir les jetons', '401'),
        )
        ..json('GET', ApiEndpoints.moi, 401, _unauthorized());

      await expectLater(
        container.read(apiClientProvider).get(ApiEndpoints.moi, _identity),
        throwsA(isA<SessionExpiredException>()),
      );
      final state = container.read(sessionControllerProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.reason, SignOutReason.sessionExpired);
    },
  );

  test('rafraîchissement impossible (réseau) : session conservée', () async {
    final container = await createContainer(
      backend: backend,
      session: testSession(),
    );
    backend
      ..on(
        'POST',
        ApiEndpoints.rafraichir,
        (_) => const FakeReply.networkError(),
      )
      ..json('GET', ApiEndpoints.moi, 401, _unauthorized());

    await expectLater(
      container.read(apiClientProvider).get(ApiEndpoints.moi, _identity),
      throwsA(isA<NetworkException>()),
    );
    expect(
      container.read(sessionControllerProvider).status,
      AuthStatus.authenticated,
    );
  });

  test('une requête multipart est rejouée intégralement', () async {
    final container = await createContainer(
      backend: backend,
      session: testSession(),
    );
    final path = ApiEndpoints.incidentPhotos(57);
    backend
      ..json(
        'POST',
        ApiEndpoints.rafraichir,
        200,
        _tokens('access-2', 'refresh-2'),
      )
      ..on(
        'POST',
        path,
        (r) => r.authorization == 'Bearer access-2'
            ? FakeReply.json(201, Contract.response('Ajouter une photo', '201'))
            : FakeReply.json(401, _unauthorized()),
      );

    final form = FormData.fromMap({
      'fichier': MultipartFile.fromBytes([1, 2, 3], filename: 'photo.jpg'),
      'legende': 'Tableau de bord',
    });
    await container.read(apiClientProvider).post(path, _identity, body: form);

    final calls = backend.calls('POST', path).toList();
    expect(calls, hasLength(2));
    for (final call in calls) {
      expect(call.bodyText, contains('name="fichier"; filename="photo.jpg"'));
      expect(call.bodyText, contains('name="legende"'));
    }
  });

  test('déconnexion pendant un rafraîchissement : résultat ignoré', () async {
    final container = await createContainer(
      backend: backend,
      session: testSession(accessExpired: true),
    );
    backend
      ..on(
        'POST',
        ApiEndpoints.rafraichir,
        (_) => FakeReply.delayed(
          200,
          _tokens('access-2', 'refresh-2'),
          const Duration(milliseconds: 80),
        ),
      )
      ..json('GET', ApiEndpoints.moi, 200, <String, Object?>{});

    final request = container
        .read(apiClientProvider)
        .get(ApiEndpoints.moi, _identity);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await container.read(sessionControllerProvider.notifier).signOut();

    await expectLater(request, throwsA(isA<SessionExpiredException>()));
    expect(container.read(sessionControllerProvider).session, isNull);
    expect(backend.calls('GET', ApiEndpoints.moi), isEmpty);
  });

  group('jetons renouvelés par la vérification en arrière-plan', () {
    FakeReply moi(RecordedRequest r) => r.authorization == 'Bearer access-2'
        ? const FakeReply.json(200, {'ok': true})
        : FakeReply.json(401, _unauthorized());

    test(
      'session enregistrée plus récente : reprise sans rafraîchir',
      () async {
        final store = InMemorySessionStore(testSession());
        final container = await createContainer(backend: backend, store: store);
        store.session = testSession(access: 'access-2', refresh: 'refresh-2');
        backend
          ..json(
            'POST',
            ApiEndpoints.rafraichir,
            401,
            Contract.response('Rafraîchir les jetons', '401'),
          )
          ..on('GET', ApiEndpoints.moi, moi);

        final result = await container
            .read(apiClientProvider)
            .get(ApiEndpoints.moi, _identity);

        expect(result, {'ok': true});
        expect(backend.calls('POST', ApiEndpoints.rafraichir), isEmpty);
        expect(
          container.read(sessionControllerProvider).session?.jetonAcces,
          'access-2',
        );
      },
    );

    test(
      'refus dû à un renouvellement concurrent : pas de déconnexion',
      () async {
        final store = InMemorySessionStore(testSession());
        final container = await createContainer(backend: backend, store: store);
        backend
          ..on('POST', ApiEndpoints.rafraichir, (_) {
            // L'autre isolat a consommé le même jeton juste avant.
            store.session = testSession(
              access: 'access-2',
              refresh: 'refresh-2',
            );
            return FakeReply.json(
              401,
              Contract.response('Rafraîchir les jetons', '401'),
            );
          })
          ..on('GET', ApiEndpoints.moi, moi);

        final result = await container
            .read(apiClientProvider)
            .get(ApiEndpoints.moi, _identity);

        expect(result, {'ok': true});
        final state = container.read(sessionControllerProvider);
        expect(state.status, AuthStatus.authenticated);
        expect(state.session?.jetonRafraichissement, 'refresh-2');
      },
    );
  });
}
