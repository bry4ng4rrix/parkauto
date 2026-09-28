import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/badge_icon_button.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../fuel/data/fuel_repository.dart';
import '../../incidents/data/incidents_repository.dart';
import '../../messaging/application/unread_counter.dart';
import '../../missions/presentation/mission_tile.dart';
import '../../notifications/data/notification_feed.dart';
import '../../vehicle/data/vehicle_repository.dart';
import '../data/moi_repository.dart';
import '../domain/moi_response.dart';
import 'home_widgets.dart';

/// Tableau de bord du conducteur (`GET /api/moi`).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final results = await Future.wait([
      ref.read(moiProvider.notifier).refresh(),
      ref.read(fuelEntriesProvider.notifier).refresh(),
      ref.read(incidentsProvider.notifier).refresh(),
      ref.read(vehicleProvider.notifier).refresh(),
    ]);
    final error = results.first;
    if (error != null && context.mounted) showErrorMessage(context, error);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moi = ref.watch(moiProvider);
    final fallbackName = ref.watch(
      sessionControllerProvider.select((s) => s.session?.nomComplet),
    );
    final blocked = switch (moi.error) {
      final Object e => switch (asAppException(e)) {
        final ApiException api when api.isForbidden => api.userMessage,
        _ => null,
      },
      null => null,
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: blocked != null
            ? AccountBlockedView(message: blocked)
            : RefreshIndicator(
                onRefresh: () => _refresh(context, ref),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Header(
                        prenom:
                            moi.value?.value.profil.prenom ??
                            fallbackName?.split(' ').first,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        0,
                        AppSpacing.gutter,
                        120,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: ResponsiveCenter(
                          child: ResourceView(
                            value: moi,
                            loading: const _HomeSkeleton(),
                            onRetry: () => ref.invalidate(moiProvider),
                            builder: (context, data) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                StaleNote(data: data),
                                _Dashboard(moi: data.value),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.prenom});

  final String? prenom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadMessages = ref.watch(unreadCountProvider);
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final hour = DateTime.now().hour;
    final greeting = hour >= 18 ? 'Bonsoir' : 'Bonjour';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xl,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prenom == null ? greeting : '$greeting $prenom',
                  style: theme.textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormat.day(DateTime.now()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          BadgeIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            count: unreadMessages,
            tooltip: 'Messages',
            onPressed: () => context.go(AppRoutes.messages),
          ),
          BadgeIconButton(
            icon: Icons.notifications_none_rounded,
            count: unreadNotifications,
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.notifications),
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.moi});

  final MoiResponse moi;

  @override
  Widget build(BuildContext context) {
    final current = moi.missionEnCours;
    final upcoming = moi.prochainesMissions.planned();
    final highlight = current ?? upcoming.firstOrNull;
    final others = [
      for (final m in upcoming)
        if (m.idMission != highlight?.idMission) m,
    ];
    final qualification = moi.profil.qualification;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (qualification != null && qualification.niveau.needsAttention) ...[
          QualificationNotice(qualification: qualification),
          AppSpacing.gapXl,
        ],
        SectionHeader(
          title: current != null ? 'Mission en cours' : 'Prochaine mission',
          actionLabel: 'Tout voir',
          onAction: () => context.go(AppRoutes.missions),
        ),
        if (highlight != null)
          MissionHighlightCard(mission: highlight)
        else
          const NoMissionCard(),
        AppSpacing.gapXl,
        Align(
          alignment: Alignment.centerLeft,
          child: UpcomingCount(count: upcoming.length),
        ),
        AppSpacing.gapXl,
        const SectionHeader(title: 'Actions rapides'),
        const QuickActions(),
        AppSpacing.gapXxl,
        SectionHeader(
          title: 'Mon véhicule',
          actionLabel: moi.vehicule == null ? null : 'Détails',
          onAction: () => context.push(AppRoutes.vehicle),
        ),
        VehicleSummaryCard(
          vehicule: moi.vehicule,
          alertes: moi.alertesVehicule,
        ),
        if (others.isNotEmpty) ...[
          AppSpacing.gapXxl,
          const SectionHeader(title: 'Missions à venir'),
          for (final (i, mission) in others.take(3).indexed) ...[
            if (i > 0) AppSpacing.gapMd,
            MissionTile(mission: mission),
          ],
        ],
        AppSpacing.gapXxl,
        const RecentActivity(),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const Skeleton(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(width: 160, height: 18),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 3, height: 150),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(width: 120, height: 18),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 1),
        SizedBox(height: AppSpacing.xl),
        SkeletonCard(lines: 2, height: 120),
      ],
    ),
  );
}
