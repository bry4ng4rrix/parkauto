import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/tone.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/websocket/realtime_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/status_badge.dart';
import '../../messaging/application/realtime.dart';
import '../data/theme_mode_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final config = ref.watch(appConfigProvider);
    final realtime =
        ref.watch(realtimeStatusProvider).value ?? RealtimeStatus.disconnected;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Apparence'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Thème', style: theme.textTheme.titleSmall),
                      AppSpacing.gapMd,
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Système'),
                            icon: Icon(Icons.brightness_auto_rounded),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Clair'),
                            icon: Icon(Icons.light_mode_rounded),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Sombre'),
                            icon: Icon(Icons.dark_mode_rounded),
                          ),
                        ],
                        selected: {themeMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) => ref
                            .read(themeModeProvider.notifier)
                            .select(selection.first),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapXxl,
                const SectionHeader(title: 'Notifications'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Les nouveaux messages sont signalés dans '
                        "l'application et, pendant quelques minutes après "
                        'sa mise en arrière-plan, par une notification.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      AppSpacing.gapMd,
                      OutlinedButton.icon(
                        onPressed: () async {
                          final granted = await ref
                              .read(localNotificationServiceProvider)
                              .requestPermission();
                          if (!context.mounted) return;
                          showInfoMessage(
                            context,
                            granted
                                ? 'Notifications autorisées'
                                : 'Notifications refusées : modifiez-les '
                                      'dans les réglages du téléphone.',
                          );
                        },
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Autoriser les notifications'),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapXxl,
                const SectionHeader(title: 'Connexion'),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Messagerie en temps réel',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          switch (realtime) {
                            RealtimeStatus.connected => const StatusBadge(
                              label: 'Connectée',
                              tone: Tone.success,
                            ),
                            RealtimeStatus.connecting => const StatusBadge(
                              label: 'Connexion…',
                              tone: Tone.warning,
                            ),
                            RealtimeStatus.disconnected => const StatusBadge(
                              label: 'Déconnectée',
                              tone: Tone.neutral,
                            ),
                          },
                        ],
                      ),
                      AppSpacing.gapSm,
                      InfoRow(
                        label: 'Environnement',
                        value: config.environment.label,
                      ),
                      InfoRow(label: 'Serveur', value: config.apiBaseUrl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
