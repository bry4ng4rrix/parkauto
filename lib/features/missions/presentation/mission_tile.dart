import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/mission.dart';

IconData missionStatusIcon(StatutMission statut) => switch (statut) {
  StatutMission.planifiee => Icons.event_rounded,
  StatutMission.enCours => Icons.play_circle_rounded,
  StatutMission.terminee => Icons.check_circle_rounded,
  StatutMission.annulee => Icons.cancel_rounded,
  StatutMission.inconnu => Icons.help_outline_rounded,
};

class MissionStatusBadge extends StatelessWidget {
  const MissionStatusBadge({super.key, required this.statut});

  final StatutMission statut;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: statut.label,
    tone: statut.tone,
    icon: missionStatusIcon(statut),
  );
}

/// Carte d'une mission dans les listes.
class MissionTile extends StatelessWidget {
  const MissionTile({super.key, required this.mission, this.trailing});

  final Mission mission;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall;
    final distance = mission.distance;
    return AppCard(
      onTap: () => context.push(AppRoutes.mission(mission.idMission)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Retour à la ligne sur petit écran ou grand texte.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              MissionStatusBadge(statut: mission.statut),
              Text(
                AppFormat.range(mission.dateDebutPrevue, mission.dateFinPrevue),
                style: muted,
              ),
            ],
          ),
          AppSpacing.gapMd,
          Text(
            mission.motif,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapXs,
          Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              AppSpacing.gapXs,
              Expanded(
                child: Text(
                  mission.vehicule,
                  style: muted,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (distance != null)
                Text(AppFormat.km(distance), style: muted),
            ],
          ),
          if (trailing case final action?) ...[AppSpacing.gapLg, action],
        ],
      ),
    );
  }
}
