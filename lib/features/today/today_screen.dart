/// The main screen: week strip, cycle ring hero, and daily shortcuts.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/units.dart';
import '../../widgets/widgets.dart';
import '../analysis/analysis_screen.dart';
import '../calendar/edit_period_screen.dart';
import '../insights/daily_insights.dart';
import '../log/log_sheet.dart';
import '../modes/perimenopause_home.dart';
import '../modes/postpartum_home.dart';
import '../modes/pregnancy_home.dart';
import '../reminders/due_reminders.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime _selected = today();

  void _select(DateTime d) => setState(() => _selected = dayOf(d));

  String _greeting(String name) {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'Good morning'
        : h < 18
            ? 'Good afternoon'
            : 'Good evening';
    return name.isEmpty ? part : '$part, $name';
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: addDays(today(), -730),
      lastDate: addDays(today(), 365),
    );
    if (d != null) _select(d);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final profile = store.profile;
    final goal = profile.goal;
    final cycleGoal = goal != Goal.trackPregnancy && goal != Goal.postpartum;
    final showLate = store.engine.isLate && (goal == Goal.trackCycle || goal == Goal.getPregnant);
    final hasReminders = dueToday(store, DateTime.now()).isNotEmpty;
    final phase = store.engine.info(_selected).phase;

    return Scaffold(
      body: BloomPage(
        eyebrow: fmtLong(today()),
        title: _greeting(profile.name),
        heroColor: !cycleGoal
            ? (goal == Goal.trackPregnancy ? BloomColors.pregnancy : BloomColors.brand)
            : phase == null
                ? BloomColors.brand
                : phaseColor(phase),
        actions: [
          IconButton(
            tooltip: 'Pick a date',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
        children: [
          _WeekStrip(selected: _selected, onSelect: _select),
          // Hero.
          if (goal == Goal.trackPregnancy)
            const PregnancyHome()
          else if (goal == Goal.postpartum)
            const PostpartumHome()
          else ...[
            if (goal == Goal.perimenopause) const PerimenopauseHome(),
            _CycleHero(day: _selected, simplified: goal == Goal.perimenopause),
          ],
          if (showLate) const _LateCard(),
          if (hasReminders) const DueRemindersBanner(),
          const SectionHeader('Daily insights', subtitle: 'Short reads picked for this phase'),
          const DailyInsightsStrip(),
          _LogSummaryCard(day: _selected),
          if (goal != Goal.trackPregnancy) const _MyCyclesSection(),
          const SectionHeader('Quick tools'),
          _WaterCard(day: _selected),
          _NoteCard(day: _selected),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ week strip

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final fdow = store.profile.firstDayOfWeek;
    final start = addDays(selected, -((selected.weekday - fdow + 7) % 7));
    final now = today();
    final onToday = sameDay(selected, now);
    final mid = addDays(start, 3);
    final month = '${const [
      'January', 'February', 'March', 'April', 'May', 'June', //
      'July', 'August', 'September', 'October', 'November', 'December',
    ][mid.month - 1]} ${mid.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(month, style: theme.textTheme.titleMedium)),
            AnimatedSwitcher(
              duration: Motion.medium,
              child: onToday
                  ? const SizedBox.shrink()
                  : TextButton(
                      key: const ValueKey('back-to-today'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => onSelect(now),
                      child: const Text('Today'),
                    ),
            ),
            IconButton(
              tooltip: 'Previous week',
              visualDensity: VisualDensity.compact,
              onPressed: () => onSelect(addDays(selected, -7)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next week',
              visualDensity: VisualDensity.compact,
              onPressed: () => onSelect(addDays(selected, 7)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Gap.v8,
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 60),
                      child: _DayPill(
                        day: addDays(start, i),
                        selected: sameDay(addDays(start, i), selected),
                        onTap: onSelect,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.selected, required this.onTap});

  final DateTime day;
  final bool selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = BloomTokens.of(context);
    final dark = theme.brightness == Brightness.dark;
    final pregnant = store.profile.goal == Goal.trackPregnancy;
    final info = store.engine.info(day);
    final isToday = sameDay(day, today());
    final hasLog = !(store.logs[dayKey(day)]?.isEmpty ?? true);

    Color? fill;
    var text = scheme.onSurface;
    Border? border;
    if (!pregnant) {
      if (info.isPeriod) {
        fill = BloomColors.period;
        text = Colors.white;
      } else if (info.isPredictedPeriod) {
        fill = BloomColors.predicted.withValues(alpha: dark ? 0.22 : 0.18);
        border = Border.all(color: BloomColors.predicted, width: 1.5);
        text = readableTint(BloomColors.period, theme.brightness);
      } else if (info.isFertile) {
        fill = BloomColors.fertile.withValues(alpha: dark ? 0.24 : 0.16);
        text = readableTint(BloomColors.ovulation, theme.brightness);
      }
      if (info.isOvulation) border = Border.all(color: BloomColors.ovulation, width: 2);
    }

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final label = '${fmtLong(day)}'
        '${info.isPeriod ? ', period' : ''}${info.isPredictedPeriod ? ', predicted period' : ''}'
        '${info.isFertile ? ', fertile' : ''}${info.isOvulation ? ', ovulation' : ''}'
        '${hasLog ? ', has log' : ''}';

    final selectedBg = dark ? scheme.surfaceContainerHigh : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.curve,
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: Radii.pillAll,
          border: Border.all(
            color: selected ? scheme.primary.withValues(alpha: dark ? 0.7 : 0.45) : Colors.transparent,
            width: 1.4,
          ),
          boxShadow: selected ? tokens.cardShadow : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onTap(day),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isToday ? 'Today' : weekdays[day.weekday - 1],
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: theme.textTheme.labelSmall!.copyWith(
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isToday ? scheme.primary : tokens.muted,
                    ),
                  ),
                  Gap.v4,
                  AnimatedContainer(
                    duration: Motion.medium,
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: border),
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: text,
                        fontWeight: isToday || selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  Gap.v4,
                  AnimatedContainer(
                    duration: Motion.medium,
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasLog ? scheme.primary.withValues(alpha: 0.7) : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ cycle hero

/// Next period start strictly after [d], logged or predicted.
DateTime? _nextPeriodAfter(CycleEngine e, DateTime d) {
  final c = e.cycleFor(d);
  if (c?.nextStart != null && c!.nextStart!.isAfter(d)) return c.nextStart;
  for (final f in e.futureCycles(14)) {
    if (f.start.isAfter(d)) return f.start;
  }
  return null;
}

/// Next ovulation on or after [d] that comes before the next period.
DateTime? _nextOvulation(CycleEngine e, DateTime d) {
  final c = e.cycleFor(d);
  if (c != null && !c.ovulation.isBefore(d) && (c.nextStart == null || c.ovulation.isBefore(c.nextStart!))) {
    return c.ovulation;
  }
  for (final f in e.futureCycles(14)) {
    if (!f.ovulation.isBefore(d)) return f.ovulation;
  }
  return null;
}

String _days(int n) => n == 1 ? '1 day' : '$n days';

/// A [CycleRing] for the cycle that contains [day], with the marker on [day].
CycleRing _ringFor(CycleEngine e, DateTime day, {required double size, required Widget child}) {
  const stroke = 16.0;
  if (!e.hasData) {
    final len = e.avgCycleLength;
    return CycleRing(
      cycleLength: len,
      periodLength: e.avgPeriodLength,
      ovulationDay: len - 13,
      size: size,
      stroke: stroke,
      child: child,
    );
  }
  final c = e.cycleFor(day);
  if (c != null) {
    final end = c.nextStart ?? e.nextPeriodStart!;
    final inCycle = day.isBefore(end) || (c.isCurrent && !day.isAfter(e.today));
    if (inCycle) {
      return CycleRing(
        cycleLength: math.max(daysBetween(c.start, end), 1),
        periodLength: c.period.length,
        ovulationDay: daysBetween(c.start, c.ovulation) + 1,
        today: daysBetween(c.start, day) + 1,
        size: size,
        stroke: stroke,
        child: child,
      );
    }
  }
  final len = e.avgCycleLength;
  for (final f in e.futureCycles(14)) {
    if (!day.isBefore(f.start) && day.isBefore(addDays(f.start, len))) {
      return CycleRing(
        cycleLength: len,
        periodLength: e.avgPeriodLength,
        ovulationDay: daysBetween(f.start, f.ovulation) + 1,
        today: daysBetween(f.start, day) + 1,
        size: size,
        stroke: stroke,
        child: child,
      );
    }
  }
  // A day before the first logged period.
  return CycleRing(
    cycleLength: len,
    periodLength: e.avgPeriodLength,
    ovulationDay: len - 13,
    size: size,
    stroke: stroke,
    child: child,
  );
}

/// What the hero says about a day.
class _HeroText {
  const _HeroText(this.label, this.value, {this.unit, this.caption});
  final String label;
  final String value;
  final String? unit;
  final String? caption;
}

class _CycleHero extends StatelessWidget {
  const _CycleHero({required this.day, this.simplified = false});

  final DateTime day;
  final bool simplified;

  _HeroText _text(AppStore store) {
    final e = store.engine;
    final info = e.info(day);
    final isToday = sameDay(day, today());
    if (!e.hasData) return const _HeroText('Welcome', 'Log your period', caption: 'to see predictions');
    if (e.isOnPeriod(day)) {
      final p = e.periods.lastWhere((p) => p.contains(day), orElse: () => e.periods.last);
      return _HeroText('Period', 'Day ${daysBetween(p.start, day) + 1}');
    }
    if (isToday && e.isLate) {
      return _HeroText('Period is', '${e.daysLate}',
          unit: e.daysLate == 1 ? 'day late' : 'days late', caption: 'Consider taking a pregnancy test');
    }
    if (info.isPredictedPeriod) return _HeroText('Expected period', 'Day ${info.cycleDay}');
    if (!simplified && info.isOvulation) {
      return _HeroText('Ovulation', isToday ? 'Today' : fmtShort(day), caption: 'High chance of getting pregnant');
    }
    if (!simplified && info.isFertile) {
      return _HeroText('Fertile window', info.chance == Chance.high ? 'High' : 'Medium',
          unit: 'chance', caption: 'of getting pregnant');
    }
    final next = _nextPeriodAfter(e, day);
    final ov = simplified ? null : _nextOvulation(e, day);
    final preferOv = store.profile.goal == Goal.getPregnant && ov != null && (next == null || ov.isBefore(next));
    if (preferOv) {
      final n = daysBetween(day, ov);
      return _HeroText('Ovulation in', '$n',
          unit: n == 1 ? 'day' : 'days', caption: next == null ? null : 'Period in ${_days(daysBetween(day, next))}');
    }
    if (next != null) {
      final n = daysBetween(day, next);
      return _HeroText('Period in', '$n',
          unit: n == 1 ? 'day' : 'days',
          caption: ov != null && ov.isBefore(next) ? 'Ovulation in ${_days(daysBetween(day, ov))}' : null);
    }
    return _HeroText('Cycle day', '${info.cycleDay ?? '-'}');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final e = store.engine;
    final info = e.info(day);
    final now = today();
    final isToday = sameDay(day, now);
    final onPeriod = e.isOnPeriod(day);
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final text = _text(store);
    final late = isToday && e.isLate && !onPeriod;
    final accent = late
        ? BloomColors.warning
        : info.phase == null
            ? BloomColors.brand
            : phaseColor(info.phase!);
    final accentText = readableTint(accent, theme.brightness);

    final canLogPast = !day.isAfter(now);
    final (String actionLabel, IconData actionIcon, VoidCallback action) = onPeriod && canLogPast
        ? ('Period ended?', Icons.check_rounded, () => _confirmEnd(context, store))
        : canLogPast
            ? ('Log period', Icons.water_drop_rounded, () => store.startPeriod(day))
            : ('Edit period dates', Icons.edit_calendar_rounded, () => _editDates(context));

    final numeric = text.value.length <= 6;
    final valueStyle = numeric
        ? theme.textTheme.displayLarge!.copyWith(fontWeight: FontWeight.w700, height: 1.05)
        : theme.textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w700);

    final center = AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.emphasized,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child),
      ),
      child: Column(
        key: ValueKey('${text.label}|${text.value}|${text.unit}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium!.copyWith(color: accentText, letterSpacing: 1.2),
          ),
          Gap.v4,
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text.value, textAlign: TextAlign.center, style: valueStyle),
          ),
          if (text.unit != null)
            Text(text.unit!, style: theme.textTheme.titleMedium!.copyWith(color: tokens.muted)),
          if (text.caption != null) ...[
            Gap.v8,
            Text(
              text.caption!,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(builder: (context, box) {
      final size = math.min(272.0, box.maxWidth - Space.xxl * 2);
      return BloomCard(
        padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (!isToday) PillChip(fmtLong(day), icon: Icons.event_rounded, color: theme.colorScheme.secondary),
                if (e.hasData && info.cycleDay != null)
                  PillChip(
                    'Cycle day ${info.cycleDay}${info.phase == null ? '' : ' · ${info.phase!.label}'}',
                    color: accent,
                  ),
                if (e.hasData && !simplified && store.profile.goal != Goal.postpartum && info.cycleDay != null)
                  PillChip('${info.chance.label} chance', icon: Icons.favorite_rounded, color: _chanceColor(info.chance)),
              ],
            ),
            Gap.v16,
            Center(child: _ringFor(e, day, size: size, child: center)),
            Gap.v20,
            GradientButton(
              label: actionLabel,
              icon: actionIcon,
              expanded: true,
              gradient: canLogPast ? BloomGradients.period : BloomGradients.brand,
              onPressed: action,
            ),
            Gap.v4,
            Center(
              child: TextButton.icon(
                onPressed: () => _editDates(context),
                icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                label: const Text('Edit period dates'),
              ),
            ),
            if (!simplified && store.profile.goal == Goal.trackCycle)
              Text(
                'Predictions are estimates. Do not use Bloom as birth control.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
              ),
          ],
        ),
      );
    });
  }

  static Color _chanceColor(Chance c) => switch (c) {
        Chance.high => BloomColors.ovulation,
        Chance.medium => BloomColors.fertile,
        Chance.low => BloomColors.luteal,
      };

  void _editDates(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditPeriodScreen()));

  Future<void> _confirmEnd(BuildContext context, AppStore store) async {
    final yesterday = addDays(day, -1);
    final choice = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('When did your period end?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, day),
            child: Text(sameDay(day, today()) ? 'Today' : fmtLong(day)),
          ),
          if (store.isPeriodDay(yesterday))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, yesterday),
              child: Text(sameDay(day, today()) ? 'Yesterday' : fmtLong(yesterday)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (choice != null) store.endPeriod(choice);
  }
}

