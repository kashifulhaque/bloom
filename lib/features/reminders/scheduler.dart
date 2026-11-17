/// Pure reminder scheduling: turns reminder settings, birth control
/// settings, and cycle predictions into dated occurrences.
///
/// Nothing here touches plugins or the store, so it runs in unit tests and
/// on the web. `notification_service.dart` hands the results to the
/// Android notification plugin, and `due_reminders.dart` shows today's
/// occurrences in the app.
library;

import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import 'contraception_model.dart';
import 'reminder_model.dart';

/// One dated reminder.
class ReminderOccurrence {
  ReminderOccurrence({required this.type, required this.when, required this.title, required this.body});

  final ReminderType type;
  final DateTime when;

  /// Detailed text. Use [notificationText] to respect notification privacy.
  final String title;
  final String body;

  DateTime get day => dayOf(when);

  @override
  String toString() => '${type.name} @ $when: $title';
}

/// Computes reminder occurrences from the start of [now]'s day up to
/// [horizonDays] days ahead, sorted by time. Occurrences earlier today are
/// included so the in-app banner can show them; filter with
/// `when.isAfter(now)` before scheduling notifications.
List<ReminderOccurrence> computeOccurrences({
  required ReminderSettings settings,
  required Contraception contraception,
  required CycleEngine engine,
  required Goal goal,
  required DateTime now,
  int horizonDays = 14,
}) {
  final start = dayOf(now);
  final end = addDays(start, horizonDays); // exclusive
  final out = <ReminderOccurrence>[];
  bool inRange(DateTime d) => !d.isBefore(start) && d.isBefore(end);
  DateTime at(DateTime d, int h, int m) => DateTime(d.year, d.month, d.day, h, m);
  void add(ReminderType t, DateTime when, String title, String body) {
    if (inRange(dayOf(when))) out.add(ReminderOccurrence(type: t, when: when, title: title, body: body));
  }

  final days = [for (var i = 0; i < horizonDays; i++) addDays(start, i)];

  for (final r in settings.enabled) {
    switch (r.type.kind) {
      case ReminderKind.cycle:
        if (goal == Goal.trackPregnancy || !engine.hasData) break;
        _cycle(r, engine, start, add, at);
      case ReminderKind.daily:
        for (final d in days) {
          add(r.type, at(d, r.hour, r.minute), r.type.title, _dailyBody(r.type));
        }
      case ReminderKind.interval:
        final step = r.intervalHours.clamp(1, 12);
        for (final d in days) {
          for (var h = r.startHour; h <= r.endHour && h < 24; h += step) {
            add(r.type, at(d, h, 0), 'Time for a glass of water', 'Staying hydrated helps with energy and cramps.');
          }
        }
      case ReminderKind.weekly:
        for (final d in days.where((d) => d.weekday == r.weekday)) {
          add(r.type, at(d, r.hour, r.minute), 'Log your weight', 'Step on the scale and add today\'s weight in Bloom.');
        }
      case ReminderKind.monthly:
        for (final d in days.where((d) => d.day == r.dayOfMonth)) {
          add(r.type, at(d, r.hour, r.minute), 'Monthly breast self-exam',
              'Take a few minutes to check for any changes. See a clinician if something feels different.');
        }
      case ReminderKind.contraception:
        _contraception(r, contraception, days, start, add, at);
    }
  }

  out.sort((a, b) => a.when.compareTo(b.when));
  return out;
}

typedef _Add = void Function(ReminderType t, DateTime when, String title, String body);
typedef _At = DateTime Function(DateTime d, int h, int m);

void _cycle(Reminder r, CycleEngine engine, DateTime today, _Add add, _At at) {
  final future = engine.futureCycles(3);
  switch (r.type) {
    case ReminderType.periodComing:
      for (final f in future) {
        final n = r.days;
        add(r.type, at(addDays(f.start, -n), r.hour, r.minute), 'Period coming soon',
            'Your period is expected in $n day${n == 1 ? '' : 's'}, around ${fmtShort(f.start)}.');
      }
    case ReminderType.periodStart:
      for (final f in future) {
        add(r.type, at(f.start, r.hour, r.minute), 'Period expected today',
            'Your period may start today. Log it in Bloom when it does.');
      }
    case ReminderType.periodLate:
      final next = engine.nextPeriodStart;
      if (next == null) break;
      final lateDay = addDays(next, r.days);
      if (engine.isLate && engine.daysLate >= r.days) {
        add(r.type, at(today, r.hour, r.minute), 'Your period is late',
            'Your period is ${engine.daysLate} days later than predicted. Log it if it has started.');
      } else if (lateDay.isAfter(today)) {
        add(r.type, at(lateDay, r.hour, r.minute), 'Your period is late',
            'Your period is ${r.days} days later than predicted. Log it if it has started.');
      }
    case ReminderType.fertileStart:
    case ReminderType.ovulation:
      final ovulations = <DateTime>{
        if (engine.currentCycle != null) engine.currentCycle!.ovulation,
        for (final f in future) f.ovulation,
      };
      for (final ov in ovulations) {
        if (r.type == ReminderType.ovulation) {
          add(r.type, at(ov, r.hour, r.minute), 'Predicted ovulation day', 'Today is your predicted ovulation day.');
        } else {
          add(r.type, at(addDays(ov, -5), r.hour, r.minute), 'Fertile window starts',
              'Your predicted fertile window starts today and lasts about 6 days.');
        }
      }
    default:
      break;
  }
}

