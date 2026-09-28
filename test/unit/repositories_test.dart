import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/core/domain/enums.dart';
import 'package:parkauto/core/errors/app_exception.dart';
import 'package:parkauto/features/fuel/data/fuel_repository.dart';
import 'package:parkauto/features/fuel/domain/fuel_entry.dart';
import 'package:parkauto/features/incidents/data/incidents_repository.dart';
import 'package:parkauto/features/incidents/domain/incident.dart';
import 'package:parkauto/features/messaging/data/messaging_repository.dart';
import 'package:parkauto/features/messaging/domain/local_attachment.dart';
import 'package:parkauto/features/missions/data/missions_repository.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend());

  group('Missions', () {
    test('démarrer : POST kilometrage, mission renvoyée', () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      backend.json(
        'POST',
        ApiEndpoints.demarrerMission(91),
        200,
        Contract.response('Démarrer une mission', '200'),
      );

      final mission = await container
          .read(missionsRepositoryProvider)
          .demarrer(91, 84360);

      expect(mission.statut, StatutMission.enCours);
      expect(
        backend.calls('POST', '/api/moi/missions/91/demarrer').single.json,
        {'kilometrage': 84360.0},
      );
    });

    test('terminer : 409 → message métier du backend tel quel', () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      backend.json(
        'POST',
        ApiEndpoints.terminerMission(88),
        409,
        Contract.response('Terminer une mission', '409'),
      );

      await expectLater(
        container.read(missionsRepositoryProvider).terminer(88, 84100),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isConflict, 'conflit', isTrue)
              .having(
                (e) => e.userMessage,
                'message',
                'Le kilométrage de retour (84100,0) ne peut pas être '
                    'inférieur au kilométrage de départ (84150,0)',
              ),
        ),
      );
    });
  });

  group('Carburant', () {
    test('corps : champs null omis, station nettoyée', () {
      const request = CreateFuelRequest(
        typeApprovisionnement: TypeApprovisionnement.bidon,
        kilometrageAuPlein: 84360,
        quantiteLitres: 10,
        prixUnitaire: 5200,
        station: '  ',
      );
      expect(request.toJson(), {
        'typeApprovisionnement': 'BIDON',
        'kilometrageAuPlein': 84360.0,
        'quantiteLitres': 10.0,
        'prixUnitaire': 5200.0,
      });
    });

    test('corps complet avec date locale sans fuseau', () {
      final request = CreateFuelRequest(
        typeApprovisionnement: TypeApprovisionnement.pleinComplet,
        kilometrageAuPlein: 84230,
        quantiteLitres: 52.5,
        prixUnitaire: 5200,
        station: ' Jovena Ivato ',
        idEngin: 4,
        dateHeure: DateTime(2026, 9, 28, 10),
      );
      expect(request.toJson(), {
        'idEngin': 4,
        'dateHeure': '2026-09-28T10:00:00',
        'typeApprovisionnement': 'PLEIN_COMPLET',
        'kilometrageAuPlein': 84230.0,
        'quantiteLitres': 52.5,
        'prixUnitaire': 5200.0,
        'station': 'Jovena Ivato',
      });
    });

    test('POST 201 et erreurs 400 rattachées aux champs', () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      final repository = container.read(fuelRepositoryProvider);
      backend.json(
        'POST',
        ApiEndpoints.pleins,
        201,
        Contract.response('Plein complet', '201'),
      );
      const request = CreateFuelRequest(
        typeApprovisionnement: TypeApprovisionnement.pleinComplet,
        kilometrageAuPlein: 84230,
        quantiteLitres: 52.5,
        prixUnitaire: 5200,
      );
      expect((await repository.declarer(request)).idCarburant, 301);

      backend.json(
        'POST',
        ApiEndpoints.pleins,
        400,
        Contract.response('Plein complet', '400'),
      );
      await expectLater(
        repository.declarer(request),
        throwsA(
          isA<ApiException>().having((e) => e.fieldErrors, 'champs', {
            'quantiteLitres': 'doit être supérieur à 0',
          }),
        ),
      );
    });
  });

  group('Incidents', () {
    test('déclaration puis photo en multipart (fichier, legende)', () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      final repository = container.read(incidentsRepositoryProvider);
      backend
        ..json(
          'POST',
          ApiEndpoints.incidents,
          201,
          Contract.response('Déclarer un incident', '201'),
        )
        ..json(
          'POST',
          ApiEndpoints.incidentPhotos(57),
          201,
          Contract.response('Ajouter une photo', '201'),
        );

      final incident = await repository.declarer(
        const CreateIncidentRequest(
          type: TypeIncident.panne,
          gravite: Gravite.elevee,
          description: ' Voyant moteur allumé ',
        ),
      );
      expect(incident.idIncident, 57);
      expect(backend.calls('POST', ApiEndpoints.incidents).single.json, {
        'type': 'PANNE',
        'gravite': 'ELEVEE',
        'description': 'Voyant moteur allumé',
      });

      final dir = await Directory.systemTemp.createTemp('parkauto');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/tableau.jpg')..writeAsBytesSync([1, 2, 3]);
      final photo = await repository.ajouterPhoto(
        57,
        path: file.path,
        legende: 'Tableau de bord',
      );
      expect(photo.url, '/api/moi/incidents/photos/140/fichier');
      final body = backend
          .calls('POST', ApiEndpoints.incidentPhotos(57))
          .single
          .bodyText;
      expect(body, contains('name="fichier"; filename="tableau.jpg"'));
      expect(body, contains('name="legende"'));
      expect(body, contains('Tableau de bord'));
    });

    test('limite de 10 photos : message 409 du backend', () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      backend.json(
        'POST',
        ApiEndpoints.incidentPhotos(57),
        409,
        Contract.response('Ajouter une photo', '409 (limite)'),
      );
      final dir = await Directory.systemTemp.createTemp('parkauto');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/p.jpg')..writeAsBytesSync([1]);

      await expectLater(
        container
            .read(incidentsRepositoryProvider)
            .ajouterPhoto(57, path: file.path),
        throwsA(
          isA<ApiException>().having(
            (e) => e.userMessage,
            'message',
            '10 photos au plus par incident',
          ),
        ),
      );
      expect(Incident.maxPhotos, 10);
    });
  });

  group('Messagerie', () {
    test('messages : limite et avant en paramètres', () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      backend.json(
        'GET',
        ApiEndpoints.messages(5),
        200,
        Contract.response("Messages d'une conversation", '200'),
      );
      final repository = container.read(messagingRepositoryProvider);

      await repository.messages(5, limite: 30);
      await repository.messages(5, limite: 30, avant: 410);

      final calls = backend.calls('GET', ApiEndpoints.messages(5)).toList();
      expect(calls[0].query, {'limite': '30'});
      expect(calls[1].query, {'limite': '30', 'avant': '410'});
    });

    test('envoi multipart : contenu et plusieurs fichiers', () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      backend.json(
        'POST',
        ApiEndpoints.messages(5),
        201,
        Contract.response('Envoyer un message', '201'),
      );
      final dir = await Directory.systemTemp.createTemp('parkauto');
      addTearDown(() => dir.delete(recursive: true));
      final a = File('${dir.path}/a.jpg')..writeAsBytesSync([1]);
      final b = File('${dir.path}/b.pdf')..writeAsBytesSync([2]);

      final message = await container
          .read(messagingRepositoryProvider)
          .envoyer(
            5,
            contenu: 'Déchargement terminé.',
            fichiers: [
              LocalAttachment.fromPath(a.path),
              LocalAttachment.fromPath(b.path),
            ],
          );

      expect(message.idMessage, 418);
      final body = backend
          .calls('POST', ApiEndpoints.messages(5))
          .single
          .bodyText;
      expect(body, contains('name="contenu"'));
      expect('name="fichiers"'.allMatches(body), hasLength(2));
    });

    test('non-lus, conversation privée, marquer comme lu (204)', () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      backend
        ..json(
          'GET',
          ApiEndpoints.nonLus,
          200,
          Contract.response('Messages non lus', '200'),
        )
        ..json(
          'POST',
          ApiEndpoints.conversationPrivee,
          200,
          Contract.response('Ouvrir une conversation privée', '200'),
        )
        ..on(
          'POST',
          ApiEndpoints.marquerLu(5),
          (_) => const FakeReply.noContent(),
        );
      final repository = container.read(messagingRepositoryProvider);

      expect(await repository.nonLus(), 3);
      expect((await repository.ouvrirConversationPrivee(2)).idConversation, 5);
      expect(
        backend.calls('POST', ApiEndpoints.conversationPrivee).single.json,
        {'idUtilisateur': 2},
      );
      await repository.marquerLu(5);
      expect(backend.calls('POST', ApiEndpoints.marquerLu(5)), hasLength(1));
    });

    test('erreur 500 du backend : message générique du backend', () async {
      final container = await createContainer(
        backend: backend,
        session: testSession(),
      );
      backend.json('GET', ApiEndpoints.messages(1), 500, {
        'horodatage': '2026-09-28T11:41:08.074816Z',
        'statut': 500,
        'erreur': 'Erreur interne',
        'message': 'Une erreur inattendue est survenue',
        'details': <String>[],
      });
      await expectLater(
        container.read(messagingRepositoryProvider).messages(1, limite: 30),
        throwsA(
          isA<ApiException>().having(
            (e) => e.userMessage,
            'message',
            'Une erreur inattendue est survenue',
          ),
        ),
      );
    });
  });
}
