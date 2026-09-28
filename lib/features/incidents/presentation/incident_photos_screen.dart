import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_image.dart';
import '../../../core/domain/tone.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/incidents_repository.dart';
import '../domain/incident.dart';
import 'incident_widgets.dart';
import 'photo_picker.dart';
import 'photo_selection.dart';
import 'photo_upload_controller.dart';

/// Photos d'un incident : `GET …/photos`, ajout via `POST …/photos`
/// (multipart `fichier`, `legende`).
class IncidentPhotosScreen extends ConsumerStatefulWidget {
  const IncidentPhotosScreen({super.key, required this.idIncident});

  final int idIncident;

  @override
  ConsumerState<IncidentPhotosScreen> createState() =>
      _IncidentPhotosScreenState();
}

class _IncidentPhotosScreenState extends ConsumerState<IncidentPhotosScreen> {
  List<LocalPhoto> _selection = const [];

  @override
  void initState() {
    super.initState();
    _recoverLostPhotos();
  }

  /// Android : photo prise juste avant une fermeture de l'activité.
  Future<void> _recoverLostPhotos() async {
    final result = await IncidentPhotoPicker().recoverLost();
    if (!mounted || result.photos.isEmpty) return;
    setState(() {
      _selection = [
        ..._selection,
        for (final p in result.photos) LocalPhoto(path: p.path, size: p.size),
      ];
    });
  }

  void _send() {
    if (_selection.isEmpty) return;
    ref
        .read(photoUploadProvider(widget.idIncident).notifier)
        .enqueue([for (final p in _selection) (path: p.path, legende: p.legende)]);
    final count = _selection.length;
    setState(() => _selection = const []);
    showInfoMessage(
      context,
      'Envoi de ${AppFormat.plural(count, 'photo')} en cours',
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.idIncident;
    Incident? incident;
    for (final i in ref.watch(incidentsProvider).value?.value ?? const <Incident>[]) {
      if (i.idIncident == id) incident = i;
    }
    final photos = ref.watch(incidentPhotosProvider(id));
    final uploads = ref.watch(photoUploadProvider(id));
    final controller = ref.read(photoUploadProvider(id).notifier);
    final api = ref.watch(apiClientProvider);
    final theme = Theme.of(context);

    final active = uploads.where((u) => u.status != UploadStatus.done).toList();
    final uploaded = photos.value?.length ?? incident?.nombrePhotos ?? 0;
    final accepts = incident?.acceptsPhotos ?? true;
    final remaining = remainingPhotoSlots(
      alreadyUploaded: uploaded,
      pending: active.length + _selection.length,
    );
    final failed = active
        .where((u) => u.status == UploadStatus.failed)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text("Photos de l'incident")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$uploaded/${Incident.maxPhotos} photos envoyées',
                  style: theme.textTheme.titleSmall,
                ),
                AppSpacing.gapMd,
                if (!accepts) ...[
                  const InlineMessage(
                    message:
                        'Cet incident est clôturé : on ne peut plus y ajouter '
                        'de photo',
                    tone: Tone.info,
                  ),
                  AppSpacing.gapLg,
                ],
                if (failed?.error case final error?) ...[
                  InlineMessage.error(error),
                  AppSpacing.gapLg,
                ],
                switch (photos) {
                  AsyncValue(value: final list?) =>
                    list.isEmpty && active.isEmpty
                        ? AppCard(
                            child: Text(
                              'Aucune photo pour le moment.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : PhotoGrid(
                            children: [
                              for (final upload in active)
                                UploadThumbnail(
                                  upload: upload,
                                  onRetry: () => controller.retry(upload.localId),
                                  onRemove: () =>
                                      controller.remove(upload.localId),
                                ),
                              for (final photo in list)
                                PhotoThumbnail(
                                  image: ApiImage(photo.url, api).thumbnail(300),
                                  semanticLabel:
                                      photo.legende ?? 'Photo ajoutée le '
                                          '${AppFormat.dateTime(photo.dateAjout)}',
                                  onTap: () => PhotoViewer.open(
                                    context,
                                    image: ApiImage(photo.url, api),
                                    caption: photo.legende,
                                  ),
                                ),
                            ],
                          ),
                  AsyncValue(error: final error?) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InlineMessage.error(error),
                      TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(incidentPhotosProvider(id)),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                  _ => const Skeleton(child: SkeletonBox(height: 110)),
                },
                if (accepts) ...[
                  AppSpacing.gapXxl,
                  Text('Ajouter des photos', style: theme.textTheme.titleSmall),
                  AppSpacing.gapSm,
                  PhotoSelection(
                    photos: _selection,
                    remaining: remaining,
                    onChanged: (photos) => setState(() => _selection = photos),
                  ),
                ],
                AppSpacing.gapXxxl,
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selection.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: FilledButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    'Envoyer ${AppFormat.plural(_selection.length, 'photo')}',
                  ),
                ),
              ),
            ),
    );
  }
}
