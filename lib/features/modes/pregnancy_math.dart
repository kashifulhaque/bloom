/// Pure pregnancy date math and the `pregnancy` feature model.
///
/// Gestational age is counted from the first day of the last menstrual
/// period (LMP). The estimated due date is LMP + 280 days.
library;

import '../../core/dates.dart';
import '../../core/store.dart';

/// Days from LMP to the estimated due date.
const int kPregnancyDays = 280;

/// Gestational weeks after which the app gently asks whether the baby has arrived.
const int kOverdueWeeks = 42;

DateTime dueFromLmp(DateTime lmp) => addDays(lmp, kPregnancyDays);
DateTime lmpFromDue(DateTime due) => addDays(due, -kPregnancyDays);

/// Conception usually happens about two weeks after the LMP.
DateTime lmpFromConception(DateTime conception) => addDays(conception, -14);

/// Gestational age on a given day.
class GestationalAge {
  const GestationalAge(this.totalDays);

  /// Days since the LMP. Can be negative when the LMP is in the future.
  final int totalDays;

  /// Completed weeks.
  int get weeks => totalDays < 0 ? 0 : totalDays ~/ 7;

  /// Days into the current week, 0-6.
  int get days => totalDays < 0 ? 0 : totalDays % 7;

  /// Trimester 1 (weeks 0-13), 2 (weeks 14-27), or 3 (week 28 on).
  int get trimester => weeks < 14 ? 1 : (weeks < 28 ? 2 : 3);

  /// Fraction of the 280-day pregnancy elapsed, clamped to 0..1.
  double get progress => (totalDays / kPregnancyDays).clamp(0.0, 1.0);

  /// Week index for week-by-week content, 1..42.
  int get contentWeek => weeks.clamp(1, 42);

  bool get isOverdue => weeks >= kOverdueWeeks;

  String get label => 'Week $weeks, day $days';
}

GestationalAge gestationalAge(DateTime lmp, DateTime on) => GestationalAge(daysBetween(lmp, on));

String trimesterLabel(int t) => switch (t) {
  1 => 'First trimester',
  2 => 'Second trimester',
  _ => 'Third trimester',
};

/// The active pregnancy, read from the `pregnancy` feature.
class PregnancyData {
  PregnancyData({
    required this.lmp,
    required this.babies,
    this.startedAt,
    List<String>? checklist,
    List<Map<String, dynamic>>? appointments,
    Map<String, dynamic>? extra,
  }) : checklist = checklist ?? [],
       appointments = appointments ?? [],
       extra = extra ?? {};

  DateTime lmp;
  int babies;
  String? startedAt;
  List<String> checklist;
  List<Map<String, dynamic>> appointments;

  /// Unknown keys, kept so saving never drops data.
  Map<String, dynamic> extra;

  DateTime get dueDate => dueFromLmp(lmp);

  GestationalAge ageOn(DateTime d) => gestationalAge(lmp, d);

  int daysToGo(DateTime on) => daysBetween(on, dueDate);

  Map<String, dynamic> toJson() => {
    ...extra,
    'lmp': dayKey(lmp),
    'dueDate': dayKey(dueDate),
    'babies': babies,
    'startedAt': startedAt ?? DateTime.now().toIso8601String(),
    'checklist': checklist,
    'appointments': appointments,
  };

  static PregnancyData? fromJson(Map? raw) {
    if (raw == null) return null;
    final j = Map<String, dynamic>.from(raw);
    DateTime? lmp;
    if (j['lmp'] is String) {
      lmp = parseDayKey(j['lmp']);
    } else if (j['dueDate'] is String) {
      lmp = lmpFromDue(parseDayKey(j['dueDate']));
    }
    if (lmp == null) return null;
    const known = {'lmp', 'dueDate', 'babies', 'startedAt', 'checklist', 'appointments'};
    return PregnancyData(
      lmp: lmp,
      babies: (j['babies'] as num?)?.toInt() ?? 1,
      startedAt: j['startedAt'] as String?,
      checklist: List<String>.from(j['checklist'] ?? const []),
      appointments: [for (final a in (j['appointments'] as List? ?? const [])) Map<String, dynamic>.from(a as Map)],
      extra: {
        for (final e in j.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
    );
  }
}

/// Reads the active pregnancy. Falls back to the onboarding answers
/// (`pregnancyLmp` or `dueDate`) when `pregnancy` isn't set yet and no
/// earlier pregnancy was archived.
PregnancyData? readPregnancy(AppStore store) {
  final saved = PregnancyData.fromJson(store.feature<Map>('pregnancy'));
  if (saved != null) return saved;
  final history = store.feature<List>('pregnancy_history');
  if (history != null && history.isNotEmpty) return null;
  final ob = store.feature<Map>('onboarding');
  if (ob == null) return null;
  if (ob['pregnancyLmp'] is String) {
    return PregnancyData(lmp: parseDayKey(ob['pregnancyLmp']), babies: 1);
  }
  if (ob['dueDate'] is String) {
    return PregnancyData(lmp: lmpFromDue(parseDayKey(ob['dueDate'])), babies: 1);
  }
  return null;
}

void savePregnancy(AppStore store, PregnancyData p) => store.setFeature('pregnancy', p.toJson());

/// Moves the active pregnancy into `pregnancy_history` and clears `pregnancy`.
void archivePregnancy(AppStore store, {required String outcome, DateTime? endDate}) {
  final p = readPregnancy(store);
  final history = [...(store.feature<List>('pregnancy_history') ?? const [])];
  if (p != null) {
    history.add({
      'lmp': dayKey(p.lmp),
      'dueDate': dayKey(p.dueDate),
      'babies': p.babies,
      'startedAt': p.startedAt,
      'endedAt': dayKey(endDate ?? today()),
      'outcome': outcome,
    });
  }
  store.features['pregnancy_history'] = history;
  store.setFeature('pregnancy', null);
}
