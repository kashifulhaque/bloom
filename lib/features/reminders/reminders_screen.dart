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

/// The badge color for a reminder category.
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
        title: 'Reminders',
        subtitle: kIsWeb
            ? 'In the browser, due reminders appear on the Today screen. On Android, they arrive as notifications.'
            : 'Reminders arrive as notifications. Bloom schedules them on this device only.',
        children: [
          _UpNext(upcoming: upcoming, enabledCount: on),
          MenuSection(
            children: [
              MenuTile(
                icon: Icons.visibility_off_rounded,
                color: BloomColors.brand,
                title: 'Notification privacy',
                value: _privacyLabel(store.profile.notificationPrivacy),
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPrivacyScreen())),
              ),
            ],
          ),
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
              MenuTile(
                emoji: contraception.method.emoji,
                color: BloomColors.luteal,
                title: 'Method: ${contraception.method.label}',
                subtitle: contraception.status(DateTime.now()),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContraceptionScreen())),
              ),
            ],
          ),
          MenuSection(
            title: 'Wellness',
            children: [for (final t in _wellnessTypes) _ReminderTile(type: t, settings: settings)],
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

/// The hero: the next few reminders, or an empty state.
class _UpNext extends StatelessWidget {
  const _UpNext({required this.upcoming, required this.enabledCount});
  final List<ReminderOccurrence> upcoming;
  final int enabledCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (upcoming.isEmpty) {
      return BloomCard(
        child: EmptyState(
          compact: true,
          icon: Icons.notifications_none_rounded,
          title: enabledCount == 0 ? 'No reminders yet' : 'Nothing in the next week',
          body: enabledCount == 0
              ? 'Turn on a reminder below for a gentle nudge before your period, for your pill, or to drink water.'
              : 'Your reminders will show up here when they\'re coming up.',
        ),
      );
    }
    final next = upcoming.first;
    final white70 = Colors.white.withValues(alpha: 0.82);
    String when(DateTime d) {
      final day = dayOf(d);
      final t = today();
      final label = sameDay(day, t)
          ? 'Today'
          : sameDay(day, addDays(t, 1))
          ? 'Tomorrow'
          : DateFormat('EEE, MMM d').format(d);
      return '$label · ${fmtTimeOfDay(d.hour, d.minute)}';
    }

    return BloomCard.gradient(
      gradient: BloomGradients.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PillChip('Up next', solid: true, icon: Icons.notifications_active_rounded, color: Colors.white),
              const Spacer(),
              Text('$enabledCount on', style: theme.textTheme.labelLarge!.copyWith(color: white70)),
            ],
          ),
          Gap.v16,
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: Radii.mdAll),
                child: Text(next.type.emoji, style: const TextStyle(fontSize: 26)),
              ),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(next.title, style: theme.textTheme.titleLarge!.copyWith(color: Colors.white)),
                    Gap.v4,
                    Text(when(next.when), style: theme.textTheme.bodyMedium!.copyWith(color: white70)),
                  ],
                ),
              ),
            ],
          ),
          if (upcoming.length > 1) ...[
            Gap.v16,
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.25)),
            Gap.v8,
            for (final o in upcoming.skip(1))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(
                  children: [
                    SizedBox(width: 28, child: Text(o.type.emoji, style: const TextStyle(fontSize: 16))),
                    Expanded(
                      child: Text(
                        o.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Gap.h8,
                    Text(when(o.when), style: theme.textTheme.bodySmall!.copyWith(color: white70)),
                  ],
                ),
              ),
          ],
        ],
      ),
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

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.type, required this.settings, this.contraception});
  final ReminderType type;
  final ReminderSettings settings;
  final Contraception? contraception;

  @override
  Widget build(BuildContext context) {
    final r = settings[type];
    return MenuTile(
      emoji: type.emoji,
      color: reminderColor(type),
      title: type.title,
      subtitle: r.enabled ? reminderSchedule(r, contraception: contraception) : type.description,
      onTap: () => type.kind == ReminderKind.contraception
          ? Navigator.push(context, MaterialPageRoute(builder: (_) => const ContraceptionScreen()))
          : showReminderEditor(context, type),
      trailing: Switch(
        value: r.enabled,
        onChanged: (v) {
          r.enabled = v;
          saveReminders(context, settings, askPermission: v);
        },
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
    final tokens = BloomTokens.of(context);
    final color = reminderColor(type);

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
          color: color,
          onChanged: (v) => update((r) => r.intervalHours = v),
        ),
        StepperTile(
          title: 'From',
          value: r.startHour,
          min: 5,
          max: r.endHour,
          display: _hour,
          color: color,
          onChanged: (v) => update((r) => r.startHour = v),
        ),
        StepperTile(
          title: 'Until',
          value: r.endHour,
          min: r.startHour,
          max: 23,
          display: _hour,
          color: color,
          onChanged: (v) => update((r) => r.endHour = v),
        ),
      ] else
        MenuTile(
          icon: Icons.schedule_rounded,
          color: color,
          title: 'Time',
          value: fmtTimeOfDay(r.hour, r.minute),
          onTap: pickTime,
        ),
      if (type == ReminderType.periodComing || type == ReminderType.periodLate)
        StepperTile(
          title: type == ReminderType.periodComing ? 'Days before' : 'Days after predicted start',
          value: r.days,
          min: 1,
          max: type == ReminderType.periodComing ? 7 : 10,
          color: color,
          onChanged: (v) => update((r) => r.days = v),
        ),
      if (type.kind == ReminderKind.monthly)
        StepperTile(
          title: 'Day of the month',
          value: r.dayOfMonth,
          min: 1,
          max: 28,
          suffix: '',
          color: color,
          onChanged: (v) => update((r) => r.dayOfMonth = v),
        ),
    ];

    return AppBottomSheet(
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(emoji: type.emoji, color: color, size: 52),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.title, style: theme.textTheme.headlineSmall),
                    Gap.v4,
                    Text(type.description, style: theme.textTheme.bodyMedium!.copyWith(color: tokens.muted)),
                  ],
                ),
              ),
            ],
          ),
          Gap.v20,
          MenuSection(
            children: [
              MenuTile.toggle(
                icon: Icons.notifications_active_rounded,
                color: color,
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
                    padding: const EdgeInsets.only(top: Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MenuSection(title: 'Schedule', children: controls),
                        if (type.kind == ReminderKind.weekly) ...[
                          Gap.v16,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                            child: Text(
                              'DAY',
                              style: theme.textTheme.labelMedium!.copyWith(color: tokens.muted, letterSpacing: 1),
                            ),
                          ),
                          Gap.v8,
                          Wrap(
                            spacing: Space.sm,
                            runSpacing: Space.sm,
                            children: [
                              for (var d = 1; d <= 7; d++)
                                SelectChip(
                                  label: DateFormat('EEE').format(DateTime(2024, 1, d)),
                                  selected: r.weekday == d,
                                  color: color,
                                  showCheck: false,
                                  onSelected: (_) => update((r) => r.weekday = d),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
