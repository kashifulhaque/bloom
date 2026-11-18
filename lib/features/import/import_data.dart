/// The result of reading another app's export, mapped to Bloom's model, and
/// the helper that parsers use to build it.
///
/// Nothing here touches the store or the UI, so every parser can run in an
/// isolate and in unit tests.
library;

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/models.dart';

/// A file format that Bloom can read.
enum ImportFormat { appleHealth, clue, clueLegacy, flo, drip, mensinator, genericCsv }

extension ImportFormatLabel on ImportFormat {
  String get label => switch (this) {
        ImportFormat.appleHealth => 'Apple Health export',
        ImportFormat.clue => 'Clue export',
        ImportFormat.clueLegacy => 'Clue backup (older format)',
        ImportFormat.flo => 'Flo data export',
        ImportFormat.drip => 'drip CSV export',
        ImportFormat.mensinator => 'Mensinator export',
        ImportFormat.genericCsv => 'CSV file',
      };
}

/// A problem with the file that the user can act on. [message] is shown as
/// is, so write it in Bloom's voice.
class ImportException implements Exception {
  const ImportException(this.message, {this.wrongPassword = false});
  final String message;

  /// The archive is encrypted and the password is missing or wrong.
  final bool wrongPassword;

  @override
  String toString() => message;
}

/// Everything a parser read, ready to preview and merge.
///
/// [skipped] counts items Bloom has no place for, by a readable label, so the
/// preview can list them. Nothing is dropped without being counted there or
/// in [unrelatedRecords].
class ImportedData {
  ImportedData({
    required this.format,
    required this.logs,
    required this.periodDays,
    this.skipped = const {},
    this.adjusted = const {},
    this.recordsRead = 0,
    this.unrelatedRecords = 0,
  });

  final ImportFormat format;

  /// Day logs keyed by day key (`yyyy-MM-dd`). None of them is empty.
  final Map<String, DayLog> logs;

  /// Day keys of period days.
  final Set<String> periodDays;

  /// Items that weren't imported, by label, with how many there were.
  final Map<String, int> skipped;

  /// Items imported in a slightly different form, by label, such as "Very
  /// heavy flow, saved as heavy".
  final Map<String, int> adjusted;

  /// Records, rows, or entries read from the file.
  final int recordsRead;

  /// Records that aren't about cycles at all, such as step counts in an Apple
  /// Health export. They're reported as one line instead of one per type.
  final int unrelatedRecords;

  bool get isEmpty => logs.isEmpty && periodDays.isEmpty;

  int get skippedCount => skipped.values.fold(0, (a, b) => a + b);

  /// Every day the import touches.
  Set<String> get days => {...logs.keys, ...periodDays};

  /// The first and last day with data, or null when there's none.
  ({DateTime first, DateTime last})? get range {
    final all = days.toList()..sort();
    if (all.isEmpty) return null;
    return (first: parseDayKey(all.first), last: parseDayKey(all.last));
  }

  /// How many periods: runs of consecutive period days.
  int get periodCount => countPeriods(periodDays);
}

/// Counts runs of consecutive days in [periodDays].
int countPeriods(Iterable<String> periodDays) {
  final sorted = periodDays.map(parseDayKey).toList()..sort();
  var runs = 0;
  DateTime? prev;
  for (final d in sorted) {
    if (prev == null || daysBetween(prev, d) > 1) runs++;
    prev = d;
  }
  return runs;
}

