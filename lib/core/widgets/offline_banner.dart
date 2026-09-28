import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_colors.dart';
import '../domain/tone.dart';
import '../network/network_status.dart';

/// Bannière globale « Hors connexion » avec « Réessayer ».
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);
    final colors = StatusColors.of(context);
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: !offline
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Material(
                color: colors.background(Tone.warning),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.xs,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 18,
                          color: colors.foreground(Tone.warning),
                        ),
                        AppSpacing.gapSm,
                        Expanded(
                          child: Text(
                            'Hors connexion · données enregistrées affichées',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.foreground(Tone.warning),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
