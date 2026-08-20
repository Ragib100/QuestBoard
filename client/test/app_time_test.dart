import 'package:flutter_test/flutter_test.dart';

import 'package:client/core/app_time.dart';

/// Everything the app shows is Bangladesh time, and getting there needed two
/// fixes. These pin both.
void main() {
  group('parseServerTime', () {
    test('reads an unzoned server timestamp as UTC, not local', () {
      // The bug: `created_at` comes back as `timestamp without time zone`
      // holding UTC, and `DateTime.parse` treats an unzoned string as *local*.
      // On a phone in Dhaka a quest posted seconds ago read "6h ago".
      final parsed = parseServerTime('2026-08-20T14:18:09.297403');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      expect(parsed.hour, 14);
      expect(parsed.millisecondsSinceEpoch,
          DateTime.utc(2026, 8, 20, 14, 18, 9, 297).millisecondsSinceEpoch);
    });

    test('leaves an explicit zone alone', () {
      final zulu = parseServerTime('2026-08-20T14:18:09Z');
      final offset = parseServerTime('2026-08-20T20:18:09+06:00');

      expect(zulu, isNotNull);
      expect(offset, isNotNull);
      // Same instant, written two ways.
      expect(offset!.millisecondsSinceEpoch, zulu!.millisecondsSinceEpoch);
    });

    test('returns null for nothing rather than inventing a time', () {
      expect(parseServerTime(null), isNull);
      expect(parseServerTime(''), isNull);
      expect(parseServerTime('not a date'), isNull);
    });
  });

  group('Dhaka rendering', () {
    test('an instant renders on the Bangladesh calendar day', () {
      // 18:30 UTC is already 00:30 the next day in Dhaka. The server pays the
      // challenge for the 21st; the screen has to say the 21st too.
      final instant = DateTime.utc(2026, 8, 20, 18, 30);

      expect(formatDhakaDate(instant), '21 Aug 2026');
      expect(formatDhaka(instant), '21 Aug 2026, 12:30 am');
    });

    test('noon and midnight are am/pm correct', () {
      // 06:00 UTC is 12:00 Dhaka — the case a `hour % 12` off-by-one breaks.
      expect(formatDhaka(DateTime.utc(2026, 8, 20, 6)), '20 Aug 2026, 12:00 pm');
      expect(
          formatDhaka(DateTime.utc(2026, 8, 20, 18)), '21 Aug 2026, 12:00 am');
    });

    test('a calendar day is not shifted', () {
      // `challenge_date` is a date, not an instant. Converting one would move
      // it a day.
      final day = parseServerDate('2026-08-20');
      expect(day, isNotNull);
      expect(formatDay(day!), '20 Aug 2026');
    });
  });

  group('timeAgo', () {
    test('compares instants, so the phone timezone does not matter', () {
      final justNow = DateTime.now().toUtc().subtract(const Duration(seconds: 5));
      expect(timeAgo(justNow), 'just now');

      expect(timeAgo(DateTime.now().toUtc().subtract(const Duration(hours: 3))),
          '3h ago');
    });

    test('a clock slightly behind the server reads "just now", not "-1m ago"',
        () {
      expect(timeAgo(DateTime.now().toUtc().add(const Duration(minutes: 2))),
          'just now');
    });
  });
}
