/// Reads Flo's JSON data export.
///
/// Flo sends it on request as a password-protected ZIP. The known structure
/// is `operationalData.cycles[]` with `period_start_date` and
/// `period_end_date` (`yyyy-MM-dd`), and `operationalData.
/// point_events_manual_v2[]` with `category`, `subcategory`, and `date`.
/// Flo's flow levels and symptoms aren't in any documented field, so periods
/// arrive without a flow level, and every other event is counted as skipped.
/// See `docs/IMPORT_FORMATS.md`.
library;

import '../../core/dates.dart';
import 'import_data.dart';

/// Longest run of days Bloom accepts as one period. Longer ranges are
/// usually a missing end date, so only the first [_maxPeriodDays] are kept.
const _maxPeriodDays = 15;

ImportedData parseFlo(Object? json, {DateTime? today}) {
  final data = json is Map ? json['operationalData'] : null;
  if (data is! Map) throw const ImportException('This file doesn\'t look like a Flo export.');
  final b = ImportBuilder(ImportFormat.flo, today: today);
  final now = dayOf(today ?? DateTime.now());

  final cycles = data['cycles'];
  if (cycles is List) {
    for (final c in cycles) {
      b.records++;
      if (c is! Map) {
        b.skip('Cycles Bloom couldn\'t read');
        continue;
      }
      final start = b.day(isoDayKey(c['period_start_date']), what: 'Periods');
      if (start == null) continue;
      final endKey = isoDayKey(c['period_end_date']);
      final first = parseDayKey(start);
      var last = endKey == null ? first : parseDayKey(endKey);
      if (endKey == null) b.adjust('Periods with no end date, saved as one day');
      if (last.isBefore(first)) {
        b.adjust('Periods that end before they start, saved as one day');
        last = first;
      }
      if (daysBetween(first, last) >= _maxPeriodDays) {
        b.adjust('Periods longer than $_maxPeriodDays days, shortened');
        last = addDays(first, _maxPeriodDays - 1);
      }
      if (last.isAfter(now)) last = now;
      for (var d = first; !d.isAfter(last); d = addDays(d, 1)) {
        b.period(dayKey(d));
      }
    }
  }

  final events = data['point_events_manual_v2'];
  if (events is List) {
    for (final e in events) {
      b.records++;
      if (e is! Map) {
        b.skip('Events Bloom couldn\'t read');
        continue;
      }
      final category = '${e['category'] ?? ''}';
      final sub = '${e['subcategory'] ?? ''}';
      final day = b.day(isoDayKey(e['date']), what: 'Events');
      if (day == null) continue;
      switch ((category, sub)) {
        case ('OvulationTest', 'Positive'):
          b.option(day, 'ovulation_test', 'positive');
        case ('OvulationTest', 'Negative'):
          b.option(day, 'ovulation_test', 'negative');
        case ('Ovulation', _):
          b.option(day, 'ovulation_test', 'my_method');
        case ('PregnancyTest', 'Positive'):
          b.option(day, 'pregnancy_test', 'positive');
        case ('PregnancyTest', 'Negative'):
          b.option(day, 'pregnancy_test', 'negative');
        case ('PregnancyTest', 'FaintLine'):
          b.option(day, 'pregnancy_test', 'faint');
        default:
          b.skip(sub.isEmpty ? _words(category) : '${_words(category)}: ${_words(sub).toLowerCase()}');
      }
    }
  }

  if (cycles is! List && events is! List) {
    throw const ImportException('This Flo export has no cycles or events Bloom can read.');
  }
  return b.build();
}

/// `OvulationTest` → `Ovulation test`.
String _words(String s) {
  if (s.isEmpty) return 'Unknown';
  final spaced = s.replaceAll('_', ' ').replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ').toLowerCase();
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
