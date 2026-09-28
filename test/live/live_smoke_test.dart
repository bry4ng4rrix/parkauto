// Vérification contre un vrai backend (ignorée par défaut).
//
// flutter test test/live --dart-define-from-file=env/dev.json \
//   --dart-define=LIVE_EMAIL=... --dart-define=LIVE_PASSWORD=... \
//   [--dart-define=LIVE_WRITE=true]
//
// LIVE_WRITE=true crée de vraies données de test (message, incident).
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_client.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/core/auth/auth_api.dart';
import 'package:parkauto/core/auth/session_controller.dart';
import 'package:parkauto/core/auth/token_refresher.dart';
import 'package:parkauto/core/domain/enums.dart';
import 'package:parkauto/core/errors/app_exception.dart';
import 'package:parkauto/features/fuel/domain/fuel_entry.dart';
import 'package:parkauto/features/home/domain/moi_response.dart';
import 'package:parkauto/features/incidents/data/incidents_repository.dart';
import 'package:parkauto/features/incidents/domain/incident.dart';
import 'package:parkauto/features/messaging/application/realtime.dart';
import 'package:parkauto/features/messaging/data/messaging_repository.dart';
import 'package:parkauto/features/messaging/domain/local_attachment.dart';
import 'package:parkauto/features/messaging/domain/realtime_event.dart';
import 'package:parkauto/features/missions/domain/mission.dart';
import 'package:parkauto/features/profile/domain/conducteur_profile.dart';
import 'package:parkauto/features/vehicle/data/vehicle_repository.dart';
import 'package:parkauto/features/vehicle/domain/vehicule.dart';

import '../helpers/test_app.dart';

const _email = String.fromEnvironment('LIVE_EMAIL');
const _password = String.fromEnvironment('LIVE_PASSWORD');
const _write = bool.fromEnvironment('LIVE_WRITE');