String _dailyBody(ReminderType t) => switch (t) {
      ReminderType.bedtime => 'Time to wind down. A regular bedtime helps your sleep and mood.',
      ReminderType.dailyLog => 'How are you feeling today? Take a moment to log it.',
      ReminderType.meditation => 'Take a few minutes to breathe and relax.',
      _ => 'Open Bloom to see it.',
    };

void _contraception(Reminder r, Contraception c, List<DateTime> days, DateTime today, _Add add, _At at) {
  final h = c.hour, m = c.minute;
  const t = ReminderType.contraception;
  switch (c.method) {
    case BirthControlMethod.none:
      return;
    case BirthControlMethod.pill:
      for (final d in days) {
        final p = c.packDay(d);
        if (p == null) return;
        if (!p.isBreak) {
          add(t, at(d, h, m), 'Time for your pill',
              p.active ? 'Take pill ${p.dayInPack} of your pack.' : 'Take pill ${p.dayInPack} (placebo) of your pack.');
        } else if (p.dayInPack == kPackLength) {
          add(t, at(d, h, m), 'New pack tomorrow', 'Your pill-free break ends today. Start a new pack tomorrow.');
        }
        if (c.refillReminder && sameDay(d, addDays(p.nextPackStart, -c.refillDaysBefore))) {
          add(t, at(d, h, m), 'Refill your pills', 'Your next pack starts on ${fmtShort(p.nextPackStart)}.');
        }
      }
    case BirthControlMethod.ring:
      for (final d in days) {
        final n = c.ringDay(d);
        if (n == null) return;
        if (n == 1) add(t, at(d, h, m), 'Insert a new ring', 'Today is the day to insert a new ring.');
        if (n == 22) add(t, at(d, h, m), 'Remove your ring', 'Today is the day to remove your ring for the 7-day break.');
        if (c.refillReminder && n == kPackLength - c.refillDaysBefore + 1) {
          add(t, at(d, h, m), 'Refill your rings', 'You\'ll need a new ring in ${c.refillDaysBefore} days.');
        }
      }
    case BirthControlMethod.patch:
      for (final d in days) {
        final n = c.patchDay(d);
        if (n == null) return;
        if (n == 1 || n == 8 || n == 15) add(t, at(d, h, m), 'Change your patch', 'Today is the day to apply a new patch.');
        if (n == 22) add(t, at(d, h, m), 'Remove your patch', 'Remove your patch today for the patch-free week.');
        if (c.refillReminder && n == kPackLength - c.refillDaysBefore + 1) {
          add(t, at(d, h, m), 'Refill your patches', 'You\'ll start a new box of patches in ${c.refillDaysBefore} days.');
        }
      }
    case BirthControlMethod.injection:
      final next = c.nextInjection;
      if (next == null) return;
      if (next.isBefore(today)) {
        add(t, at(today, h, m), 'Injection overdue', 'Your birth control injection was due on ${fmtShort(next)}.');
      } else {
        add(t, at(addDays(next, -7), h, m), 'Injection due next week', 'Book your next injection for ${fmtShort(next)}.');
        add(t, at(next, h, m), 'Injection due today', 'Your next birth control injection is due today.');
      }
    case BirthControlMethod.iud:
    case BirthControlMethod.implant:
      final exp = c.expiryDate;
      if (exp == null) return;
      final name = c.method.label;
      add(t, at(addDays(exp, -30), h, m), '$name expires next month',
          'Your $name should be replaced by ${fmtShort(exp)}. Contact your clinic.');
      add(t, at(exp, h, m), '$name expires today', 'Your $name has reached its replacement date.');
  }
}

/// Notification title and body for [o] at the chosen privacy level.
(String, String) notificationText(ReminderOccurrence o, NotificationPrivacy privacy) {
  switch (privacy) {
    case NotificationPrivacy.detailed:
      return (o.title, o.body);
    case NotificationPrivacy.minimal:
      final sensitive = o.type.isCycle || o.type == ReminderType.contraception || o.type == ReminderType.breastExam;
      return sensitive ? ('Bloom', 'You have a health update. Open Bloom to see it.') : ('Bloom', o.type.title);
    case NotificationPrivacy.private:
      return ('Bloom', 'You have a reminder from Bloom');
  }
}

/// Example notification text shown in the privacy settings.
String privacyExample(NotificationPrivacy p) => switch (p) {
      NotificationPrivacy.detailed => 'Period coming soon: Your period is expected in 2 days, around Mar 14.',
      NotificationPrivacy.minimal => 'Bloom: You have a health update. Open Bloom to see it.',
      NotificationPrivacy.private => 'Bloom: You have a reminder from Bloom',
    };
