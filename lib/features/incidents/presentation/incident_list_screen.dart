import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/state_views.dart';
import '../data/incidents_repository.dart';
import 'incident_widgets.dart';

/// `GET /api/moi/incidents`.
class IncidentListScreen extends ConsumerWidget {
  const IncidentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);

    Future<void> refresh() async {
      final error = await ref.read(incidentsProvider.notifier).refresh();
      if (error != null && context.mounted) showErrorMessage(context, error);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mes incidents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.incidentNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Déclarer'),
      ),
      body: ResourceView(
        value: incidents,
        onRetry: () => ref.invalidate(incidentsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: RefreshableFill(
          onRefresh: refresh,
          child: const EmptyState(
            icon: Icons.verified_user_outlined,
            title: 'Aucun incident déclaré',
            message:
                'Panne, accident ou vol : déclarez-le ici, photos à '
                "l'appui.",
          ),
        ),
        builder: (context, data) {
          final list = [...data.value]
            ..sort((a, b) => b.dateSurvenue.compareTo(a.dateSurvenue));
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                96,
              ),
              itemCount: list.length + 1,
              separatorBuilder: (_, index) =>
                  index == 0 ? const SizedBox.shrink() : AppSpacing.gapMd,
              itemBuilder: (context, index) => index == 0
                  ? StaleNote(data: data)
                  : ResponsiveCenter(
                      child: IncidentTile(incident: list[index - 1]),
                    ),
            ),
          );
        },
      ),
    );
  }
}
