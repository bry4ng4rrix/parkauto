import 'package:intl/intl.dart';

import 'app_date_time.dart';

/// Formats d'affichage (français).
abstract final class AppFormat {
  static final _integer = NumberFormat('#,##0', 'fr');
  static final _decimal = NumberFormat('#,##0.##', 'fr');
  static final _date = DateFormat('d MMM yyyy', 'fr');
  static final _shortDate = DateFormat('d MMM', 'fr');
  static final _dateTime = DateFormat("d MMM yyyy 'à' HH:mm", 'fr');
  static final _time = DateFormat('HH:mm', 'fr');
  static final _weekday = DateFormat('EEEE d MMMM', 'fr');
  static final _month = DateFormat('MMMM yyyy', 'fr');

  static String number(num value) => _decimal.format(value);

  static String km(double? value) =>
      value == null ? '—' : '${_integer.format(value)} km';

  static String hours(double? value) =>
      value == null ? '—' : '${_decimal.format(value)} h';

  static String litres(double? value) =>
      value == null ? '—' : '${_decimal.format(value)} L';

  static String money(double? value, String currency) =>
      value == null ? '—' : '${_integer.format(value)} $currency';

  static String date(DateTime value) =>
      _date.format(AppDateTime.toDisplay(value));

  static String shortDate(DateTime value) =>
      _shortDate.format(AppDateTime.toDisplay(value));

  static String dateTime(DateTime value) =>
      _dateTime.format(AppDateTime.toDisplay(value));

  static String time(DateTime value) =>
      _time.format(AppDateTime.toDisplay(value));

  static String month(DateTime value) =>
      _capitalize(_month.format(AppDateTime.toDisplay(value)));

  /// « Aujourd'hui », « Hier » ou « lundi 28 septembre ».
  static String day(DateTime value, {DateTime? now}) {
    final local = AppDateTime.toDisplay(value);
    final today = now ?? DateTime.now();
    if (AppDateTime.isSameDay(local, today)) return "Aujourd'hui";
    if (AppDateTime.isSameDay(local, today.subtract(const Duration(days: 1)))) {
      return 'Hier';
    }
    return _capitalize(_weekday.format(local));
  }

  /// « À l'instant », « Il y a 5 min », « Il y a 2 h », « Hier », date.
  static String relative(DateTime value, {DateTime? now}) {
    final local = AppDateTime.toDisplay(value);
    final reference = now ?? DateTime.now();
    final diff = reference.difference(local);
    if (diff.isNegative) return dateTime(local);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24 && AppDateTime.isSameDay(local, reference)) {
      return 'Il y a ${diff.inHours} h';
    }
    if (AppDateTime.isSameDay(
      local,
      reference.subtract(const Duration(days: 1)),
    )) {
      return 'Hier à ${time(local)}';
    }
    return date(local);
  }

  /// Horodatage compact pour les listes (heure si aujourd'hui, sinon date).
  static String compact(DateTime value, {DateTime? now}) {
    final local = AppDateTime.toDisplay(value);
    final reference = now ?? DateTime.now();
    if (AppDateTime.isSameDay(local, reference)) return time(local);
    if (local.year == reference.year) return shortDate(local);
    return date(local);
  }

  /// Plage horaire : « 28 sept. · 07:00 – 17:00 » ou « 28 sept. 07:00 →
  /// 29 sept. 17:00 ».
  static String range(DateTime start, DateTime end) {
    if (AppDateTime.isSameDay(start, end)) {
      return '${shortDate(start)} · ${time(start)} – ${time(end)}';
    }
    return '${shortDate(start)} ${time(start)} → ${shortDate(end)} ${time(end)}';
  }

  /// Échéance à partir de `joursRestants`.
  static String remainingDays(int days) {
    if (days < 0) {
      final n = -days;
      return 'Expiré depuis $n jour${n > 1 ? 's' : ''}';
    }
    if (days == 0) return "Expire aujourd'hui";
    return 'Expire dans $days jour${days > 1 ? 's' : ''}';
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${_integer.format(bytes / 1024)} Ko';
    return '${_decimal.format(bytes / (1024 * 1024))} Mo';
  }

  static String plural(int count, String singular, [String? pluralForm]) =>
      '$count ${count > 1 ? (pluralForm ?? '${singular}s') : singular}';

  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
