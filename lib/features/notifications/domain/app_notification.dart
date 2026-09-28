import 'package:flutter/foundation.dart';

/// Origine d'une notification locale. Le backend n'expose pas d'endpoint
/// de notifications : elles sont construites dans l'application.
enum AppNotificationKind {
  message('message'),
  mission('mission'),
  incident('incident'),
  vehicleAlert('alerte'),
  expiry('echeance'),
  info('info');

  const AppNotificationKind(this.key);

  final String key;

  static AppNotificationKind parse(String? key) => values.firstWhere(
    (k) => k.key == key,
    orElse: () => AppNotificationKind.info,
  );
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.route,
    this.conversationId,
  });

  /// Identifiant stable : sert au dédoublonnage.
  final String id;
  final AppNotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// Écran ouvert au toucher (ex. `/chat/5`).
  final String? route;
  final int? conversationId;

  AppNotification asRead() => read
      ? this
      : AppNotification(
          id: id,
          kind: kind,
          title: title,
          body: body,
          createdAt: createdAt,
          read: true,
          route: route,
          conversationId: conversationId,
        );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.key,
    'title': title,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'read': read,
    'route': route,
    'conversationId': conversationId,
  };

  static AppNotification? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    final body = json['body'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (id is! String ||
        title is! String ||
        body is! String ||
        createdAt == null) {
      return null;
    }
    final kind = json['kind'];
    final route = json['route'];
    final conversationId = json['conversationId'];
    return AppNotification(
      id: id,
      kind: AppNotificationKind.parse(kind is String ? kind : null),
      title: title,
      body: body,
      createdAt: createdAt,
      read: json['read'] == true,
      route: route is String ? route : null,
      conversationId: conversationId is int ? conversationId : null,
    );
  }
}
