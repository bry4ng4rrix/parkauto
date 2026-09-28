import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'linux_camera_screen.dart';
import 'photo_picker.dart';

/// Photo prise directement avec la caméra : appareil photo du téléphone
/// (Android, iOS) ou webcam sous Linux.
abstract final class CameraCapture {
  static bool get isAvailable =>
      Platform.isAndroid || Platform.isIOS || Platform.isLinux;

  static Future<PhotoPickResult> capture(
    BuildContext context, {
    int? maxBytes,
  }) async {
    if (!Platform.isLinux) {
      return PhotoPicker(
        maxBytes: maxBytes,
      ).pick(source: ImageSource.camera, remaining: 1);
    }
    final path = await LinuxCameraScreen.open(context);
    if (path == null) return const PhotoPickResult([]);
    final size = await File(path).length();
    if (maxBytes != null && size > maxBytes) {
      return const PhotoPickResult([], rejected: 1);
    }
    return PhotoPickResult([PickedPhoto(path: path, size: size)]);
  }
}