// ------------------------------------------------------------------ late card

class _LateCard extends StatelessWidget {
  const _LateCard();

  @override
  Widget build(BuildContext context) {
    final e = context.watch<AppStore>().engine;
    final theme = Theme.of(context);
    return BloomCard.tinted(
      color: BloomColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.hourglass_bottom_rounded, color: BloomColors.warning),
              Gap.h12,
              Expanded(child: Text('Your period is ${_days(e.daysLate)} late', style: theme.textTheme.titleMedium)),
            ],
          ),
          Gap.v12,
          Text(
            'Stress, illness, travel, and changes in weight or sleep can delay a period. '
            'If you have had sex since your last period, a home pregnancy test can help. '
            'Tests are most reliable from the first day of a missed period.',
            style: theme.textTheme.bodyMedium,
          ),
          Gap.v16,
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => showLogSheet(context, today()),
                icon: const Text('🧪'),
                label: const Text('Log a test'),
              ),
              OutlinedButton.icon(
                onPressed: () => HomeShell.goTo(context, 3),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Ask the assistant'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ log summary

String _metricText(String id, double v, Profile p) => switch (id) {
      'water' => '${v.round()} ml water',
      'sleep' => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} h sleep',
      'weight' => fmtWeight(v, p.weightUnit),
      'bbt' => fmtTemp(v, p.tempUnit),
      'steps' => '${v.round()} steps',
      'energy' => 'Energy ${v.round()}/5',
      _ => '$v',
    };

