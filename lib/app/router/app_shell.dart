import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/badge_icon_button.dart';
import '../../features/home/presentation/quick_actions_sheet.dart';
import '../../features/messaging/application/unread_counter.dart';

/// Structure à onglets : barre de navigation (téléphone) ou rail (tablette).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _railBreakpoint = 600.0;

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final wide = MediaQuery.sizeOf(context).width >= _railBreakpoint;
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

    final fab = index <= 1
        ? FloatingActionButton.extended(
            onPressed: () => showQuickActionsSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Déclarer'),
          )
        : null;

    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: index,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final (i, item) in items.indexed)
                    NavigationRailDestination(
                      icon: Semantics(label: item.$4, child: icon(item.$1, i)),
                      selectedIcon: icon(item.$2, i),
                      label: Text(item.$3),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      floatingActionButton: fab,
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
