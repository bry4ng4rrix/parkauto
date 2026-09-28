import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_colors.dart';
import '../domain/tone.dart';
import '../errors/app_exception.dart';
import '../errors/error_messages.dart';

/// Message encadré dans un formulaire (erreur backend, avertissement).
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.tone = Tone.danger,
    this.details = const [],
    this.icon,
  });

  /// Erreur : `message` du backend et, pour une 400, ses `details`.
  factory InlineMessage.error(Object error, {Key? key}) {
    final exception = asAppException(error);
    return InlineMessage(
      key: key,
      message: exception.userMessage,
      details: switch (exception) {
        ApiException(:final error) => error.details,
        _ => const [],
      },
    );
  }

  final String message;
  final Tone tone;
  final List<String> details;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final foreground = colors.foreground(tone);
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.background(tone),
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon ??
                  (tone == Tone.danger
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded),
              size: 20,
              color: foreground,
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final detail in details)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        '• $detail',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
