import 'package:farmer_mobile/core/network/paged.dart';
import 'package:farmer_mobile/core/utils/formatters.dart';
import 'package:farmer_mobile/core/utils/json_utils.dart';
import 'package:farmer_mobile/core/utils/validators.dart';
import 'package:farmer_mobile/core/utils/vn_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVnd', () {
    test('groups thousands with dots', () {
      expect(formatVnd(0), '0 ₫');
      expect(formatVnd(950), '950 ₫');
      expect(formatVnd(1250000), '1.250.000 ₫');
      expect(formatVnd(1250000, symbol: false), '1.250.000');
    });
    test('keeps a fraction only when there is one', () {
      expect(formatVnd(1234.5), '1.234,5 ₫');
      expect(formatVnd(1234.05), '1.234,05 ₫');
      expect(formatVnd(-5000), '-5.000 ₫');
    });
  });

  test('initialsOf takes the first and last word', () {
    expect(initialsOf('Trần Văn Hải'), 'TH');
    expect(initialsOf('  hải '), 'H');
    expect(initialsOf(''), '?');
    expect(initialsOf('Nông dân E2E 170679 (sửa)'), 'NS'); // never a bracket
    expect(initialsOf('( )'), '?');
  });

  group('Vietnam time', () {
    test('21:30 UTC is already the next day in Vietnam', () {
      final instant = DateTime.utc(2026, 12, 31, 21, 30);
      expect(formatVnDate(instant), '01/01/2027');
      expect(formatVnDateTime(instant), '04:30 01/01/2027');
      expect(vnDateIso(instant), '2027-01-01');
    });
    test('vnToday ignores the device time zone', () {
      expect(vnToday(DateTime.utc(2026, 10, 7, 20)), DateTime.utc(2026, 10, 8));
      expect(vnToday(DateTime.utc(2026, 10, 7, 16)), DateTime.utc(2026, 10, 7));
    });
    test('a missing date shows a dash', () => expect(formatVnDate(null), '—'));
  });

  group('validators', () {
    test('Vietnamese mobile numbers follow the backend rule', () {
      expect(validateVnPhone('0912345678'), isNull);
      expect(validateVnPhone('0912 345 678'), isNull);
      expect(validateVnPhone('+84912345678'), isNull);
      expect(validateVnPhone('84912345678'), isNull);
      expect(validateVnPhone('0212345678'), isNotNull); // not a mobile prefix
      expect(validateVnPhone('091234567'), isNotNull); // too short
      expect(validateVnPhone(''), isNotNull);
    });
    test('passwords need 8 to 128 characters', () {
      expect(validateNewPassword('1234567'), isNotNull);
      expect(validateNewPassword('12345678'), isNull);
      expect(validateNewPassword('a' * 129), isNotNull);
    });
    test('email is optional but must look like one', () {
      expect(validateOptionalEmail(''), isNull);
      expect(validateOptionalEmail('a@b.vn'), isNull);
      expect(validateOptionalEmail('a@b'), isNotNull);
    });
    test('full name is required', () {
      expect(validateFullName('  '), isNotNull);
      expect(validateFullName('Hải'), isNull);
    });
  });

  group('json readers', () {
    test('numbers arrive as int, double or text', () {
      expect(asDouble(5), 5.0);
      expect(asDouble('2.5'), 2.5);
      expect(asInt(7.0), 7);
      expect(asInt(null, 3), 3);
      expect(asDoubleOrNull(null), isNull);
    });
    test('a date without an offset is read as UTC', () {
      expect(asDateTime('2026-10-08T03:00:00'), DateTime.utc(2026, 10, 8, 3));
      expect(asDateTime('2026-10-08T10:00:00+07:00'), DateTime.utc(2026, 10, 8, 3));
      expect(asDateTime(null), isNull);
    });
  });

  group('Paged', () {
    test('reads the envelope and says whether there is another page', () {
      final page = Paged<int>.fromJson(
        {
          'items': [
            {'v': 1},
            {'v': 2},
          ],
          'page': 1,
          'pageSize': 2,
          'totalCount': 5,
        },
        (json) => json['v'] as int,
      );
      expect(page.items, [1, 2]);
      expect(page.totalPages, 3);
      expect(page.hasMore, isTrue);

      const next = Paged<int>(items: [3, 4], page: 2, pageSize: 2, totalCount: 5);
      final both = page.append(next);
      expect(both.items, [1, 2, 3, 4]);
      expect(both.page, 2);
    });
  });
}
