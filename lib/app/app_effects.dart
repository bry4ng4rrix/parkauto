import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/lifecycle/app_lifecycle.dart';
import '../core/network/network_status.dart';
import '../core/widgets/offline_banner.dart';
import 'app_coordinator.dart';

/// Racine toujours visible : maintient [AppCoordinator] actif, relaie le
/// cycle de vie et affiche la bannière hors connexion au-dessus des écrans.
class AppEffects extends ConsumerStatefulWidget {
  const AppEffects({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppEffects> createState() => _AppEffectsState();
}

class _AppEffectsState extends ConsumerState<AppEffects> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  void _onLifecycle(AppLifecycleState state) {
    ref.read(appLifecycleProvider.notifier).update(state);
    ref.read(appCoordinatorProvider).onLifecycle(state);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(appCoordinatorProvider);
    final offline = ref.watch(isOfflineProvider);
    return Column(
      children: [
        OfflineBanner(onRetry: coordinator.retryNow),
        Expanded(
          // La bannière occupe déjà la zone de la barre d'état.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: offline,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
