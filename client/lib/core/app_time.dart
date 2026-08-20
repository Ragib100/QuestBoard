/// Every date the app shows is Bangladesh time.
///
/// Two separate bugs live here, and both were real:
///
/// 1. **The server sends naive timestamps.** `created_at` arrives as
///    `2026-08-20T14:18:09.297403` with no zone, and `DateTime.parse` reads an
///    unzoned string as *local* — so a quest posted a moment ago rendered as
///    "6h ago" on a phone in Dhaka. Those columns are `timestamp without time
///    zone` holding UTC, so [parseServerTime] says so explicitly.
/// 2. **The device's clock is not the product's clock.** A user travelling, or
///    with the wrong zone set, would see a different "today" than the one the
///    server pays challenges for. [toDhaka] pins rendering to UTC+6 regardless.
///
/// Dart's [DateTime] only knows local and UTC, so "Dhaka time" here is a UTC
/// instant shifted by the offset and then read with the `.hour`/`.day` getters.
/// Never do arithmetic on the result — convert, then format.
library;

/// Asia/Dhaka is UTC+6 and has had no DST since 2009, so a fixed offset is the
/// whole truth. Mirrors `server/app/core/clock.py`.
const Duration dhakaOffset = Duration(hours: 6);

/// Parses a timestamp from the API. An unzoned string is UTC, because that is
/// what the column holds.
DateTime? parseServerTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  final hasZone = raw.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
  final parsed = DateTime.tryParse(hasZone ? raw : '${raw}Z');
  return parsed?.toUtc();
}

/// Parses a plain `YYYY-MM-DD` — a calendar day, which has no zone to convert.
/// Shifting one of these would move it a day.
DateTime? parseServerDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// The same instant, with its fields readable as Bangladesh wall-clock time.
DateTime toDhaka(DateTime instant) => instant.toUtc().add(dhakaOffset);

/// Right now, in Bangladesh.
DateTime dhakaNow() => toDhaka(DateTime.now());

/// Today's date in Bangladesh — what the server means by "today".
DateTime dhakaToday() {
  final now = dhakaNow();
  return DateTime(now.year, now.month, now.day);
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `20 Aug 2026` — Bangladesh's calendar day for that instant.
String formatDhakaDate(DateTime instant) {
  final d = toDhaka(instant);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// A calendar day that arrived without a zone, formatted as-is.
String formatDay(DateTime day) => '${day.day} ${_months[day.month - 1]} ${day.year}';

/// `20 Aug 2026, 8:18 pm` — the full stamp, for anywhere the exact time matters.
String formatDhaka(DateTime instant) {
  final d = toDhaka(instant);
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final meridiem = d.hour < 12 ? 'am' : 'pm';
  return '${formatDhakaDate(instant)}, $hour12:$minute $meridiem';
}

/// Relative time for feed rows: "3h ago".
///
/// Compares instants, so it is correct whatever zone the phone is in — the
/// zone only matters once we start printing a wall clock.
String timeAgo(DateTime when) {
  final d = DateTime.now().toUtc().difference(when.toUtc());

  // A clock a few seconds behind the server should read "just now", not
  // "-1m ago".
  if (d.isNegative || d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${(d.inDays / 30).floor()}mo ago';
}
