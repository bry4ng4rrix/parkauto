import 'package:flutter/material.dart';

/// Icône avec compteur (🔔 notifications, 💬 messages).
class BadgeIconButton extends StatelessWidget {
  const BadgeIconButton({
    super.key,
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final int count;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = count == 0 ? tooltip : '$tooltip : $count non lu${count > 1 ? 's' : ''}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: CountBadge(count: count, child: Icon(icon)),
      ),
    );
  }
}

/// Badge numérique (masqué à zéro, plafonné à 99+).
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    child: child,
  );
}
