import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/json/json_reader.dart';
import 'messaging_models.dart';

/// Événements reçus sur `ws://…/ws/messagerie` (section `tempsReel`).
sealed class RealtimeEvent {
  const RealtimeEvent();

  /// Décode une trame texte. Renvoie `null` si elle est illisible.
  static RealtimeEvent? decode(Object? frame) {
    final text = switch (frame) {
      String() => frame,
      List<int>() => utf8.decode(frame, allowMalformed: true),
      _ => null,
    };
    if (text == null || text.trim().isEmpty) return null;
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return UnknownRealtimeEvent(type: null, raw: text);
    }
    if (json is! Map) return UnknownRealtimeEvent(type: null, raw: text);
    final type = json['type'];
    try {
      return switch (type) {
        'PONG' => const RealtimePong(),
        'MESSAGE' => MessageRealtimeEvent.fromJson(json),
        _ => UnknownRealtimeEvent(
          type: type is String ? type : null,
          raw: text,
        ),
      };
    } on ContractException {
      return UnknownRealtimeEvent(
        type: type is String ? type : null,
        raw: text,
      );
    }
  }
}

/// `{"type":"PONG"}` en réponse à « ping ».
final class RealtimePong extends RealtimeEvent {
  const RealtimePong();
}

/// `{"type":"MESSAGE","idConversation":5,"message":{…}}`.
@immutable
final class MessageRealtimeEvent extends RealtimeEvent {
  const MessageRealtimeEvent({
    required this.idConversation,
    required this.message,
  });

  factory MessageRealtimeEvent.fromJson(Object? json) {
    final j = JsonReader.of(json, 'RealtimeMessage');
    return MessageRealtimeEvent(
      idConversation: j.reqInt('idConversation'),
      message: j.reqObject('message', Message.fromJson),
    );
  }

  final int idConversation;
  final Message message;
}

/// Type non documenté : journalisé puis ignoré.
final class UnknownRealtimeEvent extends RealtimeEvent {
  const UnknownRealtimeEvent({required this.type, required this.raw});

  final String? type;
  final String raw;
}
