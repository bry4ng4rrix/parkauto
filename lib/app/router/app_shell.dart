import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/badge_icon_button.dart';
import '../../features/home/presentation/quick_actions_sheet.dart';
import '../../features/messaging/application/unread_counter.dart';

/// Structure à onglets : barre de navigation toujours fixée en bas
/// (comportement Android, quelle que soit la largeur de la fenêtre).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final index = navigationShell.currentIndex;
    final messagesLabel = unread > 0
        ? 'Messagerie, $unread non lu${unread > 1 ? 's' : ''}'
        : 'Messagerie';

    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'Accueil', 'Accueil'),
      (Icons.route_outlined, Icons.route_rounded, 'Missions', 'Missions'),
      (
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        'Messagerie',
        messagesLabel,
      ),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profil', 'Profil'),
    ];

    Widget icon(IconData data, int i) =>
        i == 2 ? CountBadge(count: unread, child: Icon(data)) : Icon(data);

    return Scaffold(
      body: navigationShell,
      floatingActionButton: index <= 1
          ? FloatingActionButton.extended(
              onPressed: () => showQuickActionsSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Déclarer'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _select,
        destinations: [
          for (final (i, item) in items.indexed)
            NavigationDestination(
              icon: icon(item.$1, i),
              selectedIcon: icon(item.$2, i),
              label: item.$3,
              tooltip: item.$4,
            ),
        ],
      ),
    );
  }
}
