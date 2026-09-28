import 'dart:async';
import 'dart:math';

import '../logging/app_logger.dart';
import 'realtime_connection.dart';

enum RealtimeStatus { disconnected, connecting, connected }

/// Connexion temps réel unique : ticket à usage unique → WebSocket,
/// heartbeat « ping », reconnexion avec backoff exponentiel et jitter.
///
/// Un compteur de génération invalide toute opération en cours dès qu'une
/// nouvelle connexion est demandée : jamais deux sockets ouvertes.
class RealtimeService<E> {
  RealtimeService({
    required this._fetchTicket,
    required this._buildUri,
    required this._decode,
    this._connector = ioRealtimeConnector,
    bool Function(Object error)? isFatal,
    this.pingInterval = const Duration(seconds: 25),
    this.silenceTimeout = const Duration(seconds: 35),
    this.connectTimeout = const Duration(seconds: 10),
    this.maxBackoff = const Duration(seconds: 30),
    Random? random,
    DateTime Function()? clock,
  }) : _isFatal = isFatal ?? ((_) => false),
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now;

  static const _tick = Duration(seconds: 5);

  final Duration pingInterval;
  final Duration silenceTimeout;
  final Duration connectTimeout;
  final Duration maxBackoff;

  final Future<String> Function() _fetchTicket;
  final Uri Function(String ticket) _buildUri;
  final E? Function(Object? frame) _decode;
  final RealtimeConnector _connector;
  final bool Function(Object error) _isFatal;
  final Random _random;
  final DateTime Function() _clock;

  final _events = StreamController<E>.broadcast();
  final _statuses = StreamController<RealtimeStatus>.broadcast();

  RealtimeStatus _status = RealtimeStatus.disconnected;
  bool _wanted = false;
  bool _halted = false;
  int _generation = 0;
  int _attempt = 0;
  RealtimeConnection? _connection;
  // Annulée dans _teardown (appel null-aware non reconnu par le lint).
  // ignore: cancel_subscriptions
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _retryTimer;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPingAt = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<E> get events => _events.stream;

  Stream<RealtimeStatus> get statusChanges => _statuses.stream;

  RealtimeStatus get status => _status;

  /// Démarre la connexion (sans effet si elle est déjà active).
  void connect() {
    _wanted = true;
    _halted = false;
    if (_status != RealtimeStatus.disconnected || _retryTimer != null) return;
    unawaited(_open());
  }

  /// Nouvelle connexion immédiate (retour du réseau, reprise).
  void reconnect() {
    if (!_wanted || _halted) return;
    _attempt = 0;
    _teardown();
    unawaited(_open());
  }

  /// Fermeture propre ; aucune reconnexion automatique ensuite.
  Future<void> disconnect() async {
    _wanted = false;
    final connection = _teardown();
    _setStatus(RealtimeStatus.disconnected);
    await connection?.close();
  }

  void sendPing() => _send('ping');

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    await _statuses.close();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    _setStatus(RealtimeStatus.connecting);
    try {
      final ticket = await _fetchTicket();
      if (!_isCurrent(generation)) return;
      final connection = await _connector(_buildUri(ticket), connectTimeout);
      if (!_isCurrent(generation)) {
        await connection.close();
        return;
      }
      _connection = connection;
      _attempt = 0;
      _lastFrameAt = _clock();
      _subscription = connection.frames.listen(
        (frame) => _onFrame(generation, frame),
        onError: (Object error) => _onDropped(generation, error),
        onDone: () => _onDropped(generation, null),
        cancelOnError: true,
      );
      _setStatus(RealtimeStatus.connected);
      AppLogger.debug('Realtime', 'WebSocket connecté');
      _heartbeat = Timer.periodic(_tick, (_) => _checkHeartbeat(generation));
      sendPing();
    } on Object catch (error) {
      if (!_isCurrent(generation)) return;
      if (_isFatal(error)) {
        AppLogger.warning('Realtime', 'Temps réel arrêté', error);
        _halted = true;
        _setStatus(RealtimeStatus.disconnected);
        return;
      }
      AppLogger.debug('Realtime', 'Connexion impossible : $error');
      _scheduleRetry(generation);
    }
  }

  void _onFrame(int generation, Object? frame) {
    if (!_isCurrent(generation)) return;
    _lastFrameAt = _clock();
    final event = _decode(frame);
    if (event != null && !_events.isClosed) _events.add(event);
  }

  void _checkHeartbeat(int generation) {
    if (!_isCurrent(generation)) return;
    final now = _clock();
    if (now.difference(_lastFrameAt) > silenceTimeout) {
      _onDropped(
        generation,
        'aucune trame depuis ${silenceTimeout.inSeconds} s',
      );
      return;
    }
    if (now.difference(_lastPingAt) >= pingInterval) sendPing();
  }

  void _onDropped(int generation, Object? reason) {
    if (!_isCurrent(generation)) return;
    AppLogger.debug(
      'Realtime',
      'WebSocket déconnecté${reason == null ? '' : ' ($reason)'}',
    );
    final connection = _teardown();
    unawaited(connection?.close());
    _scheduleRetry(_generation);
  }

  void _scheduleRetry(int generation) {
    _setStatus(RealtimeStatus.disconnected);
    final delay = _backoff(_attempt++);
    AppLogger.debug(
      'Realtime',
      'Nouvelle tentative dans ${delay.inMilliseconds} ms',
    );
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_isCurrent(generation)) unawaited(_open());
    });
  }

  Duration _backoff(int attempt) {
    final seconds = min(maxBackoff.inSeconds, 1 << min(attempt, 5));
    final jitter = 0.5 + _random.nextDouble() * 0.5;
    return Duration(milliseconds: (seconds * 1000 * jitter).round());
  }

  /// Invalide toute opération en cours ; renvoie l'ancienne connexion.
  RealtimeConnection? _teardown() {
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final connection = _connection;
    _connection = null;
    return connection;
  }

  bool _isCurrent(int generation) => _wanted && generation == _generation;

  void _send(String data) {
    final connection = _connection;
    if (connection == null) return;
    try {
      connection.send(data);
      _lastPingAt = _clock();
    } on Object catch (error) {
      _onDropped(_generation, error);
    }
  }

  void _setStatus(RealtimeStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }
}
