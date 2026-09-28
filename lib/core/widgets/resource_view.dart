import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../state/cached_resource.dart';
import '../utils/formatters.dart';
import 'skeleton.dart';
import 'state_views.dart';

/// Rend une ressource en cache : skeleton → données (ou vide) → erreur.
class ResourceView<T extends Object> extends StatelessWidget {
  const ResourceView({
    super.key,
    required this.value,
    required this.builder,
    this.loading,
    this.onRetry,
    this.isEmpty,
    this.empty,
  });

  final AsyncValue<Cached<T>> value;
  final Widget Function(BuildContext context, Cached<T> data) builder;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool Function(T value)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final (String key, Widget child) = switch (value) {
      AsyncValue(value: final data?) =>
        (isEmpty?.call(data.value) ?? false) && empty != null
            ? ('empty', empty ?? const SizedBox.shrink())
            : ('data', builder(context, data)),
      AsyncValue(error: final error?) => (
        'error',
        ErrorState(error: error, onRetry: onRetry),
      ),
      _ => ('loading', loading ?? const SkeletonList()),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }
}

/// Contenu non défilant rendu compatible avec le pull-to-refresh.
class RefreshableFill extends StatelessWidget {
  const RefreshableFill({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
    ),
  );
}

/// Mention discrète quand les données affichées ne sont pas à jour.
class StaleNote extends StatelessWidget {
  const StaleNote({super.key, required this.data});

  final Cached<Object> data;

  @override
  Widget build(BuildContext context) {
    if (!data.isStale) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final (icon, text) = data.isOffline
        ? (
            Icons.cloud_off_rounded,
            'Hors connexion · données du ${AppFormat.dateTime(data.updatedAt)}',
          )
        : data.refreshError != null
        ? (
            Icons.sync_problem_rounded,
            'Actualisation impossible · données du '
                '${AppFormat.dateTime(data.updatedAt)}',
          )
        : (Icons.sync_rounded, 'Actualisation…');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          AppSpacing.gapSm,
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
