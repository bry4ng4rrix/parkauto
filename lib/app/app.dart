import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/feedback.dart';
import '../features/settings/data/theme_mode_controller.dart';
import 'app_effects.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class ParkAutoApp extends ConsumerWidget {
  const ParkAutoApp({super.key});

  static final _light = AppTheme.light();
  static final _dark = AppTheme.dark();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'ParkAuto',
    debugShowCheckedModeBanner: false,
    theme: _light,
    darkTheme: _dark,
    themeMode: ref.watch(themeModeProvider),
    themeAnimationDuration: const Duration(milliseconds: 200),
    routerConfig: ref.watch(routerProvider),
    scaffoldMessengerKey: rootScaffoldMessengerKey,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) =>
        AppEffects(child: child ?? const SizedBox.shrink()),
  );
}
