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
    final tokens = BloomTokens.of(context);
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
                    child: Row(
                      children: [
                        IconButton(tooltip: 'Cancel', icon: const Icon(Icons.close_rounded), onPressed: _cancel),
                        Gap.h4,
                        Expanded(
                          child: Text('Edit period dates',
                              overflow: TextOverflow.ellipsis, style: theme.textTheme.headlineSmall),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
                    child: Text(
                      'Tap days to mark or clear them as period days.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: tokens.border)),
                    ),
                    child: WeekdayHeader(firstDayOfWeek: firstDay),
                  ),
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      final cell = math.min((box.maxWidth - Space.md * 2) / 7, 64.0);
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
                            padding: const EdgeInsets.symmetric(horizontal: Space.md),
                            sliver: SliverList.builder(
                              itemCount: _monthsBack,
                              itemBuilder: (context, i) => month(addMonths(monthOf(_now), -1 - i)),
                            ),
                          ),
                          SliverPadding(
                            key: _centerKey,
                            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xxl),
                            sliver: SliverList.builder(
                              itemCount: _monthsAhead + 1,
                              itemBuilder: (context, i) => month(addMonths(monthOf(_now), i)),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _SaveBar(
          marked: _selected.length,
          changes: _changes,
          onSave: _save,
        ),
      ),
    );
  }
}

/// The sticky bar at the bottom with a summary of changes and the Save button.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.marked, required this.changes, required this.onSave});
  final int marked;
  final int changes;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final light = theme.brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: light ? Colors.white : theme.colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: tokens.border)),
        boxShadow: light ? tokens.raisedShadow : null,
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
                        Text(
                          marked == 1 ? '1 period day' : '$marked period days',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        AnimatedSwitcher(
                          duration: Motion.fast,
                          child: Text(
                            changes == 0 ? 'No changes yet' : (changes == 1 ? '1 unsaved change' : '$changes unsaved changes'),
                            key: ValueKey(changes),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: changes == 0 ? tokens.muted : readableTint(BloomColors.period, theme.brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.h12,
                  GradientButton(label: 'Save', icon: Icons.check_rounded, onPressed: onSave),
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
    final theme = Theme.of(context);
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
            padding: const EdgeInsets.fromLTRB(Space.sm, Space.lg, Space.sm, Space.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(DateFormat.yMMMM().format(month), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                AnimatedOpacity(
                  duration: Motion.fast,
                  opacity: count == 0 ? 0 : 1,
                  child: PillChip(count == 1 ? '1 day' : '$count days', color: BloomColors.period, icon: Icons.water_drop_rounded, dense: true),
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
                    Expanded(child: Builder(builder: (context) {
                      final n = row * 7 + col - blanks + 1;
                      if (n < 1 || n > days) return const SizedBox.shrink();
                      final d = DateTime(month.year, month.month, n);
                      final on = selected.contains(dayKey(d));
                      bool sel(int offset) {
                        final m = n + offset;
                        return m >= 1 && m <= days && selected.contains(dayKey(DateTime(month.year, month.month, m)));
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
                        size: cell * 0.72,
                        onTap: () => onToggle(d),
                        label: fmtLong(d),
                      );
                    })),
                ],
              ),
            ),
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
  /// soft band that links the days into one period.
  final bool joinLeft;
  final bool joinRight;
  final bool enabled;
  final bool isToday;
  final double size;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final tokens = BloomTokens.of(context);
    final band = BloomColors.period.withValues(alpha: dark ? 0.28 : 0.18);
    final textColor = on
        ? Colors.white
        : !enabled
            ? tokens.muted.withValues(alpha: 0.5)
            : isToday
                ? scheme.primary
                : scheme.onSurface;
    return Semantics(
      checked: on,
      enabled: enabled,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 0,
              child: Row(
                children: [
                  Expanded(child: Container(height: size, color: joinLeft ? band : null)),
                  Expanded(child: Container(height: size, color: joinRight ? band : null)),
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
                gradient: on ? BloomGradients.period : null,
                color: on ? null : (enabled ? (dark ? scheme.surfaceContainer : Colors.white) : Colors.transparent),
                border: on
                    ? null
                    : Border.all(
                        color: isToday
                            ? scheme.primary
                            : enabled
                                ? BloomColors.predicted.withValues(alpha: 0.7)
                                : tokens.border,
                        width: isToday ? 1.8 : 1.2,
                      ),
              ),
              child: Text(
                '$day',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: textColor,
                  fontWeight: on || isToday ? FontWeight.w800 : FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
