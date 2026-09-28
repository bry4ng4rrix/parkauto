import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_config.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_colors.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/tone.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../fuel/data/fuel_repository.dart';
import '../../incidents/data/incidents_repository.dart';
import '../../incidents/presentation/incident_widgets.dart';
import '../../missions/domain/mission.dart';
import '../../missions/presentation/mission_action_sheet.dart';
import '../../missions/presentation/mission_tile.dart';
import '../../profile/domain/conducteur_profile.dart';
import '../../vehicle/domain/vehicule.dart';
import '../../vehicle/presentation/vehicle_widgets.dart';

/// Mission en cours (Terminer) ou prochaine mission (Démarrer).
class MissionHighlightCard extends StatelessWidget {
  const MissionHighlightCard({super.key, required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final inProgress = mission.canFinish;
    return MissionTile(
      mission: mission,
      trailing: SizedBox(
        width: double.infinity,
        child: inProgress
            ? FilledButton.icon(
                onPressed: () => showMissionActionSheet(
                  context,
                  mission,
                  MissionAction.finish,
                ),
                icon: const Icon(Icons.flag_rounded),
                label: const Text('Terminer la mission'),
              )
            : mission.canStart
            ? FilledButton.tonalIcon(
                onPressed: () => showMissionActionSheet(
                  context,
                  mission,
                  MissionAction.start,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Démarrer la mission'),
              )
            : null,
      ),
    );
  }
}

class NoMissionCard extends StatelessWidget {
  const NoMissionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Text(
              'Aucune mission en cours ni planifiée.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Véhicule affecté (ou absence de véhicule) avec ses alertes.
class VehicleSummaryCard extends StatelessWidget {
  const VehicleSummaryCard({
    super.key,
    required this.vehicule,
    required this.alertes,
  });

  final VehiculeSummary? vehicule;
  final int alertes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = vehicule;
    if (v == null) {
      return AppCard(
        onTap: () => context.push(AppRoutes.vehicle),
        child: Row(
          children: [
            Icon(
              Icons.no_transfer_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Text(NoVehicle.message, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }
    return AppCard(
      onTap: () => context.push(AppRoutes.vehicle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VehicleIcon(categorie: v.categorie),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.identifiant, style: theme.textTheme.titleMedium),
                    if (v.marqueModele case final model?)
                      Text(model, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              VehicleStatusBadge(statut: v.statut),
            ],
          ),
          AppSpacing.gapLg,
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: v.isEngin ? 'Compteur' : 'Kilométrage',
                  value: v.isEngin
                      ? AppFormat.hours(v.compteurHeures)
                      : AppFormat.km(v.kilometrage),
                ),
              ),
              Expanded(
                child: _Metric(label: 'Affectation', value: v.source.label),
              ),
            ],
          ),
          if (alertes > 0) ...[
            AppSpacing.gapMd,
            StatusBadge(
              label: AppFormat.plural(
                alertes,
                'alerte active',
                'alertes actives',
              ),
              tone: Tone.danger,
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

/// Avertissement d'échéance du permis / CACES.
class QualificationNotice extends StatelessWidget {
  const QualificationNotice({super.key, required this.qualification});

  final Qualification qualification;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final tone = qualification.niveau.tone;
    final days = qualification.joursRestants;
    final text = days != null
        ? AppFormat.remainingDays(days)
        : qualification.niveau.label;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.background(tone),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(Icons.badge_outlined, color: colors.foreground(tone)),
          AppSpacing.gapMd,
          Expanded(
            child: Text(
              '${qualification.type.label} · $text',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.foreground(tone),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raccourcis : plein, incident, missions, messagerie.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.local_gas_station_rounded,
        'Plein',
        () => context.push(AppRoutes.fuelNew),
      ),
      (
        Icons.report_problem_rounded,
        'Incident',
        () => context.push(AppRoutes.incidentNew),
      ),
      (Icons.route_rounded, 'Missions', () => context.go(AppRoutes.missions)),
      (
        Icons.chat_bubble_outline_rounded,
        'Messages',
        () => context.go(AppRoutes.messages),
      ),
    ];
    return Row(
      children: [
        for (final (i, (icon, label, onTap)) in actions.indexed) ...[
          if (i > 0) AppSpacing.gapSm,
          Expanded(
            child: _QuickAction(icon: icon, label: label, onTap: onTap),
          ),
        ],
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xs,
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          AppSpacing.gapSm,
          Text(
            label,
            style: theme.textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Dernier plein et dernier incident (chargés indépendamment).
class RecentActivity extends ConsumerWidget {
  const RecentActivity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuel = ref.watch(fuelEntriesProvider);
    final incidents = ref.watch(incidentsProvider);
    final currency = ref.watch(appConfigProvider).currencyLabel;
    final theme = Theme.of(context);

    Widget loadingOr(bool loading, Widget child) =>
        loading ? const Skeleton(child: SkeletonCard(lines: 1)) : child;

    final lastFuel = fuel.value?.value.firstOrNull;
    final lastIncident = incidents.value?.value.firstOrNull;
    if (!fuel.isLoading &&
        !incidents.isLoading &&
        lastFuel == null &&
        lastIncident == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Activité récente',
          actionLabel: 'Pleins',
          onAction: () => context.push(AppRoutes.fuel),
        ),
        loadingOr(
          fuel.isLoading && lastFuel == null,
          lastFuel == null
              ? const SizedBox.shrink()
              : AppCard(
                  onTap: () => context.push(AppRoutes.fuel),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_gas_station_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      AppSpacing.gapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppFormat.litres(lastFuel.quantiteLitres)} · '
                              '${AppFormat.money(lastFuel.montantTotal, currency)}',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              '${AppFormat.relative(lastFuel.dateHeure)}'
                              '${lastFuel.station == null ? '' : ' · ${lastFuel.station}'}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (lastIncident != null || incidents.isLoading) AppSpacing.gapMd,
        loadingOr(
          incidents.isLoading && lastIncident == null,
          lastIncident == null
              ? const SizedBox.shrink()
              : IncidentTile(incident: lastIncident),
        ),
      ],
    );
  }
}

/// 403 « compte non relié » : écran bloquant avec déconnexion.
class AccountBlockedView extends ConsumerWidget {
  const AccountBlockedView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EmptyState(
    icon: Icons.person_off_rounded,
    title: 'Accès impossible',
    message: message,
    action: FilledButton(
      onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
      child: const Text('Se déconnecter'),
    ),
  );
}

/// Pastille « missions à venir » pour l'en-tête du tableau de bord.
class UpcomingCount extends StatelessWidget {
  const UpcomingCount({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: count == 0
        ? 'Aucune mission à venir'
        : AppFormat.plural(count, 'mission à venir', 'missions à venir'),
    tone: count == 0 ? Tone.neutral : Tone.info,
    icon: Icons.event_note_rounded,
  );
}

extension MissionListX on List<Mission> {
  List<Mission> planned() =>
      where((m) => m.statut == StatutMission.planifiee).toList();
}
