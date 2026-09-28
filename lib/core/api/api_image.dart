import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'api_client.dart';

/// Image servie par un endpoint protégé (Bearer), chargée en octets via
/// [ApiClient] (rafraîchissement du jeton compris) et mise en cache par
/// l'`ImageCache` de Flutter, indexée par chemin.
@immutable
class ApiImage extends ImageProvider<ApiImage> {
  const ApiImage(this.path, this.client);

  /// Chemin relatif, ex. `/api/moi/incidents/photos/140/fichier`.
  final String path;
  final ApiClient client;

  @override
  Future<ApiImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(ApiImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _load(decode),
        scale: 1,
        debugLabel: path,
      );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    try {
      final bytes = await client.getBytes(path);
      return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } on Object {
      // Échec : on retire l'entrée pour permettre un nouvel essai.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      rethrow;
    }
  }

  /// Vignette décodée à [width] pixels (mémoire réduite).
  ImageProvider<Object> thumbnail(int width) =>
      ResizeImage(this, width: width, policy: ResizeImagePolicy.fit);

  @override
  bool operator ==(Object other) => other is ApiImage && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
