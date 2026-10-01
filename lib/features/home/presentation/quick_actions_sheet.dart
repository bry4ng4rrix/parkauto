import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';

/// Action rapide « Déclarer » : plein, incident, mission.
Future<void> showQuickActionsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        void open(String route) {
          Navigator.of(sheetContext).pop();
          context.push(route);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  0,
                  AppSpacing.xxl,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Déclarer',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              _ActionTile(
                icon: Icons.local_gas_station_rounded,
                title: 'Réapprovisionnement de carburant',
                subtitle: 'Plein complet, appoint ou bidon',
                onTap: () => open(AppRoutes.fuelNew),
              ),
              _ActionTile(
                icon: Icons.report_problem_rounded,
                title: 'Un incident',
                subtitle: 'Panne, accident, vol… avec photos',
                onTap: () => open(AppRoutes.incidentNew),
              ),
              _ActionTile(
                icon: Icons.route_rounded,
                title: 'Démarrer ou terminer une mission',
                subtitle: 'Saisir le kilométrage',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(AppRoutes.missions);
                },
              ),
            ],
          ),
        );
      },
    );

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: scheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
