/// Birth control setup: method, pill pack, dates, reminder time, and a pill
/// pack grid that logs taken or missed pills.
library;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../settings/settings_widgets.dart';
import 'contraception_model.dart';
import 'reminder_model.dart';
import 'reminders_screen.dart';

class ContraceptionScreen extends StatefulWidget {
  const ContraceptionScreen({super.key});

  @override
  State<ContraceptionScreen> createState() => _ContraceptionScreenState();
}

class _ContraceptionScreenState extends State<ContraceptionScreen> {
  /// Pack offset from the current pack shown in the grid (0 = current).
  int _packOffset = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = Contraception.of(store);
    final reminders = ReminderSettings.of(store);
    final now = today();

    void update(void Function(Contraception c) change) {
      change(c);
      c.save(store);
      saveReminders(context, reminders);
    }

    Future<void> pickDate() async {
      final d = await showDatePicker(
        context: context,
        initialDate: c.startDate ?? now,
        firstDate: DateTime(now.year - 12),
        lastDate: addDays(now, 60),
      );
      if (d != null) update((c) => c.startDate = dayOf(d));
    }

    Future<void> pickTime() async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: c.hour, minute: c.minute),
      );
      if (t != null) {
        update((c) {
          c.hour = t.hour;
          c.minute = t.minute;
        });
      }
    }

    final m = c.method;
    final hasRefill = m == BirthControlMethod.pill || m == BirthControlMethod.ring || m == BirthControlMethod.patch;
    final remindOn = reminders[ReminderType.contraception].enabled;
    return Scaffold(
      body: BloomPage(
        title: 'Birth control',
        subtitle: 'Reminders and a pill tracker',
        children: [
          AnimatedSwitcher(
            duration: Motion.medium,
            child: m == BirthControlMethod.none
                ? const BloomCard(
                    key: ValueKey('none'),
                    child: EmptyState(
                      compact: true,
                      emoji: '💊',
                      color: BloomColors.luteal,
                      title: 'No method set',
                      body: 'Choose your method below to get reminders and track your pills.',
                    ),
                  )
                : _TodayHero(key: ValueKey(m), contraception: c),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader('Method'),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final method in BirthControlMethod.values)
                    SelectChip(
                      emoji: method == BirthControlMethod.none ? null : method.emoji,
                      icon: method == BirthControlMethod.none ? Icons.block_rounded : null,
                      label: method.label,
                      color: BloomColors.luteal,
                      selected: m == method,
                      onSelected: (_) => update((c) => c.method = method),
                    ),
                ],
              ),
            ],
          ),
          if (m == BirthControlMethod.pill && c.startDate != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader('Pill pack', subtitle: 'Tap a pill to mark it taken. Long-press for more.'),
                _PackGrid(contraception: c, packOffset: _packOffset, onOffset: (o) => setState(() => _packOffset = o)),
              ],
            ),
          if (m != BirthControlMethod.none) ...[
            MenuSection(
              title: 'Schedule',
              children: [
                if (m == BirthControlMethod.pill)
                  MenuTile(
                    icon: Icons.grid_view_rounded,
                    color: BloomColors.luteal,
                    title: 'Pack type',
                    subtitle: c.pack.label,
                    onTap: () async {
                      final p = await showAppBottomSheet<PillPack>(
                        context,
                        builder: (ctx) => AppBottomSheet(
                          title: 'Pack type',
                          child: MenuSection(
                            children: [
                              for (final p in PillPack.values)
                                MenuTile(
                                  title: p.label,
                                  trailing: p == c.pack
                                      ? Icon(Icons.check_circle_rounded, color: Theme.of(ctx).colorScheme.primary)
                                      : null,
                                  onTap: () => Navigator.pop(ctx, p),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (p != null) update((c) => c.pack = p);
                    },
                  ),
                MenuTile(
                  icon: Icons.event_rounded,
                  color: BloomColors.info,
                  title: m.startLabel,
                  value: c.startDate == null ? 'Set date' : fmtFull(c.startDate!),
                  onTap: pickDate,
                ),
                if (m == BirthControlMethod.pill)
                  MenuTile(
                    icon: Icons.restart_alt_rounded,
                    color: BloomColors.fertile,
                    title: 'Started a new pack today',
                    showChevron: false,
                    onTap: () => update((c) => c.startDate = now),
                  ),
                if (m == BirthControlMethod.injection)
                  StepperTile(
                    icon: Icons.vaccines_rounded,
                    color: BloomColors.luteal,
                    title: 'Weeks between',
                    value: c.injectionWeeks,
                    min: 8,
                    max: 13,
                    suffix: 'wk',
                    onChanged: (v) => update((c) => c.injectionWeeks = v),
                  ),
                if (m == BirthControlMethod.iud || m == BirthControlMethod.implant)
                  StepperTile(
                    icon: Icons.hourglass_bottom_rounded,
                    color: BloomColors.luteal,
                    title: 'Lasts',
                    subtitle: 'Check your device\'s approved lifetime with your clinic.',
                    value: c.effectiveExpiryYears,
                    min: 1,
                    max: 12,
                    suffix: 'yr',
                    onChanged: (v) => update((c) => c.expiryYears = v),
                  ),
              ],
            ),
            MenuSection(
              title: 'Reminders',
              children: [
                MenuTile.toggle(
                  icon: Icons.notifications_active_rounded,
                  color: BloomColors.warning,
                  title: 'Remind me',
                  subtitle: _reminderHint(m),
                  value: remindOn,
                  onChanged: (v) {
                    reminders[ReminderType.contraception].enabled = v;
                    saveReminders(context, reminders, askPermission: v);
                  },
                ),
                MenuTile(
                  icon: Icons.schedule_rounded,
                  color: BloomColors.info,
                  title: 'Reminder time',
                  value: fmtTimeOfDay(c.hour, c.minute),
                  onTap: pickTime,
                ),
                if (hasRefill)
                  MenuTile.toggle(
                    icon: Icons.local_pharmacy_rounded,
                    color: BloomColors.fertile,
                    title: 'Refill reminder',
                    value: c.refillReminder,
                    onChanged: (v) => update((c) => c.refillReminder = v),
                  ),
                if (hasRefill && c.refillReminder)
                  StepperTile(
                    title: 'Days before next pack',
                    value: c.refillDaysBefore,
                    min: 1,
                    max: 14,
                    color: BloomColors.fertile,
                    onChanged: (v) => update((c) => c.refillDaysBefore = v),
                  ),
              ],
            ),
            if (m == BirthControlMethod.ring || m == BirthControlMethod.patch)
              InfoBanner(
                tone: BannerTone.info,
                title: 'How it works',
                message: m == BirthControlMethod.ring
                    ? 'A typical schedule: the ring stays in for 3 weeks, then comes out for a 1-week break. '
                          'Bloom reminds you on insert and remove days.'
                    : 'A typical schedule: a new patch each week for 3 weeks, then a patch-free week. '
                          'Bloom reminds you on change and remove days.',
              ),
          ],
          const Disclaimer(
            text:
                'Bloom helps you remember; it isn\'t medical advice. Follow your prescriber\'s and leaflet\'s '
                'instructions, especially for missed doses, and ask a clinician if you\'re unsure.',
          ),
        ],
      ),
    );
  }

  static String _reminderHint(BirthControlMethod m) => switch (m) {
    BirthControlMethod.pill => 'Every day at your pill time',
    BirthControlMethod.ring => 'On ring insert and remove days',
    BirthControlMethod.patch => 'On patch change days',
    BirthControlMethod.injection => 'A week before and on your injection date',
    BirthControlMethod.iud || BirthControlMethod.implant => 'A month before and on the replacement date',
    BirthControlMethod.none => '',
  };
}

