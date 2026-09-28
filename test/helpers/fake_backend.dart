import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = FutureOr<FakeReply> Function(RecordedRequest request);

/// Réponse simulée.
class FakeReply {
  const FakeReply.json(this.status, this.body)
    : bytes = null,
      networkError = false,
      delay = Duration.zero;

  const FakeReply.noContent()
    : status = 204,
      body = null,
      bytes = null,
      networkError = false,
      delay = Duration.zero;

  const FakeReply.bytes(this.bytes, {this.status = 200})
    : body = null,
      networkError = false,
      delay = Duration.zero;

  const FakeReply.networkError()
    : status = 0,
      body = null,
      bytes = null,
      networkError = true,
      delay = Duration.zero;

  const FakeReply.delayed(this.status, this.body, this.delay)
    : bytes = null,
      networkError = false;

  final int status;
  final Object? body;
  final List<int>? bytes;
  final bool networkError;
  final Duration delay;
}

/// Requête reçue par le faux backend.
class RecordedRequest {
  RecordedRequest(this.options, this.body);

  final RequestOptions options;
  final List<int> body;

  String get method => options.method;
  String get path => options.uri.path;
  Map<String, String> get query => options.uri.queryParameters;
  String? get authorization => options.headers['Authorization'] as String?;
  String get bodyText => utf8.decode(body, allowMalformed: true);
  Object? get json => body.isEmpty ? null : jsonDecode(bodyText);
}

/// Faux serveur branché comme `HttpClientAdapter` de Dio. Partagé par les
/// clients clonés (rejeu après rafraîchissement du jeton).
class FakeBackend implements HttpClientAdapter {
  final requests = <RecordedRequest>[];
  final _routes = <(String, String, FakeHandler)>[];

  /// Déclare une route ; la dernière déclarée l'emporte.
  void on(String method, String path, FakeHandler handler) =>
      _routes.insert(0, (method, path, handler));

  void json(String method, String path, int status, Object? body) =>
      on(method, path, (_) => FakeReply.json(status, body));

  Iterable<RecordedRequest> calls(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = requestStream == null
        ? <int>[]
        : await requestStream.expand((chunk) => chunk).toList();
    final request = RecordedRequest(options, body);
    requests.add(request);

    FakeHandler? handler;
    for (final (method, path, h) in _routes) {
      if (method == options.method && path == options.uri.path) {
        handler = h;
        break;
      }
    }
    final reply = handler == null
        ? const FakeReply.json(404, {
            'horodatage': '2026-09-28T09:31:02.418Z',
            'statut': 404,
            'erreur': 'Ressource introuvable',
            'message': 'Route non simulée',
            'details': <String>[],
          })
        : await handler(request);

    if (reply.delay > Duration.zero) await Future<void>.delayed(reply.delay);
    if (reply.networkError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Réseau simulé indisponible',
      );
    }
    final bytes = reply.bytes;
    if (bytes != null) {
      return ResponseBody.fromBytes(
        bytes,
        reply.status,
        headers: {
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
    }
    if (reply.status == 204) return ResponseBody.fromString('', 204);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