/// The catalog option for a logged selection. Falls back to the same option
/// id in another category (for data logged under an older category), and
/// finally to a readable version of the id.
({String label, String emoji, Color color}) _optionDisplay(String categoryId, String optionId) {
  final cat = categoryById(categoryId);
  final own = cat?.option(optionId);
  if (own != null) return (label: own.label, emoji: own.emoji, color: Color(cat!.colorHex));
  for (final c in kCategories) {
    final o = c.option(optionId);
    if (o != null) return (label: o.label, emoji: o.emoji, color: Color(cat?.colorHex ?? c.colorHex));
  }
  final words = optionId.replaceAll('_', ' ');
  final label = words.isEmpty ? optionId : words[0].toUpperCase() + words.substring(1);
  return (label: label, emoji: cat?.emoji ?? '📌', color: Color(cat?.colorHex ?? 0xFF8C8FA3));
}

class _LogSummaryCard extends StatelessWidget {
  const _LogSummaryCard({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final log = store.logFor(day);
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final chips = <Widget>[
      for (final e in log.selections.entries)
        for (final o in e.value)
          for (final d in [_optionDisplay(e.key, o)]) PillChip(d.label, emoji: d.emoji, color: d.color),
      for (final m in log.metrics.entries)
        PillChip(
          _metricText(m.key, m.value, store.profile),
          emoji: metricById(m.key)?.emoji,
          color: BloomColors.info,
        ),
    ];
    final isToday = sameDay(day, today());
    final count = chips.length;
    return BloomCard(
      onTap: () => showLogSheet(context, day),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.edit_note_rounded),
              Gap.h12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isToday ? 'Log your symptoms' : 'Logged on ${fmtShort(day)}',
                        style: theme.textTheme.titleMedium),
                    Text(
                      count == 0 ? 'Nothing logged yet' : count == 1 ? '1 entry' : '$count entries',
                      style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              ),
              Gap.h8,
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                ),
                onPressed: () => showLogSheet(context, day),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Log'),
              ),
            ],
          ),
          Gap.v16,
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: chips.isEmpty
                ? Text(
                    'Track symptoms, mood, discharge, sleep, and more. It takes a few seconds.',
                    style: theme.textTheme.bodyMedium!.copyWith(color: tokens.muted),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: chips),
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ my cycles

