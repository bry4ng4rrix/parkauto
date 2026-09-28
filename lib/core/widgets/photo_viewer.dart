import 'package:flutter/material.dart';

/// Visionneuse plein écran avec zoom.
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.image, this.caption});

  final ImageProvider<Object> image;
  final String? caption;

  static Future<void> open(
    BuildContext context, {
    required ImageProvider<Object> image,
    String? caption,
  }) => Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => PhotoViewer(image: image, caption: caption),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: switch (caption) {
        final text? => Text(text),
        null => null,
      },
      titleTextStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: Colors.white),
    ),
    body: Center(
      child: InteractiveViewer(
        maxScale: 5,
        child: Image(
          image: image,
          fit: BoxFit.contain,
          semanticLabel: caption ?? 'Photo',
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const CircularProgressIndicator(color: Colors.white54),
          errorBuilder: (_, _, _) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 48,
          ),
        ),
      ),
    ),
  );
}
