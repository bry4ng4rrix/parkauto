import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Contenu attaché à une notification système : écran à ouvrir et
/// destinataire (un toucher destiné à un autre compte est ignoré).
@immutable
class NotificationPayload {
  const NotificationPayload({required this.route, required this.userId});

  final String route;
  final int? userId;

  String encode() => jsonEncode({'route': route, 'uid': userId});

  static NotificationPayload? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final route = json['route'];
      final uid = json['uid'];
      if (route is! String || !route.startsWith('/')) return null;
      return NotificationPayload(route: route, userId: uid is int ? uid : null);
    } on FormatException {
      return null;
    }
  }
}
