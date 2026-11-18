/// Edit-period-dates mode: tick period days across several months, then save.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'calendar_widgets.dart';

/// Months of history shown before the current month.
const _monthsBack = 12;

/// Months shown after the current month.
const _monthsAhead = 2;

/// Days after today that can still be marked (to log an expected period).
const _selectableAhead = 10;

class EditPeriodScreen extends StatefulWidget {
  const EditPeriodScreen({super.key});

  @override
  State<EditPeriodScreen> createState() => _EditPeriodScreenState();
}

class _EditPeriodScreenState extends State<EditPeriodScreen> {
  late final DateTime _now = today();
  late final DateTime _from = addMonths(monthOf(_now), -_monthsBack);
  late final DateTime _to = addDays(addMonths(monthOf(_now), _monthsAhead + 1), -1);
  late final DateTime _lastSelectable = addDays(_now, _selectableAhead);
  late final Set<String> _initial;
  late final Set<String> _selected;
  final _centerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _initial = store.periodDays.where((k) {
      final d = parseDayKey(k);
      return !d.isBefore(_from) && !d.isAfter(_to);
    }).toSet();
    _selected = {..._initial};
  }

  bool get _dirty => _selected.length != _initial.length || !_selected.containsAll(_initial);

  int get _changes => _selected.difference(_initial).length + _initial.difference(_selected).length;

  void _toggle(DateTime d) {
    if (d.isAfter(_lastSelectable)) return;
    final k = dayKey(d);
    setState(() => _selected.contains(k) ? _selected.remove(k) : _selected.add(k));
  }

  void _save() {
    context.read<AppStore>().setPeriodDaysInRange(_from, _to, _selected.map(parseDayKey).toSet());
    Navigator.of(context).pop();
  }

  Future<void> _cancel() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your period date changes will not be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final firstDay = context.select<AppStore, int>((s) => s.profile.firstDayOfWeek);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Space.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.gutter, 0),
                    child: IconButton(
                      tooltip: 'Cancel',
                      icon: Icon(Icons.close, size: 20, color: p.ink),
                      onPressed: _cancel,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MonoLabel('Edit'),
                        Gap.v8,
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Period '),
                              TextSpan(
                                text: 'dates',
                                style: Almanac.serif(size: 34, weight: 300, italic: true, color: p.period),
                              ),
                            ],
                          ),
                          style: theme.textTheme.headlineLarge,
                        ),
                        Gap.v8,
                        Text(
                          'Tap days to mark or clear them as period days.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: p.ink2),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
                    child: Column(
                      children: [
                        WeekdayHeader(firstDayOfWeek: firstDay),
                        Gap.v8,
                        const Hairline(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final cell = math.min((box.maxWidth - Space.gutter * 2) / 7, 56.0);
                        Widget month(DateTime m) => _EditableMonth(
                          month: m,
                          firstDayOfWeek: firstDay,
                          cell: cell,
                          now: _now,
                          lastSelectable: _lastSelectable,
                          selected: _selected,
                          onToggle: _toggle,
                        );
                        // Opens on the current month: past months scroll up, future ones down.
                        return CustomScrollView(
                          center: _centerKey,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                              sliver: SliverList.builder(
                                itemCount: _monthsBack,
                                itemBuilder: (context, i) => month(addMonths(monthOf(_now), -1 - i)),
                              ),
                            ),
                            SliverPadding(
                              key: _centerKey,
                              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
                              sliver: SliverList.builder(
                                itemCount: _monthsAhead + 1,
                                itemBuilder: (context, i) => month(addMonths(monthOf(_now), i)),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _SaveBar(marked: _selected.length, changes: _changes, onSave: _save),
      ),
    );
  }
}

/// The sticky bar at the bottom: a count of marked days, the unsaved
/// changes, and the ink Save button.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.marked, required this.changes, required this.onSave});
  final int marked;
  final int changes;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border(top: BorderSide(color: p.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Space.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '$marked', style: Almanac.numeral(context, size: 26, weight: 340)),
                              TextSpan(
                                text: marked == 1 ? ' period day' : ' period days',
                                style: Almanac.italic(context, size: 16, color: p.ink2),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: Motion.fast,
                          child: MonoLabel(
                            changes == 0
                                ? 'No changes yet'
                                : (changes == 1 ? '1 unsaved change' : '$changes unsaved changes'),
                            key: ValueKey(changes),
                            color: changes == 0 ? null : BloomColors.period,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.h12,
                  InkButton(label: 'Save', icon: Icons.check, onPressed: onSave),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableMonth extends StatelessWidget {
  const _EditableMonth({
    required this.month,
    required this.firstDayOfWeek,
    required this.cell,
    required this.now,
    required this.lastSelectable,
    required this.selected,
    required this.onToggle,
  });

  final DateTime month;
  final int firstDayOfWeek;
  final double cell;
  final DateTime now;
  final DateTime lastSelectable;
  final Set<String> selected;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final blanks = leadingBlanks(month, firstDayOfWeek);
    final days = daysInMonth(month);
    final rows = ((blanks + days) / 7).ceil();
    final count = [
      for (var n = 1; n <= days; n++)
        if (selected.contains(dayKey(DateTime(month.year, month.month, n)))) n,
    ].length;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, Space.xl, 0, Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${DateFormat.MMMM().format(month)} '),
                        TextSpan(
                          text: '${month.year}',
                          style: Almanac.serif(size: 20, weight: 300, italic: true, color: p.ink2),
                        ),
                      ],
                    ),
                    style: Almanac.serif(size: 20, weight: 380, color: p.ink),
                  ),
                ),
                AnimatedOpacity(
                  duration: Motion.fast,
                  opacity: count == 0 ? 0 : 1,
                  child: MonoLabel(count == 1 ? '1 day' : '$count days', color: BloomColors.period),
                ),
              ],
            ),
          ),
          for (var row = 0; row < rows; row++)
            SizedBox(
              height: cell,
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final n = row * 7 + col - blanks + 1;
                          if (n < 1 || n > days) return const SizedBox.shrink();
                          final d = DateTime(month.year, month.month, n);
                          final on = selected.contains(dayKey(d));
                          bool sel(int offset) {
                            final m = n + offset;
                            return m >= 1 &&
                                m <= days &&
                                selected.contains(dayKey(DateTime(month.year, month.month, m)));
                          }

                          final enabled = !d.isAfter(lastSelectable);
                          return _PeriodToggle(
                            key: ValueKey('edit-${dayKey(d)}'),
                            day: n,
                            on: on,
                            joinLeft: on && col > 0 && sel(-1),
                            joinRight: on && col < 6 && sel(1),
                            enabled: enabled,
                            isToday: sameDay(d, now),
                            size: math.min(cell * 0.72, 38),
                            onTap: () => onToggle(d),
                            label: fmtLong(d),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          Gap.v8,
          const Hairline(),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    super.key,
    required this.day,
    required this.on,
    required this.joinLeft,
    required this.joinRight,
    required this.enabled,
    required this.isToday,
    required this.size,
    required this.onTap,
    required this.label,
  });

  final int day;
  final bool on;

  /// The previous or next day in the same row is also selected; draws a
  /// faint band that links the days into one period.
  final bool joinLeft;
  final bool joinRight;
  final bool enabled;
  final bool isToday;
  final double size;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final band = dark ? p.period.withValues(alpha: 0.22) : p.periodSoft;
    final textColor = on
        ? BloomColors.onColor(p.period)
        : !enabled
        ? p.ink2.withValues(alpha: 0.45)
        : p.ink;
    return Semantics(
      checked: on,
      enabled: enabled,
      label: isToday ? '$label, today' : label,
      excludeSemantics: true,
      child: Pressable(
        onTap: enabled
            ? () {
                Almanac.tick();
                onTap();
              }
            : null,
        pressedOpacity: 0.7,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const SizedBox.expand(),
            Positioned(
              left: 0,
              right: 0,
              child: Row(
                children: [
                  Expanded(
                    child: Container(height: size * 0.62, color: joinLeft ? band : null),
                  ),
                  Expanded(
                    child: Container(height: size * 0.62, color: joinRight ? band : null),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: Motion.fast,
              curve: Motion.curve,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? p.period : Colors.transparent,
                // A faint ring marks the days that can be tapped.
                border: Border.all(color: on || !enabled ? Colors.transparent : p.hairline),
              ),
              child: Text(
                '$day',
                style: Almanac.serif(
                  size: (size * 0.45).clamp(13.0, 17.0),
                  weight: on || isToday ? 460 : 380,
                  color: textColor,
                  height: 1,
                  tabular: true,
                ),
              ),
            ),
            if (isToday)
              Positioned(
                bottom: 1,
                child: Container(width: size * 0.45, height: 1.5, color: p.ink),
              ),
          ],
        ),
      ),
    );
  }
}
