/// Birth control setup: method, pill pack, dates, reminder time, and a pill
/// pack grid that logs taken or missed pills.
library;

import 'dart:math' as math;

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
        eyebrow: 'Reminders · Birth control',
        title: 'Birth control',
        subtitle: 'Reminders and a printed pill chart.',
        spacing: Space.xxl,
        children: [
          AnimatedSwitcher(
            duration: Motion.medium,
            child: m == BirthControlMethod.none
                ? const BloomCard(
                    key: ValueKey('none'),
                    child: EmptyState(
                      compact: true,
                      glyph: Botanical.sprig,
                      title: 'No method set',
                      body: 'Choose your method below to get reminders and track your pills.',
                    ),
                  )
                : _TodayHero(key: ValueKey(m), contraception: c),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MonoLabel('Method'),
              Gap.v12,
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final method in BirthControlMethod.values)
                    SelectChip(
                      label: method.label,
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
                const SectionHeader(
                  'Pill pack',
                  label: 'Chart',
                  subtitle: 'Tap a pill to mark it taken. Long-press for more.',
                  padding: EdgeInsets.zero,
                ),
                Gap.v16,
                _PackGrid(contraception: c, packOffset: _packOffset, onOffset: (o) => setState(() => _packOffset = o)),
              ],
            ),
          if (m != BirthControlMethod.none) ...[
            MenuSection(
              title: 'Schedule',
              children: [
                if (m == BirthControlMethod.pill)
                  MenuTile(
                    title: 'Pack type',
                    subtitle: c.pack.label,
                    onTap: () async {
                      final p = await showAppBottomSheet<PillPack>(
                        context,
                        builder: (ctx) => AppBottomSheet(
                          eyebrow: 'Pill pack',
                          title: 'Pack type',
                          child: MenuSection(
                            children: [
                              for (final p in PillPack.values)
                                MenuTile(
                                  title: p.label,
                                  trailing: p == c.pack
                                      ? Icon(Icons.check, size: 18, color: BloomColors.of(ctx).ink)
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
                  title: m.startLabel,
                  value: c.startDate == null ? 'Set date' : fmtFull(c.startDate!),
                  onTap: pickDate,
                ),
                if (m == BirthControlMethod.pill)
                  MenuTile(
                    title: 'Started a new pack today',
                    showChevron: false,
                    onTap: () => update((c) => c.startDate = now),
                  ),
                if (m == BirthControlMethod.injection)
                  StepperTile(
                    title: 'Weeks between',
                    value: c.injectionWeeks,
                    min: 8,
                    max: 13,
                    suffix: 'wk',
                    onChanged: (v) => update((c) => c.injectionWeeks = v),
                  ),
                if (m == BirthControlMethod.iud || m == BirthControlMethod.implant)
                  StepperTile(
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
                  title: 'Remind me',
                  subtitle: _reminderHint(m),
                  value: remindOn,
                  onChanged: (v) {
                    reminders[ReminderType.contraception].enabled = v;
                    saveReminders(context, reminders, askPermission: v);
                  },
                ),
                MenuTile(
                  title: 'Reminder time',
                  value: fmtTimeOfDay(c.hour, c.minute),
                  onTap: pickTime,
                ),
                if (hasRefill)
                  MenuTile.toggle(
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
                    onChanged: (v) => update((c) => c.refillDaysBefore = v),
                  ),
              ],
            ),
            if (m == BirthControlMethod.ring || m == BirthControlMethod.patch)
              Marginalia(
                label: 'Note',
                child: Text(m == BirthControlMethod.ring
                    ? 'A typical schedule: the ring stays in for 3 weeks, then comes out for a 1-week break. '
                          'Bloom reminds you on insert and remove days.'
                    : 'A typical schedule: a new patch each week for 3 weeks, then a patch-free week. '
                          'Bloom reminds you on change and remove days.'),
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
    final p = BloomColors.of(context);
    final c = contraception;
    final now = today();
    final pd = c.method == BirthControlMethod.pill ? c.packDay(now) : null;
    final pillDue = pd != null && !pd.isBreak;
    final state = store.logFor(now).get('pill').firstOrNull;
    final taken = state == 'taken' || state == 'double' || state == 'late';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoLabel('Today · ${c.method.label}'),
        Gap.v8,
        Text(c.status(now), style: Almanac.serif(size: 26, weight: 340, color: p.ink, height: 1.2)),
        if (pillDue) ...[
          Gap.v16,
          AnimatedSwitcher(
            duration: Motion.medium,
            child: taken
                ? Row(
                    key: const ValueKey('taken'),
                    children: [
                      Icon(Icons.check, size: 18, color: p.ink),
                      Gap.h8,
                      Text(
                        state == 'late' ? 'Taken late today.' : 'Today\'s pill is taken.',
                        style: Almanac.italic(context, size: 18),
                      ),
                    ],
                  )
                : Align(
                    key: const ValueKey('take'),
                    alignment: Alignment.centerLeft,
                    child: InkButton(
                      label: 'I took pill ${pd.dayInPack}',
                      icon: Icons.check,
                      onPressed: () => store.toggleOption(now, 'pill', 'taken', single: true),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

/// A 28-pill blister pack drawn as a printed chart, one row per week.
class _PackGrid extends StatelessWidget {
  const _PackGrid({required this.contraception, required this.packOffset, required this.onOffset});
  final Contraception contraception;
  final int packOffset;
  final ValueChanged<int> onOffset;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = BloomColors.of(context);
    final now = today();
    final current = contraception.packDay(now)!;
    final packStart = addDays(current.packStart, packOffset * kPackLength);
    final pack = contraception.pack;
    var taken = 0;
    for (var i = 0; i < pack.activeDays; i++) {
      final st = store.logFor(addDays(packStart, i)).get('pill').firstOrNull;
      if (st != null && st != 'missed') taken++;
    }

    Widget arrow(IconData icon, String tip, VoidCallback? onTap) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: onTap == null ? p.hairline : p.ink),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Hairline(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Row(
            children: [
              arrow(Icons.arrow_back, 'Previous pack', () => onOffset(packOffset - 1)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      packOffset == 0
                          ? 'Current pack'
                          : packOffset > 0
                          ? 'Next pack'
                          : 'Earlier pack',
                      style: Almanac.serif(size: 19, weight: 380, color: p.ink),
                    ),
                    Gap.v4,
                    MonoLabel(
                      '${fmtShort(packStart)} – ${fmtShort(addDays(packStart, kPackLength - 1))} · $taken of ${pack.activeDays} taken',
                      textAlign: TextAlign.center,
                      size: 10,
                    ),
                  ],
                ),
              ),
              arrow(Icons.arrow_forward, 'Next pack', packOffset < 1 ? () => onOffset(packOffset + 1) : null),
            ],
          ),
        ),
        const Hairline(),
        Gap.v12,
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: MonoLabel(DateFormat('EEE').format(addDays(packStart, i)).substring(0, 2), size: 10),
                ),
              ),
          ],
        ),
        Gap.v8,
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.xs,
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
        Gap.v12,
        const Hairline(),
        Gap.v12,
        Wrap(
          spacing: Space.lg,
          runSpacing: Space.sm,
          children: [
            _legend(context, _Pill.taken, 'Taken'),
            _legend(context, _Pill.late, 'Late'),
            _legend(context, _Pill.missed, 'Missed'),
            _legend(context, _Pill.placebo, pack.hasBreak ? 'Break' : 'Placebo'),
            _legend(context, _Pill.active, 'Today', today: true),
          ],
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, _Pill kind, String label, {bool today = false}) {
    final p = BloomColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(dimension: 14, child: CustomPaint(painter: _PillPainter(kind: kind, palette: p))),
            const SizedBox(height: 2),
            Container(width: 10, height: 1.5, color: today ? p.ink : Colors.transparent),
          ],
        ),
        Gap.h8,
        MonoLabel(label, size: 10),
      ],
    );
  }
}

