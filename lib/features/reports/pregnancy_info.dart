/// Best-effort pregnancy dates for the report and partner snapshot.
///
/// Pregnancy mode belongs to another feature, so this reads its `pregnancy`
/// feature data defensively (`dueDate` or `lmp`, as a day key or ISO date)
/// and falls back to the last logged period start as the LMP.
library;

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';

class PregnancyInfo {
  PregnancyInfo({required this.dueDate, required this.now});
  final DateTime dueDate;
  final DateTime now;

  /// Last menstrual period implied by the due date (280 days before).
  DateTime get lmp => addDays(dueDate, -280);
  int get daysPregnant => daysBetween(lmp, now).clamp(0, 300);
  int get weeks => daysPregnant ~/ 7;
  int get days => daysPregnant % 7;
  int get daysToGo => daysBetween(now, dueDate);
  int get trimester => weeks < 14 ? 1 : (weeks < 28 ? 2 : 3);
}

DateTime? _parse(Object? v) {
  if (v is! String || v.isEmpty) return null;
  try {
    return v.length == 10 ? parseDayKey(v) : dayOf(DateTime.parse(v));
  } catch (_) {
    return null;
  }
}

/// Pregnancy dates when the goal is pregnancy, or null.
PregnancyInfo? pregnancyInfo(AppStore store, {DateTime? now}) {
  if (store.profile.goal != Goal.trackPregnancy) return null;
  final n = dayOf(now ?? DateTime.now());
  final raw = store.feature<Object>('pregnancy');
  if (raw is Map) {
    final due = _parse(raw['dueDate'] ?? raw['due']);
    if (due != null) return PregnancyInfo(dueDate: due, now: n);
    final lmp = _parse(raw['lmp'] ?? raw['lastPeriod']);
    if (lmp != null) return PregnancyInfo(dueDate: addDays(lmp, 280), now: n);
  }
  final periods = store.engine.periods;
  if (periods.isEmpty) return null;
  return PregnancyInfo(dueDate: addDays(periods.last.start, 280), now: n);
}
