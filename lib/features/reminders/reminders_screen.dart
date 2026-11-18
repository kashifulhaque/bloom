/// Reminder settings: cycle, birth control, and wellness reminders.
library;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../settings/notification_privacy_screen.dart';
import '../../widgets/widgets.dart';
import '../settings/settings_widgets.dart';
import 'contraception_model.dart';
import 'contraception_screen.dart';
import 'notification_service.dart';
import 'reminder_model.dart';
import 'scheduler.dart';

/// The meaning color of a reminder: oxblood for period reminders, sage for
/// fertility. Screens draw it only as a small dot beside cycle reminders.
Color reminderColor(ReminderType t) => switch (t.kind) {
  ReminderKind.cycle => switch (t) {
    ReminderType.fertileStart || ReminderType.ovulation => BloomColors.fertile,
    _ => BloomColors.period,
  },
  ReminderKind.contraception => BloomColors.luteal,
  _ => BloomColors.info,
};

String _hour(int h) => fmtTimeOfDay(h, 0).replaceFirst(':00', '');

/// A one-line summary of when [r] fires, for example "2 days before · 9:00 AM".
String reminderSchedule(Reminder r, {Contraception? contraception}) {
  final time = fmtTimeOfDay(r.hour, r.minute);
  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';
  return switch (r.type.kind) {
    ReminderKind.cycle => switch (r.type) {
      ReminderType.periodComing => '${plural(r.days, 'day')} before · $time',
      ReminderType.periodLate => '${plural(r.days, 'day')} after · $time',
      _ => 'On the day · $time',
    },
    ReminderKind.daily => 'Every day · $time',
    ReminderKind.interval => 'Every ${r.intervalHours} h · ${_hour(r.startHour)} to ${_hour(r.endHour)}',
    ReminderKind.weekly => 'Every ${DateFormat('EEEE').format(DateTime(2024, 1, r.weekday))} · $time',
    ReminderKind.monthly => 'Day ${r.dayOfMonth} of each month · $time',
    ReminderKind.contraception =>
      contraception == null || contraception.method == BirthControlMethod.none
          ? 'Choose a method first'
          : '${contraception.method.label} · ${fmtTimeOfDay(contraception.hour, contraception.minute)}',
  };
}

/// What the reminder follows, without the time: "2 days before your
/// period", "every Friday". The schedule column shows the time.
String reminderCadence(Reminder r, {Contraception? contraception}) {
  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';
  return switch (r.type.kind) {
    ReminderKind.cycle => switch (r.type) {
      ReminderType.periodComing => '${plural(r.days, 'day')} before your period',
      ReminderType.periodLate => '${plural(r.days, 'day')} after the predicted start',
      ReminderType.periodStart => 'on the predicted first day',
      ReminderType.fertileStart => 'as the fertile window opens',
      _ => 'on the predicted ovulation day',
    },
    ReminderKind.daily => 'every day',
    ReminderKind.interval => 'every ${plural(r.intervalHours, 'hour')} until ${_hour(r.endHour)}',
    ReminderKind.weekly => 'every ${DateFormat('EEEE').format(DateTime(2024, 1, r.weekday))}',
    ReminderKind.monthly => 'on day ${r.dayOfMonth} of each month',
    ReminderKind.contraception =>
      contraception == null || contraception.method == BirthControlMethod.none
          ? 'choose a method first'
          : contraception.method.label.toLowerCase(),
  };
}

