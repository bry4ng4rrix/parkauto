import 'package:flutter/material.dart';

/// Bouton d'envoi : désactivé et animé pendant la requête, pour éviter
/// toute double soumission.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = destructive
        ? FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          )
        : null;
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: loading
          ? SizedBox.square(
              key: const ValueKey('loading'),
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: scheme.onSurfaceVariant,
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
    return Semantics(
      button: true,
      enabled: !loading && onPressed != null,
      label: loading ? '$label, envoi en cours' : null,
      child: FilledButton(
        style: style,
        onPressed: loading ? null : onPressed,
        child: child,
      ),
    );
  }
}
