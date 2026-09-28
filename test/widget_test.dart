import 'package:flutter_test/flutter_test.dart';
import 'package:parkauto/core/utils/app_date_time.dart';

void main() {
  group('AppDateTime', () {
    test('une date avec Z est un instant UTC', () {
      final parsed = AppDateTime.parse('2026-09-28T07:06:12Z');
      expect(parsed.isUtc, isTrue);
      expect(parsed, DateTime.utc(2026, 9, 28, 7, 6, 12));
    });

    test('une date sans fuseau est conservée telle quelle', () {
      final parsed = AppDateTime.parse('2026-09-28T10:02:11');
      expect(parsed.isUtc, isFalse);
      expect(parsed.hour, 10);
      expect(parsed.minute, 2);
    });

    test('fractions au-delà de la microseconde acceptées', () {
      final parsed = AppDateTime.parse('2026-10-28T11:40:45.527310900Z');
      expect(parsed.isUtc, isTrue);
      expect(parsed.second, 45);
    });

    test('format API sans fuseau', () {
      expect(
        AppDateTime.toApi(DateTime(2026, 9, 28, 9, 30)),
        '2026-09-28T09:30:00',
      );
    });
  });
}
