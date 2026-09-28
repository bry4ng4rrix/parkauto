import 'package:flutter/material.dart';

import '../../../app/theme/app_radius.dart';

/// Logo ParkAuto (pictogramme + nom).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: 'ParkAuto',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: AppRadius.lgAll,
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              color: scheme.onPrimary,
              size: size * 0.52,
            ),
          ),
          if (showName) ...[
            SizedBox(height: size * 0.28),
            Text('ParkAuto', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              'Espace conducteur',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
