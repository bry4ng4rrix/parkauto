import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// État du cycle de vie de l'application (mis à jour par `AppEffects`).
final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
      AppLifecycleNotifier.new,
    );

class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState build() =>
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  void update(AppLifecycleState lifecycle) {
    if (state != lifecycle) state = lifecycle;
  }
}

extension AppLifecycleStateX on AppLifecycleState {
  bool get isForeground => this == AppLifecycleState.resumed;
}