/// The time shown in the schedule column for [r].
String _scheduleTime(Reminder r, Contraception? contraception) => switch (r.type.kind) {
  ReminderKind.interval => _hour(r.startHour),
  ReminderKind.contraception =>
    contraception == null || contraception.method == BirthControlMethod.none
        ? '—'
        : fmtTimeOfDay(contraception.hour, contraception.minute),
  _ => fmtTimeOfDay(r.hour, r.minute),
};

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  static const _cycleTypes = [
    ReminderType.periodComing,
    ReminderType.periodStart,
    ReminderType.periodLate,
    ReminderType.fertileStart,
    ReminderType.ovulation,
  ];
  static const _wellnessTypes = [
    ReminderType.water,
    ReminderType.bedtime,
    ReminderType.dailyLog,
    ReminderType.weight,
    ReminderType.meditation,
    ReminderType.breastExam,
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final settings = ReminderSettings.of(store);
    final contraception = Contraception.of(store);
    final pregnant = store.profile.goal == Goal.trackPregnancy;
    final occurrences = computeOccurrences(
      settings: settings,
      contraception: contraception,
      engine: store.engine,
      goal: store.profile.goal,
      now: DateTime.now(),
      horizonDays: 7,
    ).where((o) => o.when.isAfter(DateTime.now()));
    // The next occurrence of each reminder, so frequent ones don't crowd out the rest.
    final seen = <ReminderType>{};
    final upcoming = [
      for (final o in occurrences)
        if (seen.add(o.type)) o,
    ].take(4).toList();
    final on = settings.enabled.length;

    return Scaffold(
      body: BloomPage(
        eyebrow: on == 0 ? 'None set' : '$on on',
        title: 'Reminders',
        subtitle: kIsWeb
            ? 'In the browser, due reminders appear on the Today page. On Android, they arrive as notifications.'
            : 'Reminders arrive as notifications. Bloom schedules them on this device only.',
        spacing: Space.xxl,
        children: [
          _UpNext(upcoming: upcoming, enabledCount: on),
          MenuSection(
            title: 'Cycle',
            footer: pregnant
                ? 'Cycle reminders are paused in pregnancy mode.'
                : !store.engine.hasData
                ? 'Log a period so Bloom can predict when to remind you.'
                : null,
            children: [for (final t in _cycleTypes) _ReminderTile(type: t, settings: settings)],
          ),
          MenuSection(
            title: 'Birth control',
            children: [
              _ReminderTile(type: ReminderType.contraception, settings: settings, contraception: contraception),
              IndexEntry(
                title: 'Method',
                subtitle: contraception.status(DateTime.now()),
                value: contraception.method.label,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContraceptionScreen())),
              ),
            ],
          ),
          MenuSection(
            title: 'Wellness',
            children: [for (final t in _wellnessTypes) _ReminderTile(type: t, settings: settings)],
          ),
          MenuSection(
            title: 'Privacy',
            children: [
              IndexEntry(
                title: 'Notification privacy',
                subtitle: 'What a notification shows on the lock screen',
                value: _privacyLabel(store.profile.notificationPrivacy),
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPrivacyScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _privacyLabel(NotificationPrivacy p) => switch (p) {
    NotificationPrivacy.detailed => 'Detailed',
    NotificationPrivacy.minimal => 'Minimal',
    NotificationPrivacy.private => 'Private',
  };
}

/// A small dot for reminders that follow the cycle (oxblood for the period,
/// sage for fertility). Other reminders have none.
Widget? _meaningDot(BuildContext context, ReminderType t) {
  if (t.kind != ReminderKind.cycle) return null;
  return Container(
    width: 6,
    height: 6,
    margin: const EdgeInsets.only(right: Space.sm),
    decoration: BoxDecoration(color: BloomColors.resolve(context, reminderColor(t)), shape: BoxShape.circle),
  );
}

/// The hero: the week ahead as an almanac schedule, or an empty state.
class _UpNext extends StatelessWidget {
  const _UpNext({required this.upcoming, required this.enabledCount});
  final List<ReminderOccurrence> upcoming;
  final int enabledCount;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    if (upcoming.isEmpty) {
      return BloomCard(
        child: EmptyState(
          compact: true,
          glyph: Botanical.sprig,
          title: enabledCount == 0 ? 'No reminders yet' : 'Nothing in the next week',
          body: enabledCount == 0
              ? 'Turn on a reminder below for a gentle nudge before your period, for your pill, or to drink water.'
              : 'Your reminders will show up here when they\'re coming up.',
        ),
      );
    }
    String day(DateTime d) {
      final t = today();
      final dd = dayOf(d);
      if (sameDay(dd, t)) return 'Today';
      if (sameDay(dd, addDays(t, 1))) return 'Tomorrow';
      return DateFormat('EEE d').format(d);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MonoLabel('The week ahead'),
        Gap.v8,
        for (var i = 0; i < upcoming.length; i++) ...[
          const Hairline(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: i == 0 ? Space.lg : Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84,
                  child: Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 6 : 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MonoLabel(day(upcoming[i].when), color: i == 0 ? p.ink : null),
                        Gap.v4,
                        Text(
                          fmtTimeOfDay(upcoming[i].when.hour, upcoming[i].when.minute),
                          style: Almanac.data(context, size: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ?_meaningDot(context, upcoming[i].type),
                          Flexible(
                            child: Text(
                              upcoming[i].title,
                              style: Almanac.serif(size: i == 0 ? 26 : 18, weight: i == 0 ? 350 : 380, color: p.ink, height: 1.15),
                            ),
                          ),
                        ],
                      ),
                      Gap.v4,
                      Text(
                        upcoming[i].body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Almanac.italic(context, size: i == 0 ? 16 : 14.5, color: p.ink2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const Hairline(),
      ],
    );
  }
}

/// Saves [settings] and reschedules notifications on Android.
Future<void> saveReminders(BuildContext context, ReminderSettings settings, {bool askPermission = false}) async {
  final store = context.read<AppStore>();
  settings.save(store);
  if (askPermission && NotificationService.supported) {
    final ok = await NotificationService.requestPermission();
    if (!ok && context.mounted) {
      showSnack(context, 'Notifications are off for Bloom. Turn them on in system settings.');
    }
  }
  await NotificationService.sync(store);
}

/// One line of the schedule: a mono time in the margin, the reminder name
/// in Fraunces, an italic cadence, and a switch.
class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.type, required this.settings, this.contraception});
  final ReminderType type;
  final ReminderSettings settings;
  final Contraception? contraception;

  @override
  Widget build(BuildContext context) {
    final r = settings[type];
    final p = BloomColors.of(context);
    final theme = Theme.of(context);
    final on = r.enabled;
    return Pressable(
      onTap: () => type.kind == ReminderKind.contraception
          ? Navigator.push(context, MaterialPageRoute(builder: (_) => const ContraceptionScreen()))
          : showReminderEditor(context, type),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 72,
                child: AnimatedDefaultTextStyle(
                  duration: Motion.medium,
                  style: Almanac.data(context, size: 12, color: on ? p.ink : p.ink2.withValues(alpha: 0.55)),
                  child: Text(_scheduleTime(r, contraception)),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ?_meaningDot(context, type),
                        Flexible(
                          child: Text(type.title, style: Almanac.serif(size: 18, weight: 380, color: p.ink, height: 1.2)),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: on
                          ? Text(
                              reminderCadence(r, contraception: contraception),
                              style: Almanac.italic(context, size: 14.5, color: p.ink2),
                            )
                          : Text(type.description, style: theme.textTheme.bodySmall!.copyWith(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Gap.h8,
              InkSwitch(
                value: on,
                semanticLabel: type.title,
                onChanged: (v) {
                  r.enabled = v;
                  saveReminders(context, settings, askPermission: v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the bottom sheet that edits one reminder's schedule.
Future<void> showReminderEditor(BuildContext context, ReminderType type) =>
    showAppBottomSheet<void>(context, builder: (_) => ReminderEditorSheet(type: type));

/// The reminder editor shown by [showReminderEditor].
class ReminderEditorSheet extends StatelessWidget {
  const ReminderEditorSheet({super.key, required this.type});
  final ReminderType type;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final settings = ReminderSettings.of(store);
    final r = settings[type];
    final theme = Theme.of(context);

    void update(void Function(Reminder r) change, {bool ask = false}) {
      change(r);
      saveReminders(context, settings, askPermission: ask);
    }

    Future<void> pickTime() async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
      );
      if (t != null && context.mounted) {
        update((r) {
          r.hour = t.hour;
          r.minute = t.minute;
        });
      }
    }

    final controls = <Widget>[
      if (type.kind == ReminderKind.interval) ...[
        StepperTile(
          title: 'Every',
          value: r.intervalHours,
          min: 1,
          max: 6,
          display: (v) => '$v h',
          onChanged: (v) => update((r) => r.intervalHours = v),
        ),
        StepperTile(
          title: 'From',
          value: r.startHour,
          min: 5,
          max: r.endHour,
          display: _hour,
          onChanged: (v) => update((r) => r.startHour = v),
        ),
        StepperTile(
          title: 'Until',
          value: r.endHour,
          min: r.startHour,
          max: 23,
          display: _hour,
          onChanged: (v) => update((r) => r.endHour = v),
        ),
      ] else
        MenuTile(title: 'Time', value: fmtTimeOfDay(r.hour, r.minute), onTap: pickTime),
      if (type == ReminderType.periodComing || type == ReminderType.periodLate)
        StepperTile(
          title: type == ReminderType.periodComing ? 'Days before' : 'Days after predicted start',
          value: r.days,
          min: 1,
          max: type == ReminderType.periodComing ? 7 : 10,
          onChanged: (v) => update((r) => r.days = v),
        ),
      if (type.kind == ReminderKind.monthly)
        StepperTile(
          title: 'Day of the month',
          value: r.dayOfMonth,
          min: 1,
          max: 28,
          suffix: '',
          onChanged: (v) => update((r) => r.dayOfMonth = v),
        ),
      if (type.kind == ReminderKind.weekly)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text('Day', style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w500)),
              ),
              TextChoices<int>(
                spacing: Space.md,
                options: [
                  for (var d = 1; d <= 7; d++)
                    TextChoice(
                      d,
                      DateFormat('EEE').format(DateTime(2024, 1, d)),
                      semanticLabel: DateFormat('EEEE').format(DateTime(2024, 1, d)),
                    ),
                ],
                selected: r.weekday,
                onChanged: (d) => update((r) => r.weekday = d),
              ),
            ],
          ),
        ),
    ];

    return AppBottomSheet(
      eyebrow: switch (type.kind) {
        ReminderKind.cycle => 'Cycle reminder',
        ReminderKind.contraception => 'Birth control',
        _ => 'Wellness reminder',
      },
      title: type.title,
      subtitle: type.description,
      actions: [InkButton(label: 'Done', onPressed: () => Navigator.pop(context))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuSection(
            children: [
              MenuTile.toggle(
                title: 'Remind me',
                subtitle: r.enabled ? reminderSchedule(r) : 'Off',
                value: r.enabled,
                onChanged: (v) => update((r) => r.enabled = v, ask: v),
              ),
            ],
          ),
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: r.enabled
                ? Padding(
                    padding: const EdgeInsets.only(top: Space.xxl),
                    child: MenuSection(title: 'Schedule', children: controls),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
