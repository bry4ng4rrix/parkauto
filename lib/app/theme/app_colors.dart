import 'package:flutter/material.dart';

/// Palette volontairement restreinte : un bleu profond pour l'action,
/// des neutres froids, et des couleurs sémantiques réservées aux statuts.
abstract final class AppColors {
  static const brand = Color(0xFF1F4FD8);
  static const brandDark = Color(0xFF8AA4FF);

  // Neutres — clair
  static const lightBackground = Color(0xFFF6F7F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceMuted = Color(0xFFF0F2F5);
  static const lightBorder = Color(0xFFE3E6EB);
  static const lightTextPrimary = Color(0xFF11151C);
  static const lightTextSecondary = Color(0xFF505968);

  // Neutres — sombre
  static const darkBackground = Color(0xFF0C0E12);
  static const darkSurface = Color(0xFF14171D);
  static const darkSurfaceMuted = Color(0xFF1B1F26);
  static const darkBorder = Color(0xFF282D36);
  static const darkTextPrimary = Color(0xFFF1F3F6);
  static const darkTextSecondary = Color(0xFFA0A8B5);

  // Sémantiques — clair / sombre
  static const successLight = Color(0xFF0E8A4F);
  static const successDark = Color(0xFF4ADE95);
  static const warningLight = Color(0xFFB45309);
  static const warningDark = Color(0xFFFBBF4E);
  static const dangerLight = Color(0xFFC62828);
  static const dangerDark = Color(0xFFFF7A70);
  static const infoLight = Color(0xFF1F4FD8);
  static const infoDark = Color(0xFF8AA4FF);
  static const neutralLight = Color(0xFF5B6473);
  static const neutralDark = Color(0xFFA0A8B5);
}
