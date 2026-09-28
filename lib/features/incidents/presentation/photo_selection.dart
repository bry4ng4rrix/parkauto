import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/media/photo_picker.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../domain/incident.dart';
import 'incident_widgets.dart';

/// Photo choisie, pas encore envoyée.
@immutable
class LocalPhoto {
  const LocalPhoto({required this.path, required this.size, this.legende});

  final String path;
  final int size;
  final String? legende;

  LocalPhoto withCaption(String? caption) => LocalPhoto(
    path: path,
    size: size,
    legende: (caption == null || caption.trim().isEmpty) ? null : caption.trim(),
  );
}

/// Sélection de photos avant envoi : caméra, galerie, aperçu, légende,
/// suppression. Respecte la limite de 10 photos par incident.
class PhotoSelection extends StatelessWidget {
  const PhotoSelection({
    super.key,
    required this.photos,
    required this.remaining,
    required this.onChanged,
    this.enabled = true,
  });

  final List<LocalPhoto> photos;

  /// Emplacements encore disponibles (hors [photos]).
  final int remaining;
  final ValueChanged<List<LocalPhoto>> onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final result = await PhotoPicker(maxBytes: Incident.maxPhotoBytes).pick(
      source: source,
      remaining: remaining,
    );
    if (!context.mounted) return;
    if (result.error case final message?) {
      showInfoMessage(context, message);
      return;
    }
    if (result.rejected > 0) {
      showInfoMessage(
        context,
        '${AppFormat.plural(result.rejected, 'photo écartée')} : '
        '5 Mo maximum par fichier.',
      );
    }
    if (result.photos.isEmpty) return;
    onChanged([
      ...photos,
      for (final p in result.photos) LocalPhoto(path: p.path, size: p.size),
    ]);
  }

  Future<void> _edit(BuildContext context, int index) async {
    final photo = photos[index];
    final controller = TextEditingController(text: photo.legende);
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: PhotoThumbnail(
                image: ResizeImage(FileImage(File(photo.path)), width: 900),
              ),
            ),
            AppSpacing.gapLg,
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Légende (facultatif)',
                hintText: 'Ex. Tableau de bord',
              ),
            ),
            AppSpacing.gapSm,
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop('remove'),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Retirer'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop('save'),
                  child: const Text('Valider'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final caption = controller.text;
    controller.dispose();
    if (action == 'remove') {
      onChanged([...photos]..removeAt(index));
    } else if (action == 'save') {
      onChanged([
        for (final (i, p) in photos.indexed)
          i == index ? p.withCaption(caption) : p,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = enabled && remaining > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photos.isNotEmpty) ...[
          PhotoGrid(
            children: [
              for (final (i, photo) in photos.indexed)
                PhotoThumbnail(
                  image: ResizeImage(FileImage(File(photo.path)), width: 300),
                  semanticLabel: photo.legende ?? 'Photo ${i + 1}',
                  onTap: enabled ? () => _edit(context, i) : null,
                  overlay: Align(
                    alignment: Alignment.bottomLeft,
                    child: photo.legende == null
                        ? null
                        : Container(
                            width: double.infinity,
                            color: Colors.black45,
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Text(
                              photo.legende ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
          AppSpacing.gapMd,
        ],
        Row(
          children: [
            if (PhotoPicker.supportsCamera) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canAdd
                      ? () => _pick(context, ImageSource.camera)
                      : null,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Appareil photo'),
                ),
              ),
              AppSpacing.gapMd,
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAdd
                    ? () => _pick(context, ImageSource.gallery)
                    : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galerie'),
              ),
            ),
          ],
        ),
        AppSpacing.gapSm,
        Text(
          remaining > 0
              ? 'Touchez une photo pour ajouter une légende. '
                    '${Incident.maxPhotos} photos de 5 Mo au plus par incident.'
              : 'Limite de ${Incident.maxPhotos} photos atteinte.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
