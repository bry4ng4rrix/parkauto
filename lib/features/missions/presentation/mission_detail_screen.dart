import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../data/missions_repository.dart';
import '../domain/mission.dart';
import 'mission_action_sheet.dart';
import 'mission_tile.dart';

/// Détail d'une mission. Le contrat n'a pas de `GET` unitaire : la mission
/// est lue dans la liste `GET /api/moi/missions`.
class MissionDetailScreen extends ConsumerWidget {
  const MissionDetailScreen({super.key, required this.idMission});

  final int idMission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(missionsProvider);
    Mission? mission;
    for (final m in missions.value?.value ?? const <Mission>[]) {
      if (m.idMission == idMission) mission = m;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: ResourceView(
        value: missions,
        loading: const Skeleton(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.gutter),
            child: SkeletonCard(lines: 5),
          ),
        ),
        onRetry: () => ref.invalidate(missionsProvider),
        builder: (context, data) => switch (mission) {
          null => const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Mission introuvable',
            message: 'Cette mission ne figure plus dans votre liste.',
          ),
          final m => _MissionDetails(mission: m),
        },
      ),
      bottomNavigationBar: switch (mission) {
        final m? when m.canStart || m.canFinish => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: FilledButton.icon(
              onPressed: () => showMissionActionSheet(
                context,
                m,
                m.canStart ? MissionAction.start : MissionAction.finish,
              ),
              icon: Icon(
                m.canStart ? Icons.play_arrow_rounded : Icons.flag_rounded,
              ),
              label: Text(
                m.canStart ? 'Démarrer la mission' : 'Terminer la mission',
              ),
            ),
          ),
        ),
        _ => null,
      },
    );
  }
}

class _MissionDetails extends StatelessWidget {
  const _MissionDetails({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String dateOrDash(DateTime? d) => d == null ? '—' : AppFormat.dateTime(d);
    final distance = mission.distance;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MissionStatusBadge(statut: mission.statut),
              AppSpacing.gapMd,
              Text(mission.motif, style: theme.textTheme.headlineSmall),
              AppSpacing.gapSm,
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Text(
                      mission.vehicule,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapXxl,
              const SectionHeader(title: 'Planification'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow(
                      icon: Icons.event_rounded,
                      label: 'Début prévu',
                      value: AppFormat.dateTime(mission.dateDebutPrevue),
                    ),
                    InfoRow(
                      icon: Icons.event_available_rounded,
                      label: 'Fin prévue',
                      value: AppFormat.dateTime(mission.dateFinPrevue),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapXxl,
              const SectionHeader(title: 'Réalisation'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow(
                      icon: Icons.play_circle_outline_rounded,
                      label: 'Début réel',
                      value: dateOrDash(mission.dateDebutReelle),
                    ),
                    InfoRow(
                      icon: Icons.flag_outlined,
                      label: 'Fin réelle',
                      value: dateOrDash(mission.dateFinReelle),
                    ),
                    InfoRow(
                      icon: Icons.speed_rounded,
                      label: 'Kilométrage de départ',
                      value: AppFormat.km(mission.kilometrageDepart),
                    ),
                    InfoRow(
                      icon: Icons.speed_rounded,
                      label: 'Kilométrage de retour',
                      value: AppFormat.km(mission.kilometrageRetour),
                    ),
                    if (distance != null)
                      InfoRow(
                        icon: Icons.straighten_rounded,
                        label: 'Distance parcourue',
                        value: AppFormat.km(distance),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
