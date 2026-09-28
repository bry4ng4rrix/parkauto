import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/domain/enums.dart';
import '../domain/messaging_models.dart';

/// Reconnaît les messages du conducteur connecté : `auteur.idUtilisateur`
/// comparé au claim `idUtilisateur` du jeton ; à défaut (claim absent),
/// nom complet et rôle CONDUCTEUR.
final ownMessageMatcherProvider = Provider<bool Function(Message)>((ref) {
  final (userId, nomComplet) = ref.watch(
    sessionControllerProvider.select(
      (s) => (s.session?.idUtilisateur, s.session?.nomComplet),
    ),
  );
  return (message) {
    final author = message.auteur;
    if (userId != null) return author.idUtilisateur == userId;
    return nomComplet != null &&
        author.role == UserRoles.conducteur &&
        author.nomComplet == nomComplet;
  };
});
