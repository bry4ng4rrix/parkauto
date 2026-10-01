import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import '../logging/app_logger.dart';
import 'auth_api.dart';
import 'auth_response.dart';
import 'session.dart';
import 'session_controller.dart';

/// Rafraîchissement unique partagé : les requêtes concurrentes, le ticket
/// temps réel et le rafraîchissement anticipé attendent le même Future.
class TokenRefresher {
  TokenRefresher(
    this._ref, {
    this.concurrentRefreshGrace = const Duration(seconds: 1),
  });

  final Ref _ref;

  /// Attente avant de relire la session enregistrée après un refus.
  final Duration concurrentRefreshGrace;
  Future<Session>? _inFlight;

  Future<Session> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<Session> _refresh() async {
    final controller = _ref.read(sessionControllerProvider.notifier);
    final current = controller.session;
    if (current == null) throw const SessionExpiredException();
    final epoch = controller.epoch;

    // La vérification en arrière-plan (autre isolat) a pu renouveler les
    // jetons : on reprend les plus récents avant d'en consommer un.
    final adopted = await _adoptStoredSession(current, epoch);
    if (adopted != null) return adopted;

    AppLogger.debug('Auth', 'Rafraîchissement du jeton');
    final AuthResponse auth;
    try {
      auth = await _ref
          .read(authApiProvider)
          .rafraichir(current.jetonRafraichissement);
    } on AppException catch (e) {
      if (isRefreshRejected(e)) {
        // Refus dû à un renouvellement concurrent : pas une vraie expiration.
        // Le gagnant enregistre ses jetons juste après sa réponse.
        await Future<void>.delayed(concurrentRefreshGrace);
        final concurrent = await _adoptStoredSession(current, epoch);
        if (concurrent != null) return concurrent;
        AppLogger.debug('Auth', 'Jeton de rafraîchissement refusé');
        if (epoch == controller.epoch) await controller.expire();
        throw const SessionExpiredException();
      }
      // Erreur réseau ou serveur : la session est conservée.
      rethrow;
    }

    final renewed = current.renewed(auth, now: DateTime.now());
    final applied = await controller.applyRefreshed(renewed, epoch);
    if (!applied) throw const SessionExpiredException();
    AppLogger.debug('Auth', 'Jeton rafraîchi');
    return renewed;
  }

  /// Session enregistrée plus récente que [current] (autres jetons, accès
  /// encore valide), appliquée et renvoyée ; sinon `null`.
  Future<Session?> _adoptStoredSession(Session current, int epoch) async {
    final stored = await _ref.read(sessionStoreProvider).read();
    if (stored == null ||
        stored.jetonRafraichissement == current.jetonRafraichissement ||
        stored.isAccessExpired(DateTime.now())) {
      return null;
    }
    final applied = await _ref
        .read(sessionControllerProvider.notifier)
        .applyRefreshed(stored, epoch);
    return applied ? stored : null;
  }
}

final tokenRefresherProvider = Provider<TokenRefresher>(TokenRefresher.new);