/// The hero: today's status, with a one-tap "taken" action for pills.
class _TodayHero extends StatelessWidget {
  const _TodayHero({super.key, required this.contraception});
  final Contraception contraception;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final c = contraception;
    final now = today();
    final pd = c.method == BirthControlMethod.pill ? c.packDay(now) : null;
    final pillDue = pd != null && !pd.isBreak;
    final state = store.logFor(now).get('pill').firstOrNull;
    final taken = state == 'taken' || state == 'double' || state == 'late';
    final white = Colors.white.withValues(alpha: 0.85);
    return BloomCard.gradient(
      gradient: BloomGradients.luteal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: Radii.mdAll),
                child: Text(c.method.emoji, style: const TextStyle(fontSize: 28)),
              ),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TODAY', style: theme.textTheme.labelMedium!.copyWith(color: white, letterSpacing: 1)),
                    Gap.v4,
                    Text(c.status(now), style: theme.textTheme.titleLarge!.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          if (pillDue) ...[
            Gap.v16,
            AnimatedSwitcher(
              duration: Motion.medium,
              child: taken
                  ? Row(
                      key: const ValueKey('taken'),
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white),
                        Gap.h8,
                        Text(
                          state == 'late' ? 'Taken late today' : 'Today\'s pill is taken',
                          style: theme.textTheme.titleSmall!.copyWith(color: Colors.white),
                        ),
                      ],
                    )
                  : SizedBox(
                      key: const ValueKey('take'),
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: readableTint(BloomColors.luteal, Brightness.light),
                        ),
                        onPressed: () => store.toggleOption(now, 'pill', 'taken', single: true),
                        icon: const Icon(Icons.check_rounded),
                        label: Text('I took pill ${pd.dayInPack}'),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A 28-pill blister pack, one row per week.
class _PackGrid extends StatelessWidget {
  const _PackGrid({required this.contraception, required this.packOffset, required this.onOffset});
  final Contraception contraception;
  final int packOffset;
  final ValueChanged<int> onOffset;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final dark = theme.brightness == Brightness.dark;
    final now = today();
    final current = contraception.packDay(now)!;
    final packStart = addDays(current.packStart, packOffset * kPackLength);
    final pack = contraception.pack;
    var taken = 0;
    for (var i = 0; i < pack.activeDays; i++) {
      final st = store.logFor(addDays(packStart, i)).get('pill').firstOrNull;
      if (st != null && st != 'missed') taken++;
    }

    return BloomCard(
      padding: Insets.cardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous pack',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => onOffset(packOffset - 1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      packOffset == 0
                          ? 'Current pack'
                          : packOffset > 0
                          ? 'Next pack'
                          : 'Earlier pack',
                      style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${fmtShort(packStart)} - ${fmtShort(addDays(packStart, kPackLength - 1))} · $taken of ${pack.activeDays} taken',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next pack',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: packOffset < 1 ? () => onOffset(packOffset + 1) : null,
              ),
            ],
          ),
          Gap.v12,
          // The foil sheet.
          Container(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
            decoration: BoxDecoration(
              borderRadius: Radii.lgAll,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [theme.colorScheme.surfaceContainerHigh, theme.colorScheme.surfaceContainerHighest]
                    : [theme.colorScheme.surfaceContainerLow, theme.colorScheme.surfaceContainerHigh],
              ),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Center(
                          child: Text(
                            DateFormat('EEE').format(addDays(packStart, i)).substring(0, 2),
                            style: theme.textTheme.labelSmall!.copyWith(color: tokens.muted),
                          ),
                        ),
                      ),
                  ],
                ),
                Gap.v4,
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Space.sm,
                  crossAxisSpacing: Space.xs,
                  childAspectRatio: 0.82,
                  children: [
                    for (var i = 0; i < kPackLength; i++)
                      _PillCell(
                        number: i + 1,
                        date: addDays(packStart, i),
                        active: i < pack.activeDays,
                        isBreak: i >= pack.activeDays && pack.hasBreak,
                        state: store.logFor(addDays(packStart, i)).get('pill').firstOrNull,
                        isToday: sameDay(addDays(packStart, i), now),
                        isFuture: addDays(packStart, i).isAfter(now),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Gap.v12,
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.md,
            runSpacing: Space.xs,
            children: [
              _legend(context, _PillCell.takenColor(context), 'Taken', icon: Icons.check_rounded),
              _legend(context, BloomColors.warning, 'Late', icon: Icons.schedule_rounded),
              _legend(context, theme.colorScheme.error, 'Missed', icon: Icons.close_rounded),
              _legend(context, _PillCell.activeColor, 'Active'),
              _legend(context, _PillCell.placeboColor(context), pack.hasBreak ? 'Break' : 'Placebo'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label, {IconData? icon}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: BloomTokens.of(context).border),
        ),
        child: icon == null ? null : Icon(icon, size: 10, color: BloomColors.onColor(color)),
      ),
      Gap.h4,
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _PillCell extends StatelessWidget {
  const _PillCell({
    required this.number,
    required this.date,
    required this.active,
    required this.isBreak,
    required this.state,
    required this.isToday,
    required this.isFuture,
  });
  final int number;
  final DateTime date;
  final bool active;
  final bool isBreak;
  final String? state;
  final bool isToday;
  final bool isFuture;

  static const activeColor = BloomColors.luteal;
  static Color takenColor(BuildContext context) => BloomColors.success;
  static Color placeboColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.outline : Colors.white;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final store = context.read<AppStore>();
    final base = switch (state) {
      'taken' || 'double' => takenColor(context),
      'late' => BloomColors.warning,
      'missed' => theme.colorScheme.error,
      _ => active ? activeColor : placeboColor(context),
    };
    final logged = state != null;
    // Future pills look softer; pills already pushed out look like empty foil.
    final fill = isBreak
        ? Colors.transparent
        : (isFuture && !logged ? base.withValues(alpha: active ? 0.45 : 0.6) : base);
    final fg = isBreak
        ? tokens.muted
        : isFuture && !logged
        ? readableTint(base, theme.brightness)
        : BloomColors.onColor(fill);
    final icon = switch (state) {
      'taken' => Icons.check_rounded,
      'double' => Icons.done_all_rounded,
      'late' => Icons.schedule_rounded,
      'missed' => Icons.close_rounded,
      _ => null,
    };

    Future<void> chooseState() async {
      final v = await showAppBottomSheet<String>(
        context,
        builder: (ctx) => AppBottomSheet(
          title: 'Pill $number',
          subtitle: fmtLong(date),
          child: MenuSection(
            children: [
              for (final (id, text, ic, color) in [
                ('taken', 'Taken on time', Icons.check_rounded, BloomColors.success),
                ('late', 'Taken late', Icons.schedule_rounded, BloomColors.warning),
                ('missed', 'Missed', Icons.close_rounded, theme.colorScheme.error),
                ('double', 'Double dose', Icons.done_all_rounded, BloomColors.info),
              ])
                MenuTile(
                  icon: ic,
                  color: color,
                  title: text,
                  trailing: state == id ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
                  onTap: () => Navigator.pop(ctx, id),
                ),
            ],
          ),
        ),
      );
      if (v != null) store.toggleOption(date, 'pill', v, single: true);
    }

    final enabled = !isFuture && !isBreak;
    return Semantics(
      button: enabled,
      label: 'Pill $number, ${fmtShort(date)}${state == null ? '' : ', $state'}${isToday ? ', today' : ''}',
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.curve,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // The blister cavity, with a ring for today.
              color: isToday
                  ? Colors.transparent
                  : (theme.brightness == Brightness.dark ? Colors.black26 : Colors.white70),
              border: isToday ? Border.all(color: theme.colorScheme.primary, width: 2.5) : null,
            ),
            child: Material(
              shape: CircleBorder(
                side: isBreak
                    ? BorderSide(color: tokens.muted.withValues(alpha: 0.4), width: 1.2)
                    : (!active && !logged ? BorderSide(color: tokens.border) : BorderSide.none),
              ),
              clipBehavior: Clip.antiAlias,
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isBreak
                      ? null
                      : RadialGradient(
                          center: const Alignment(-0.35, -0.45),
                          radius: 0.95,
                          colors: [Color.lerp(fill, Colors.white, 0.35)!, fill],
                        ),
                ),
                child: InkWell(
                  onTap: enabled ? () => store.toggleOption(date, 'pill', 'taken', single: true) : null,
                  onLongPress: enabled ? chooseState : null,
                  child: Center(
                    child: icon != null
                        ? Icon(icon, size: 18, color: fg)
                        : Text(
                            isBreak ? '-' : '$number',
                            style: theme.textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
