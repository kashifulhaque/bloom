/// Calendar tab: month and year views, legend, and a day-detail panel.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/units.dart';
import '../../widgets/widgets.dart';
import '../log/log_sheet.dart';
import 'calendar_widgets.dart';
import 'edit_period_screen.dart';

/// Days a pregnancy is drawn for after the last menstrual period.
const _pregnancyDays = 280;

DateTime? _parseDay(Object? v) {
  if (v is! String || v.length < 10) return null;
  try {
    return parseDayKey(v.substring(0, 10));
  } catch (_) {
    return null;
  }
}

/// Reads the pregnancy LMP set by the pregnancy feature, if any.
///
/// Falls back to a saved due date, and then to the onboarding answers, so
/// the calendar shows the pregnancy before the pregnancy screen first saves.
DateTime? pregnancyLmp(AppStore store) {
  if (store.profile.goal != Goal.trackPregnancy) return null;
  final data = store.feature<Object>('pregnancy');
  if (data is Map) {
    final lmp = _parseDay(data['lmp']);
    if (lmp != null) return lmp;
    final due = _parseDay(data['dueDate']);
    if (due != null) return addDays(due, -_pregnancyDays);
    return null;
  }
  final history = store.feature<Object>('pregnancy_history');
  if (history is List && history.isNotEmpty) return null;
  final ob = store.feature<Object>('onboarding');
  if (ob is! Map) return null;
  final lmp = _parseDay(ob['pregnancyLmp']);
  if (lmp != null) return lmp;
  final due = _parseDay(ob['dueDate']);
  return due == null ? null : addDays(due, -_pregnancyDays);
}

bool _inPregnancy(DateTime? lmp, DateTime d) => lmp != null && !d.isBefore(lmp) && daysBetween(lmp, d) < _pregnancyDays;