/// Turns a date string from a file into a day key, or null when it isn't a
/// real calendar date. Accepts `yyyy-MM-dd` with anything after it, such as
/// a time (`2024-01-05 08:00:00 -0500` or `2024-01-05T08:00:00Z`). The date
/// part is used as written, which is the user's local date in every format
/// Bloom reads.
String? isoDayKey(Object? raw) {
  if (raw is! String || raw.length < 10) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  return validDayKey(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// The day key for a year, month, and day, or null when that date doesn't
/// exist (for example, February 30).
String? validDayKey(int y, int m, int d) {
  if (y < 1900 || y > 2200 || m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, m, d);
  if (date.month != m || date.day != d) return null;
  return dayKey(date);
}

/// Ranks for single-choice categories: when two records disagree about one
/// day, the higher rank wins. A heavier flow and a positive test are the
/// details a user would least want to lose.
const _ranks = <String, List<String>>{
  'flow': ['spotting', 'light', 'medium', 'heavy'],
  'ovulation_test': ['none', 'negative', 'my_method', 'positive'],
  'pregnancy_test': ['none', 'negative', 'faint', 'positive'],
};

/// Collects mapped data while a parser reads a file.
class ImportBuilder {
  ImportBuilder(this.format, {DateTime? today}) : _lastDay = dayKey(today ?? DateTime.now());

  final ImportFormat format;
  final Map<String, DayLog> _logs = {};
  final Set<String> _periodDays = {};
  final Map<String, int> _skipped = {};
  final Map<String, int> _adjusted = {};
  final String _lastDay;

  /// Records, rows, or entries read. Parsers increment it.
  int records = 0;

  /// Records that aren't about cycles. Parsers increment it.
  int unrelated = 0;

  /// Returns [key] when it's a usable day, or null after counting it as
  /// skipped. Days after today can't hold real logs, so they're skipped too.
  String? day(String? key, {String what = 'Entries'}) {
    if (key == null) {
      skip('$what with a date Bloom couldn\'t read');
      return null;
    }
    if (key.compareTo(_lastDay) > 0) {
      skip('$what dated after today');
      return null;
    }
    return key;
  }

  DayLog _log(String key) => _logs.putIfAbsent(key, () => DayLog(parseDayKey(key)));

  /// Selects [optionId] in [categoryId] on [key]. For single-choice
  /// categories, the higher-ranked option wins (see [_ranks]); otherwise the
  /// first one logged stays.
  void option(String key, String categoryId, String optionId) {
    final category = categoryById(categoryId);
    assert(category?.option(optionId) != null, 'Unknown option $categoryId/$optionId');
    if (category == null) return;
    if (categoryId == 'flow') {
      flow(key, optionId);
      return;
    }
    final set = _log(key).selections.putIfAbsent(categoryId, () => {});
    if (category.kind == CategoryKind.single && set.isNotEmpty) {
      final ranks = _ranks[categoryId];
      if (ranks == null || ranks.indexOf(optionId) <= ranks.indexOf(set.first)) return;
      set.clear();
    }
    set.add(optionId);
  }

  /// Logs a flow level on [key]. Any level but `spotting` also makes it a
  /// period day, as it does when the user logs it in Bloom. Spotting on a day
  /// that's already a period day is ignored.
  void flow(String key, String level) {
    final set = _log(key).selections.putIfAbsent('flow', () => {});
    if (level == 'spotting') {
      if (_periodDays.contains(key) || set.isNotEmpty) return;
      set.add('spotting');
      return;
    }
    _periodDays.add(key);
    final ranks = _ranks['flow']!;
    if (set.isNotEmpty && ranks.indexOf(level) <= ranks.indexOf(set.first)) return;
    set
      ..clear()
      ..add(level);
  }

  /// Marks [key] as a period day without a flow level.
  void period(String key) {
    _periodDays.add(key);
    final flow = _logs[key]?.selections['flow'];
    if (flow != null && flow.contains('spotting')) flow.remove('spotting');
  }

  bool isPeriodDay(String key) => _periodDays.contains(key);

  /// Sets a numeric tracker. The first value for a day stays unless
  /// [replace] is true.
  void metric(String key, String metricId, double value, {bool replace = false}) {
    final metrics = _log(key).metrics;
    if (!replace && metrics.containsKey(metricId)) return;
    metrics[metricId] = value;
  }

  bool hasMetric(String key, String metricId) => _logs[key]?.metrics.containsKey(metricId) ?? false;

  /// Sets basal body temperature in °C after checking it's in Bloom's range.
  void bbt(String key, double celsius, {bool replace = false}) {
    if (celsius.isNaN || celsius < 35.0 || celsius > 38.5) {
      skip('Temperatures outside 35 to 38.5 °C');
      return;
    }
    metric(key, 'bbt', (celsius * 100).roundToDouble() / 100, replace: replace);
  }

  /// Adds a line to the day's note.
  void note(String key, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final log = _log(key);
    if (log.note.split('\n').contains(t)) return;
    log.note = log.note.isEmpty ? t : '${log.note}\n$t';
  }

  /// Counts an item that Bloom has no place for.
  void skip(String label, [int n = 1]) => _skipped[label] = (_skipped[label] ?? 0) + n;

  /// Counts an item that was imported in a slightly different form.
  void adjust(String label, [int n = 1]) => _adjusted[label] = (_adjusted[label] ?? 0) + n;

  ImportedData build() {
    final logs = <String, DayLog>{};
    for (final e in _logs.entries) {
      e.value.selections.removeWhere((_, s) => s.isEmpty);
      if (!e.value.isEmpty) logs[e.key] = e.value;
    }
    return ImportedData(
      format: format,
      logs: logs,
      periodDays: {..._periodDays},
      skipped: Map.unmodifiable(_skipped),
      adjusted: Map.unmodifiable(_adjusted),
      recordsRead: records,
      unrelatedRecords: unrelated,
    );
  }
}
