import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/json/json_reader.dart';

/// `{idUtilisateur, nomComplet, role}` : interlocuteur, auteur ou contact.
@immutable
class ConversationParticipant {
  const ConversationParticipant({
    required this.idUtilisateur,
    required this.nomComplet,
    required this.role,
  });

  factory ConversationParticipant.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Utilisateur');
    return ConversationParticipant(
      idUtilisateur: j.reqInt('idUtilisateur'),
      nomComplet: j.reqString('nomComplet'),
      role: j.reqString('role'),
    );
  }

  static List<ConversationParticipant> listFromJson(Object? json) =>
      JsonReader.listOf(json, 'Contact[]', ConversationParticipant.fromJson);

  final int idUtilisateur;
  final String nomComplet;

  /// Rôle libre (RESPONSABLE_PARC, CHEF_MAINTENANCE, DG…).
  final String role;

  String get roleLabel => UserRoles.label(role);
}

/// Auteur d'un message (même forme JSON).
typedef MessageAuthor = ConversationParticipant;

/// Élément de `GET /api/messagerie/contacts` (même forme JSON).
typedef Contact = ConversationParticipant;

/// Élément de `GET /api/messagerie/conversations`, réponse de `/privee`.
@immutable
class Conversation {
  const Conversation({
    required this.idConversation,
    required this.type,
    required this.titre,
    required this.objetType,
    required this.objetId,
    required this.interlocuteur,
    required this.dateDernierMessage,
    required this.nonLus,
  });

  factory Conversation.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Conversation');
    return Conversation(
      idConversation: j.reqInt('idConversation'),
      type: j.reqEnum(
        'type',
        TypeConversation.values,
        TypeConversation.inconnu,
      ),
      titre: j.reqString('titre'),
      objetType: j.optString('objetType'),
      // Toujours `null` dans le contrat : lecture tolérante.
      objetId: j.optIntLenient('objetId'),
      interlocuteur: j.optObject(
        'interlocuteur',
        ConversationParticipant.fromJson,
      ),
      dateDernierMessage: j.optDateTime('dateDernierMessage'),
      nonLus: j.reqInt('nonLus'),
    );
  }

  static List<Conversation> listFromJson(Object? json) =>
      JsonReader.listOf(json, 'Conversation[]', Conversation.fromJson);

  final int idConversation;
  final TypeConversation type;
  final String titre;
  final String? objetType;
  final int? objetId;
  final ConversationParticipant? interlocuteur;
  final DateTime? dateDernierMessage;
  final int nonLus;

  Conversation copyWith({int? nonLus, DateTime? dateDernierMessage}) =>
      Conversation(
        idConversation: idConversation,
        type: type,
        titre: titre,
        objetType: objetType,
        objetId: objetId,
        interlocuteur: interlocuteur,
        dateDernierMessage: dateDernierMessage ?? this.dateDernierMessage,
        nonLus: nonLus ?? this.nonLus,
      );
}

/// Pièce jointe d'un message.
@immutable
class Attachment {
  const Attachment({
    required this.idPieceJointe,
    required this.nom,
    required this.typeContenu,
    required this.taille,
    required this.image,
  });

  factory Attachment.fromJson(Object? json) {
    final j = JsonReader.of(json, 'PieceJointe');
    return Attachment(
      idPieceJointe: j.reqInt('idPieceJointe'),
      nom: j.reqString('nom'),
      typeContenu: j.reqString('typeContenu'),
      taille: j.reqInt('taille'),
      image: j.reqBool('image'),
    );
  }

  final int idPieceJointe;
  final String nom;
  final String typeContenu;

  /// Taille en octets.
  final int taille;
  final bool image;

  bool get isPdf => typeContenu == 'application/pdf';
}

/// Message d'une conversation (liste, envoi, événement temps réel).
@immutable
class Message {
  const Message({
    required this.idMessage,
    required this.idConversation,
    required this.auteur,
    required this.contenu,
    required this.dateEnvoi,
    required this.piecesJointes,
  });

  factory Message.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Message');
    return Message(
      idMessage: j.reqInt('idMessage'),
      idConversation: j.reqInt('idConversation'),
      auteur: j.reqObject('auteur', ConversationParticipant.fromJson),
      contenu: j.optString('contenu'),
      dateEnvoi: j.reqDateTime('dateEnvoi'),
      piecesJointes: j.list('piecesJointes', Attachment.fromJson),
    );
  }

  static List<Message> listFromJson(Object? json) =>
      JsonReader.listOf(json, 'Message[]', Message.fromJson);

  final int idMessage;
  final int idConversation;
  final MessageAuthor auteur;
  final String? contenu;
  final DateTime dateEnvoi;
  final List<Attachment> piecesJointes;

  /// Aperçu pour la liste des conversations.
  String get preview {
    final text = contenu?.trim() ?? '';
    if (text.isNotEmpty) return text;
    final count = piecesJointes.length;
    if (count == 0) return '';
    return count > 1 ? '$count pièces jointes' : 'Pièce jointe';
  }
}

/// Réponse de `GET /api/messagerie/non-lus`.
@immutable
class UnreadMessagesResponse {
  const UnreadMessagesResponse({required this.total});

  factory UnreadMessagesResponse.fromJson(Object? json) =>
      UnreadMessagesResponse(
        total: JsonReader.of(json, 'NonLus').reqInt('total'),
      );

  final int total;
}

/// Réponse de `POST /api/messagerie/ticket-temps-reel`. Usage unique,
/// à utiliser dans les [expireDansSecondes].
@immutable
class RealtimeTicket {
  const RealtimeTicket({
    required this.ticket,
    required this.expireDansSecondes,
  });

  factory RealtimeTicket.fromJson(Object? json) {
    final j = JsonReader.of(json, 'Ticket');
    return RealtimeTicket(
      ticket: j.reqString('ticket'),
      expireDansSecondes: j.reqInt('expireDansSecondes'),
    );
  }

  final String ticket;
  final int expireDansSecondes;
}
