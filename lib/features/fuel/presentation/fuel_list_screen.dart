import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_config.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/tone.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/fuel_repository.dart';
import '../domain/fuel_entry.dart';

IconData fuelTypeIcon(TypeApprovisionnement? type) => switch (type) {
  TypeApprovisionnement.appoint => Icons.add_circle_outline_rounded,
  TypeApprovisionnement.bidon => Icons.water_drop_outlined,
  _ => Icons.local_gas_station_rounded,
};

/// Historique `GET /api/moi/pleins`, groupé par mois.
class FuelListScreen extends ConsumerWidget {
  const FuelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(fuelEntriesProvider);
    final currency = ref.watch(appConfigProvider).currencyLabel;

    Future<void> refresh() async {
      final error = await ref.read(fuelEntriesProvider.notifier).refresh();
      if (error != null && context.mounted) showErrorMessage(context, error);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mes pleins')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.fuelNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Déclarer un plein'),
      ),
      body: ResourceView(
        value: entries,
        onRetry: () => ref.invalidate(fuelEntriesProvider),
        isEmpty: (list) => list.isEmpty,
        empty: RefreshableFill(
          onRefresh: refresh,
          child: const EmptyState(
            icon: Icons.local_gas_station_outlined,
            title: 'Aucun plein enregistré',
            message: 'Vos déclarations de carburant apparaîtront ici.',
          ),
        ),
        builder: (context, data) {
          final groups = _groupByMonth(data.value);
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                96,
              ),
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return StaleNote(data: data);
                final group = groups[index - 1];
                return ResponsiveCenter(
                  child: _MonthSection(
                    month: group.$1,
                    entries: group.$2,
                    currency: currency,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static List<(DateTime, List<FuelEntry>)> _groupByMonth(List<FuelEntry> all) {
    final sorted = [...all]..sort((a, b) => b.dateHeure.compareTo(a.dateHeure));
    final groups = <(DateTime, List<FuelEntry>)>[];
    for (final entry in sorted) {
      final month = DateTime(entry.dateHeure.year, entry.dateHeure.month);
      if (groups.isEmpty || groups.last.$1 != month) {
        groups.add((month, [entry]));
      } else {
        groups.last.$2.add(entry);
      }
    }
    return groups;
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.month,
    required this.entries,
    required this.currency,
  });

  final DateTime month;
  final List<FuelEntry> entries;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final litres = entries.fold<double>(0, (sum, e) => sum + e.quantiteLitres);
    final total = entries.fold<double>(0, (sum, e) => sum + e.montantTotal);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      AppFormat.month(month),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                Text(
                  '${AppFormat.litres(litres)} · ${AppFormat.money(total, currency)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          for (final (i, entry) in entries.indexed) ...[
            if (i > 0) AppSpacing.gapSm,
            FuelEntryTile(entry: entry, currency: currency),
          ],
        ],
      ),
    );
  }
}

class FuelEntryTile extends StatelessWidget {
  const FuelEntryTile({super.key, required this.entry, required this.currency});

  final FuelEntry entry;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = entry.typeApprovisionnement;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(fuelTypeIcon(type), color: theme.colorScheme.primary),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${AppFormat.litres(entry.quantiteLitres)} · '
                        '${AppFormat.money(entry.montantTotal, currency)}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (type != null && !type.isUnknown)
                      StatusBadge(
                        label: type.label,
                        tone: Tone.neutral,
                        icon: fuelTypeIcon(type),
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    AppFormat.dateTime(entry.dateHeure),
                    ?entry.station,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${AppFormat.km(entry.kilometrageAuPlein)} · '
                  '${AppFormat.money(entry.prixUnitaire, currency)}/L · '
                  '${entry.vehicule}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
