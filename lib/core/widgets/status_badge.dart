import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_colors.dart';
import '../domain/tone.dart';

/// Pastille de statut : couleur + icône + texte (jamais la couleur seule).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final foreground = colors.foreground(tone);
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: foreground);
    return Semantics(
      label: 'Statut : $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AppSpacing.sm : AppSpacing.sm + 2,
          vertical: dense ? 2 : AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.background(tone),
          borderRadius: AppRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? _defaultIcon(tone), size: 13, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(label, style: style, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _defaultIcon(Tone tone) => switch (tone) {
    Tone.success => Icons.check_circle_rounded,
    Tone.warning => Icons.schedule_rounded,
    Tone.danger => Icons.error_rounded,
    Tone.info => Icons.info_rounded,
    Tone.neutral => Icons.circle_outlined,
  };
}
