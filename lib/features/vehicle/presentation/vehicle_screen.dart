import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicule.dart';
import 'vehicle_widgets.dart';

/// `GET /api/moi/vehicule` : véhicule, documents, alertes, dernier plein.
class VehicleScreen extends ConsumerWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider);

    Future<void> refresh() async {
      final error = await ref.read(vehicleProvider.notifier).refresh();
      if (error != null && context.mounted) showErrorMessage(context, error);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mon véhicule')),
      body: ResourceView(
        value: vehicle,
        loading: const SkeletonList(count: 4),
        onRetry: () => ref.invalidate(vehicleProvider),
        builder: (context, data) => switch (data.value) {
          NoVehicle() => RefreshableFill(
            onRefresh: refresh,
            child: const EmptyState(
              icon: Icons.no_transfer_rounded,
              title: 'Aucun véhicule',
              message: NoVehicle.message,
            ),
          ),
          VehicleAssigned(:final details) => RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StaleNote(data: data),
                      _VehicleDetails(details: details),
                    ],
                  ),
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _VehicleDetails extends StatelessWidget {
  const _VehicleDetails({required this.details});

  final VehiculeDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = details.vehicule;
    final documents = [...details.documents]
      ..sort((a, b) => _urgency(a.niveau).compareTo(_urgency(b.niveau)));
    final dernierPlein = details.dernierPlein;
    final missionId = details.idMissionEnCours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            VehicleIcon(categorie: v.categorie, size: 56),
            AppSpacing.gapLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.identifiant, style: theme.textTheme.headlineSmall),
                  Text(
                    v.marqueModele ?? v.libelle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        AppSpacing.gapMd,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            VehicleStatusBadge(statut: v.statut),
            _Chip(text: v.categorie.label),
            _Chip(text: v.source.label),
          ],
        ),
        AppSpacing.gapXl,
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.9,
          children: [
            if (v.isEngin)
              MetricTile(
                icon: Icons.timer_outlined,
                label: 'Compteur horaire',
                value: AppFormat.hours(v.compteurHeures),
              )
            else
              MetricTile(
                icon: Icons.speed_rounded,
                label: 'Kilométrage',
                value: AppFormat.km(v.kilometrage),
              ),
            MetricTile(
              icon: Icons.local_gas_station_outlined,
              label: 'Énergie',
              value: details.energie?.label ?? '—',
            ),
            MetricTile(
              icon: Icons.propane_tank_outlined,
              label: 'Réservoir',
              value: AppFormat.litres(details.capaciteReservoirLitres),
            ),
            if (v.isEngin)
              MetricTile(
                icon: Icons.speed_rounded,
                label: 'Kilométrage',
                value: AppFormat.km(v.kilometrage),
              )
            else
              MetricTile(
                icon: Icons.tag_rounded,
                label: 'Immatriculation',
                value: v.identifiant,
              ),
          ],
        ),
        if (missionId != null) ...[
          AppSpacing.gapMd,
          AppCard(
            onTap: () => context.push(AppRoutes.mission(missionId)),
            child: Row(
              children: [
                Icon(Icons.route_rounded, color: theme.colorScheme.primary),
                AppSpacing.gapMd,
                Expanded(
                  child: Text(
                    'Mission en cours',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
        AppSpacing.gapXxl,
        SectionHeader(title: 'Alertes (${details.alertes.length})'),
        if (details.alertes.isEmpty)
          const _EmptyLine(
            icon: Icons.check_circle_outline_rounded,
            text: 'Aucune alerte active',
          )
        else
          for (final (i, alert) in details.alertes.indexed) ...[
            if (i > 0) AppSpacing.gapMd,
            VehicleAlertCard(alert: alert),
          ],
        AppSpacing.gapXxl,
        SectionHeader(title: 'Documents (${documents.length})'),
        if (documents.isEmpty)
          const _EmptyLine(
            icon: Icons.description_outlined,
            text: 'Aucun document enregistré',
          )
        else
          for (final (i, document) in documents.indexed) ...[
            if (i > 0) AppSpacing.gapSm,
            DocumentStatusCard(document: document),
          ],
        AppSpacing.gapXxl,
        SectionHeader(
          title: 'Dernier plein',
          actionLabel: 'Historique',
          onAction: () => context.push(AppRoutes.fuel),
        ),
        if (dernierPlein == null)
          const _EmptyLine(
            icon: Icons.local_gas_station_outlined,
            text: 'Aucun plein enregistré',
          )
        else
          AppCard(
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.event_rounded,
                  label: 'Date',
                  value: AppFormat.dateTime(dernierPlein.dateHeure),
                ),
                InfoRow(
                  icon: Icons.water_drop_outlined,
                  label: 'Quantité',
                  value: AppFormat.litres(dernierPlein.quantiteLitres),
                ),
                InfoRow(
                  icon: Icons.speed_rounded,
                  label: 'Kilométrage',
                  value: AppFormat.km(dernierPlein.kilometrageAuPlein),
                ),
                if (dernierPlein.typeApprovisionnement case final type?)
                  InfoRow(
                    icon: Icons.category_outlined,
                    label: 'Type',
                    value: type.label,
                  ),
              ],
            ),
          ),
        AppSpacing.gapXxxl,
      ],
    );
  }

  static int _urgency(NiveauEcheance niveau) => switch (niveau) {
    NiveauEcheance.expire => 0,
    NiveauEcheance.bientot => 1,
    NiveauEcheance.ok => 2,
    _ => 3,
  };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 2,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: Theme.of(context).textTheme.labelSmall),
  );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          AppSpacing.gapMd,
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
