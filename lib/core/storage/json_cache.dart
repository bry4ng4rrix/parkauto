import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';
import 'preferences.dart';

@immutable
class CachedJson {
  const CachedJson(this.data, this.savedAt);

  final Object? data;
  final DateTime savedAt;
}

/// Dernières réponses JSON reçues, par conducteur, pour l'affichage
/// hors connexion. Purgé à la déconnexion.
class JsonCache {
  JsonCache(this._prefs);

  static const _prefix = 'cache.';

  final SharedPreferencesAsync _prefs;

  String _key(int driverId, String resource) => '$_prefix$driverId.$resource';

  Future<CachedJson?> read(int driverId, String resource) async {
    try {
      final raw = await _prefs.getString(_key(driverId, resource));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = DateTime.tryParse('${decoded['savedAt']}');
      if (savedAt == null) return null;
      return CachedJson(decoded['data'], savedAt);
    } on Exception catch (e) {
      AppLogger.warning('Cache', 'Lecture impossible ($resource)', e);
      return null;
    }
  }

  Future<void> write(int driverId, String resource, Object? data) async {
    try {
      await _prefs.setString(
        _key(driverId, resource),
        jsonEncode({
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'data': data,
        }),
      );
    } on Exception catch (e) {
      AppLogger.warning('Cache', 'Écriture impossible ($resource)', e);
    }
  }

  Future<void> clearAll() async {
    final keys = (await _prefs.getKeys())
        .where((k) => k.startsWith(_prefix))
        .toSet();
    if (keys.isNotEmpty) await _prefs.clear(allowList: keys);
  }
}

final jsonCacheProvider = Provider<JsonCache>(
  (ref) => JsonCache(ref.watch(preferencesProvider)),
);
