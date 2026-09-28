import 'dart:async';

import 'package:web_socket_channel/io.dart';

/// Connexion WebSocket abstraite (remplaçable en test).
abstract interface class RealtimeConnection {
  Stream<Object?> get frames;

  void send(String data);

  Future<void> close();
}

typedef RealtimeConnector =
    Future<RealtimeConnection> Function(Uri uri, Duration timeout);

/// Implémentation `dart:io`.
Future<RealtimeConnection> ioRealtimeConnector(
  Uri uri,
  Duration timeout,
) async {
  final channel = IOWebSocketChannel.connect(uri, connectTimeout: timeout);
  await channel.ready;
  return _IoConnection(channel);
}

class _IoConnection implements RealtimeConnection {
  _IoConnection(this._channel);

  final IOWebSocketChannel _channel;

  @override
  Stream<Object?> get frames => _channel.stream;

  @override
  void send(String data) => _channel.sink.add(data);

  @override
  Future<void> close() async {
    try {
      await _channel.sink.close();
    } on Object {
      // Connexion déjà fermée.
    }
  }
}