/// How a pill is drawn on the chart.
enum _Pill { active, future, taken, late, double, missed, placebo, gap }

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

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final store = context.read<AppStore>();
    final kind = switch (state) {
      'taken' => _Pill.taken,
      'double' => _Pill.double,
      'late' => _Pill.late,
      'missed' => _Pill.missed,
      _ =>
        isBreak
            ? _Pill.gap
            : !active
            ? _Pill.placebo
            : isFuture
            ? _Pill.future
            : _Pill.active,
    };
    final inked = kind == _Pill.taken || kind == _Pill.double || kind == _Pill.late;
    final numeralColor = inked
        ? p.paper
        : kind == _Pill.active
        ? p.ink
        : p.ink2.withValues(alpha: kind == _Pill.missed ? 0.6 : 0.85);

    Future<void> chooseState() async {
      final v = await showAppBottomSheet<String>(
        context,
        builder: (ctx) => AppBottomSheet(
          eyebrow: fmtLong(date),
          title: 'Pill $number',
          child: MenuSection(
            children: [
              for (final (id, text, ic) in [
                ('taken', 'Taken on time', Icons.check),
                ('late', 'Taken late', Icons.schedule),
                ('missed', 'Missed', Icons.close),
                ('double', 'Double dose', Icons.done_all),
              ])
                MenuTile(
                  icon: ic,
                  title: text,
                  trailing: state == id ? Icon(Icons.check, size: 18, color: BloomColors.of(ctx).ink) : null,
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
      excludeSemantics: true,
      child: Pressable(
        onTap: enabled ? () => store.toggleOption(date, 'pill', 'taken', single: true) : null,
        onLongPress: enabled ? chooseState : null,
        borderRadius: Radii.smAll,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _PillPainter(kind: kind, palette: p),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.medium,
                        style: Almanac.numeral(context, size: 14, weight: inked ? 420 : 360, color: numeralColor),
                        child: Text(isBreak ? '–' : '$number'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Today is underlined, like the ledger.
            Container(width: 16, height: 1.5, color: isToday ? p.ink : Colors.transparent),
          ],
        ),
      ),
    );
  }
}

/// Draws one pill: a hairline circle, inked when taken, an oxblood cross
/// when missed, and a dotted outline for placebo and break days.
class _PillPainter extends CustomPainter {
  const _PillPainter({required this.kind, required this.palette});
  final _Pill kind;
  final BloomPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2.5;
    final p = palette;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    switch (kind) {
      case _Pill.taken || _Pill.late || _Pill.double:
        canvas.drawCircle(c, r, Paint()..color = p.ink);
        if (kind == _Pill.double) {
          canvas.drawCircle(c, r + 2, stroke..color = p.ink);
        }
        if (kind == _Pill.late) {
          // A small ochre mark at the shoulder: taken, but late.
          final at = c + Offset(r * 0.72, -r * 0.72);
          canvas.drawCircle(at, r * 0.26 + 1.2, Paint()..color = p.paper);
          canvas.drawCircle(at, r * 0.26, Paint()..color = p.warning);
        }
      case _Pill.active:
        canvas.drawCircle(c, r, stroke..color = p.ink.withValues(alpha: 0.7));
      case _Pill.future:
        canvas.drawCircle(c, r, stroke..color = p.ink2.withValues(alpha: 0.45));
      case _Pill.missed:
        canvas.drawCircle(c, r, stroke..color = p.ink2.withValues(alpha: 0.5));
        final x = Paint()
          ..color = p.period
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        final d = r * 0.62;
        canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), x);
        canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), x);
      case _Pill.placebo || _Pill.gap:
        // Dotted outline.
        final dot = Paint()..color = p.ink2.withValues(alpha: kind == _Pill.gap ? 0.45 : 0.75);
        final n = (2 * math.pi * r / 4.2).floor();
        for (var i = 0; i < n; i++) {
          final a = i * 2 * math.pi / n;
          canvas.drawCircle(c + Offset(r * math.cos(a), r * math.sin(a)), 0.8, dot);
        }
    }
  }

  @override
  bool shouldRepaint(_PillPainter old) => old.kind != kind || old.palette != palette;
}
