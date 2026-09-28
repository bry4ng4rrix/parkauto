import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connectivité du système (Wi-Fi / données mobiles).
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
  try {
    yield online(await connectivity.checkConnectivity());
  } on Exception {
    yield true;
  }
  yield* connectivity.onConnectivityChanged.map(online);
});

/// Résultat réel des dernières requêtes : le serveur a-t-il répondu ?
final serverReachableProvider = NotifierProvider<ServerReachable, bool>(
  ServerReachable.new,
);

class ServerReachable extends Notifier<bool> {
  @override
  bool build() => true;

  void report({required bool reachable}) {
    if (state != reachable) state = reachable;
  }
}

/// Hors ligne si le système n'a pas de réseau ou si le serveur ne répond pas.
final isOfflineProvider = Provider<bool>((ref) {
  final connected = ref.watch(connectivityProvider).value ?? true;
  final reachable = ref.watch(serverReachableProvider);
  return !connected || !reachable;
});