String _plural(int n, String one) => n == 1 ? '1 $one' : '$n ${one}s';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// Page index that shows the current month. Pages before it are the past.
  static const _basePage = 1200;

  final _pager = PageController(initialPage: _basePage);
  late final DateTime _baseMonth = monthOf(today());
  int _page = _basePage;
  bool _yearView = false;
  late int _year = _baseMonth.year;
  DateTime _selected = today();

  DateTime get _month => addMonths(_baseMonth, _page - _basePage);

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _goToMonth(DateTime month, {bool animate = true}) {
    final page = _basePage + monthsBetween(_baseMonth, month);
    setState(() {
      _yearView = false;
      _page = page;
    });
    if (!_pager.hasClients) return;
    if (animate && (page - _pager.page!.round()).abs() <= 2) {
      _pager.animateToPage(page, duration: Motion.medium, curve: Motion.curve);
    } else {
      _pager.jumpToPage(page);
    }
  }

  void _jumpToday() {
    setState(() {
      _selected = today();
      _year = today().year;
    });
    if (_yearView) {
      setState(() => _yearView = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToMonth(_baseMonth, animate: false));
    } else {
      _goToMonth(_baseMonth);
    }
  }

  void _openMonthFromYear(DateTime month) {
    setState(() {
      _yearView = false;
      _page = _basePage + monthsBetween(_baseMonth, month);
    });
    // The PageView is rebuilt after the switch; jump once it has clients.
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToMonth(month, animate: false));
  }

  void _setView(bool year) {
    if (year == _yearView) return;
    if (year) {
      setState(() {
        _year = _month.year;
        _yearView = true;
      });
    } else {
      _openMonthFromYear(DateTime(_year, _year == _baseMonth.year ? _baseMonth.month : 1));
    }
  }

  String _summary(AppStore store, DateTime? lmp) {
    final now = today();
    if (_inPregnancy(lmp, now)) {
      final d = daysBetween(lmp!, now);
      return 'Week ${d ~/ 7 + 1} of pregnancy';
    }
    final e = store.engine;
    if (!e.hasData) return 'Tap any day to see its details';
    if (e.isOnPeriod(now)) {
      final day = e.info(now).cycleDay;
      return day == null ? 'You are on your period' : 'Period · cycle day $day';
    }
    if (e.isLate) return 'Period is ${_plural(e.daysLate, 'day')} late';
    final n = e.daysUntilNextPeriod;
    if (n == null) return 'Tap any day to see its details';
    if (n == 0) return 'Period expected today';
    return 'Next period in ${_plural(n, 'day')}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final lmp = pregnancyLmp(store);
    final p = BloomColors.of(context);
    final title = _yearView
        ? Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'The year '),
                TextSpan(
                  text: '$_year',
                  style: Almanac.serif(size: 34, weight: 300, italic: true, color: p.ink2),
                ),
              ],
            ),
            key: ValueKey('y$_year'),
            style: Theme.of(context).textTheme.headlineLarge,
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${DateFormat.MMMM().format(_month)} '),
                TextSpan(
                  text: '${_month.year}',
                  style: Almanac.serif(size: 34, weight: 300, italic: true, color: p.ink2),
                ),
              ],
            ),
            key: ValueKey(_month),
            style: Theme.of(context).textTheme.headlineLarge,
          );
    return Scaffold(
      body: BloomPage(
        eyebrow: _summary(store, lmp),
        header: AnimatedSwitcher(
          duration: Motion.medium,
          switchInCurve: Motion.curve,
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
          child: title,
        ),
        actions: [
          IconButton(
            tooltip: 'Edit period dates',
            icon: Icon(Icons.edit_calendar_outlined, size: 20, color: p.ink2),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditPeriodScreen())),
          ),
        ],
        children: [
          _Controls(
            yearView: _yearView,
            onView: _setView,
            onToday: _jumpToday,
            onPrevious: _yearView ? () => setState(() => _year--) : () => _goToMonth(addMonths(_month, -1)),
            onNext: _yearView ? () => setState(() => _year++) : () => _goToMonth(addMonths(_month, 1)),
          ),
          if (_yearView) ..._buildYear(store, lmp) else ..._buildMonth(store, lmp),
        ],
      ),
    );
  }

  List<Widget> _buildMonth(AppStore store, DateTime? lmp) {
    return [
      Column(
        children: [
          WeekdayHeader(firstDayOfWeek: store.profile.firstDayOfWeek),
          Gap.v8,
          const Hairline(),
          Gap.v8,
          LayoutBuilder(
            builder: (context, box) {
              final cellW = box.maxWidth / 7;
              final cellH = (cellW * 1.1).clamp(52.0, 62.0);
              return SizedBox(
                height: cellH * 6,
                child: PageView.builder(
                  controller: _pager,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder: (context, page) => _MonthGrid(
                    month: addMonths(_baseMonth, page - _basePage),
                    cellW: cellW,
                    cellH: cellH,
                    store: store,
                    lmp: lmp,
                    selected: _selected,
                    onTap: (d) {
                      Almanac.tick();
                      setState(() => _selected = d);
                    },
                  ),
                ),
              );
            },
          ),
          const Hairline(spacing: Space.md),
          Align(
            alignment: Alignment.centerLeft,
            child: CalendarLegend(showPregnancy: lmp != null),
          ),
        ],
      ),
      Gap.v8,
      AnimatedSize(
        duration: Motion.medium,
        curve: Motion.curve,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: Motion.medium,
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
          child: DayDetailPanel(key: ValueKey(_selected), day: _selected),
        ),
      ),
    ];
  }

  List<Widget> _buildYear(AppStore store, DateTime? lmp) {
    return [
      LayoutBuilder(
        builder: (context, box) {
          final cols = box.maxWidth >= 520 ? 3 : 2;
          const gap = Space.xl;
          final tileW = (box.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: Space.xs,
            children: [
              for (var m = 1; m <= 12; m++)
                SizedBox(
                  width: tileW,
                  child: _MiniMonth(
                    month: DateTime(_year, m),
                    store: store,
                    lmp: lmp,
                    onTap: () => _openMonthFromYear(DateTime(_year, m)),
                  ),
                ),
            ],
          );
        },
      ),
      const Hairline(),
      CalendarLegend(showPregnancy: lmp != null),
    ];
  }
}

