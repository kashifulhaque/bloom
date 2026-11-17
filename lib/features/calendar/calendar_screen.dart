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

bool _inPregnancy(DateTime? lmp, DateTime d) =>
    lmp != null && !d.isBefore(lmp) && daysBetween(lmp, d) < _pregnancyDays;

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
    return Scaffold(
      body: BloomPage(
        title: 'Calendar',
        subtitle: _summary(store, lmp),
        actions: [
          FilledButton.tonal(
            onPressed: _jumpToday,
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Today'),
          ),
          IconButton(
            tooltip: 'Edit period dates',
            icon: const Icon(Icons.edit_calendar_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EditPeriodScreen()),
            ),
          ),
        ],
        children: [
          Center(
            child: SizedBox(
              width: 280,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.calendar_view_month_rounded), label: Text('Month')),
                  ButtonSegment(value: true, icon: Icon(Icons.grid_view_rounded), label: Text('Year')),
                ],
                selected: {_yearView},
                onSelectionChanged: (s) => _setView(s.first),
              ),
            ),
          ),
          if (_yearView) ..._buildYear(store, lmp) else ..._buildMonth(store, lmp),
        ],
      ),
    );
  }

  List<Widget> _buildMonth(AppStore store, DateTime? lmp) {
    final theme = Theme.of(context);
    final month = _month;
    return [
      BloomCard(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.lg),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _goToMonth(addMonths(month, -1)),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    switchInCurve: Motion.curve,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: Row(
                      key: ValueKey(month),
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            DateFormat.MMMM().format(month),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        Gap.h8,
                        Text(
                          '${month.year}',
                          style: theme.textTheme.titleMedium?.copyWith(color: BloomTokens.of(context).muted),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _goToMonth(addMonths(month, 1)),
                ),
              ],
            ),
            Gap.v12,
            WeekdayHeader(firstDayOfWeek: store.profile.firstDayOfWeek),
            Gap.v8,
            LayoutBuilder(builder: (context, box) {
              final cellW = box.maxWidth / 7;
              final cellH = (cellW * 1.15).clamp(48.0, 60.0);
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
                    onTap: (d) => setState(() => _selected = d),
                  ),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Divider(height: 1, color: BloomTokens.of(context).border),
            ),
            CalendarLegend(showPregnancy: lmp != null),
          ],
        ),
      ),
      AnimatedSize(
        duration: Motion.medium,
        curve: Motion.curve,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: Motion.medium,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: DayDetailPanel(key: ValueKey(_selected), day: _selected),
        ),
      ),
    ];
  }

  List<Widget> _buildYear(AppStore store, DateTime? lmp) {
    final theme = Theme.of(context);
    return [
      Row(
        children: [
          IconButton(
            tooltip: 'Previous year',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() => _year--),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: Text(
                '$_year',
                key: ValueKey(_year),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next year',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => setState(() => _year++),
          ),
        ],
      ),
      LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 520 ? 3 : 2;
        const gap = Space.md;
        final tileW = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
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
      }),
      BloomCard.outlined(
        padding: Insets.cardCompact,
        child: CalendarLegend(showPregnancy: lmp != null),
      ),
    ];
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
    final theme = Theme.of(context);
    final blanks = leadingBlanks(month, store.profile.firstDayOfWeek);
    final days = daysInMonth(month);
    final now = today();
    final scheme = theme.colorScheme;
    // Ring area: the circle plus room for the today ring, leaving space for
    // the logged dot underneath.
    final outer = math.min(cellW - Space.sm, cellH - 13);
    final circle = outer - DayCircle.todayRingExtent;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: (circle * 0.42).clamp(12.0, 16.0));
    return Column(
      children: [
        for (var row = 0; row < 6; row++)
          SizedBox(
            height: cellH,
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final n = row * 7 + col - blanks + 1;
                      if (n < 1 || n > days) return const SizedBox.shrink();
                      final d = DateTime(month.year, month.month, n);
                      final info = store.engine.info(d);
                      final isSelected = sameDay(d, selected);
                      final hasLog = store.logs[dayKey(d)]?.isEmpty == false;
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: fmtLong(d),
                        child: Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: AnimatedContainer(
                            duration: Motion.medium,
                            curve: Motion.curve,
                            decoration: BoxDecoration(
                              borderRadius: Radii.smAll,
                              color: isSelected ? scheme.primary.withValues(alpha: 0.09) : Colors.transparent,
                            ),
                            foregroundDecoration: BoxDecoration(
                              borderRadius: Radii.smAll,
                              border: Border.all(
                                color: isSelected ? scheme.primary.withValues(alpha: 0.45) : Colors.transparent,
                                width: 1.4,
                              ),
                            ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                key: ValueKey('day-${dayKey(d)}'),
                                borderRadius: Radii.smAll,
                                onTap: () => onTap(d),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox.square(
                                      dimension: outer,
                                      child: Center(
                                        child: DayCircle(
                                          style: DayStyle.fromInfo(info, pregnancy: _inPregnancy(lmp, d)),
                                          label: '$n',
                                          isToday: sameDay(d, now),
                                          size: circle,
                                          textStyle: textStyle,
                                          compact: false,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    LoggedDot(visible: hasLog),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
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
    final blanks = leadingBlanks(month, store.profile.firstDayOfWeek);
    final days = daysInMonth(month);
    final now = today();
    final isCurrent = month.year == now.year && month.month == now.month;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = ((blanks + days) / 7).ceil();
    return BloomCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.MMMM().format(month),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isCurrent ? scheme.primary : null,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                ),
            ],
          ),
          Gap.v8,
          WeekdayHeader(firstDayOfWeek: store.profile.firstDayOfWeek, compact: true),
          Gap.v4,
          LayoutBuilder(builder: (context, box) {
            final cellW = box.maxWidth / 7;
            final cell = math.min(cellW, 26.0);
            final textStyle = TextStyle(fontSize: (cell * 0.46).clamp(8.5, 11.0), letterSpacing: -0.2);
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
                                  child: Builder(builder: (context) {
                                    final n = row * 7 + col - blanks + 1;
                                    if (n < 1 || n > days) return const SizedBox.shrink();
                                    final d = DateTime(month.year, month.month, n);
                                    return Center(
                                      child: DayCircle(
                                        style: DayStyle.fromInfo(store.engine.info(d), pregnancy: _inPregnancy(lmp, d)),
                                        label: '$n',
                                        isToday: sameDay(d, now),
                                        size: cell - 2,
                                        compact: true,
                                        textStyle: textStyle,
                                      ),
                                    );
                                  }),
                                ),
                            ],
                          ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Details for one day: cycle day, phase, chance, logged entries, and actions.
class DayDetailPanel extends StatelessWidget {
  const DayDetailPanel({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final info = store.engine.info(day);
    final log = store.logs[dayKey(day)];
    final lmp = pregnancyLmp(store);
    final pregnant = _inPregnancy(lmp, day);
    final isFuture = day.isAfter(today());
    final isPeriod = store.isPeriodDay(day);

    final facts = <String>[];
    if (pregnant) {
      final days = daysBetween(lmp!, day);
      facts.add('Pregnancy week ${days ~/ 7 + 1} (${days ~/ 7}w ${days % 7}d)');
    } else {
      if (info.cycleDay != null) facts.add('Cycle day ${info.cycleDay}');
      if (info.phase != null) facts.add(info.phase!.label);
    }

    String? status;
    Color? statusColor;
    IconData? statusIcon;
    if (pregnant) {
      status = 'Pregnancy';
      statusColor = BloomColors.pregnancy;
      statusIcon = Icons.child_friendly_rounded;
    } else if (info.isPeriod) {
      status = 'Period day';
      statusColor = BloomColors.period;
      statusIcon = Icons.water_drop_rounded;
    } else if (info.isPredictedPeriod) {
      status = 'Predicted period';
      statusColor = BloomColors.period;
      statusIcon = Icons.water_drop_outlined;
    } else if (info.isOvulation) {
      status = info.isPredicted ? 'Predicted ovulation' : 'Ovulation';
      statusColor = BloomColors.ovulation;
      statusIcon = Icons.egg_alt_rounded;
    } else if (info.isFertile) {
      status = info.isPredicted ? 'Predicted fertile day' : 'Fertile window';
      statusColor = BloomColors.fertile;
      statusIcon = Icons.spa_rounded;
    }
    final emptyStatus = store.engine.hasData ? 'No period or fertile window' : 'Log a period to see predictions';
    final accent = statusColor ?? (info.phase != null ? phaseColor(info.phase!) : theme.colorScheme.primary);

    final chanceColor = switch (info.chance) {
      Chance.low => tokens.muted,
      Chance.medium => BloomColors.fertile,
      Chance.high => BloomColors.ovulation,
    };

    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateBadge(day: day, color: accent),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmtLong(day), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: Space.xxs),
                      Text(facts.join(' · '), style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Gap.v16,
          if (status != null)
            PillChip(status, color: statusColor, icon: statusIcon)
          else
            PillChip(emptyStatus, color: theme.colorScheme.secondary, icon: Icons.radio_button_unchecked_rounded),
          if (!pregnant && info.cycleDay != null) ...[
            Gap.v12,
            _StatRow(
              icon: Icons.favorite_rounded,
              iconColor: chanceColor == tokens.muted ? BloomColors.brand : chanceColor,
              label: 'Chance of getting pregnant',
              trailing: PillChip(info.chance.label, color: chanceColor == tokens.muted ? theme.colorScheme.secondary : chanceColor, dense: true),
            ),
          ],
          if (info.isPredicted && !pregnant)
            const Disclaimer(text: 'Predictions are estimates and are not a form of birth control.'),
          Gap.v8,
          Divider(height: Space.xxl, color: tokens.border),
          if (log != null && !log.isEmpty)
            _LoggedEntries(log: log, store: store)
          else
            Row(
              children: [
                Icon(isFuture ? Icons.schedule_rounded : Icons.edit_note_rounded, size: 20, color: tokens.muted),
                Gap.h8,
                Expanded(
                  child: Text(
                    isFuture ? 'You can log this day when it comes.' : 'Nothing logged for this day.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted),
                  ),
                ),
              ],
            ),
          Gap.v20,
          LayoutBuilder(builder: (context, box) {
            final log = FilledButton.icon(
              onPressed: isFuture ? null : () => showLogSheet(context, day),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log symptoms'),
            );
            final mark = OutlinedButton.icon(
              onPressed: isFuture ? null : () => store.setPeriodDay(day, !isPeriod),
              icon: Icon(isPeriod ? Icons.remove_circle_outline_rounded : Icons.water_drop_outlined),
              label: Text(isPeriod ? 'Unmark period day' : 'Mark period day', overflow: TextOverflow.ellipsis),
            );
            if (box.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [log, Gap.v8, mark],
              );
            }
            return Row(children: [Expanded(child: log), Gap.h12, Expanded(child: mark)]);
          }),
        ],
      ),
    );
  }
}

/// A tinted square with the weekday and day number, in the day's phase color.
class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.day, required this.color});
  final DateTime day;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = readableTint(color, theme.brightness);
    return AnimatedContainer(
      duration: Motion.medium,
      width: 60,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.13),
        borderRadius: Radii.mdAll,
        border: Border.all(color: color.withValues(alpha: dark ? 0.35 : 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat.E().format(day).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
          Text(
            '${day.day}',
            style: theme.textTheme.headlineSmall?.copyWith(color: fg, height: 1.1),
          ),
        ],
      ),
    );
  }
}

