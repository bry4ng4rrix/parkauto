import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/badge_icon_button.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_badge.dart';
import '../../notifications/data/notification_feed.dart';
import '../data/profile_repository.dart';
import '../domain/conducteur_profile.dart';

/// `GET /api/moi/profil`.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous devrez saisir à nouveau vos identifiants.',
      confirmLabel: 'Se déconnecter',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(sessionControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    Future<void> refresh() async {
      final error = await ref.read(profileProvider.notifier).refresh();
      if (error != null && context.mounted) showErrorMessage(context, error);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Paramètres',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResourceView(
                    value: profile,
                    loading: const Skeleton(
                      child: Column(
                        children: [
                          SkeletonCard(lines: 2, height: 120),
                          SizedBox(height: AppSpacing.lg),
                          SkeletonCard(lines: 3),
                        ],
                      ),
                    ),
                    onRetry: () => ref.invalidate(profileProvider),
                    builder: (context, data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StaleNote(data: data),
                        _Identity(profile: data.value),
                        AppSpacing.gapXl,
                        _Contact(profile: data.value),
                        if (data.value.qualification case final q?) ...[
                          AppSpacing.gapXl,
                          _QualificationCard(qualification: q),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.gapXxl,
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _Link(
                          icon: Icons.local_shipping_outlined,
                          label: 'Mon véhicule',
                          onTap: () => context.push(AppRoutes.vehicle),
                        ),
                        _Link(
                          icon: Icons.local_gas_station_outlined,
                          label: 'Mes pleins',
                          onTap: () => context.push(AppRoutes.fuel),
                        ),
                        _Link(
                          icon: Icons.report_problem_outlined,
                          label: 'Mes incidents',
                          onTap: () => context.push(AppRoutes.incidents),
                        ),
                        _Link(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notifications',
                          count: unreadNotifications,
                          onTap: () => context.push(AppRoutes.notifications),
                        ),
                        _Link(
                          icon: Icons.settings_outlined,
                          label: 'Paramètres',
                          onTap: () => context.push(AppRoutes.settings),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapXxl,
                  OutlinedButton.icon(
                    onPressed: () => _logout(context, ref),
                    icon: Icon(
                      Icons.logout_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      'Se déconnecter',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  AppSpacing.gapXxxl,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.profile});

  final ConducteurProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          InitialsAvatar(label: profile.nomComplet, size: 64),
          AppSpacing.gapLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.nomComplet, style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  'Matricule ${profile.matricule} · ${profile.categorie.label}',
                  style: theme.textTheme.bodySmall,
                ),
                AppSpacing.gapSm,
                StatusBadge(
                  label: profile.statut.label,
                  tone: profile.statut.tone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.profile});

  final ConducteurProfile profile;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(title: 'Coordonnées'),
      AppCard(
        child: Column(
          children: [
            InfoRow(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: profile.telephone ?? '—',
            ),
            InfoRow(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              value: profile.email ?? '—',
            ),
          ],
        ),
      ),
    ],
  );
}

class _QualificationCard extends StatelessWidget {
  const _QualificationCard({required this.qualification});

  final Qualification qualification;

  @override
  Widget build(BuildContext context) {
    final date = qualification.dateExpiration;
    final days = qualification.joursRestants;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: qualification.type.label),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(
                label: days == null
                    ? qualification.niveau.label
                    : '${qualification.niveau.label} · '
                          '${AppFormat.remainingDays(days).toLowerCase()}',
                tone: qualification.niveau.tone,
              ),
              AppSpacing.gapSm,
              InfoRow(
                icon: Icons.badge_outlined,
                label: 'Numéro',
                value: qualification.numero,
              ),
              if (qualification.categorie case final categorie?)
                InfoRow(
                  icon: Icons.category_outlined,
                  label: 'Catégorie',
                  value: categorie,
                ),
              InfoRow(
                icon: Icons.event_outlined,
                label: "Date d'expiration",
                value: date == null ? '—' : AppFormat.date(date),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count = 0,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int count;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: CountBadge(count: count, child: Icon(icon)),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
      if (!last) const Divider(indent: 56),
    ],
  );
}
