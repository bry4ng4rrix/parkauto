import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/auth/auth_response.dart';
import 'package:parkauto/core/auth/jwt_claims.dart';
import 'package:parkauto/core/domain/enums.dart';
import 'package:parkauto/core/errors/api_error.dart';
import 'package:parkauto/core/errors/app_exception.dart';
import 'package:parkauto/features/fuel/domain/fuel_entry.dart';
import 'package:parkauto/features/home/domain/moi_response.dart';
import 'package:parkauto/features/incidents/domain/incident.dart';
import 'package:parkauto/features/messaging/domain/messaging_models.dart';
import 'package:parkauto/features/messaging/domain/realtime_event.dart';
import 'package:parkauto/features/missions/domain/mission.dart';
import 'package:parkauto/features/profile/domain/conducteur_profile.dart';
import 'package:parkauto/features/vehicle/domain/vehicule.dart';

import '../helpers/contract.dart';

/// Modèle attendu pour chaque réponse 2xx JSON du contrat.
final _parsers = <String, Object Function(Object?)>{
  'Connexion': AuthResponse.fromJson,
  'Rafraîchir les jetons': AuthResponse.fromJson,
  'Accueil': MoiResponse.fromJson,
  'Profil': ConducteurProfile.fromJson,
  'Mon véhicule': VehiculeDetails.fromJson,
  'Mes missions': Mission.listFromJson,
  'Démarrer une mission': Mission.fromJson,
  'Terminer une mission': Mission.fromJson,
  'Mes saisies carburant': FuelEntry.listFromJson,
  'Plein complet': FuelEntry.fromJson,
  'Appoint': FuelEntry.fromJson,
  'Bidon': FuelEntry.fromJson,
  'Mes incidents': Incident.listFromJson,
  'Déclarer un incident': Incident.fromJson,
  'Ajouter une photo': IncidentPhoto.fromJson,
  "Photos d'un incident": IncidentPhoto.listFromJson,
  'Mes conversations': Conversation.listFromJson,
  'Messages non lus': UnreadMessagesResponse.fromJson,
  'Contacts': ConversationParticipant.listFromJson,
  'Ouvrir une conversation privée': Conversation.fromJson,
  "Messages d'une conversation": Message.listFromJson,
  'Envoyer un message': Message.fromJson,
  'Ticket temps réel': RealtimeTicket.fromJson,
};

/// Réponses binaires ou vides : pas de JSON à analyser.
const _nonJson = {
  "Fichier d'une photo",
  'Télécharger une pièce jointe',
  'Déconnexion',
  'Marquer comme lu',
};

