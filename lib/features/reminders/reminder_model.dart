/// Reminder settings, saved in the store under the `reminders` key.
library;

import '../../core/store.dart';

enum ReminderType {
  periodComing,
  periodStart,
  periodLate,
  fertileStart,
  ovulation,
  contraception,
  water,
  bedtime,
  dailyLog,
  weight,
  meditation,
  breastExam,
}

/// How a reminder repeats, which decides the controls shown for it.
enum ReminderKind { cycle, daily, interval, weekly, monthly, contraception }

extension ReminderTypeInfo on ReminderType {
  String get title => switch (this) {
        ReminderType.periodComing => 'Period coming soon',
        ReminderType.periodStart => 'Period start',
        ReminderType.periodLate => 'Period is late',
        ReminderType.fertileStart => 'Fertile window starts',
        ReminderType.ovulation => 'Ovulation day',
        ReminderType.contraception => 'Birth control',
        ReminderType.water => 'Drink water',
        ReminderType.bedtime => 'Bedtime',
        ReminderType.dailyLog => 'Daily check-in',
        ReminderType.weight => 'Log your weight',
        ReminderType.meditation => 'Meditation',
        ReminderType.breastExam => 'Breast self-exam',
      };

  String get description => switch (this) {
        ReminderType.periodComing => 'A heads-up a few days before your predicted period.',
        ReminderType.periodStart => 'On the day your period is predicted to start.',
        ReminderType.periodLate => 'When your period hasn\'t started after the predicted day.',
        ReminderType.fertileStart => 'On the first day of your predicted fertile window.',
        ReminderType.ovulation => 'On your predicted ovulation day.',
        ReminderType.contraception => 'Pill, ring, patch, injection, IUD, or implant reminders.',
        ReminderType.water => 'Regular nudges to drink water during the day.',
        ReminderType.bedtime => 'Wind down for a good night\'s sleep.',
        ReminderType.dailyLog => 'A daily nudge to log how you feel.',
        ReminderType.weight => 'A weekly nudge to log your weight.',
        ReminderType.meditation => 'A daily moment to breathe and relax.',
        ReminderType.breastExam => 'A monthly reminder to check your breasts.',
      };

  String get emoji => switch (this) {
        ReminderType.periodComing => '🗓️',
        ReminderType.periodStart => '🩸',
        ReminderType.periodLate => '⏳',
        ReminderType.fertileStart => '🌱',
        ReminderType.ovulation => '🥚',
        ReminderType.contraception => '💊',
        ReminderType.water => '💧',
        ReminderType.bedtime => '🌙',
        ReminderType.dailyLog => '📝',
        ReminderType.weight => '⚖️',
        ReminderType.meditation => '🧘',
        ReminderType.breastExam => '🤍',
      };

  ReminderKind get kind => switch (this) {
        ReminderType.periodComing ||
        ReminderType.periodStart ||
        ReminderType.periodLate ||
        ReminderType.fertileStart ||
        ReminderType.ovulation =>
          ReminderKind.cycle,
        ReminderType.contraception => ReminderKind.contraception,
        ReminderType.water => ReminderKind.interval,
        ReminderType.weight => ReminderKind.weekly,
        ReminderType.breastExam => ReminderKind.monthly,
        _ => ReminderKind.daily,
      };

  /// True for reminders that depend on cycle predictions.
  bool get isCycle => kind == ReminderKind.cycle;
}

/// Settings for one reminder type.
class Reminder {
  Reminder({
    required this.type,
    this.enabled = false,
    this.hour = 9,
    this.minute = 0,
    this.days = 2,
    this.intervalHours = 2,
    this.startHour = 9,
    this.endHour = 21,
    this.weekday = DateTime.monday,
    this.dayOfMonth = 7,
  });

  final ReminderType type;
  bool enabled;
  int hour;
  int minute;

  /// Days before (period coming) or after (period late) the predicted day.
  int days;

  /// Water: remind every [intervalHours] between [startHour] and [endHour].
  int intervalHours;
  int startHour;
  int endHour;

  /// Weight: day of the week.
  int weekday;

  /// Breast self-exam: day of the month (1-28).
  int dayOfMonth;

  factory Reminder.defaults(ReminderType t) => switch (t) {
        ReminderType.periodComing => Reminder(type: t, days: 2, hour: 9),
        ReminderType.periodLate => Reminder(type: t, days: 2, hour: 10),
        ReminderType.bedtime => Reminder(type: t, hour: 22, minute: 30),
        ReminderType.dailyLog => Reminder(type: t, hour: 20),
        ReminderType.meditation => Reminder(type: t, hour: 18),
        ReminderType.weight => Reminder(type: t, hour: 8),
        ReminderType.contraception => Reminder(type: t, hour: 21),
        _ => Reminder(type: t),
      };

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'days': days,
        'intervalHours': intervalHours,
        'startHour': startHour,
        'endHour': endHour,
        'weekday': weekday,
        'dayOfMonth': dayOfMonth,
      };

  factory Reminder.fromJson(ReminderType t, Map<String, dynamic> j) {
    final d = Reminder.defaults(t);
    int read(String k, int fallback) => (j[k] as num?)?.toInt() ?? fallback;
    return Reminder(
      type: t,
      enabled: j['enabled'] as bool? ?? false,
      hour: read('hour', d.hour),
      minute: read('minute', d.minute),
      days: read('days', d.days),
      intervalHours: read('intervalHours', d.intervalHours),
      startHour: read('startHour', d.startHour),
      endHour: read('endHour', d.endHour),
      weekday: read('weekday', d.weekday),
      dayOfMonth: read('dayOfMonth', d.dayOfMonth),
    );
  }
}

/// All reminder settings.
class ReminderSettings {
  ReminderSettings(this.items);

  static const storageKey = 'reminders';

  final Map<ReminderType, Reminder> items;

  Reminder operator [](ReminderType t) => items[t] ??= Reminder.defaults(t);

  Iterable<Reminder> get enabled => ReminderType.values.map((t) => this[t]).where((r) => r.enabled);

  factory ReminderSettings.fromJson(Map<String, dynamic>? j) {
    final items = <ReminderType, Reminder>{};
    for (final t in ReminderType.values) {
      final raw = j?[t.name];
      items[t] = raw is Map ? Reminder.fromJson(t, Map<String, dynamic>.from(raw)) : Reminder.defaults(t);
    }
    return ReminderSettings(items);
  }

  Map<String, dynamic> toJson() => {for (final e in items.entries) e.key.name: e.value.toJson()};

  static ReminderSettings of(AppStore store) {
    final raw = store.feature<Object>(storageKey);
    return ReminderSettings.fromJson(raw is Map ? Map<String, dynamic>.from(raw) : null);
  }

  void save(AppStore store) => store.setFeature(storageKey, toJson());
}
