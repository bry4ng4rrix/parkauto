import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_colors.dart';
import '../../../core/domain/enums.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/incident.dart';
import 'photo_upload_controller.dart';

IconData incidentTypeIcon(TypeIncident type) => switch (type) {
  TypeIncident.accident => Icons.car_crash_rounded,
  TypeIncident.panne => Icons.build_circle_rounded,
  TypeIncident.vol => Icons.no_crash_rounded,
  TypeIncident.autre || TypeIncident.inconnu => Icons.report_problem_rounded,
};

class IncidentStatusBadge extends StatelessWidget {
  const IncidentStatusBadge({super.key, required this.statut});

  final StatutIncident statut;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: statut.label,
    tone: statut.tone,
    icon: switch (statut) {
      StatutIncident.declare => Icons.outbox_rounded,
      StatutIncident.enTraitement => Icons.engineering_rounded,
      StatutIncident.cloture => Icons.task_alt_rounded,
      StatutIncident.inconnu => Icons.help_outline_rounded,
    },
  );
}

class GraviteBadge extends StatelessWidget {
  const GraviteBadge({super.key, required this.gravite});

  final Gravite gravite;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: 'Gravité ${gravite.label.toLowerCase()}',
    tone: gravite.tone,
    icon: gravite == Gravite.critique
        ? Icons.priority_high_rounded
        : Icons.signal_cellular_alt_rounded,
    dense: true,
  );
}

/// Carte d'un incident dans les listes.
class IncidentTile extends StatelessWidget {
  const IncidentTile({super.key, required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    return AppCard(
      onTap: () => context.push(AppRoutes.incident(incident.idIncident)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.background(incident.gravite.tone),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(
              incidentTypeIcon(incident.type),
              color: colors.foreground(incident.gravite.tone),
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        incident.type.label,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IncidentStatusBadge(statut: incident.statut),
                  ],
                ),
                AppSpacing.gapXs,
                Text(
                  incident.description,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.gapSm,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GraviteBadge(gravite: incident.gravite),
                    Text(
                      AppFormat.dateTime(incident.dateSurvenue),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (incident.nombrePhotos > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${incident.nombrePhotos}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vignette carrée d'une photo (locale ou distante).
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    super.key,
    required this.image,
    this.onTap,
    this.overlay,
    this.semanticLabel,
  });

  final ImageProvider<Object> image;
  final VoidCallback? onTap;
  final Widget? overlay;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: semanticLabel ?? 'Photo',
      button: onTap != null,
      child: ClipRRect(
        borderRadius: AppRadius.mdAll,
        child: Material(
          color: scheme.surfaceContainer,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, sync) =>
                      AnimatedOpacity(
                        opacity: sync || frame != null ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: child,
                      ),
                  errorBuilder: (context, error, stack) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ?overlay,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Photo en cours d'envoi : progression, erreur et « Réessayer ».
class UploadThumbnail extends StatelessWidget {
  const UploadThumbnail({
    super.key,
    required this.upload,
    required this.onRetry,
    required this.onRemove,
  });

  final PhotoUpload upload;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final overlay = switch (upload.status) {
      UploadStatus.waiting || UploadStatus.uploading => Container(
        color: Colors.black38,
        alignment: Alignment.center,
        child: SizedBox.square(
          dimension: 36,
          child: CircularProgressIndicator(
            value:
                upload.status == UploadStatus.uploading && upload.progress > 0
                ? upload.progress
                : null,
            strokeWidth: 3,
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
      ),
      UploadStatus.failed => Container(
        color: Colors.black54,
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: 'Réessayer',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Retirer',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
      UploadStatus.done => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(Icons.check_circle_rounded, color: colors.success),
        ),
      ),
    };
    final label = switch (upload.status) {
      UploadStatus.waiting => 'Photo en attente d\'envoi',
      UploadStatus.uploading =>
        'Envoi de la photo, ${(upload.progress * 100).round()} %',
      UploadStatus.failed => switch (upload.error) {
        final error? => "Échec de l'envoi : ${userMessageOf(error)}",
        null => "Échec de l'envoi",
      },
      UploadStatus.done => 'Photo envoyée',
    };
    return PhotoThumbnail(
      image: ResizeImage(FileImage(File(upload.path)), width: 300),
      overlay: overlay,
      semanticLabel: label,
    );
  }
}

/// Grille de vignettes adaptée à la largeur.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 120).floor().clamp(3, 6);
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        children: children,
      );
    },
  );
}
