import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:parkauto/app/config/app_config.dart';
import 'package:parkauto/core/api/dio_factory.dart';
import 'package:parkauto/core/auth/session.dart';
import 'package:parkauto/core/auth/session_controller.dart';
import 'package:parkauto/core/auth/session_store.dart';
import 'package:parkauto/core/network/network_status.dart';
import 'package:parkauto/core/notifications/local_notification_service.dart';
import 'package:parkauto/core/notifications/notification_payload.dart';
import 'package:parkauto/core/websocket/realtime_connection.dart';
import 'package:parkauto/features/messaging/application/realtime.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_backend.dart';

const testConfig = AppConfig(
  environment: AppEnvironment.dev,
  apiBaseUrl: 'http://parkauto.test',
  wsBaseUrl: 'ws://parkauto.test',
);

/// Session valide ; `idUtilisateur` 27 comme dans le contrat.
Session testSession({
  String access = 'access-1',
  String refresh = 'refresh-1',
  bool accessExpired = false,
}) {
  final now = DateTime.now().toUtc();
  return Session(
    jetonAcces: access,
    jetonRafraichissement: refresh,
    accessExpiresAt: accessExpired
        ? now.subtract(const Duration(minutes: 1))
        : now.add(const Duration(hours: 1)),
    refreshExpiresAt: now.add(const Duration(days: 30)),
    idConducteur: 12,
    idUtilisateur: 27,
    nomComplet: 'Tiana RABE',
    role: 'CONDUCTEUR',
  );
}

class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this.session]);

  Session? session;

  @override
  Future<Session?> read() async => session;

  @override
  Future<void> write(Session session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<void> wipe() async => session = null;
}

class FakeLocalNotifications implements LocalNotificationService {
  final shown = <({int id, String title, String body, NotificationPayload payload})>[];
  final _taps = StreamController<NotificationPayload>.broadcast();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showMessage({
    required int id,
    required String title,
    required String body,
    required NotificationPayload payload,
  }) async => shown.add((id: id, title: title, body: body, payload: payload));

  @override
  Stream<NotificationPayload> get taps => _taps.stream;

  @override
  NotificationPayload? takeLaunchPayload() => null;

  @override
  Future<void> cancelAll() async => shown.clear();

  Future<void> dispose() => _taps.close();
}

/// WebSocket simulé : trames entrantes injectables, trames sortantes
/// enregistrées.
class FakeRealtimeConnection implements RealtimeConnection {
  final _frames = StreamController<Object?>();
  final sent = <String>[];
  bool closed = false;

  @override
  Stream<Object?> get frames => _frames.stream;

  @override
  void send(String data) => sent.add(data);

  void receive(Object? frame) => _frames.add(frame);

  /// Coupure côté serveur.
  Future<void> drop() => _frames.close();

  @override
  Future<void> close() async {
    closed = true;
    if (!_frames.isClosed) await _frames.close();
  }
}

class FakeRealtimeConnector {
  final connections = <FakeRealtimeConnection>[];
  final uris = <Uri>[];

  Future<RealtimeConnection> call(Uri uri, Duration timeout) async {
    uris.add(uri);
    final connection = FakeRealtimeConnection();
    connections.add(connection);
    return connection;
  }
}

/// Préférences en mémoire (cache, notifications locales).
void useInMemoryPreferences() {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
}

List<Override> testOverrides({
  required FakeBackend backend,
  required SessionStore store,
  LocalNotificationService? notifications,
  FakeRealtimeConnector? connector,
}) => [
  appConfigProvider.overrideWithValue(testConfig),
  httpClientAdapterProvider.overrideWithValue(backend),
  sessionStoreProvider.overrideWithValue(store),
  localNotificationServiceProvider.overrideWithValue(
    notifications ?? FakeLocalNotifications(),
  ),
  realtimeConnectorProvider.overrideWithValue(
    (connector ?? FakeRealtimeConnector()).call,
  ),
  connectivityProvider.overrideWith((ref) => Stream.value(true)),
];

/// Conteneur de test (retry désactivé) avec une session éventuelle déjà
/// restaurée.
Future<ProviderContainer> createContainer({
  required FakeBackend backend,
  Session? session,
  LocalNotificationService? notifications,
  FakeRealtimeConnector? connector,
  List<Override> overrides = const [],
  bool freshPreferences = true,
}) async {
  if (freshPreferences) useInMemoryPreferences();
  final container = ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      ...testOverrides(
        backend: backend,
        store: InMemorySessionStore(session),
        notifications: notifications,
        connector: connector,
      ),
      ...overrides,
    ],
  );
  await container.read(sessionControllerProvider.notifier).restore();
  return container;
}
