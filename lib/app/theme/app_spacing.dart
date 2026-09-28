import 'package:flutter/widgets.dart';

/// Échelle d'espacement (multiples de 4).
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Marge latérale des écrans.
  static const double gutter = 16;

  /// Largeur maximale du contenu (tablettes).
  static const double maxContentWidth = 720;

  static const page = EdgeInsets.symmetric(horizontal: gutter);
  static const card = EdgeInsets.all(lg);

  static const gapXs = SizedBox(height: xs, width: xs);
  static const gapSm = SizedBox(height: sm, width: sm);
  static const gapMd = SizedBox(height: md, width: md);
  static const gapLg = SizedBox(height: lg, width: lg);
  static const gapXl = SizedBox(height: xl, width: xl);
  static const gapXxl = SizedBox(height: xxl, width: xxl);
  static const gapXxxl = SizedBox(height: xxxl, width: xxxl);
}
