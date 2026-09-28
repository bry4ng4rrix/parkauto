import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../data/messaging_repository.dart';
import '../domain/messaging_models.dart';

/// Téléchargements en cours : `idPieceJointe` → progression (0 → 1).
final attachmentDownloadsProvider =
    NotifierProvider.autoDispose<AttachmentDownloads, Map<int, double>>(
      AttachmentDownloads.new,
    );

class AttachmentDownloads extends Notifier<Map<int, double>> {
  @override
  Map<int, double> build() => const {};

  /// `GET /api/messagerie/pieces-jointes/{id}` (binaire) puis ouverture
  /// avec l'application du téléphone. Renvoie un message d'erreur ou null.
  Future<String?> open(Attachment attachment) async {
    final id = attachment.idPieceJointe;
    if (state.containsKey(id)) return null;
    state = {...state, id: 0};
    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/pieces-jointes/$id-${_safeName(attachment.nom)}',
      );
      if (!file.existsSync()) {
        final bytes = await ref
            .read(messagingRepositoryProvider)
            .telechargerPieceJointe(
              id,
              onProgress: (received, total) {
                if (total > 0 && ref.mounted) {
                  state = {...state, id: received / total};
                }
              },
            );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
      }
      final result = await OpenFilex.open(file.path, type: attachment.typeContenu);
      return switch (result.type) {
        ResultType.done => null,
        ResultType.noAppToOpen =>
          "Aucune application ne permet d'ouvrir ce fichier.",
        _ => "Impossible d'ouvrir le fichier.",
      };
    } on AppException catch (e) {
      return e.userMessage;
    } on FileSystemException catch (e) {
      AppLogger.warning('Messagerie', 'Écriture du fichier impossible', e);
      return "Impossible d'enregistrer le fichier sur l'appareil.";
    } finally {
      if (ref.mounted) state = {...state}..remove(id);
    }
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
