import 'package:flutter/material.dart';

import '../errors/error_messages.dart';

/// Clé globale : bannières affichées hors de tout `Scaffold` (temps réel).
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showSuccessMessage(BuildContext context, String message) =>
    _show(ScaffoldMessenger.maybeOf(context), message, Icons.check_circle_rounded);

void showErrorMessage(BuildContext context, Object error) => _show(
  ScaffoldMessenger.maybeOf(context),
  userMessageOf(error),
  Icons.error_outline_rounded,
);

void showInfoMessage(BuildContext context, String message) =>
    _show(ScaffoldMessenger.maybeOf(context), message, Icons.info_outline_rounded);

void _show(ScaffoldMessengerState? messenger, String message, IconData icon) {
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
