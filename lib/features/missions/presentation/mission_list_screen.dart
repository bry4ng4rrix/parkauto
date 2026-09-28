import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/enums.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/state_views.dart';
import '../data/missions_repository.dart';
import '../domain/mission.dart';
import 'mission_action_sheet.dart';
import 'mission_tile.dart';

enum MissionFilter {
  toutes('Toutes', null),
  planifiees('Planifiées', StatutMission.planifiee),
  enCours('En cours', StatutMission.enCours),
  terminees('Terminées', StatutMission.terminee),
  annulees('Annulées', StatutMission.annulee);

  const MissionFilter(this.label, this.statut);

  final String label;
  final StatutMission? statut;

  bool accepts(Mission m) => statut == null || m.statut == statut;
}

/// En cours, puis planifiées (les plus proches d'abord), puis historique.
List<Mission> sortMissions(List<Mission> missions) {
  int rank(Mission m) => switch (m.statut) {
    StatutMission.enCours => 0,
    StatutMission.planifiee => 1,
    _ => 2,
  };
  final sorted = [...missions];
  sorted.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return rank(a) == 1
        ? a.dateDebutPrevue.compareTo(b.dateDebutPrevue)
        : b.dateDebutPrevue.compareTo(a.dateDebutPrevue);
  });
  return sorted;
}

class MissionListScreen extends ConsumerStatefulWidget {
  const MissionListScreen({super.key});

  @override
  ConsumerState<MissionListScreen> createState() => _MissionListScreenState();
}

class _MissionListScreenState extends ConsumerState<MissionListScreen> {
  MissionFilter _filter = MissionFilter.toutes;

  Future<void> _refresh() async {
    final error = await ref.read(missionsProvider.notifier).refresh();
    if (error != null && mounted) showErrorMessage(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final missions = ref.watch(missionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Missions')),
      body: ResourceView(
        value: missions,
        onRetry: () => ref.invalidate(missionsProvider),
        builder: (context, data) {
          final all = sortMissions(data.value);
          final visible = all.where(_filter.accepts).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _FilterBar(
                    selected: _filter,
                    counts: {
                      for (final f in MissionFilter.values)
                        f: all.where(f.accepts).length,
                    },
                    onSelected: (f) => setState(() => _filter = f),
                  ),
                ),
                SliverPadding(
                  padding: AppSpacing.page,
                  sliver: SliverToBoxAdapter(child: StaleNote(data: data)),
                ),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.route_outlined,
                      title: _filter == MissionFilter.toutes
                          ? 'Aucune mission'
                          : 'Aucune mission ${_filter.label.toLowerCase()}',
                      message:
                          'Les missions qui vous sont attribuées '
                          'apparaîtront ici.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      0,
                      AppSpacing.gutter,
                      96,
                    ),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => AppSpacing.gapMd,
                      itemBuilder: (context, index) => ResponsiveCenter(
                        child: _MissionItem(mission: visible[index]),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MissionItem extends StatelessWidget {
  const _MissionItem({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final action = mission.canStart
        ? MissionAction.start
        : mission.canFinish
        ? MissionAction.finish
        : null;
    return MissionTile(
      mission: mission,
      trailing: action == null
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: action == MissionAction.start
                  ? FilledButton.tonalIcon(
                      onPressed: () =>
                          showMissionActionSheet(context, mission, action),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Démarrer'),
                    )
                  : FilledButton.icon(
                      onPressed: () =>
                          showMissionActionSheet(context, mission, action),
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('Terminer'),
                    ),
            ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final MissionFilter selected;
  final Map<MissionFilter, int> counts;
  final ValueChanged<MissionFilter> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.sm,
      ),
      itemCount: MissionFilter.values.length,
      separatorBuilder: (_, _) => AppSpacing.gapSm,
      itemBuilder: (context, index) {
        final filter = MissionFilter.values[index];
        return ChoiceChip(
          label: Text('${filter.label} · ${counts[filter] ?? 0}'),
          selected: filter == selected,
          showCheckmark: false,
          onSelected: (_) => onSelected(filter),
        );
      },
    ),
  );
}
