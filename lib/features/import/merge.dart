/// How imported data joins what's already in Bloom.
library;

import '../../core/models.dart';
import 'import_data.dart';

enum MergeMode {
  /// Adds imported days. On a day Bloom already has, Bloom's entry stays and
  /// the imported one is left out.
  add,

  /// Replaces every period day and daily log with the import. The profile,
  /// settings, reminders, and journal stay.
  replace,
}

/// What an import will write, worked out before anything changes.
class MergePlan {
  const MergePlan({
    required this.mode,
    required this.logs,
    required this.periodDays,
    required this.keptDays,
    required this.removedDays,
  });

  final MergeMode mode;

  /// Day logs to write.
  final Map<String, DayLog> logs;

  /// Period days to write.
  final Set<String> periodDays;

  /// Days in the import that Bloom already had, kept as they are ([MergeMode.add]).
  final int keptDays;

  /// Days of existing data that the import removes ([MergeMode.replace]).
  final int removedDays;

  /// Days the import adds or changes.
  int get importedDays => {...logs.keys, ...periodDays}.length;

  int get periodCount => countPeriods(periodDays);
}

/// Works out a [MergePlan] without changing anything.
///
/// A day "exists" in Bloom when it's a period day or has a non-empty log.
MergePlan planMerge({
  required Set<String> existingPeriodDays,
  required Map<String, DayLog> existingLogs,
  required ImportedData data,
  required MergeMode mode,
}) {
  if (mode == MergeMode.replace) {
    final existing = {...existingPeriodDays, ...existingLogs.keys};
    return MergePlan(
      mode: mode,
      logs: {for (final e in data.logs.entries) e.key: e.value.copy()},
      periodDays: {...data.periodDays},
      keptDays: 0,
      removedDays: existing.difference(data.days).length,
    );
  }
  bool exists(String k) => existingPeriodDays.contains(k) || !(existingLogs[k]?.isEmpty ?? true);
  final logs = <String, DayLog>{};
  final periods = <String>{};
  var kept = 0;
  for (final day in data.days) {
    if (exists(day)) {
      kept++;
      continue;
    }
    final log = data.logs[day];
    if (log != null) logs[day] = log.copy();
    if (data.periodDays.contains(day)) periods.add(day);
  }
  return MergePlan(mode: mode, logs: logs, periodDays: periods, keptDays: kept, removedDays: 0);
}
