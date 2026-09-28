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
  TokenRefresher(this._ref);

  final Ref _ref;
  Future<Session>? _inFlight;

  Future<Session> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<Session> _refresh() async {
    final controller = _ref.read(sessionControllerProvider.notifier);
    final current = controller.session;
    if (current == null) throw const SessionExpiredException();
    final epoch = controller.epoch;

    AppLogger.debug('Auth', 'Rafraîchissement du jeton');
    final AuthResponse auth;
    try {
      auth = await _ref
          .read(authApiProvider)
          .rafraichir(current.jetonRafraichissement);
    } on AppException catch (e) {
      if (isRefreshRejected(e)) {
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
}

final tokenRefresherProvider = Provider<TokenRefresher>(TokenRefresher.new);
