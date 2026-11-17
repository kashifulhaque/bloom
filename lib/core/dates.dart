/// Date helpers. All app dates are local calendar days with no time part.
library;

import 'package:intl/intl.dart';

/// Returns [d] with the time part removed.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Today's date with no time part.
DateTime today() => dayOf(DateTime.now());

/// Stable storage key for a day, in `yyyy-MM-dd` form.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Parses a key made by [dayKey].
DateTime parseDayKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Adds [n] calendar days. Safe across daylight-saving changes.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Whole calendar days from [a] to [b] (positive when [b] is later).
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String fmtShort(DateTime d) => DateFormat('MMM d').format(d);
String fmtLong(DateTime d) => DateFormat('EEEE, MMMM d').format(d);
String fmtFull(DateTime d) => DateFormat('MMM d, yyyy').format(d);
