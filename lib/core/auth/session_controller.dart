import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import 'auth_api.dart';
import 'auth_response.dart';
import 'session.dart';
import 'session_store.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

enum SignOutReason { userRequested, sessionExpired }

@immutable
class AuthState {
  const AuthState._(this.status, this.session, this.reason);

  const AuthState.unknown() : this._(AuthStatus.unknown, null, null);

  const AuthState.authenticated(Session session)
    : this._(AuthStatus.authenticated, session, null);

  const AuthState.unauthenticated([SignOutReason? reason])
    : this._(AuthStatus.unauthenticated, null, reason);

  final AuthStatus status;
  final Session? session;
  final SignOutReason? reason;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final sessionControllerProvider =
    NotifierProvider<SessionController, AuthState>(SessionController.new);

/// Identité stable du conducteur connecté : ne change pas lors d'un
/// rafraîchissement de jeton, donc ne reconstruit pas les données.
final currentDriverIdProvider = Provider<int?>(
  (ref) => ref.watch(
    sessionControllerProvider.select((s) => s.session?.idConducteur),
  ),
);

/// `idUtilisateur` du conducteur (claim du jeton), pour la messagerie.
final currentUserIdProvider = Provider<int?>(
  (ref) => ref.watch(
    sessionControllerProvider.select((s) => s.session?.idUtilisateur),
  ),
);

class SessionController extends Notifier<AuthState> {
  /// Incrémenté à chaque connexion / déconnexion : un rafraîchissement
  /// lancé pour une session précédente est ignoré.
  int _epoch = 0;

  @override
  AuthState build() => const AuthState.unknown();

  SessionStore get _store => ref.read(sessionStoreProvider);

  int get epoch => _epoch;

  Session? get session => state.session;

  /// Splash : lecture locale uniquement, aucun appel réseau.
  Future<void> restore() async {
    if (state.status != AuthStatus.unknown) return;
    final stored = await _store.read();
    if (stored == null) {
      state = const AuthState.unauthenticated();
    } else if (stored.isRefreshExpired(DateTime.now())) {
      await _store.clear();
      state = const AuthState.unauthenticated(SignOutReason.sessionExpired);
    } else {
      state = AuthState.authenticated(stored);
    }
  }

  Future<void> signIn(AuthResponse auth) async {
    final session = Session.fromAuth(auth, now: DateTime.now());
    _epoch++;
    await _store.write(session);
    state = AuthState.authenticated(session);
  }

  /// Applique des jetons rafraîchis, sauf si la session a changé entre-temps.
  Future<bool> applyRefreshed(Session renewed, int epoch) async {
    if (epoch != _epoch || !state.isAuthenticated) return false;
    state = AuthState.authenticated(renewed);
    await _store.write(renewed);
    return true;
  }

  /// Jeton de rafraîchissement refusé : retour à la connexion.
  Future<void> expire() async {
    if (!state.isAuthenticated) return;
    _epoch++;
    state = const AuthState.unauthenticated(SignOutReason.sessionExpired);
    await _store.clear();
  }

  Future<void> signOut() async {
    final current = state.session;
    _epoch++;
    state = const AuthState.unauthenticated(SignOutReason.userRequested);
    await _store.clear();
    if (current != null) {
      unawaited(_revoke(current.jetonRafraichissement));
    }
  }

  Future<void> _revoke(String jetonRafraichissement) async {
    try {
      await ref.read(authApiProvider).deconnexion(jetonRafraichissement);
    } on Exception catch (e) {
      AppLogger.warning('Auth', 'Déconnexion serveur non confirmée', e);
    }
  }
}
