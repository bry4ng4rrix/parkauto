import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_image.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/photo_viewer.dart';
import '../domain/local_attachment.dart';
import '../domain/messaging_models.dart';
import 'attachment_downloads.dart';
import 'chat_controller.dart';

const _bubbleRadius = Radius.circular(18);
const _tailRadius = Radius.circular(4);

/// Bulle d'un message reçu ou envoyé.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.showAuthor = false,
  });

  final Message message;
  final bool mine;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final text = message.contenu?.trim() ?? '';
    return _BubbleFrame(
      mine: mine,
      semanticLabel:
          '${mine ? 'Vous' : message.auteur.nomComplet}, '
          '${AppFormat.dateTime(message.dateEnvoi)} : $text',
      author: showAuthor && !mine ? message.auteur.nomComplet : null,
      footer: _Footer(
        time: AppFormat.time(message.dateEnvoi),
        mine: mine,
        icon: mine ? Icons.done_rounded : null,
      ),
      children: [
        for (final attachment in message.piecesJointes)
          attachment.image
              ? _RemoteImage(attachment: attachment, mine: mine)
              : _FileTile(attachment: attachment, mine: mine),
        if (text.isNotEmpty) _BubbleText(text: text, mine: mine),
      ],
    );
  }
}

/// Message en cours d'envoi ou en échec (« Réessayer » / « Supprimer »).
class PendingBubble extends StatelessWidget {
  const PendingBubble({
    super.key,
    required this.pending,
    required this.onRetry,
    required this.onDiscard,
  });

  final PendingMessage pending;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final failed = pending.status == PendingStatus.failed;
    final scheme = Theme.of(context).colorScheme;
    final text = pending.contenu ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Opacity(
          opacity: failed ? 0.6 : 0.85,
          child: _BubbleFrame(
            mine: true,
            semanticLabel: failed
                ? 'Message non envoyé : $text'
                : 'Envoi en cours : $text',
            footer: _Footer(
              time: failed ? 'Non envoyé' : 'Envoi…',
              mine: true,
              icon: failed ? Icons.error_outline_rounded : Icons.schedule_rounded,
            ),
            children: [
              for (final file in pending.fichiers)
                file.isImage
                    ? _LocalImage(file: file)
                    : _LocalFileTile(file: file),
              if (text.isNotEmpty) _BubbleText(text: text, mine: true),
            ],
          ),
        ),
        if (failed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Wrap(
              spacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (pending.error case final error?)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      userMessageOf(error),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: scheme.error),
                      textAlign: TextAlign.end,
                    ),
                  ),
                TextButton(onPressed: onRetry, child: const Text('Réessayer')),
                TextButton(onPressed: onDiscard, child: const Text('Supprimer')),
              ],
            ),
          ),
      ],
    );
  }
}

class _BubbleFrame extends StatelessWidget {
  const _BubbleFrame({
    required this.mine,
    required this.children,
    required this.footer,
    required this.semanticLabel,
    this.author,
  });

  final bool mine;
  final List<Widget> children;
  final Widget footer;
  final String semanticLabel;
  final String? author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth.clamp(0, 520)),
        child: Semantics(
          label: semanticLabel,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: mine ? scheme.primary : scheme.surfaceContainer,
              borderRadius: BorderRadius.only(
                topLeft: _bubbleRadius,
                topRight: _bubbleRadius,
                bottomLeft: mine ? _bubbleRadius : _tailRadius,
                bottomRight: mine ? _tailRadius : _bubbleRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (author case final name?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      name,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.xs),
                  child,
                ],
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleText extends StatelessWidget {
  const _BubbleText({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SelectableText(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: mine ? scheme.onPrimary : scheme.onSurface,
        height: 1.35,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.time, required this.mine, this.icon});

  final String time;
  final bool mine;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = mine
        ? scheme.onPrimary.withValues(alpha: 0.75)
        : scheme.onSurfaceVariant;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              time,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w500),
            ),
            if (icon case final data?) ...[
              const SizedBox(width: 3),
              Icon(data, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemoteImage extends ConsumerWidget {
  const _RemoteImage({required this.attachment, required this.mine});

  final Attachment attachment;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ApiImage(
      ApiEndpoints.pieceJointe(attachment.idPieceJointe),
      ref.watch(apiClientProvider),
    );
    return Semantics(
      image: true,
      button: true,
      label: 'Image ${attachment.nom}',
      child: GestureDetector(
        onTap: () =>
            PhotoViewer.open(context, image: image, caption: attachment.nom),
        child: ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, minWidth: 160),
            child: Image(
              image: image.thumbnail(600),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (_, _, _) =>
                  _FileTile(attachment: attachment, mine: mine),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileTile extends ConsumerWidget {
  const _FileTile({required this.attachment, required this.mine});

  final Attachment attachment;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final progress = ref.watch(
      attachmentDownloadsProvider.select((d) => d[attachment.idPieceJointe]),
    );
    final foreground = mine ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      label:
          'Pièce jointe ${attachment.nom}, ${AppFormat.fileSize(attachment.taille)}',
      excludeSemantics: true,
      child: Material(
        color: foreground.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: progress != null
              ? null
              : () async {
                  final error = await ref
                      .read(attachmentDownloadsProvider.notifier)
                      .open(attachment);
                  if (error != null && context.mounted) {
                    showInfoMessage(context, error);
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  attachment.isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.insert_drive_file_rounded,
                  color: foreground,
                ),
                AppSpacing.gapSm,
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                      Text(
                        AppFormat.fileSize(attachment.taille),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapSm,
                SizedBox.square(
                  dimension: 22,
                  child: progress == null
                      ? Icon(
                          Icons.download_rounded,
                          size: 20,
                          color: foreground,
                        )
                      : CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          strokeWidth: 2.4,
                          color: foreground,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalImage extends StatelessWidget {
  const _LocalImage({required this.file});

  final LocalAttachment file;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: AppRadius.mdAll,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: Image(
        image: ResizeImage(FileImage(File(file.path)), width: 600),
        fit: BoxFit.cover,
      ),
    ),
  );
}

class _LocalFileTile extends StatelessWidget {
  const _LocalFileTile({required this.file});

  final LocalAttachment file;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insert_drive_file_rounded, color: scheme.onPrimary),
        AppSpacing.gapSm,
        Flexible(
          child: Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
