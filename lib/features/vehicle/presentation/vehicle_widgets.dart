import 'package:flutter/material.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_colors.dart';
import '../../../core/domain/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/vehicule.dart';

class VehicleIcon extends StatelessWidget {
  const VehicleIcon({super.key, required this.categorie, this.size = 44});

  final CategorieEngin categorie;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: AppRadius.mdAll,
        ),
        child: Icon(
          categorie == CategorieEngin.enginChantier
              ? Icons.construction_rounded
              : Icons.local_shipping_rounded,
          color: scheme.primary,
          size: size * 0.5,
        ),
      ),
    );
  }
}

class VehicleStatusBadge extends StatelessWidget {
  const VehicleStatusBadge({super.key, required this.statut});

  final StatutEngin statut;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: statut.label,
    tone: statut.tone,
    icon: switch (statut) {
      StatutEngin.enPanne => Icons.car_crash_rounded,
      StatutEngin.enMaintenance => Icons.build_rounded,
      StatutEngin.enMission => Icons.route_rounded,
      _ => null,
    },
  );
}

IconData _levelIcon(NiveauEcheance niveau) => switch (niveau) {
  NiveauEcheance.ok => Icons.verified_rounded,
  NiveauEcheance.bientot => Icons.schedule_rounded,
  NiveauEcheance.expire => Icons.gpp_bad_rounded,
  NiveauEcheance.sansDate ||
  NiveauEcheance.inconnu => Icons.help_outline_rounded,
};

/// Document du véhicule : l'échéance est rendue par la couleur, l'icône
/// et le texte (OK, BIENTOT, EXPIRE, SANS_DATE).
class DocumentStatusCard extends StatelessWidget {
  const DocumentStatusCard({super.key, required this.document});

  final VehiculeDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final tone = document.niveau.tone;
    final days = document.joursRestants;
    final date = document.dateExpiration;
    final detail = switch ((days, date)) {
      (final int d, _) => AppFormat.remainingDays(d),
      (null, final DateTime at) => 'Expire le ${AppFormat.date(at)}',
      _ => "Pas de date d'expiration",
    };
    return Semantics(
      label:
          '${document.type.label}, ${document.niveau.label}, $detail'
          '${document.numeroReference == null ? '' : ', référence ${document.numeroReference}'}',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.background(tone),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(
                _levelIcon(document.niveau),
                color: colors.foreground(tone),
                size: 20,
              ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(document.type.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    [
                      ?document.numeroReference,
                      if (date != null) AppFormat.date(date),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            AppSpacing.gapSm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(
                  label: document.niveau.label,
                  tone: tone,
                  dense: true,
                ),
                if (days != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    days < 0 ? '${-days} j de retard' : '$days j',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.foreground(tone),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Alerte active du véhicule (GPS, documents, consommation…).
class VehicleAlertCard extends StatelessWidget {
  const VehicleAlertCard({super.key, required this.alert});

  final VehiculeAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final tone = alert.priorite.tone;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_alertIcon(alert.type), color: colors.foreground(tone)),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.type.label,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    StatusBadge(
                      label: 'Priorité ${alert.priorite.label.toLowerCase()}',
                      tone: tone,
                      dense: true,
                    ),
                  ],
                ),
                AppSpacing.gapXs,
                Text(alert.description, style: theme.textTheme.bodyMedium),
                AppSpacing.gapSm,
                Text(
                  [
                    AppFormat.plural(alert.nombreOccurrences, 'occurrence'),
                    'depuis ${AppFormat.dateTime(alert.premiereOccurrence)}',
                    'dernière ${AppFormat.relative(alert.derniereOccurrence).toLowerCase()}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _alertIcon(TypeAlerte type) => switch (type) {
    TypeAlerte.survitesse => Icons.speed_rounded,
    TypeAlerte.perteConnexionGps ||
    TypeAlerte.gpsDesactivePendantMission => Icons.gps_off_rounded,
    TypeAlerte.entreeZoneInterdite ||
    TypeAlerte.sortieZoneAutorisee ||
    TypeAlerte.deplacementAnormal => Icons.wrong_location_rounded,
    TypeAlerte.arretProlonge => Icons.timer_off_rounded,
    TypeAlerte.consommationAnormale ||
    TypeAlerte.baisseCarburantSuspecte => Icons.local_gas_station_rounded,
    TypeAlerte.documentExpire ||
    TypeAlerte.documentAExpirer => Icons.description_rounded,
    TypeAlerte.maintenanceAPrevoir ||
    TypeAlerte.stockPieceBas => Icons.build_rounded,
    TypeAlerte.incidentCritique => Icons.report_rounded,
    TypeAlerte.inconnu => Icons.warning_amber_rounded,
  };
}

/// Pastille compacte d'une information clé.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          AppSpacing.gapSm,
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
