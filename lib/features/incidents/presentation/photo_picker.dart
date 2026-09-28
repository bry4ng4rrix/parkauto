import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/incident.dart';

/// Photo choisie sur l'appareil, déjà compressée par le sélecteur.
class PickedPhoto {
  const PickedPhoto({required this.path, required this.size});

  final String path;
  final int size;
}

class PhotoPickResult {
  const PhotoPickResult(this.photos, {this.rejected = 0, this.error});

  final List<PickedPhoto> photos;

  /// Photos écartées car > 5 Mo après compression.
  final int rejected;
  final String? error;
}

/// Caméra ou galerie, compression raisonnable (JPEG 80 %, 1920 px max),
/// contrôle de la taille (5 Mo) et du nombre restant.
class IncidentPhotoPicker {
  IncidentPhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  static const _quality = 80;
  static const _maxDimension = 1920.0;

  final ImagePicker _picker;

  Future<PhotoPickResult> pick({
    required ImageSource source,
    required int remaining,
  }) async {
    if (remaining <= 0) return const PhotoPickResult([]);
    try {
      final files = source == ImageSource.camera
          ? [
              ?await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: _quality,
                maxWidth: _maxDimension,
                maxHeight: _maxDimension,
              ),
            ]
          : await _picker.pickMultiImage(
              imageQuality: _quality,
              maxWidth: _maxDimension,
              maxHeight: _maxDimension,
              limit: remaining,
            );
      return _check(files.take(remaining).toList());
    } on PlatformException catch (e) {
      AppLogger.warning('Photos', 'Sélection impossible', e);
      return PhotoPickResult(
        const [],
        error: source == ImageSource.camera
            ? "Impossible d'ouvrir l'appareil photo. Vérifiez les autorisations."
            : "Impossible d'ouvrir la galerie. Vérifiez les autorisations.",
      );
    }
  }

  /// Android : photo prise alors que l'activité a été détruite.
  Future<PhotoPickResult> recoverLost() async {
    if (!Platform.isAndroid) return const PhotoPickResult([]);
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return const PhotoPickResult([]);
      return _check(response.files ?? const []);
    } on PlatformException {
      return const PhotoPickResult([]);
    }
  }

  Future<PhotoPickResult> _check(List<XFile> files) async {
    final accepted = <PickedPhoto>[];
    var rejected = 0;
    for (final file in files) {
      final size = await file.length();
      if (size > Incident.maxPhotoBytes) {
        rejected++;
      } else {
        accepted.add(PickedPhoto(path: file.path, size: size));
      }
    }
    return PhotoPickResult(accepted, rejected: rejected);
  }
}
