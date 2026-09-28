import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/api/api_endpoints.dart';
import 'package:parkauto/features/messaging/application/realtime.dart';
import 'package:parkauto/features/messaging/presentation/chat_screen.dart';
import 'package:parkauto/features/messaging/presentation/message_bubble.dart';

import '../helpers/contract.dart';
import '../helpers/fake_backend.dart';
import '../helpers/pump.dart';
import '../helpers/test_app.dart';

FakeBackend _backend() => FakeBackend()
  ..json(
    'GET',
    ApiEndpoints.messages(5),
    200,
    Contract.response("Messages d'une conversation", '200'),
  )
  ..json(
    'GET',
    ApiEndpoints.conversations,
    200,
    Contract.response('Mes conversations', '200'),
  )
  ..json('POST', ApiEndpoints.ticketTempsReel, 200, Contract.response('Ticket temps réel', '200'))
  ..on('POST', ApiEndpoints.marquerLu(5), (_) => const FakeReply.noContent());

bool _isMine(WidgetTester tester, String text) => tester
    .widget<MessageBubble>(
      find.ancestor(of: find.text(text), matching: find.byType(MessageBubble)),
    )
    .mine;

void main() {
  testWidgets('fil : messages reçus et envoyés, pièce jointe', (tester) async {
    await pumpScreen(
      tester,
      const ChatScreen(idConversation: 5),
      backend: _backend(),
      session: testSession(),
    );

    expect(find.text('Hery RAKOTO'), findsWidgets);
    expect(
      _isMine(tester, "Bonjour Tiana, le chantier d'Ivato attend le ciment avant 10 h."),
      isFalse,
    );
    expect(_isMine(tester, 'Bien reçu, je pars maintenant.'), isTrue);
    expect(find.text('bon-livraison-ivato.pdf'), findsOneWidget);
    expect(find.text('Début de la conversation'), findsOneWidget);
  });

  testWidgets('envoi puis écho WebSocket : un seul message', (tester) async {
    final backend = _backend()
      ..json(
        'POST',
        ApiEndpoints.messages(5),
        201,
        Contract.response('Envoyer un message', '201'),
      );
    final connector = FakeRealtimeConnector();
    final container = await pumpScreen(
      tester,
      const ChatScreen(idConversation: 5),
      backend: backend,
      session: testSession(),
      connector: connector,
    );
    container.read(realtimeServiceProvider).connect();
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'Déchargement terminé.');
    await tester.tap(find.byTooltip('Envoyer'));
    await settle(tester);

    expect(find.text('Déchargement terminé.'), findsOneWidget);
    expect(_isMine(tester, 'Déchargement terminé.'), isTrue);
    expect(
      backend.calls('POST', ApiEndpoints.messages(5)).single.bodyText,
      contains('Déchargement terminé.'),
    );

    // Écho du même message (idMessage 418) par le WebSocket.
    connector.connections.last.receive(jsonEncode(Contract.realtimeMessage));
    await settle(tester);
    expect(find.text('Déchargement terminé.'), findsOneWidget);

    await container.read(realtimeServiceProvider).disconnect();
  });

  testWidgets('erreur serveur : message et « Réessayer »', (tester) async {
    final backend = _backend()
      ..json('GET', ApiEndpoints.messages(5), 500, {
        'horodatage': '2026-09-28T11:41:08.074816Z',
        'statut': 500,
        'erreur': 'Erreur interne',
        'message': 'Une erreur inattendue est survenue',
        'details': <String>[],
      });
    await pumpScreen(
      tester,
      const ChatScreen(idConversation: 5),
      backend: backend,
      session: testSession(),
    );

    expect(find.text('Une erreur inattendue est survenue'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
