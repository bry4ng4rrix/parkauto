import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/auth/auth_api.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/errors/app_exception.dart';

@immutable
class LoginState {
  const LoginState({this.submitting = false, this.error});

  final bool submitting;
  final AppException? error;

  /// Erreurs 400 rattachées aux champs `email` / `motDePasse`.
  Map<String, String> get fieldErrors => switch (error) {
    ApiException(:final fieldErrors) => fieldErrors,
    _ => const {},
  };
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  /// `POST /api/auth/mobile/connexion`, puis ouverture de session. Le
  /// routeur redirige vers l'accueil, qui charge `GET /api/moi`.
  Future<bool> submit({required String email, required String password}) async {
    if (state.submitting) return false;
    state = const LoginState(submitting: true);
    try {
      final auth = await ref
          .read(authApiProvider)
          .connexion(
            email: email.trim(),
            motDePasse: password,
            appareil: ref.read(appConfigProvider).deviceName,
          );
      await ref.read(sessionControllerProvider.notifier).signIn(auth);
      if (ref.mounted) state = const LoginState();
      return true;
    } on AppException catch (e) {
      if (ref.mounted) state = LoginState(error: e);
      return false;
    }
  }
}
