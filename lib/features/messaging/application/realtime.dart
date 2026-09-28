import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/websocket/realtime_connection.dart';
import '../../../core/websocket/realtime_service.dart';
import '../data/messaging_repository.dart';
import '../domain/realtime_event.dart';

/// Connecteur WebSocket (remplacé par un faux en test).
final realtimeConnectorProvider = Provider<RealtimeConnector>(
  (ref) => ioRealtimeConnector,
);

/// Service temps réel unique de l'application.
final realtimeServiceProvider = Provider<RealtimeService<RealtimeEvent>>((ref) {
  final config = ref.watch(appConfigProvider);
  final service = RealtimeService<RealtimeEvent>(
    fetchTicket: () async =>
        (await ref.read(messagingRepositoryProvider).ticketTempsReel()).ticket,
    buildUri: config.realtimeUri,
    decode: RealtimeEvent.decode,
    connector: ref.watch(realtimeConnectorProvider),
    // Session refusée ou accès interdit : inutile d'insister.
    isFatal: (error) =>
        error is SessionExpiredException ||
        (error is ApiException && error.isForbidden),
    connectTimeout: config.connectTimeout,
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// État de la connexion, pour l'indicateur de la messagerie.
final realtimeStatusProvider = StreamProvider<RealtimeStatus>((ref) async* {
  final service = ref.watch(realtimeServiceProvider);
  yield service.status;
  yield* service.statusChanges;
});

/// Conversation affichée à l'écran (route courante, app au premier plan).
final activeConversationProvider = NotifierProvider<ActiveConversation, int?>(
  ActiveConversation.new,
);

class ActiveConversation extends Notifier<int?> {
  @override
  int? build() => null;

  // Appelés de façon différée par l'écran : le conteneur peut déjà avoir
  // été libéré (fermeture de l'application).
  void enter(int idConversation) {
    if (ref.mounted) state = idConversation;
  }

  void leave(int idConversation) {
    if (ref.mounted && state == idConversation) state = null;
  }
}
