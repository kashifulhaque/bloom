/// The main screen, set like a page of an almanac: a serif headline for the
/// day, the cycle dial, a ledger of the week, a note in the margin, and the
/// day's journal below.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';
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
import '../log/almanac_rows.dart';
import '../log/log_sheet.dart';
import '../log/tracker_style.dart';
import '../modes/perimenopause_home.dart';
import '../modes/postpartum_home.dart';
import '../modes/pregnancy_home.dart';
import '../reminders/due_reminders.dart';
import '../updates/update_controller.dart';
import '../updates/update_widgets.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime _selected = today();

  void _select(DateTime d) {
    Almanac.tick();
    setState(() => _selected = dayOf(d));
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'Good morning'
        : h < 18
            ? 'Good afternoon'
            : 'Good evening';
    return name.isEmpty ? '$part.' : '$part, $name.';
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
    final simplified = goal == Goal.perimenopause;
    final hasReminders = dueToday(store, DateTime.now()).isNotEmpty;
    final updates = watchUpdates(context);
    final update = updates?.pending;
    final story = _DayStory.of(store.engine, _selected, simplified: simplified);
    final date = DateFormat('EEEE, d MMM').format(_selected);
    final p = BloomColors.of(context);

    final Widget title = cycleGoal
        ? _Headline(story: story, greeting: _greeting(profile.name))
        : PhaseTitle(
            lead: _greeting(profile.name).replaceFirst(RegExp(r'[.,].*$'), ','),
            italic: profile.name.isEmpty ? 'welcome back.' : '${profile.name}.',
            color: goal == Goal.trackPregnancy ? BloomColors.pregnancy : null,
          );
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        Transform.translate(
          offset: const Offset(Space.sm, -Space.sm),
          child: IconButton(
            tooltip: 'Pick a date',
            onPressed: _pickDate,
            icon: Icon(Icons.calendar_today_outlined, size: 20, color: p.ink2),
          ),
        ),
      ],
    );

    return Scaffold(
      body: BloomPage(
        eyebrow: cycleGoal && story.cycleNo != null ? 'Cycle ${story.cycleNo.toString().padLeft(2, '0')} · $date' : date,
        header: header,
        children: [
          if (goal == Goal.trackPregnancy) ...[
            const PregnancyHome(),
            _WeekLedger(selected: _selected, onSelect: _select),
          ] else if (goal == Goal.postpartum) ...[
            const PostpartumHome(),
            _WeekLedger(selected: _selected, onSelect: _select),
          ] else ...[
            if (goal == Goal.perimenopause) const PerimenopauseHome(),
            _Dial(story: story),
            _WeekLedger(selected: _selected, onSelect: _select),
            const Hairline(),
            _Margin(story: story, showLateActions: goal == Goal.trackCycle || goal == Goal.getPregnant),
          ],
          _Actions(day: _selected, cycleGoal: cycleGoal),
          if (cycleGoal && !simplified && goal == Goal.trackCycle)
            Text(
              'Predictions are estimates. Don’t use Bloom as birth control.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (hasReminders) ...[Gap.v8, const DueRemindersBanner()],
          if (update != null) UpdateNote(controller: updates!, version: update),
          const SectionHeader('Daily insights', label: 'Reading', subtitle: 'Short reads picked for this phase'),
          const DailyInsightsStrip(),
          _LogSummary(day: _selected),
          if (goal != Goal.trackPregnancy) const _MyCycles(),
          const SectionHeader('Water and note', label: 'Daybook'),
          _WaterRow(day: _selected),
          const Hairline(),
          _NoteRow(day: _selected),
          const Hairline(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ day story

/// What a day means, in the order the hero checks it.
enum _State { noData, period, late, dueToday, predictedPeriod, ovulation, fertile, phase }

String _days(int n) => n == 1 ? '1 day' : '$n days';

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

/// Everything the hero says about one day, computed once so the headline,
/// the dial, and the note always agree.
class _DayStory {
  _DayStory({
    required this.day,
    required this.state,
    required this.info,
    required this.isToday,
    required this.simplified,
    this.cycleNo,
    this.cycleDay,
    this.periodDay = 0,
    this.lateBy = 0,
    this.nextPeriod,
    this.nextOvulation,
    this.preferOvulation = false,
    required this.ring,
  });

  factory _DayStory.of(CycleEngine e, DateTime day, {bool simplified = false}) {
    final d = dayOf(day);
    final now = e.today;
    final info = e.info(d);
    final isToday = sameDay(d, now);
    final ring = _RingSpec.of(e, d);

    // The cycle number for the eyebrow: logged cycles first, then predictions.
    int? cycleNo;
    final c = e.cycleFor(d);
    if (c != null) {
      cycleNo = e.cycles.indexOf(c) + 1;
      if (c.isCurrent && d.isAfter(now)) {
        cycleNo += e.futureCycles(14).where((f) => !d.isBefore(f.start) && f.start.isAfter(c.start)).length;
      }
    }

    _DayStory make(_State s, {int periodDay = 0, int lateBy = 0, DateTime? next, DateTime? ov, bool preferOv = false}) =>
        _DayStory(
          day: d,
          state: s,
          info: info,
          isToday: isToday,
          simplified: simplified,
          cycleNo: cycleNo,
          cycleDay: info.cycleDay,
          periodDay: periodDay,
          lateBy: lateBy,
          nextPeriod: next,
          nextOvulation: ov,
          preferOvulation: preferOv,
          ring: ring,
        );

    if (!e.hasData) return make(_State.noData);
    if (e.isOnPeriod(d)) {
      final p = e.periods.lastWhere((p) => p.contains(d), orElse: () => e.periods.last);
      return make(_State.period, periodDay: daysBetween(p.start, d) + 1, next: _nextPeriodAfter(e, d));
    }

    // In the current cycle, on or after the predicted start, and not in the
    // future: the period is due or late. Never count down to the cycle after.
    final expected = e.nextPeriodStart;
    if (c != null && c.isCurrent && expected != null && !d.isAfter(now) && !d.isBefore(expected)) {
      final lateBy = daysBetween(expected, d);
      return make(lateBy > 0 ? _State.late : _State.dueToday, lateBy: lateBy);
    }

    if (info.isPredictedPeriod) return make(_State.predictedPeriod, next: _nextPeriodAfter(e, d));
    final next = _nextPeriodAfter(e, d);
    final ov = simplified ? null : _nextOvulation(e, d);
    final ovAhead = ov != null && (next == null || ov.isBefore(next)) ? ov : null;
    final preferOv = e.profile.goal == Goal.getPregnant && ovAhead != null;
    if (!simplified && info.isOvulation) return make(_State.ovulation, next: next, ov: ovAhead, preferOv: preferOv);
    if (!simplified && info.isFertile) return make(_State.fertile, next: next, ov: ovAhead, preferOv: preferOv);
    return make(_State.phase, next: next, ov: ovAhead, preferOv: preferOv);
  }

  final DateTime day;
  final _State state;
  final DayInfo info;
  final bool isToday;
  final bool simplified;
  final int? cycleNo;
  final int? cycleDay;
  final int periodDay;

  /// Days past the predicted start, for [_State.late].
  final int lateBy;
  final DateTime? nextPeriod;

  /// The next ovulation, only when it comes before [nextPeriod].
  final DateTime? nextOvulation;
  final bool preferOvulation;
  final _RingSpec ring;

  static String _spelledDays(int n) => n == 1 ? 'one day' : '${Almanac.spell(n)} days';

  /// The italic phrase of the headline and its meaning color.
  (String, Color?) get phrase => switch (state) {
        _State.noData => ('begin with your period.', null),
        _State.period => (periodDay == 1 ? 'your period begins.' : 'period, day ${Almanac.spell(periodDay)}.', BloomColors.period),
        _State.late => ('late by ${_spelledDays(lateBy)}.', BloomColors.warning),
        _State.dueToday => ('period due today.', BloomColors.period),
        _State.predictedPeriod => ('period expected.', BloomColors.predicted),
        _State.ovulation => ('ovulation likely.', BloomColors.ovulation),
        _State.fertile => ('fertile window.', BloomColors.fertile),
        _State.phase => switch (info.phase) {
            Phase.menstrual => ('your period.', BloomColors.period),
            Phase.follicular => ('the follicular phase.', BloomColors.follicular),
            Phase.ovulation => (simplified ? 'mid-cycle.' : 'fertile window.', simplified ? null : BloomColors.fertile),
            Phase.luteal => ('the luteal phase.', BloomColors.luteal),
            null => ('a quiet day.', null),
          },
      };

  /// The italic caption under the dial numeral.
  String get caption => switch (state) {
        _State.noData => 'to see predictions',
        _State.late => 'late by ${_spelledDays(lateBy)}',
        _State.dueToday => 'period due today',
        _State.period => 'period, day ${Almanac.spell(periodDay)}',
        _ => 'of ${Almanac.spell(ring.length)}',
      };

  /// The marginal note: an italic lead word and a short explanation.
  (String, String) get note => switch (state) {
        _State.noData => (
            'Begin here.',
            'Log the first day of your last period, and Bloom will start to learn your rhythm.',
          ),
        _State.period => ('Menstrual.', 'Rest counts. Warmth, water, and iron-rich food can ease these days.'),
        _State.late => (
            'Late.',
            'Stress, illness, travel, and changes in weight or sleep can delay a period. If you’ve had sex since '
                'your last period, a home pregnancy test is most reliable from the first day of a missed period.',
          ),
        _State.dueToday => (
            'Due today.',
            'Your period is expected today. Arriving a day or two early or late is common.',
          ),
        _State.predictedPeriod => ('Menstrual.', 'Bloom expects your period around now. Predictions are estimates.'),
        _State.ovulation => ('Ovulatory.', 'Energy and confidence often peak now. This is the most fertile day of the cycle.'),
        _State.fertile => ('Fertile.', 'Your fertile window is open: pregnancy is possible on these days.'),
        _State.phase => switch (info.phase) {
            Phase.menstrual => ('Menstrual.', 'Rest counts. Warmth, water, and iron-rich food can ease these days.'),
            Phase.follicular => ('Follicular.', 'Estrogen is rising. Many people feel energy and focus return.'),
            Phase.ovulation => simplified
                ? ('Mid-cycle.', 'Cycles can vary more in perimenopause. Logging helps you see your own pattern.')
                : ('Fertile.', 'Your fertile window is open: pregnancy is possible on these days.'),
            Phase.luteal => (
                'Luteal.',
                'Progesterone rises after ovulation. Some people notice cravings, tender breasts, or a shorter fuse.',
              ),
            null => ('Before your log.', 'This day comes before your first logged period.'),
          },
      };

  /// The plain countdown sentence. Null when there is nothing ahead to say.
  String? get ahead {
    switch (state) {
      case _State.noData:
        return null;
      case _State.late:
        return isToday ? 'Period is ${_days(lateBy)} late.' : 'Period was ${_days(lateBy)} late on this day.';
      case _State.dueToday:
        return isToday ? 'Period expected today.' : 'Period was expected on this day.';
      case _:
        break;
    }
    String around(DateTime d) => DateFormat('d MMMM').format(d);
    final parts = <String>[];
    final next = nextPeriod;
    final ov = nextOvulation;
    String periodIn(DateTime n) {
      final k = daysBetween(day, n);
      return 'Period in ${_days(k)}, around ${around(n)}.';
    }

    String ovIn(DateTime o) {
      final k = daysBetween(day, o);
      return k == 0 ? 'Ovulation likely today.' : 'Ovulation in ${_days(k)}.';
    }

    if (preferOvulation && ov != null) {
      parts.add(ovIn(ov));
      if (next != null) parts.add(periodIn(next));
    } else {
      if (next != null) parts.add(periodIn(next));
      if (ov != null && state != _State.ovulation) parts.add(ovIn(ov));
    }
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// The dial's numbers for the cycle that contains a day.
class _RingSpec {
  const _RingSpec({required this.length, required this.periodLength, required this.ovulationDay, this.today});

  factory _RingSpec.of(CycleEngine e, DateTime day) {
    if (!e.hasData) {
      final len = e.avgCycleLength;
      return _RingSpec(length: len, periodLength: e.avgPeriodLength, ovulationDay: len - 13);
    }
    final c = e.cycleFor(day);
    if (c != null) {
      final end = c.nextStart ?? e.nextPeriodStart!;
      final inCycle = day.isBefore(end) || (c.isCurrent && !day.isAfter(e.today));
      if (inCycle) {
        final index = daysBetween(c.start, day) + 1;
        // On the predicted start itself the period is due, not late: stretch
        // the dial by one day so the marker doesn't read as late.
        final length = sameDay(day, end) ? index : daysBetween(c.start, end);
        return _RingSpec(
          length: math.max(length, 1),
          periodLength: c.period.length,
          ovulationDay: daysBetween(c.start, c.ovulation) + 1,
          today: index,
        );
      }
    }
    final len = e.avgCycleLength;
    for (final f in e.futureCycles(14)) {
      if (!day.isBefore(f.start) && day.isBefore(addDays(f.start, len))) {
        return _RingSpec(
          length: len,
          periodLength: e.avgPeriodLength,
          ovulationDay: daysBetween(f.start, f.ovulation) + 1,
          today: daysBetween(f.start, day) + 1,
        );
      }
    }
    // A day before the first logged period.
    return _RingSpec(length: len, periodLength: e.avgPeriodLength, ovulationDay: len - 13);
  }

  final int length;
  final int periodLength;
  final int ovulationDay;
  final int? today;
}

// ------------------------------------------------------------------ headline and dial

class _Headline extends StatelessWidget {
  const _Headline({required this.story, required this.greeting});

  final _DayStory story;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    final (italic, color) = story.phrase;
    final day = story.cycleDay;
    final lead = story.state == _State.noData || day == null ? 'Welcome,' : 'Day ${Almanac.spell(day)},';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: Motion.medium,
          switchInCurve: Motion.curve,
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
          child: PhaseTitle(key: ValueKey('$lead$italic'), lead: lead, italic: italic, color: color),
        ),
        Gap.v8,
        Text(greeting, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2)),
      ],
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.story});

  final _DayStory story;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final r = story.ring;
    final noData = story.state == _State.noData;
    final center = AnimatedSwitcher(
      duration: Motion.medium,
      child: Column(
        key: ValueKey('${story.cycleDay}|${story.caption}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (noData)
            Text('Log your period',
                textAlign: TextAlign.center, style: Almanac.serif(size: 24, weight: 340, color: p.ink, height: 1.1))
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${story.cycleDay ?? '–'}', style: Almanac.numeral(context, size: 64)),
            ),
          Gap.v4,
          Text(
            story.caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Almanac.italic(
              context,
              size: 15,
              color: story.state == _State.late ? readableTint(BloomColors.warning, Theme.of(context).brightness) : p.ink2,
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(builder: (context, box) {
      final size = math.min(260.0, box.maxWidth - Space.lg * 2);
      return Center(
        child: CycleRing(
          key: ValueKey('${r.length}|${r.periodLength}|${r.ovulationDay}'),
          cycleLength: r.length,
          periodLength: r.periodLength,
          ovulationDay: r.ovulationDay,
          today: r.today,
          size: size,
          stroke: 16,
          child: center,
        ),
      );
    });
  }
}

// ------------------------------------------------------------------ week ledger

class _WeekLedger extends StatelessWidget {
  const _WeekLedger({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final e = store.engine;
    final pregnant = store.profile.goal == Goal.trackPregnancy;
    final fdow = store.profile.firstDayOfWeek;
    final start = addDays(selected, -((selected.weekday - fdow + 7) % 7));
    final now = today();
    final onToday = sameDay(selected, now);
    final month = DateFormat('MMMM y').format(addDays(start, 3));

    LedgerDay styleFor(DateTime d) {
      final hasLog = !(store.logs[dayKey(d)]?.isEmpty ?? true);
      final dot = hasLog ? BloomColors.ink2 : null;
      if (pregnant) return LedgerDay(dot: dot, semanticLabel: hasLog ? 'has log' : null);
      final info = e.info(d);
      final tags = <String>[
        if (info.isPeriod) 'period',
        if (info.isPredictedPeriod) 'predicted period',
        if (info.isOvulation) 'ovulation' else if (info.isFertile) 'fertile',
        if (hasLog) 'has log',
      ];
      final label = tags.isEmpty ? null : tags.join(', ');
      if (info.isPeriod) return LedgerDay(color: BloomColors.period, dot: dot, semanticLabel: label);
      if (info.isPredictedPeriod) {
        return LedgerDay(color: BloomColors.period, predicted: true, dot: dot, semanticLabel: label);
      }
      if (info.isOvulation || info.isFertile) {
        return LedgerDay(
          color: info.isOvulation ? BloomColors.ovulation : BloomColors.fertile,
          predicted: info.isPredicted,
          dot: dot,
          semanticLabel: label,
        );
      }
      return LedgerDay(dot: dot, semanticLabel: label);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: MonoLabel(month)),
            AnimatedSwitcher(
              duration: Motion.medium,
              child: onToday
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const ValueKey('back-to-today'),
                      padding: const EdgeInsets.only(right: Space.xs),
                      child: InkLink('Today', size: 13, onTap: () => onSelect(now)),
                    ),
            ),
            ThinIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Previous week',
              boxed: false,
              onTap: () => onSelect(addDays(selected, -7)),
            ),
            ThinIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Next week',
              boxed: false,
              onTap: () => onSelect(addDays(selected, 7)),
            ),
          ],
        ),
        Ledger(
          days: [for (var i = 0; i < 7; i++) addDays(start, i)],
          today: now,
          selected: onToday ? null : selected,
          styleFor: styleFor,
          onTap: onSelect,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ margin notes

class _Margin extends StatelessWidget {
  const _Margin({required this.story, required this.showLateActions});

  final _DayStory story;
  final bool showLateActions;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final theme = Theme.of(context);
    final (lead, body) = story.note;
    final (_, color) = story.phrase;
    final ahead = story.ahead;
    final late = story.state == _State.late && story.isToday;
    final italicColor = color == null ? p.ink : readableTint(color, theme.brightness);
    return AnimatedSize(
      duration: Motion.medium,
      curve: Motion.curve,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Marginalia(
            label: 'Note',
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$lead ', style: Almanac.italic(context, size: 17, color: italicColor)),
              TextSpan(text: body, style: theme.textTheme.bodyMedium!.copyWith(height: 1.55)),
            ])),
          ),
          if (ahead != null) ...[
            Gap.v12,
            Marginalia(
              label: late ? 'Late' : 'Ahead',
              labelColor: late ? BloomColors.warning : null,
              child: Text(ahead, style: theme.textTheme.bodyMedium!.copyWith(height: 1.55, color: p.ink)),
            ),
          ],
          if (late && showLateActions) ...[
            Gap.v4,
            Padding(
              padding: const EdgeInsets.only(left: Space.margin),
              child: Wrap(
                spacing: Space.lg,
                children: [
                  InkLink('Log a test', size: 13.5, onTap: () => showLogSheet(context, today())),
                  InkLink('Ask the assistant', size: 13.5, onTap: () => HomeShell.goTo(context, 3)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ actions

class _Actions extends StatelessWidget {
  const _Actions({required this.day, required this.cycleGoal});

  final DateTime day;
  final bool cycleGoal;

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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = today();
    final isToday = sameDay(day, now);
    final canLogPast = !day.isAfter(now);
    final onPeriod = store.engine.isOnPeriod(day);
    final logLabel = isToday ? 'Log today' : 'Log ${fmtShort(day)}';
    final Widget? periodAction = !cycleGoal
        ? null
        : onPeriod && canLogPast
            ? InkButton.outlined(
                label: 'Period ended?',
                icon: Icons.check,
                color: BloomColors.period,
                onPressed: () => _confirmEnd(context, store),
              )
            : canLogPast
                ? InkButton.outlined(
                    label: 'Log period',
                    icon: Icons.water_drop_outlined,
                    color: BloomColors.period,
                    onPressed: () => store.startPeriod(day),
                  )
                : null;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              InkButton(label: logLabel, icon: Icons.add, onPressed: () => showLogSheet(context, day)),
              ?periodAction,
            ],
          ),
          if (cycleGoal) ...[
            Gap.v4,
            InkLink('Edit period dates', size: 13.5, arrow: true, onTap: () => _editDates(context)),
          ],
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

/// The catalog label for a logged selection. Falls back to the same option
/// id in another category (for data logged under an older category), and
/// finally to a readable version of the id.
String _optionLabel(String categoryId, String optionId) {
  final own = categoryById(categoryId)?.option(optionId);
  if (own != null) return own.label;
  for (final c in kCategories) {
    final o = c.option(optionId);
    if (o != null) return o.label;
  }
  final words = optionId.replaceAll('_', ' ');
  return words.isEmpty ? optionId : words[0].toUpperCase() + words.substring(1);
}

class _LogSummary extends StatelessWidget {
  const _LogSummary({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final log = store.logFor(day);
    final p = BloomColors.of(context);
    final tags = <Widget>[
      for (final e in log.selections.entries)
        for (final o in e.value) PillChip(_optionLabel(e.key, o), color: categoryColor(e.key)),
      for (final m in log.metrics.entries) PillChip(_metricText(m.key, m.value, store.profile), color: metricColor(m.key)),
    ];
    final isToday = sameDay(day, today());
    final count = tags.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          isToday ? 'Logged today' : 'Logged on ${fmtShort(day)}',
          label: count == 0 ? 'Journal' : count == 1 ? 'Journal · 1 entry' : 'Journal · $count entries',
          actionLabel: count == 0 ? 'Log' : 'Edit',
          onAction: () => showLogSheet(context, day),
        ),
        Gap.v12,
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: tags.isEmpty
              ? Pressable(
                  onTap: () => showLogSheet(context, day),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Nothing written here yet. Symptoms, mood, sleep, and more take a few seconds.',
                      style: Almanac.italic(context, size: 16, color: p.ink2),
                    ),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: tags),
                ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ my cycles

class _MyCycles extends StatelessWidget {
  const _MyCycles();

  void _open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AnalysisScreen()));

  @override
  Widget build(BuildContext context) {
    final e = context.watch<AppStore>().engine;
    final next = e.nextPeriodStart;
    final due = (e.daysUntilNextPeriod ?? 1) <= 0 && !e.isOnPeriod(e.today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('My cycles', label: 'Ledger', actionLabel: 'Details', onAction: () => _open(context)),
        Gap.v8,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                value: '${e.avgCycleLength}',
                unit: 'days',
                label: 'Average cycle',
                onTap: () => _open(context),
              ),
            ),
            Gap.h16,
            Expanded(
              child: StatTile(
                value: '${e.avgPeriodLength}',
                unit: 'days',
                label: 'Average period',
                color: BloomColors.period,
                onTap: () => _open(context),
              ),
            ),
            Gap.h16,
            Expanded(
              child: StatTile(
                value: next == null ? '–' : (due ? 'Due' : '${next.day}'),
                unit: next == null ? null : (due ? 'now' : DateFormat('MMM').format(next)),
                label: 'Next period',
                color: BloomColors.predicted,
                onTap: () => _open(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ water and note

class _WaterRow extends StatelessWidget {
  const _WaterRow({required this.day});

  final DateTime day;

  static const _glass = 250.0;
  static const _goalGlasses = 8;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = BloomColors.of(context);
    final ml = store.logFor(day).metrics['water'] ?? 0;
    final glasses = (ml / _glass).round();
    final reached = glasses >= _goalGlasses;
    return Row(
      children: [
        const SizedBox(width: Space.margin, child: MonoLabel('Water')),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$glasses', style: Almanac.numeral(context, size: 26, weight: 340)),
                  TextSpan(
                    text: reached ? ' glasses, goal reached' : ' of $_goalGlasses glasses',
                    style: Almanac.italic(context, size: 15, color: p.ink2),
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Gap.v8,
              Row(
                children: [
                  for (var i = 0; i < _goalGlasses; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: AnimatedContainer(
                        duration: Motion.medium,
                        curve: Motion.curve,
                        height: i < glasses ? 3 : 1,
                        color: i < glasses ? p.ink : p.hairline,
                      ),
                    ),
                  ],
                ],
              ),
              Gap.v4,
              Text('${ml.round()} ml · goal ${(_goalGlasses * _glass).round()} ml', style: Almanac.data(context, size: 11.5)),
            ],
          ),
        ),
        Gap.h8,
        ThinStepper(
          minusTooltip: 'Remove a glass',
          plusTooltip: 'Add a glass, 250 ml',
          onMinus: ml <= 0 ? null : () => store.setMetric(day, 'water', ml - _glass <= 0 ? null : ml - _glass),
          onPlus: () => store.setMetric(day, 'water', ml + _glass),
        ),
      ],
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.day});

  final DateTime day;

  Future<void> _edit(BuildContext context, AppStore store, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Note for ${fmtShort(day)}'),
        content: SizedBox(
          width: 420,
          child: LinedPaperField(controller: ctrl, autofocus: true, hintText: 'Write anything you want to remember'),
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
    final p = BloomColors.of(context);
    final note = store.logFor(day).note;
    return Pressable(
      onTap: () => _edit(context, store, note),
      semanticLabel: note.isEmpty ? 'Add a note' : 'Edit note',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Marginalia(
          label: 'Note',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.isEmpty ? 'Add a quick note' : note,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: note.isEmpty
                      ? Almanac.italic(context, size: 16, color: p.ink2)
                      : Almanac.serif(size: 16, weight: 330, color: p.ink, height: 1.5),
                ),
              ),
              Gap.h8,
              Icon(note.isEmpty ? Icons.add : Icons.edit_outlined, size: 18, color: p.ink2),
            ],
          ),
        ),
      ),
    );
  }
}