void main() {
  group('Contrat : chaque exemple est lu sans erreur', () {
    for (final (nom, status, body) in Contract.allResponses) {
      final code = int.parse(status.split(' ').first);
      test('$nom — $status', () {
        if (code >= 400) {
          final error = ApiError.tryParse(body);
          expect(error, isNotNull, reason: 'format ApiError attendu');
          expect(error?.statut, code);
          expect(error?.message, isNotEmpty);
          return;
        }
        if (_nonJson.contains(nom)) return;
        final parse = _parsers[nom];
        expect(parse, isNotNull, reason: 'aucun modèle pour « $nom »');
        expect(() => parse!(body), returnsNormally);
      });
    }
  });

  group('Valeurs lues', () {
    test('AuthResponse et claim idUtilisateur du jeton', () {
      final auth = AuthResponse.fromJson(Contract.response('Connexion', '200'));
      expect(auth.typeJeton, 'Bearer');
      expect(auth.expireDans, 3600);
      expect(auth.idConducteur, 12);
      expect(auth.expirationRafraichissement.isUtc, isTrue);
      expect(JwtClaims.idUtilisateur(auth.jetonAcces), 27);
    });

    test('Accueil sans véhicule ni mission', () {
      final moi = MoiResponse.fromJson(
        Contract.response('Accueil', '200 (sans véhicule ni mission)'),
      );
      expect(moi.vehicule, isNull);
      expect(moi.missionEnCours, isNull);
      expect(moi.prochainesMissions, isEmpty);
      expect(moi.profil.qualification?.niveau, NiveauEcheance.bientot);
    });

    test('Véhicule : documents, alertes, dernier plein', () {
      final v = VehiculeDetails.fromJson(
        Contract.response('Mon véhicule', '200'),
      );
      expect(v.energie, Energie.gasoil);
      expect(v.documents.first.dateExpiration, isNull);
      expect(v.documents.first.niveau, NiveauEcheance.sansDate);
      expect(v.documents[3].joursRestants, -28);
      expect(v.alertes.first.type, TypeAlerte.perteConnexionGps);
      expect(v.alertes.first.priorite, Gravite.elevee);
      expect(
        v.dernierPlein?.typeApprovisionnement,
        TypeApprovisionnement.pleinComplet,
      );
    });

    test('Missions : nullables et distance', () {
      final missions = Mission.listFromJson(
        Contract.response('Mes missions', '200'),
      );
      final enCours = missions.first;
      expect(enCours.statut, StatutMission.enCours);
      expect(enCours.canFinish, isTrue);
      expect(enCours.kilometrageRetour, isNull);
      final terminee = missions.firstWhere(
        (m) => m.statut == StatutMission.terminee,
      );
      expect(terminee.distance, 112);
      expect(
        missions.where((m) => m.statut == StatutMission.annulee),
        hasLength(1),
      );
    });

    test('Plein « bidon » sans station', () {
      final entry = FuelEntry.fromJson(Contract.response('Bidon', '201'));
      expect(entry.station, isNull);
      expect(entry.typeApprovisionnement, TypeApprovisionnement.bidon);
      expect(entry.montantTotal, 52000);
    });

    test('Messages : auteur, pièces jointes, dates UTC', () {
      final messages = Message.listFromJson(
        Contract.response("Messages d'une conversation", '200'),
      );
      expect(messages.map((m) => m.idMessage), [410, 411, 415]);
      expect(messages.last.piecesJointes.single.isPdf, isTrue);
      expect(messages.first.dateEnvoi.isUtc, isTrue);
    });

    test('Conversation canal sans interlocuteur', () {
      final conversations = Conversation.listFromJson(
        Contract.response('Mes conversations', '200'),
      );
      expect(conversations.last.type, TypeConversation.canal);
      expect(conversations.last.interlocuteur, isNull);
      expect(conversations.last.type.isGroup, isTrue);
    });

    test('Erreur 400 : détails rattachés aux champs', () {
      final error = ApiError.tryParse(
        Contract.response('Terminer une mission', '400'),
      );
      expect(error?.fieldErrors, {'kilometrage': 'ne doit pas être nul'});
    });
  });

  group('Robustesse', () {
    Map<String, Object?> fuel() =>
        (Contract.response('Plein complet', '201')! as Map<String, Object?>);

    test('typeApprovisionnement absent (backend de dev) → null', () {
      final json = fuel()..remove('typeApprovisionnement');
      expect(FuelEntry.fromJson(json).typeApprovisionnement, isNull);
    });

    test('valeur d’énumération inconnue → inconnu', () {
      final json = fuel()..['typeApprovisionnement'] = 'CITERNE';
      expect(
        FuelEntry.fromJson(json).typeApprovisionnement,
        TypeApprovisionnement.inconnu,
      );
    });

    test('champ obligatoire absent → ContractException nommant le champ', () {
      final json = fuel()..remove('idCarburant');
      expect(
        () => FuelEntry.fromJson(json),
        throwsA(
          isA<ContractException>().having(
            (e) => e.field,
            'field',
            'Plein.idCarburant',
          ),
        ),
      );
    });

    test('entier transmis en décimal accepté', () {
      final json = fuel()..['idEngin'] = 4.0;
      expect(FuelEntry.fromJson(json).idEngin, 4);
    });
  });

  group('Événements temps réel', () {
    test('MESSAGE', () {
      final event = RealtimeEvent.decode(jsonEncode(Contract.realtimeMessage));
      expect(event, isA<MessageRealtimeEvent>());
      final message = (event! as MessageRealtimeEvent).message;
      expect(message.idMessage, 418);
      expect(message.piecesJointes.single.image, isTrue);
    });

    test('PONG', () {
      expect(RealtimeEvent.decode('{"type":"PONG"}'), isA<RealtimePong>());
    });

    test('type inconnu ou texte illisible ignorés', () {
      expect(
        RealtimeEvent.decode('{"type":"MISSION"}'),
        isA<UnknownRealtimeEvent>(),
      );
      expect(RealtimeEvent.decode('pas du json'), isA<UnknownRealtimeEvent>());
      expect(RealtimeEvent.decode(''), isNull);
    });
  });
}