class _MyCyclesSection extends StatelessWidget {
  const _MyCyclesSection();

  void _open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AnalysisScreen()));

  @override
  Widget build(BuildContext context) {
    final e = context.watch<AppStore>().engine;
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final next = e.nextPeriodStart;

    Widget stat(IconData icon, Color color, String value, String label) => Expanded(
          child: Column(
            children: [
              IconBadge(icon: icon, color: color, size: 36),
              Gap.v8,
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: theme.textTheme.titleLarge, maxLines: 1),
              ),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted)),
            ],
          ),
        );

    Widget divider() => Container(width: 1, height: 56, color: tokens.border);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('My cycles', actionLabel: 'Details', onAction: () => _open(context)),
        Gap.v12,
        BloomCard(
          onTap: () => _open(context),
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xl),
          child: Row(
            children: [
              stat(Icons.loop_rounded, BloomColors.luteal, _days(e.avgCycleLength), 'Average cycle'),
              divider(),
              stat(Icons.water_drop_rounded, BloomColors.period, _days(e.avgPeriodLength), 'Average period'),
              divider(),
              stat(Icons.event_rounded, BloomColors.fertile, next == null ? '-' : fmtShort(next), 'Next period'),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ water and note

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.day});

  final DateTime day;

  static const _glass = 250.0;
  static const _goalGlasses = 8;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final ml = store.logFor(day).metrics['water'] ?? 0;
    final glasses = (ml / _glass).round();
    final reached = glasses >= _goalGlasses;
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(emoji: '💧', color: BloomColors.info),
              Gap.h12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water', style: theme.textTheme.titleMedium),
                    Text(
                      reached ? 'Daily goal reached' : '$glasses of $_goalGlasses glasses',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove a glass',
                onPressed: ml <= 0 ? null : () => store.setMetric(day, 'water', ml - _glass <= 0 ? null : ml - _glass),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                ),
                onPressed: () => store.setMetric(day, 'water', ml + _glass),
                child: const Text('+250 ml'),
              ),
            ],
          ),
          Gap.v16,
          Row(
            children: [
              for (var i = 0; i < _goalGlasses; i++) ...[
                if (i > 0) Gap.h4,
                Expanded(
                  child: AnimatedContainer(
                    duration: Motion.medium,
                    curve: Motion.curve,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: Radii.pillAll,
                      color: i < glasses ? BloomColors.info : tokens.subtle,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Gap.v8,
          Row(
            children: [
              Expanded(
                child: Text('${ml.round()} ml',
                    style: theme.textTheme.labelMedium!.copyWith(color: readableTint(BloomColors.info, theme.brightness))),
              ),
              Text('Goal ${(_goalGlasses * _glass).round()} ml',
                  style: theme.textTheme.labelMedium!.copyWith(color: tokens.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.day});

  final DateTime day;

  Future<void> _edit(BuildContext context, AppStore store, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Note for ${fmtShort(day)}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Write anything you want to remember'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) store.setNote(day, result.trim());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final note = store.logFor(day).note;
    return BloomCard(
      onTap: () => _edit(context, store, note),
      padding: Insets.cardCompact,
      child: Row(
        children: [
          const IconBadge(emoji: '📝', color: BloomColors.pregnancy),
          Gap.h12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Note', style: theme.textTheme.titleMedium),
                Text(
                  note.isEmpty ? 'Add a quick note' : note,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium!.copyWith(color: note.isEmpty ? tokens.muted : null),
                ),
              ],
            ),
          ),
          Gap.h8,
          Icon(note.isEmpty ? Icons.add_rounded : Icons.edit_rounded, color: tokens.muted),
        ],
      ),
    );
  }
}
