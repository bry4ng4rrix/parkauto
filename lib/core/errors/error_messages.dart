import 'package:flutter_riverpod/misc.dart';

import 'app_exception.dart';

/// Retrouve l'[AppException] d'origine, y compris quand Riverpod l'a
/// enveloppée dans une [ProviderException].
AppException asAppException(Object error) => switch (error) {
  AppException() => error,
  ProviderException(:final exception) => asAppException(exception),
  _ => UnexpectedException(error),
};

/// Message à afficher à l'utilisateur. Jamais de trace technique.
String userMessageOf(Object error) => asAppException(error).userMessage;

bool isOfflineError(Object error) =>
    asAppException(error) is NetworkException;