/// A compact label and value row inside the day panel.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.trailing, this.icon, this.emoji, this.iconColor});
  final String label;
  final Widget trailing;
  final IconData? icon;
  final String? emoji;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          IconBadge(icon: icon, emoji: emoji, color: iconColor, size: 32),
          Gap.h12,
          Expanded(
            child: Text(label, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
          ),
          Gap.h8,
          trailing,
        ],
      ),
    );
  }
}

class _LoggedEntries extends StatelessWidget {
  const _LoggedEntries({required this.log, required this.store});
  final DayLog log;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final chips = <Widget>[];
    for (final cat in kCategories) {
      for (final id in log.get(cat.id)) {
        final opt = cat.option(id);
        chips.add(PillChip(optionLabel(cat.id, id), emoji: opt?.emoji ?? cat.emoji, color: Color(cat.colorHex)));
      }
    }
    // Categories not in the catalog (for example from a newer backup).
    for (final e in log.selections.entries) {
      if (categoryById(e.key) != null) continue;
      for (final id in e.value) {
        chips.add(PillChip(optionLabel(e.key, id), color: theme.colorScheme.secondary));
      }
    }
    final metrics = <Widget>[];
    for (final m in kMetrics) {
      final v = log.metrics[m.id];
      if (v == null) continue;
      metrics.add(_StatRow(
        emoji: m.emoji,
        iconColor: theme.colorScheme.secondary,
        label: m.title,
        trailing: Text(
          formatMetric(m.id, v, store.profile),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ));
    }
    final heading = theme.textTheme.labelMedium?.copyWith(color: tokens.muted, letterSpacing: 0.8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LOGGED', style: heading),
        Gap.v12,
        if (chips.isNotEmpty) Wrap(spacing: Space.sm, runSpacing: Space.sm, children: chips),
        if (metrics.isNotEmpty) ...[
          if (chips.isNotEmpty) Gap.v12,
          ...metrics,
        ],
        if (log.note.trim().isNotEmpty) ...[
          Gap.v12,
          Container(
            width: double.infinity,
            padding: Insets.all12,
            decoration: BoxDecoration(color: tokens.subtle, borderRadius: Radii.mdAll),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_rounded, size: 18, color: tokens.muted),
                Gap.h8,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Note', style: theme.textTheme.labelLarge),
                      const SizedBox(height: Space.xxs),
                      Text(log.note, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
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
