import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/local_attachment.dart';
import '../domain/messaging_models.dart';

class MessagingRepository {
  MessagingRepository(this._api);

  final ApiClient _api;

  Future<List<Conversation>> conversations() =>
      _api.get(ApiEndpoints.conversations, Conversation.listFromJson);

  /// `GET /api/messagerie/non-lus` → `{"total": n}`.
  Future<int> nonLus() async => (await _api.get(
    ApiEndpoints.nonLus,
    UnreadMessagesResponse.fromJson,
  )).total;

  Future<List<Contact>> contacts() =>
      _api.get(ApiEndpoints.contacts, ConversationParticipant.listFromJson);

  /// `POST /api/messagerie/conversations/privee`.
  Future<Conversation> ouvrirConversationPrivee(int idUtilisateur) =>
      _api.post(
        ApiEndpoints.conversationPrivee,
        Conversation.fromJson,
        body: {'idUtilisateur': idUtilisateur},
      );

  /// Du plus ancien au plus récent ; page précédente via [avant].
  Future<List<Message>> messages(
    int idConversation, {
    int? limite,
    int? avant,
  }) => _api.get(
    ApiEndpoints.messages(idConversation),
    Message.listFromJson,
    query: {'limite': ?limite, 'avant': ?avant},
  );

  /// Multipart : `contenu` et `fichiers` (facultatifs, plusieurs possibles).
  Future<Message> envoyer(
    int idConversation, {
    String? contenu,
    List<LocalAttachment> fichiers = const [],
    ProgressCallback? onProgress,
  }) async {
    final text = contenu?.trim() ?? '';
    final form = FormData();
    if (text.isNotEmpty) form.fields.add(MapEntry('contenu', text));
    for (final file in fichiers) {
      form.files.add(
        MapEntry(
          'fichiers',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ),
      );
    }
    return _api.post(
      ApiEndpoints.messages(idConversation),
      Message.fromJson,
      body: form,
      onSendProgress: onProgress,
    );
  }

  /// 204 No Content.
  Future<void> marquerLu(int idConversation) =>
      _api.postNoContent(ApiEndpoints.marquerLu(idConversation));

  Future<Uint8List> telechargerPieceJointe(
    int idPieceJointe, {
    ProgressCallback? onProgress,
  }) => _api.getBytes(
    ApiEndpoints.pieceJointe(idPieceJointe),
    onReceiveProgress: onProgress,
  );

  Future<RealtimeTicket> ticketTempsReel() =>
      _api.post(ApiEndpoints.ticketTempsReel, RealtimeTicket.fromJson);
}

final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => MessagingRepository(ref.watch(apiClientProvider)),
);
