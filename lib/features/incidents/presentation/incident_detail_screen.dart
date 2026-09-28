import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_image.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../data/incidents_repository.dart';
import '../domain/incident.dart';
import 'incident_widgets.dart';
import 'photo_upload_controller.dart';

/// Détail d'un incident. Pas de `GET` unitaire dans le contrat : l'incident
/// est lu dans `GET /api/moi/incidents`.
class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key, required this.idIncident});

  final int idIncident;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);
    Incident? incident;
    for (final i in incidents.value?.value ?? const <Incident>[]) {
      if (i.idIncident == idIncident) incident = i;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Incident')),
      body: ResourceView(
        value: incidents,
        loading: const Skeleton(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.gutter),
            child: SkeletonCard(lines: 5),
          ),
        ),
        onRetry: () => ref.invalidate(incidentsProvider),
        builder: (context, data) => switch (incident) {
          null => const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Incident introuvable',
          ),
          final i => _IncidentDetails(incident: i),
        },
      ),
    );
  }
}

class _IncidentDetails extends ConsumerWidget {
  const _IncidentDetails({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final missionId = incident.idMission;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(incidentPhotosProvider(incident.idIncident));
        await ref.read(incidentsProvider.notifier).refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      incidentTypeIcon(incident.type),
                      color: theme.colorScheme.primary,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        incident.type.label,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapMd,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    IncidentStatusBadge(statut: incident.statut),
                    GraviteBadge(gravite: incident.gravite),
                  ],
                ),
                AppSpacing.gapXl,
                AppCard(
                  child: Text(
                    incident.description,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                AppSpacing.gapMd,
                AppCard(
                  child: Column(
                    children: [
                      InfoRow(
                        icon: Icons.event_rounded,
                        label: 'Survenu le',
                        value: AppFormat.dateTime(incident.dateSurvenue),
                      ),
                      InfoRow(
                        icon: Icons.local_shipping_outlined,
                        label: 'Véhicule',
                        value: incident.vehicule ?? '—',
                      ),
                    ],
                  ),
                ),
                if (missionId != null) ...[
                  AppSpacing.gapMd,
                  AppCard(
                    onTap: () => context.push(AppRoutes.mission(missionId)),
                    child: Row(
                      children: [
                        Icon(Icons.route_rounded, color: theme.colorScheme.primary),
                        AppSpacing.gapMd,
                        const Expanded(child: Text('Mission associée')),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ],
                AppSpacing.gapXxl,
                _PhotosSection(incident: incident),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosSection extends ConsumerWidget {
  const _PhotosSection({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = incident.idIncident;
    final photos = ref.watch(incidentPhotosProvider(id));
    final uploads = ref.watch(photoUploadProvider(id));
    final controller = ref.read(photoUploadProvider(id).notifier);
    final api = ref.watch(apiClientProvider);
    final active = uploads.where((u) => u.status != UploadStatus.done).toList();
    final failed = uploads
        .where((u) => u.status == UploadStatus.failed)
        .firstOrNull;
    final count = photos.value?.length ?? incident.nombrePhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Photos ($count/${Incident.maxPhotos})',
          actionLabel: incident.acceptsPhotos ? 'Ajouter' : null,
          onAction: () => context.push(AppRoutes.incidentPhotos(id)),
        ),
        if (failed?.error case final error?) ...[
          InlineMessage.error(error),
          AppSpacing.gapMd,
        ],
        switch (photos) {
          AsyncValue(value: final list?) =>
            list.isEmpty && active.isEmpty
                ? AppCard(
                    child: Text(
                      incident.acceptsPhotos
                          ? 'Aucune photo. Touchez « Ajouter » pour en joindre.'
                          : 'Aucune photo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : PhotoGrid(
                    children: [
                      for (final upload in active)
                        UploadThumbnail(
                          upload: upload,
                          onRetry: () => controller.retry(upload.localId),
                          onRemove: () => controller.remove(upload.localId),
                        ),
                      for (final photo in list)
                        PhotoThumbnail(
                          image: ApiImage(photo.url, api).thumbnail(300),
                          semanticLabel: photo.legende ?? "Photo de l'incident",
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
                onPressed: () => ref.invalidate(incidentPhotosProvider(id)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
          _ => const Skeleton(child: SkeletonBox(height: 110)),
        },
      ],
    );
  }
}