/// The row under the title: "Month · Year" text tabs on the left, then the
/// previous and next arrows around a "Today" link.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.yearView,
    required this.onView,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
  });

  final bool yearView;
  final ValueChanged<bool> onView;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final unit = yearView ? 'year' : 'month';
    Widget arrow(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20, color: p.ink),
    );
    return Transform.translate(
      offset: const Offset(-Space.xs, 0),
      child: Row(
        children: [
          TextTabs<bool>(options: const [(false, 'Month'), (true, 'Year')], selected: yearView, onSelected: onView),
          const Spacer(),
          arrow(Icons.chevron_left, 'Previous $unit', onPrevious),
          InkLink('Today', onTap: onToday, size: 14),
          Transform.translate(
            offset: const Offset(Space.sm, 0),
            child: arrow(Icons.chevron_right, 'Next $unit', onNext),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.cellW,
    required this.cellH,
    required this.store,
    required this.lmp,
    required this.selected,
    required this.onTap,
  });

  final DateTime month;
  final double cellW;
  final double cellH;
  final AppStore store;
  final DateTime? lmp;
  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final blanks = leadingBlanks(month, store.profile.firstDayOfWeek);
    final days = daysInMonth(month);
    final now = today();
    final circle = math.min(cellW - Space.sm, 34.0);
    final numeral = Almanac.serif(size: (circle * 0.52).clamp(14.0, 18.0), tabular: true);
    DayStyle styleOf(DateTime d) => DayStyle.fromInfo(store.engine.info(d), pregnancy: _inPregnancy(lmp, d));
    final styles = {for (var n = 0; n <= days + 1; n++) n: styleOf(DateTime(month.year, month.month, n))};
    final fertile = fertileWash(context);
    final pregnancy = pregnancyWash(context);
    return Column(
      children: [
        for (var row = 0; row < 6; row++)
          SizedBox(
            height: cellH,
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final n = row * 7 + col - blanks + 1;
                        if (n < 1 || n > days) return const SizedBox.shrink();
                        final d = DateTime(month.year, month.month, n);
                        final style = styles[n]!;
                        final isSelected = sameDay(d, selected);
                        final isToday = sameDay(d, now);
                        final hasLog = store.logs[dayKey(d)]?.isEmpty == false;
                        bool joins(int m) => styles[m]!.washed && styles[m]!.pregnancy == style.pregnancy;
                        final label = [
                          fmtLong(d),
                          if (isToday) 'today',
                          if (style.period) 'period',
                          if (style.isPredictedOnly) 'predicted period',
                          if (style.ovulation) 'ovulation' else if (style.fertile) 'fertile',
                          if (style.pregnancy) 'pregnancy',
                          if (hasLog) 'logged',
                        ].join(', ');
                        return Semantics(
                          button: true,
                          selected: isSelected,
                          label: label,
                          excludeSemantics: true,
                          child: Pressable(
                            key: ValueKey('day-${dayKey(d)}'),
                            onTap: () => onTap(d),
                            borderRadius: Radii.mdAll,
                            child: AnimatedContainer(
                              duration: Motion.medium,
                              curve: Motion.curve,
                              margin: const EdgeInsets.symmetric(vertical: 1),
                              decoration: BoxDecoration(
                                borderRadius: Radii.mdAll,
                                color: isSelected ? p.raised.withValues(alpha: 0.7) : Colors.transparent,
                              ),
                              // A foreground border takes no layout space, so wash bands meet edge to edge.
                              foregroundDecoration: BoxDecoration(
                                borderRadius: Radii.mdAll,
                                border: Border.all(
                                  color: isSelected ? p.ink2.withValues(alpha: 0.5) : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: circle,
                                    width: double.infinity,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (style.washed)
                                          Positioned.fill(
                                            child: Center(
                                              child: WashBand(
                                                color: style.pregnancy ? pregnancy : fertile,
                                                height: circle - 4,
                                                // Joins only inside the cell when selected, so the box stays clean.
                                                joinLeft: !isSelected && col > 0 && joins(n - 1),
                                                joinRight: !isSelected && col < 6 && joins(n + 1),
                                              ),
                                            ),
                                          ),
                                        DayCircle(
                                          style: style,
                                          label: '$n',
                                          isToday: isToday,
                                          size: circle,
                                          textStyle: numeral,
                                          compact: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TodayRule(visible: isToday, width: circle * 0.5),
                                  const SizedBox(height: 3),
                                  LoggedDot(visible: hasLog),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({required this.month, required this.store, required this.lmp, required this.onTap});
  final DateTime month;
  final AppStore store;
  final DateTime? lmp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final blanks = leadingBlanks(month, store.profile.firstDayOfWeek);
    final days = daysInMonth(month);
    final now = today();
    final isCurrent = month.year == now.year && month.month == now.month;
    final rows = ((blanks + days) / 7).ceil();
    final fertile = fertileWash(context);
    final pregnancy = pregnancyWash(context);
    DayStyle styleOf(DateTime d) => DayStyle.fromInfo(store.engine.info(d), pregnancy: _inPregnancy(lmp, d));
    final styles = {for (var n = 0; n <= days + 1; n++) n: styleOf(DateTime(month.year, month.month, n))};
    return Pressable(
      onTap: onTap,
      semanticLabel: DateFormat.yMMMM().format(month),
      borderRadius: Radii.smAll,
      child: Padding(
        padding: const EdgeInsets.only(top: Space.sm, bottom: Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Hairline(),
            Gap.v8,
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    DateFormat.MMMM().format(month),
                    overflow: TextOverflow.ellipsis,
                    style: Almanac.serif(size: 17, weight: isCurrent ? 450 : 360, color: p.ink),
                  ),
                ),
                if (isCurrent) Text('NOW', style: Almanac.label(context, size: 9)),
              ],
            ),
            Gap.v8,
            WeekdayHeader(firstDayOfWeek: store.profile.firstDayOfWeek, compact: true),
            Gap.v4,
            LayoutBuilder(
              builder: (context, box) {
                final cellW = box.maxWidth / 7;
                final cell = math.min(cellW, 22.0);
                final mark = cell - 3;
                final textStyle = Almanac.serif(size: (cell * 0.46).clamp(8.5, 10.5), tabular: true);
                return Column(
                  children: [
                    for (var row = 0; row < 6; row++)
                      SizedBox(
                        height: cell,
                        child: row >= rows
                            ? null
                            : Row(
                                children: [
                                  for (var col = 0; col < 7; col++)
                                    SizedBox(
                                      width: cellW,
                                      height: cell,
                                      child: Builder(
                                        builder: (context) {
                                          final n = row * 7 + col - blanks + 1;
                                          if (n < 1 || n > days) return const SizedBox.shrink();
                                          final d = DateTime(month.year, month.month, n);
                                          final style = styles[n]!;
                                          final isToday = sameDay(d, now);
                                          bool joins(int m) =>
                                              styles[m]!.washed && styles[m]!.pregnancy == style.pregnancy;
                                          return Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              if (style.washed)
                                                Positioned.fill(
                                                  child: Center(
                                                    child: WashBand(
                                                      color: style.pregnancy ? pregnancy : fertile,
                                                      height: mark - 2,
                                                      joinLeft: col > 0 && joins(n - 1),
                                                      joinRight: col < 6 && joins(n + 1),
                                                    ),
                                                  ),
                                                ),
                                              DayCircle(
                                                style: style,
                                                label: '$n',
                                                isToday: isToday,
                                                size: mark,
                                                compact: true,
                                                textStyle: textStyle,
                                              ),
                                              if (isToday)
                                                Positioned(
                                                  bottom: 0,
                                                  child: TodayRule(visible: true, width: mark * 0.55, thickness: 1.2),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Details for one day, set like a dated entry in a notebook: a mono date in
/// the margin, the serif date and italic phase, text tags, ledger rows, and
/// the day's actions.
class DayDetailPanel extends StatelessWidget {
  const DayDetailPanel({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final info = store.engine.info(day);
    final log = store.logs[dayKey(day)];
    final lmp = pregnancyLmp(store);
    final pregnant = _inPregnancy(lmp, day);
    final isFuture = day.isAfter(today());
    final isPeriod = store.isPeriodDay(day);

    // The italic line under the date: "Cycle day 11 · follicular."
    final spans = <InlineSpan>[];
    final quiet = Almanac.sans(size: 14, color: p.ink2, height: 1.4);
    if (pregnant) {
      final days = daysBetween(lmp!, day);
      spans.add(TextSpan(text: 'Pregnancy week ${days ~/ 7 + 1} ', style: quiet));
      spans.add(
        TextSpan(
          text: '(${days ~/ 7}w ${days % 7}d)',
          style: Almanac.italic(context, size: 16, color: readableTint(BloomColors.pregnancy, theme.brightness)),
        ),
      );
    } else {
      if (info.cycleDay != null) spans.add(TextSpan(text: 'Cycle day ${info.cycleDay}', style: quiet));
      if (info.phase != null) {
        if (spans.isNotEmpty) spans.add(TextSpan(text: ' · ', style: quiet));
        spans.add(
          TextSpan(
            text: '${info.phase!.label.toLowerCase()}.',
            style: Almanac.italic(context, size: 16.5, color: readableTint(phaseColor(info.phase!), theme.brightness)),
          ),
        );
      }
    }

    String? status;
    Color? statusColor;
    if (pregnant) {
      status = 'Pregnancy';
      statusColor = BloomColors.pregnancy;
    } else if (info.isPeriod) {
      status = 'Period day';
      statusColor = BloomColors.period;
    } else if (info.isPredictedPeriod) {
      status = 'Predicted period';
      statusColor = BloomColors.predicted;
    } else if (info.isOvulation) {
      status = info.isPredicted ? 'Predicted ovulation' : 'Ovulation';
      statusColor = BloomColors.ovulation;
    } else if (info.isFertile) {
      status = info.isPredicted ? 'Predicted fertile day' : 'Fertile window';
      statusColor = BloomColors.fertile;
    }
    final emptyStatus = store.engine.hasData ? 'No period or fertile window' : 'Log a period to see predictions';

    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Hairline(),
          Gap.v20,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: Space.margin,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, right: Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoLabel(DateFormat.E().format(day)),
                      const SizedBox(height: 2),
                      MonoLabel(DateFormat('d MMM').format(day)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmtLong(day), style: theme.textTheme.headlineSmall),
                    if (spans.isNotEmpty) ...[Gap.v4, Text.rich(TextSpan(children: spans))],
                    Gap.v12,
                    _Tag(status ?? emptyStatus, color: statusColor, hollow: status == null),
                  ],
                ),
              ),
            ],
          ),
          if (!pregnant && info.cycleDay != null) ...[
            Gap.v16,
            Marginalia(
              label: 'Odds',
              child: _LedgerRow(
                label: 'Chance of pregnancy',
                value: info.chance.label,
                color: switch (info.chance) {
                  Chance.low => null,
                  Chance.medium => BloomColors.fertile,
                  Chance.high => BloomColors.ovulation,
                },
              ),
            ),
          ],
          if (info.isPredicted && !pregnant) ...[
            Gap.v12,
            const Disclaimer(text: 'Predictions are estimates and are not a form of birth control.'),
          ],
          Gap.v16,
          if (log != null && !log.isEmpty)
            _LoggedEntries(log: log, store: store)
          else
            Marginalia(
              label: 'Logged',
              child: Text(
                isFuture ? 'You can log this day when it comes.' : 'Nothing logged for this day.',
                style: Almanac.italic(context, size: 16, color: p.ink2),
              ),
            ),
          Gap.v24,
          Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              InkButton(
                label: 'Log symptoms',
                icon: Icons.add,
                onPressed: isFuture ? null : () => showLogSheet(context, day),
              ),
              InkButton.outlined(
                label: isPeriod ? 'Unmark period day' : 'Mark period day',
                color: BloomColors.period,
                onPressed: isFuture
                    ? null
                    : () {
                        Almanac.tick();
                        store.setPeriodDay(day, !isPeriod);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A borderless text tag: a small colored dot and a label. [hollow] draws
/// the dot as a thin ring, for "nothing here" states.
class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.color, this.hollow = false});
  final String label;
  final Color? color;
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final c = color == null ? p.ink2 : BloomColors.resolve(context, color!);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hollow ? null : c,
            border: hollow ? Border.all(color: c) : null,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            style: Almanac.sans(size: 14, weight: FontWeight.w500, color: p.ink, height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// A ledger line: a label, a dotted leader, and a mono value on the right.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final c = color == null ? p.ink : readableTint(color!, Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.55),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Almanac.sans(size: 14, color: p.ink, height: 1.3),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, 4),
                child: SizedBox(height: 2, child: CustomPaint(painter: _LeaderPainter(p.ink2.withValues(alpha: 0.5)))),
              ),
            ),
            Text(
              value,
              maxLines: 1,
              style: Almanac.mono(size: 13, weight: FontWeight.w500, color: c),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderPainter extends CustomPainter {
  _LeaderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 1.0; x < size.width; x += 4) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.7, paint);
    }
  }

  @override
  bool shouldRepaint(_LeaderPainter old) => old.color != color;
}

/// The Almanac meaning color for a log category's tag dot.
Color _categoryColor(String id) => switch (id) {
  'flow' || 'clots' || 'products' => BloomColors.period,
  'discharge' || 'ovulation_test' => BloomColors.fertile,
  'mood' => BloomColors.luteal,
  'symptoms' || 'digestion' || 'pregnancy_symptoms' || 'postpartum' || 'menopause' => BloomColors.follicular,
  'pregnancy_test' => BloomColors.pregnancy,
  _ => BloomColors.ink2,
};

class _LoggedEntries extends StatelessWidget {
  const _LoggedEntries({required this.log, required this.store});
  final DayLog log;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final tags = <Widget>[];
    for (final cat in kCategories) {
      for (final id in log.get(cat.id)) {
        tags.add(_Tag(optionLabel(cat.id, id), color: _categoryColor(cat.id)));
      }
    }
    // Categories not in the catalog (for example from a newer backup).
    for (final e in log.selections.entries) {
      if (categoryById(e.key) != null) continue;
      for (final id in e.value) {
        tags.add(_Tag(optionLabel(e.key, id)));
      }
    }
    final metrics = <Widget>[
      for (final m in kMetrics)
        if (log.metrics[m.id] != null)
          _LedgerRow(label: m.title, value: formatMetric(m.id, log.metrics[m.id]!, store.profile)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty)
          Marginalia(
            label: 'Logged',
            child: Wrap(spacing: Space.lg, runSpacing: Space.sm, children: tags),
          ),
        if (metrics.isNotEmpty) ...[
          if (tags.isNotEmpty) Gap.v16,
          Marginalia(
            label: 'Metrics',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: metrics),
          ),
        ],
        if (log.note.trim().isNotEmpty) ...[
          Gap.v16,
          Marginalia(
            label: 'Note',
            child: Text(log.note, style: Almanac.italic(context, size: 16.5, color: p.ink).copyWith(height: 1.4)),
          ),
        ],
      ],
    );
  }
}

/// Formats a stored metric value in the user's display units.
String formatMetric(String id, double v, Profile p) => switch (id) {
  'bbt' => fmtTemp(v, p.tempUnit),
  'weight' => fmtWeight(v, p.weightUnit),
  'water' => '${v.round()} ml',
  'sleep' => '${_trim(v)} h',
  'steps' => NumberFormat.decimalPattern().format(v.round()),
  'energy' => '${v.round()}/5',
  _ => _trim(v),
};

String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
