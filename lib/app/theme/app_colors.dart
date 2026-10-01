import 'package:flutter/material.dart';

/// Palette alignée sur l'application Maintenance : un graphite neutre en
/// variante monochrome pour toute l'interface. La couleur est réservée aux
/// états (succès, avertissement, danger, information).
abstract final class AppColors {
  /// Couleur de base du schéma Material 3 (variante monochrome).
  static const graine = Color(0xFF5F6368);

  // États — une valeur par thème pour garder le contraste.
  static const successLight = Color(0xFF0A7C6A);
  static const successDark = Color(0xFF4DD0B1);
  static const warningLight = Color(0xFF9A6400);
  static const warningDark = Color(0xFFFFC04D);
  static const dangerLight = Color(0xFFB3261E);
  static const dangerDark = Color(0xFFFF8A80);
  static const infoLight = Color(0xFF3A6EA5);
  static const infoDark = Color(0xFF7FB2E5);
  static const neutralLight = Color(0xFF5B6472);
  static const neutralDark = Color(0xFF9AA4B2);
}