void main() {
  final skip = _email.isEmpty || _password.isEmpty
      ? 'LIVE_EMAIL / LIVE_PASSWORD non fournis'
      : null;

  late ProviderContainer container;

  setUpAll(() async {
    // Le binding de test bloque le réseau réel : on le rétablit ici.
    HttpOverrides.global = null;
    if (skip != null) return;
    useInMemoryPreferences();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
      ],
    );
    final auth = await container
        .read(authApiProvider)
        .connexion(email: _email, motDePasse: _password, appareil: 'Flutter');
    await container.read(sessionControllerProvider.notifier).signIn(auth);
  });

  tearDownAll(() async {
    if (skip != null) return;
    final session = container.read(sessionControllerProvider).session;
    if (session != null) {
      await container
          .read(authApiProvider)
          .deconnexion(session.jetonRafraichissement);
    }
    container.dispose();
  });

  ApiClient api() => container.read(apiClientProvider);

  test('session : claim idUtilisateur présent', () {
    final session = container.read(sessionControllerProvider).session;
    expect(session?.idUtilisateur, isNotNull);
    // ignore: avoid_print
    print(
      'idConducteur=${session?.idConducteur} idUtilisateur=${session?.idUtilisateur}',
    );
  }, skip: skip);

  test('lectures : toutes les réponses respectent le contrat', () async {
    final moi = await api().get(ApiEndpoints.moi, MoiResponse.fromJson);
    await api().get(ApiEndpoints.profil, ConducteurProfile.fromJson);
    final vehicle = await container.read(vehicleProvider.future);
    final missions = await api().get(
      ApiEndpoints.missions,
      Mission.listFromJson,
    );
    final pleins = await api().get(ApiEndpoints.pleins, FuelEntry.listFromJson);
    final incidents = await api().get(
      ApiEndpoints.incidents,
      Incident.listFromJson,
    );
    final conversations = await container
        .read(messagingRepositoryProvider)
        .conversations();
    final unread = await container.read(messagingRepositoryProvider).nonLus();
    final contacts = await container
        .read(messagingRepositoryProvider)
        .contacts();
    // ignore: avoid_print
    print(
      'moi.missionEnCours=${moi.missionEnCours?.idMission} '
      'vehicule=${vehicle.value is NoVehicle ? 'aucun' : 'affecté'} '
      'missions=${missions.length} pleins=${pleins.length} '
      'typeApprovisionnement=${pleins.map((p) => p.typeApprovisionnement?.apiValue).toSet()} '
      'incidents=${incidents.length} conversations=${conversations.length} '
      'nonLus=$unread contacts=${contacts.length}',
    );
  }, skip: skip);

  test('messages d’une conversation (avec et sans limite)', () async {
    final repository = container.read(messagingRepositoryProvider);
    for (final c in await repository.conversations()) {
      for (final limite in [30, null]) {
        try {
          final messages = await repository.messages(
            c.idConversation,
            limite: limite,
          );
          // ignore: avoid_print
          print(
            'conversation ${c.idConversation} (${c.type.apiValue}) limite=$limite : ${messages.length} messages',
          );
        } on AppException catch (e) {
          // ignore: avoid_print
          print(
            'conversation ${c.idConversation} (${c.type.apiValue}) limite=$limite : ERREUR ${e.userMessage}',
          );
        }
      }
    }
  }, skip: skip);

  test('rafraîchissement du jeton', () async {
    final before = container.read(sessionControllerProvider).session;
    final renewed = await container.read(tokenRefresherProvider).refresh();
    // Le jeton d'accès peut être identique (même seconde) ; le jeton de
    // rafraîchissement, lui, est renouvelé.
    expect(
      renewed.jetonRafraichissement == before?.jetonRafraichissement,
      isFalse,
    );
    await api().get(ApiEndpoints.moi, MoiResponse.fromJson);
  }, skip: skip);

  test('temps réel : ticket, WebSocket, ping → PONG', () async {
    final service = container.read(realtimeServiceProvider);
    final pong = service.events.firstWhere((e) => e is RealtimePong);
    service.connect();
    await pong.timeout(const Duration(seconds: 10));
    await service.disconnect();
  }, skip: skip);

  test(
    'écriture : message privé, écho temps réel, lu',
    () async {
      final repository = container.read(messagingRepositoryProvider);
      final contacts = await repository.contacts();
      final contact = contacts.firstWhere(
        (c) => c.role == 'RESPONSABLE_PARC',
        orElse: () => contacts.first,
      );
      final conversation = await repository.ouvrirConversationPrivee(
        contact.idUtilisateur,
      );

      final service = container.read(realtimeServiceProvider);
      service.connect();
      await service.events
          .firstWhere((e) => e is RealtimePong)
          .timeout(const Duration(seconds: 10));
      final echo = service.events
          .where((e) => e is MessageRealtimeEvent)
          .cast<MessageRealtimeEvent>()
          .firstWhere((e) => e.idConversation == conversation.idConversation);

      final sent = await repository.envoyer(
        conversation.idConversation,
        contenu: 'Test automatique de l’application conducteur (à ignorer).',
      );
      final event = await echo.timeout(const Duration(seconds: 10));
      expect(event.message.idMessage, sent.idMessage);
      await repository.marquerLu(conversation.idConversation);

      // Pièce jointe seule (contenu vide).
      final dir = await Directory.systemTemp.createTemp('parkauto');
      final file = File('${dir.path}/photo.jpg')..writeAsBytesSync(_tinyJpeg);
      try {
        final withFile = await repository.envoyer(
          conversation.idConversation,
          fichiers: [LocalAttachment.fromPath(file.path)],
        );
        // ignore: avoid_print
        print(
          'pièce jointe seule : OK (${withFile.piecesJointes.length} fichier)',
        );
      } on AppException catch (e) {
        // ignore: avoid_print
        print('pièce jointe seule : ${e.userMessage}');
      }
      await dir.delete(recursive: true);
      await service.disconnect();
    },
    skip: skip ?? (_write ? null : 'LIVE_WRITE=false'),
  );

  test(
    'écriture : incident de test + photo',
    () async {
      final repository = container.read(incidentsRepositoryProvider);
      try {
        final incident = await repository.declarer(
          CreateIncidentRequest(
            type: TypeIncident.autre,
            gravite: Gravite.faible,
            description:
                'TEST AUTOMATIQUE application conducteur — à supprimer',
            dateSurvenue: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        );
        // ignore: avoid_print
        print(
          'incident ${incident.idIncident} créé, dateSurvenue=${incident.dateSurvenue}',
        );
        final dir = await Directory.systemTemp.createTemp('parkauto');
        // JPEG 1×1 minimal.
        final jpeg = File('${dir.path}/test.jpg')..writeAsBytesSync(_tinyJpeg);
        final photo = await repository.ajouterPhoto(
          incident.idIncident,
          path: jpeg.path,
          legende: 'Photo de test',
        );
        final photos = await repository.photos(incident.idIncident);
        final bytes = await api().getBytes(photo.url);
        // ignore: avoid_print
        print(
          'photo ${photo.idPhoto} : ${photos.length} photo(s), fichier ${bytes.length} octets',
        );
        await dir.delete(recursive: true);
      } on AppException catch (e) {
        // ignore: avoid_print
        print('incident : refusé par le backend — ${e.userMessage}');
      }
    },
    skip: skip ?? (_write ? null : 'LIVE_WRITE=false'),
  );
}

const _tinyJpeg = <int>[
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, //
  0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
  0x00, 0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0x03, 0x02, 0x02, 0x02, 0x03,
  0x03, 0x03, 0x03, 0x04, 0x06, 0x04, 0x04, 0x04, 0x04, 0x04, 0x08, 0x06,
  0x06, 0x05, 0x06, 0x09, 0x08, 0x0A, 0x0A, 0x09, 0x08, 0x09, 0x09, 0x0A,
  0x0C, 0x0F, 0x0C, 0x0A, 0x0B, 0x0E, 0x0B, 0x09, 0x09, 0x0D, 0x11, 0x0D,
  0x0E, 0x0F, 0x10, 0x10, 0x11, 0x10, 0x0A, 0x0C, 0x12, 0x13, 0x12, 0x10,
  0x13, 0x0F, 0x10, 0x10, 0x10, 0xFF, 0xC9, 0x00, 0x0B, 0x08, 0x00, 0x01,
  0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xCC, 0x00, 0x06, 0x00, 0x10,
  0x10, 0x05, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
  0xD2, 0xCF, 0x20, 0xFF, 0xD9,
];
