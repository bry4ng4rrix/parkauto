import 'package:flutter/material.dart';

/// Échelle typographique (police système : Roboto / SF Pro).
abstract final class AppTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle style(
      double size,
      FontWeight weight,
      double height, {
      double spacing = 0,
      Color? color,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? primary,
    );

    return TextTheme(
      displaySmall: style(32, FontWeight.w700, 1.15, spacing: -0.6),
      headlineMedium: style(28, FontWeight.w700, 1.2, spacing: -0.5),
      headlineSmall: style(24, FontWeight.w700, 1.25, spacing: -0.4),
      titleLarge: style(20, FontWeight.w600, 1.3, spacing: -0.3),
      titleMedium: style(16, FontWeight.w600, 1.35, spacing: -0.1),
      titleSmall: style(14, FontWeight.w600, 1.4),
      bodyLarge: style(16, FontWeight.w400, 1.5),
      bodyMedium: style(14, FontWeight.w400, 1.45),
      bodySmall: style(12.5, FontWeight.w400, 1.4, color: secondary),
      labelLarge: style(14, FontWeight.w600, 1.3, spacing: 0.1),
      labelMedium: style(12.5, FontWeight.w600, 1.3, spacing: 0.1),
      labelSmall: style(11, FontWeight.w600, 1.3, spacing: 0.3),
    );
  }
}
