import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/state_views.dart';
import 'app_routes.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: EmptyState(
      icon: Icons.explore_off_rounded,
      title: 'Page introuvable',
      message: "Cet élément n'existe pas ou n'est plus disponible.",
      action: FilledButton(
        onPressed: () => context.go(AppRoutes.home),
        child: const Text("Retour à l'accueil"),
      ),
    ),
  );
}
