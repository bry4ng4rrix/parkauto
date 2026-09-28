import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_colors.dart';
import '../../../core/domain/tone.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../data/notification_feed.dart';
import '../domain/app_notification.dart';

/// Centre de notifications local (le backend n'expose pas d'endpoint de
/// notifications) : messages temps réel, missions, incidents, alertes.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(notificationFeedProvider);
    final unread = all.where((n) => !n.read).toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            if (unread.isNotEmpty)
              TextButton(
                onPressed: () =>
                    ref.read(notificationFeedProvider.notifier).markAllRead(),
                child: const Text('Tout lire'),
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Toutes (${all.length})'),
              Tab(text: 'Non lues (${unread.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NotificationList(
              items: all,
              empty: const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Aucune notification',
                message:
                    'Messages, missions et alertes du véhicule apparaîtront ici.',
              ),
            ),
            _NotificationList(
              items: unread,
              empty: const EmptyState(
                icon: Icons.done_all_rounded,
                title: 'Tout est lu',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({required this.items, required this.empty});

  final List<AppNotification> items;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return empty;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: items.length + 1,
      separatorBuilder: (_, index) => index == items.length - 1
          ? const SizedBox.shrink()
          : const Divider(indent: 72),
      itemBuilder: (context, index) => index == items.length
          ? const _Footnote()
          : ResponsiveCenter(child: _NotificationTile(notification: items[index])),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  static (IconData, Tone) _style(AppNotificationKind kind) => switch (kind) {
    AppNotificationKind.message => (Icons.chat_bubble_rounded, Tone.info),
    AppNotificationKind.mission => (Icons.route_rounded, Tone.success),
    AppNotificationKind.incident => (Icons.report_problem_rounded, Tone.warning),
    AppNotificationKind.vehicleAlert => (Icons.warning_amber_rounded, Tone.danger),
    AppNotificationKind.expiry => (Icons.event_busy_rounded, Tone.warning),
    AppNotificationKind.info => (Icons.info_rounded, Tone.neutral),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final (icon, tone) = _style(notification.kind);
    final unread = !notification.read;
    return Semantics(
      button: notification.route != null,
      label:
          '${unread ? 'Non lue. ' : ''}${notification.title}. '
          '${notification.body}. ${AppFormat.relative(notification.createdAt)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          ref.read(notificationFeedProvider.notifier).markRead(notification.id);
          final route = notification.route;
          if (route != null) context.push(route);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: colors.background(tone),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: colors.foreground(tone)),
              ),
              AppSpacing.gapLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapXs,
                    Text(
                      AppFormat.relative(notification.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    top: AppSpacing.xs,
                  ),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
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

class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Text(
      'Les messages arrivent en temps réel. Les nouvelles missions et les '
      'changements de statut sont détectés lors des actualisations '
      '(toutes les 5 minutes et au retour dans l’application).',
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    ),
  );
}
