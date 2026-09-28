import 'package:flutter/services.dart';

/// Saisie numérique tolérante : `52,5`, `52.5`, `84 230`.
abstract final class DecimalInput {
  static final formatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s  ]')),
  ];

  static const keyboardType = TextInputType.numberWithOptions(decimal: true);

  static double? parse(String? input) {
    if (input == null) return null;
    final normalized = input
        .trim()
        .replaceAll(RegExp(r'[\s  ]'), '')
        .replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) return null;
    return double.tryParse(normalized);
  }

  /// Valeur pré-remplie : sans décimale inutile ni séparateur de milliers.
  static String format(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toString().replaceAll('.', ',');
  }
}
