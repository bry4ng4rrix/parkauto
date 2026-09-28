/// Dernier segment d'un chemin de fichier (`/a/b/photo.jpg` → `photo.jpg`).
String fileNameOf(String path) {
  final segments = path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty);
  return segments.isEmpty ? path : segments.last;
}

/// Extension en minuscules, sans le point.
String fileExtensionOf(String name) {
  final index = name.lastIndexOf('.');
  return index < 0 ? '' : name.substring(index + 1).toLowerCase();
}

bool isImageFileName(String name) => const {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'heic',
  'heif',
}.contains(fileExtensionOf(name));
