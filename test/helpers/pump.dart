import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parkauto/app/theme/app_theme.dart';
import 'package:parkauto/core/auth/session.dart';

import 'fake_backend.dart';
import 'test_app.dart';

/// Affiche [screen] dans l'application de test (thème, français, routeur).
/// Toute navigation vers un autre écran affiche `route:/chemin`.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required FakeBackend backend,
  Session? session,
  FakeLocalNotifications? notifications,
  FakeRealtimeConnector? connector,
  Size size = const Size(420, 900),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = await createContainer(
    backend: backend,
    session: session,
    notifications: notifications,
    connector: connector,
  );
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
    errorBuilder: (_, state) =>
        Scaffold(body: Center(child: Text('route:${state.uri}'))),
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  await settle(tester);
  return container;
}

/// Laisse passer les requêtes simulées et les animations courtes (les
/// skeletons tournent en boucle : pas de `pumpAndSettle`).
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
