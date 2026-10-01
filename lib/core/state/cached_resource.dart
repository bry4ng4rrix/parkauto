import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/session_controller.dart';
import '../errors/app_exception.dart';
import '../errors/error_messages.dart';
import '../logging/app_logger.dart';
import '../storage/json_cache.dart';

/// Donnée affichée avec sa fraîcheur.
@immutable
class Cached<T> {
  const Cached({
    required this.value,
    required this.updatedAt,
    this.fromCache = false,
    this.refreshError,
  });

  final T value;
  final DateTime updatedAt;

  /// Lue depuis le cache local, pas encore confirmée par le serveur.
  final bool fromCache;

  /// Échec du dernier rafraîchissement (les données restent affichées).
  final AppException? refreshError;

  bool get isOffline => refreshError is NetworkException;

  bool get isStale => fromCache || refreshError != null;

  Cached<T> withError(AppException error) => Cached(
    value: value,
    updatedAt: updatedAt,
    fromCache: fromCache,
    refreshError: error,
  );
}

/// Requête GET dont la réponse JSON brute est mise en cache.
@immutable
class CachedQuery<T> {
  const CachedQuery({
    required this.key,
    required this.fetch,
    required this.parse,
  });

  final String key;
  final Future<Object?> Function(ApiClient api) fetch;
  final T Function(Object? json) parse;
}

/// Affiche d'abord le cache, puis revalide auprès du serveur.
/// Sans cache : chargement réseau (skeleton), puis données ou erreur.
abstract class CachedResourceNotifier<T extends Object>
    extends AsyncNotifier<Cached<T>> {
  CachedQuery<T> get query;

  Future<AppException?>? _pending;

  @override
  Future<Cached<T>> build() async {
    final driverId = ref.watch(currentDriverIdProvider);
    if (driverId == null) throw const SessionExpiredException();

    final cached = await ref.read(jsonCacheProvider).read(driverId, query.key);
    if (cached != null) {
      final value = _parseCached(cached.data);
      if (value != null) {
        scheduleMicrotask(() => unawaited(refresh()));
        return Cached(value: value, updatedAt: cached.savedAt, fromCache: true);
      }
    }
    return _fetch(driverId);
  }

  /// Rafraîchit depuis le serveur. Renvoie l'erreur éventuelle ; les
  /// données déjà affichées sont conservées.
  Future<AppException?> refresh() async {
    final current = state;
    if (current.isLoading && !current.hasValue) {
      // Premier chargement en cours : on attend son résultat. S'il vient du
      // cache, l'appelant attend la revalidation serveur qui suit.
      try {
        final loaded = await future;
        if (!loaded.fromCache || !ref.mounted) return null;
      } on Object catch (error) {
        return asAppException(error);
      }
    }
    return _pending ??= _refresh().whenComplete(() => _pending = null);
  }

  /// Applique localement une donnée renvoyée par une mutation.
  void mutate(T Function(T current) update) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      Cached(value: update(current.value), updatedAt: DateTime.now()),
    );
  }

  Future<AppException?> _refresh() async {
    final driverId = ref.read(currentDriverIdProvider);
    if (driverId == null) return const SessionExpiredException();
    try {
      final fresh = await _fetch(driverId);
      if (!ref.mounted) return null;
      state = AsyncData(fresh);
      return null;
    } on AppException catch (e) {
      if (!ref.mounted) return e;
      final current = state.value;
      state = current != null
          ? AsyncData(current.withError(e))
          : AsyncError(e, StackTrace.current);
      return e;
    }
  }

  Future<Cached<T>> _fetch(int driverId) async {
    final raw = await query.fetch(ref.read(apiClientProvider));
    final value = query.parse(raw);
    await ref.read(jsonCacheProvider).write(driverId, query.key, raw);
    return Cached(value: value, updatedAt: DateTime.now());
  }

  T? _parseCached(Object? data) {
    try {
      return query.parse(data);
    } on AppException catch (e) {
      AppLogger.warning('Cache', 'Cache illisible (${query.key})', e);
      return null;
    }
  }
}
