import 'package:flutter/widgets.dart';

/// Rayons alignés sur l'application Maintenance.
abstract final class AppRadius {
  /// Badges, puces.
  static const double sm = 8;

  /// Champs et boutons.
  static const double md = 10;

  /// Cartes.
  static const double lg = 14;

  /// Feuilles et dialogues.
  static const double xl = 20;
  static const double pill = 999;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}
