import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// Pulsation discrète appliquée à ses enfants [SkeletonBox].
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Chargement en cours',
    child: ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: widget.child,
      ),
    ),
  );
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Carte fantôme générique (titre + deux lignes).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 2, this.height});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      height: height,
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SkeletonBox(width: 140, height: 16),
            for (var i = 0; i < lines; i++) ...[
              AppSpacing.gapMd,
              SkeletonBox(width: i.isEven ? double.infinity : 180),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Liste fantôme pour les écrans de liste.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.lines = 2});

  final int count;
  final int lines;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      itemCount: count,
      separatorBuilder: (_, _) => AppSpacing.gapMd,
      itemBuilder: (_, _) => SkeletonCard(lines: lines),
    ),
  );
}
