import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/errors/api_error.dart';
import 'package:parkauto/core/errors/app_exception.dart';
import 'package:parkauto/core/websocket/realtime_service.dart';
import 'package:parkauto/features/messaging/domain/realtime_event.dart';

import '../helpers/contract.dart';
import '../helpers/test_app.dart';

class _Harness {
  _Harness(FakeAsync async, {Object? ticketError}) {
    final clock = async.getClock(DateTime(2026, 9, 28));
    service = RealtimeService<RealtimeEvent>(
      fetchTicket: () async {
        tickets++;
        if (ticketError case final error?) throw error;
        return 'ticket-$tickets';
      },
      buildUri: testConfig.realtimeUri,
      decode: RealtimeEvent.decode,
      connector: connector.call,
      isFatal: (e) => e is ApiException && e.isForbidden,
      clock: clock.now,
      random: Random(1),
    );
    service.events.listen(events.add);
  }

  final connector = FakeRealtimeConnector();
  final events = <RealtimeEvent>[];
  late final RealtimeService<RealtimeEvent> service;
  int tickets = 0;

  FakeRealtimeConnection get last => connector.connections.last;
}

void main() {
  test('ticket → WebSocket → « ping » → PONG et MESSAGE', () {
    fakeAsync((async) {
      final h = _Harness(async)..service.connect();
      async.flushMicrotasks();

      expect(h.service.status, RealtimeStatus.connected);
      expect(
        h.connector.uris.single.toString(),
        'ws://parkauto.test/ws/messagerie?ticket=ticket-1',
      );
      expect(h.last.sent, ['ping']);

      h.last
        ..receive('{"type":"PONG"}')
        ..receive(jsonEncode(Contract.realtimeMessage));
      async.flushMicrotasks();

      expect(h.events[0], isA<RealtimePong>());
      expect(
        (h.events[1] as MessageRealtimeEvent).message.idMessage,
        418,
      );
      h.service.dispose();
      async.flushMicrotasks();
    });
  });

  test('coupure : reconnexion avec backoff et un nouveau ticket', () {
    fakeAsync((async) {
      final h = _Harness(async)..service.connect();
      async.flushMicrotasks();

      h.last.drop();
      async.flushMicrotasks();
      expect(h.service.status, RealtimeStatus.disconnected);
      expect(h.connector.connections, hasLength(1));

      async.elapse(const Duration(seconds: 2));
      expect(h.connector.connections, hasLength(2));
      expect(h.tickets, 2);
      expect(h.connector.uris.last.queryParameters['ticket'], 'ticket-2');
      expect(h.service.status, RealtimeStatus.connected);
      h.service.dispose();
      async.flushMicrotasks();
    });
  });

  test('heartbeat : ping périodique, reconnexion après silence', () {
    fakeAsync((async) {
      final h = _Harness(async)..service.connect();
      async.flushMicrotasks();
      final first = h.last;

      async.elapse(const Duration(seconds: 26));
      expect(first.sent.where((s) => s == 'ping'), hasLength(2));

      // Aucune trame reçue : la connexion est jugée morte.
      async.elapse(const Duration(seconds: 15));
      expect(first.closed, isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(h.connector.connections, hasLength(2));
      h.service.dispose();
      async.flushMicrotasks();
    });
  });

  test('une trame reçue maintient la connexion en vie', () {
    fakeAsync((async) {
      final h = _Harness(async)..service.connect();
      async.flushMicrotasks();
      for (var i = 0; i < 6; i++) {
        async.elapse(const Duration(seconds: 20));
        h.last.receive('{"type":"PONG"}');
        async.flushMicrotasks();
      }
      expect(h.connector.connections, hasLength(1));
      h.service.dispose();
      async.flushMicrotasks();
    });
  });

  test('jamais deux sockets : connect() répété', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..service.connect()
        ..service.connect();
      async.flushMicrotasks();
      h.service.connect();
      async.flushMicrotasks();
      expect(h.connector.connections, hasLength(1));
      expect(h.tickets, 1);
      h.service.dispose();
      async.flushMicrotasks();
    });
  });

  test('403 sur le ticket : arrêt sans nouvelle tentative', () {
    fakeAsync((async) {
      final forbidden = ApiException(
        ApiError(
          horodatage: DateTime.utc(2026),
          statut: 403,
          erreur: 'Accès refusé',
          message: 'Rôle insuffisant pour cette action',
        ),
        403,
      );
      final h = _Harness(async, ticketError: forbidden)..service.connect();
      async.elapse(const Duration(minutes: 2));
      expect(h.tickets, 1);
      expect(h.connector.connections, isEmpty);
      expect(h.service.status, RealtimeStatus.disconnected);
      h.service.dispose();
      async.flushMicrotasks();
    });
  });

  test('erreur réseau sur le ticket : nouvelles tentatives espacées', () {
    fakeAsync((async) {
      final h = _Harness(
        async,
        ticketError: const NetworkException(NetworkFailure.offline),
      )..service.connect();
      async.elapse(const Duration(seconds: 40));
      // 1 s, 2 s, 4 s, 8 s, 16 s (jitter 50–100 %) : 5 à 7 essais.
      expect(h.tickets, inInclusiveRange(5, 8));
      h.service.dispose();
      async.flushMicrotasks();
    });
  });

  test('disconnect() ferme la socket et annule les tentatives', () {
    fakeAsync((async) {
      final h = _Harness(async)..service.connect();
      async.flushMicrotasks();
      final connection = h.last;
      h.service.disconnect();
      async.elapse(const Duration(minutes: 1));
      expect(connection.closed, isTrue);
      expect(h.connector.connections, hasLength(1));
      expect(h.service.status, RealtimeStatus.disconnected);
      h.service.dispose();
      async.flushMicrotasks();
    });
  });
}
