/// Core data models shared by every feature.
library;

import 'dates.dart';

/// What the user is using the app for. Changes trackers, content, and Today.
enum Goal { trackCycle, getPregnant, trackPregnancy, postpartum, perimenopause }

extension GoalLabel on Goal {
  String get label => switch (this) {
        Goal.trackCycle => 'Track my cycle',
        Goal.getPregnant => 'Get pregnant',
        Goal.trackPregnancy => 'Track pregnancy',
        Goal.postpartum => 'After birth',
        Goal.perimenopause => 'Perimenopause',
      };
}

enum TempUnit { celsius, fahrenheit }

enum WeightUnit { kg, lb }

enum NotificationPrivacy { detailed, minimal, private }

/// The user's profile and settings.
class Profile {
  Profile({
    this.name = '',
    this.birthYear,
    this.goal = Goal.trackCycle,
    this.cycleLength = 28,
    this.periodLength = 5,
    this.lutealLength = 14,
    this.onboarded = false,
    this.tempUnit = TempUnit.celsius,
    this.weightUnit = WeightUnit.kg,
    this.themeMode = 'system',
    this.firstDayOfWeek = DateTime.monday,
    this.notificationPrivacy = NotificationPrivacy.minimal,
    this.pin,
    this.hiddenTrackers = const [],
    this.trackerOrder = const [],
    this.excludedCycleStarts = const [],
    this.irregular = false,
    this.conditions = const [],
  });

  String name;
  int? birthYear;
  Goal goal;

  /// Fallback averages, used until enough cycles are logged.
  int cycleLength;
  int periodLength;
  int lutealLength;
  bool onboarded;
  TempUnit tempUnit;
  WeightUnit weightUnit;

  /// One of `system`, `light`, `dark`.
  String themeMode;
  int firstDayOfWeek;
  NotificationPrivacy notificationPrivacy;

  /// App lock PIN. Null when the lock is off.
  String? pin;

  /// Category ids hidden from the log sheet, and their custom order.
  List<String> hiddenTrackers;
  List<String> trackerOrder;

  /// Day keys of period starts the user excluded from averages
  /// (for example, a long gap after stopping birth control).
  List<String> excludedCycleStarts;
  bool irregular;

  /// Known conditions picked in onboarding, such as `pcos`, `endometriosis`.
  List<String> conditions;

  Map<String, dynamic> toJson() => {
        'name': name,
        'birthYear': birthYear,
        'goal': goal.name,
        'cycleLength': cycleLength,
        'periodLength': periodLength,
        'lutealLength': lutealLength,
        'onboarded': onboarded,
        'tempUnit': tempUnit.name,
        'weightUnit': weightUnit.name,
        'themeMode': themeMode,
        'firstDayOfWeek': firstDayOfWeek,
        'notificationPrivacy': notificationPrivacy.name,
        'pin': pin,
        'hiddenTrackers': hiddenTrackers,
        'trackerOrder': trackerOrder,
        'excludedCycleStarts': excludedCycleStarts,
        'irregular': irregular,
        'conditions': conditions,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] ?? '',
        birthYear: j['birthYear'],
        goal: Goal.values.asNameMap()[j['goal']] ?? Goal.trackCycle,
        cycleLength: j['cycleLength'] ?? 28,
        periodLength: j['periodLength'] ?? 5,
        lutealLength: j['lutealLength'] ?? 14,
        onboarded: j['onboarded'] ?? false,
        tempUnit: TempUnit.values.asNameMap()[j['tempUnit']] ?? TempUnit.celsius,
        weightUnit: WeightUnit.values.asNameMap()[j['weightUnit']] ?? WeightUnit.kg,
        themeMode: j['themeMode'] ?? 'system',
        firstDayOfWeek: j['firstDayOfWeek'] ?? DateTime.monday,
        notificationPrivacy:
            NotificationPrivacy.values.asNameMap()[j['notificationPrivacy']] ??
                NotificationPrivacy.minimal,
        pin: j['pin'],
        hiddenTrackers: List<String>.from(j['hiddenTrackers'] ?? const []),
        trackerOrder: List<String>.from(j['trackerOrder'] ?? const []),
        excludedCycleStarts: List<String>.from(j['excludedCycleStarts'] ?? const []),
        irregular: j['irregular'] ?? false,
        conditions: List<String>.from(j['conditions'] ?? const []),
      );
}

/// Everything logged for one calendar day.
///
/// Choice categories (see `catalog.dart`) live in [selections] as
/// category id → option ids. Numeric trackers live in [metrics] using
/// metric units: `bbt` (°C), `weight` (kg), `water` (ml), `sleep` (hours),
/// `steps`, `energy` (1-5). The menstrual flow is `selections['flow']`.
class DayLog {
  DayLog(this.date, {Map<String, Set<String>>? selections, Map<String, double>? metrics, this.note = ''})
      : selections = selections ?? {},
        metrics = metrics ?? {};

  final DateTime date;
  final Map<String, Set<String>> selections;
  final Map<String, double> metrics;
  String note;

  String get key => dayKey(date);

  bool get isEmpty =>
      selections.values.every((s) => s.isEmpty) && metrics.isEmpty && note.trim().isEmpty;

  Set<String> get(String categoryId) => selections[categoryId] ?? const {};

  bool has(String categoryId, String optionId) => get(categoryId).contains(optionId);

  /// Total count of logged options, metrics, and notes. Used for badges.
  int get entryCount =>
      selections.values.fold(0, (a, s) => a + s.length) + metrics.length + (note.trim().isEmpty ? 0 : 1);

  DayLog copy() => DayLog(date,
      selections: {for (final e in selections.entries) e.key: {...e.value}},
      metrics: {...metrics},
      note: note);

  Map<String, dynamic> toJson() => {
        'date': key,
        'selections': {for (final e in selections.entries) if (e.value.isNotEmpty) e.key: e.value.toList()},
        'metrics': metrics,
        if (note.isNotEmpty) 'note': note,
      };

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
        parseDayKey(j['date']),
        selections: {
          for (final e in (j['selections'] as Map? ?? {}).entries)
            e.key as String: Set<String>.from(e.value as List),
        },
        metrics: {
          for (final e in (j['metrics'] as Map? ?? {}).entries) e.key as String: (e.value as num).toDouble(),
        },
        note: j['note'] ?? '',
      );
}
