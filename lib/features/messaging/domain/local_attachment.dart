import 'package:flutter/foundation.dart';

import '../../../core/utils/file_names.dart';

/// Fichier choisi sur l'appareil, pas encore envoyé.
@immutable
class LocalAttachment {
  const LocalAttachment({required this.path, required this.name, this.size});

  factory LocalAttachment.fromPath(String path, {int? size}) =>
      LocalAttachment(path: path, name: fileNameOf(path), size: size);

  final String path;
  final String name;
  final int? size;

  bool get isImage => isImageFileName(name);
}
