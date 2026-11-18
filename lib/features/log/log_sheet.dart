/// The daily log sheet: period toggle, every tracker, numeric metrics, and a
/// note for one day. Every change saves to the store immediately.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/units.dart';
import '../../widgets/widgets.dart';
import 'almanac_rows.dart';
import 'edit_trackers_screen.dart';
import 'tracker_style.dart';
import 'trackers.dart';

/// Opens the daily log sheet for [day].
Future<void> showLogSheet(BuildContext context, DateTime day) async {
  await showAppBottomSheet<void>(
    context,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (ctx, scroll) => LogSheetBody(day: dayOf(day), scrollController: scroll),
    ),
  );
}

/// Content of the log sheet. Public so it can also be pushed as a page.
class LogSheetBody extends StatefulWidget {
  const LogSheetBody({super.key, required this.day, this.scrollController});

  final DateTime day;
  final ScrollController? scrollController;

  @override
  State<LogSheetBody> createState() => _LogSheetBodyState();
}

class _LogSheetBodyState extends State<LogSheetBody> {
  late DateTime _day = widget.day;
  String _query = '';
  final _searchCtrl = TextEditingController();

  /// Direction of the last day change, for the header slide.
  int _dir = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _dayLabel(DateTime d) {
    final diff = daysBetween(d, today());
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return DateFormat('d MMMM').format(d);
  }

  void _shift(int dir) => setState(() {
        _dir = dir;
        _day = addDays(_day, dir);
      });

  void _editTrackers() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditTrackersScreen()));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final profile = store.profile;
    final log = store.logFor(_day);
    final q = _query.trim().toLowerCase();
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final info = store.engine.info(_day);

    bool matches(String s) => q.isEmpty || s.toLowerCase().contains(q);

    final trackers = orderedTrackers(profile);
    final sections = <Widget>[];
    for (final tr in trackers) {
      final cat = tr.category;
      if (cat != null) {
        final opts = matches(cat.title) ? cat.options : cat.options.where((o) => matches(o.label)).toList();
        if (opts.isEmpty) continue;
        sections.add(_CategorySection(category: cat, options: opts, day: _day, log: log));
      } else {
        final m = tr.metric!;
        if (!matches(m.title)) continue;
        sections.add(_MetricSection(metric: m, day: _day, value: log.metrics[m.id], profile: profile, store: store));
      }
    }

    final showPeriod = profile.goal != Goal.trackPregnancy && (matches('period') || matches('bleeding'));
    final eyebrow = [
      DateFormat('EEE, d MMM').format(_day),
      if (info.cycleDay != null) 'Cycle day ${info.cycleDay}',
    ].join(' · ');

    final children = <Widget>[
      if (showPeriod) _PeriodToggle(day: _day),
      ...sections,
      if (sections.isEmpty && q.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Space.xl),
          child: EmptyState(
            compact: true,
            title: 'No matches',
            body: 'Nothing matches "$_query". Try another word, or turn on more categories.',
            action: InkLink('Edit categories', onTap: _editTrackers),
          ),
        ),
      if (q.isEmpty) ...[
        _NoteField(key: ValueKey(dayKey(_day)), day: _day, initial: log.note),
        Padding(
          padding: const EdgeInsets.only(top: Space.lg),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkLink('Edit categories', icon: Icons.tune, arrow: true, size: 13.5, onTap: _editTrackers),
          ),
        ),
      ],
    ];

    return Column(
      children: [
        // Day header: mono date, serif day name, thin arrows.
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.md, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.curve,
                  layoutBuilder: (current, previous) =>
                      Stack(alignment: Alignment.bottomLeft, children: [...previous, ?current]),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: Offset(0.06 * _dir, 0), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(dayKey(_day)),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoLabel(eyebrow, maxLines: 1),
                      Gap.v4,
                      Text(
                        _dayLabel(_day),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ),
              ThinIconButton(icon: Icons.chevron_left, tooltip: 'Previous day', boxed: false, onTap: () => _shift(-1)),
              ThinIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Next day',
                boxed: false,
                onTap: _day.isBefore(today()) ? () => _shift(1) : null,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.md, Space.xs),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search symptoms and moods',
                    prefixIcon: Icon(Icons.search, size: 18, color: p.ink2),
                    prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 36),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: Icon(Icons.close, size: 18, color: p.ink2),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _query = '';
                            }),
                          ),
                  ),
                ),
              ),
              Gap.h4,
              IconButton(
                tooltip: 'Edit categories',
                icon: Icon(Icons.tune, size: 20, color: p.ink2),
                onPressed: _editTrackers,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
            itemCount: children.length,
            itemBuilder: (_, i) => children[i],
          ),
        ),
        // Pinned Done button on a hairline.
        DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.md),
              child: InkButton(label: 'Done', expanded: true, onPressed: () => Navigator.of(context).maybePop()),
            ),
          ),
        ),
      ],
    );
  }
}

/// The opener of a tracker section: a dot, a mono category name, and a
/// trailing mono status or widget.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.color, this.trailing});
  final String title;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 32,
        child: Row(
          children: [
            ToneDot(color),
            Gap.h8,
            Expanded(child: MonoLabel(title, maxLines: 1)),
            ?trailing,
          ],
        ),
      );
}

/// A tracker section: hairline on top, then its content.
class _Ruled extends StatelessWidget {
  const _Ruled({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Hairline(),
          Padding(padding: const EdgeInsets.only(top: Space.md, bottom: Space.xl), child: child),
        ],
      );
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final on = store.isPeriodDay(day);
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    void toggle(bool v) {
      Almanac.tick();
      store.setPeriodDay(day, v);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Pressable(
        onTap: () => toggle(!on),
        child: Row(
          children: [
            const ToneDot(BloomColors.period, size: 8),
            Gap.h12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Period day',
                      style: Almanac.serif(
                          size: 20,
                          weight: 380,
                          color: on ? readableTint(BloomColors.period, theme.brightness) : p.ink)),
                  Text(
                    on ? 'Marked as a day of your period' : 'Mark this day as a day of your period',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            InkSwitch(value: on, onChanged: toggle, semanticLabel: 'Period day'),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.options, required this.day, required this.log});

  final LogCategory category;
  final List<LogOption> options;
  final DateTime day;
  final DayLog log;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final color = categoryColor(category.id);
    final single = category.kind == CategoryKind.single;
    final picked = options.where((o) => log.has(category.id, o.id)).length;
    return _Ruled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: category.title,
            color: color,
            trailing: AnimatedSwitcher(
              duration: Motion.medium,
              child: Text(
                picked > 0
                    ? (single ? 'Picked' : '$picked selected')
                    : single
                        ? 'Pick one'
                        : '',
                key: ValueKey('$picked'),
                style: Almanac.data(context, size: 11.5),
              ),
            ),
          ),
          Gap.v8,
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final o in options)
                SelectChip(
                  label: o.label,
                  color: color,
                  showCheck: false,
                  selected: log.has(category.id, o.id),
                  onSelected: (_) {
                    Almanac.tick();
                    store.toggleOption(day, category.id, o.id, single: single);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Converts a metric between storage (metric) units and display units.
class _MetricView {
  _MetricView(this.metric, this.profile);
  final MetricDef metric;
  final Profile profile;

  bool get _f => metric.id == 'bbt' && profile.tempUnit == TempUnit.fahrenheit;
  bool get _lb => metric.id == 'weight' && profile.weightUnit == WeightUnit.lb;

  double toDisplay(double v) => _f ? cToF(v) : _lb ? kgToLb(v) : v;
  double fromDisplay(double v) => _f ? fToC(v) : _lb ? lbToKg(v) : v;

  double get step => switch (metric.id) {
        'bbt' => _f ? 0.1 : 0.05,
        'weight' => _lb ? 0.2 : 0.1,
        _ => metric.step,
      };

  String get unit => switch (metric.id) {
        'bbt' => _f ? '°F' : '°C',
        'weight' => _lb ? 'lb' : 'kg',
        'sleep' => 'hours',
        'steps' => 'steps',
        'water' => 'ml',
        _ => metric.unit,
      };

  int get decimals => switch (metric.id) {
        'bbt' => 2,
        'weight' || 'sleep' => 1,
        _ => 0,
      };

  String format(double stored) {
    final v = toDisplay(stored);
    return switch (metric.id) {
      'water' => '${(stored / 250).round()} glasses · ${stored.round()} ml',
      'sleep' => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} h',
      'steps' => '${v.round()} steps',
      'bbt' => fmtTemp(stored, profile.tempUnit),
      'weight' => fmtWeight(stored, profile.weightUnit),
      _ => '${v.toStringAsFixed(decimals)} $unit',
    };
  }
}

class _MetricSection extends StatelessWidget {
  const _MetricSection(
      {required this.metric, required this.day, required this.value, required this.profile, required this.store});

  final MetricDef metric;
  final DateTime day;
  final double? value;
  final Profile profile;
  final AppStore store;

  static const _glass = 250.0;
  static const _glassGoal = 8;
  static const _sleepMax = 12.0;

  /// A sensible starting value: the latest logged value, or a typical one.
  double _startValue() {
    final recent = store.logs.values.where((l) => l.metrics.containsKey(metric.id)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (recent.isNotEmpty && (metric.id == 'weight' || metric.id == 'bbt')) return recent.first.metrics[metric.id]!;
    return switch (metric.id) {
      'water' => 0,
      'sleep' => 7,
      'weight' => 60,
      'bbt' => 36.5,
      'steps' => 0,
      _ => metric.min,
    };
  }

  void _set(double? v) {
    if (v == null) return store.setMetric(day, metric.id, null);
    final clamped = v.clamp(metric.min, metric.max).toDouble();
    store.setMetric(day, metric.id, double.parse(clamped.toStringAsFixed(3)));
  }

  Future<void> _typeValue(BuildContext context, _MetricView view) async {
    final ctrl = TextEditingController(
        text: value == null ? '' : view.toDisplay(value!).toStringAsFixed(view.decimals));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(metric.title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: view.unit),
          onSubmitted: (s) => Navigator.pop(ctx, double.tryParse(s.replaceAll(',', '.'))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.replaceAll(',', '.'))),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) _set(view.fromDisplay(result));
  }

  @override
  Widget build(BuildContext context) {
    final view = _MetricView(metric, profile);
    final p = BloomColors.of(context);
    final color = metricColor(metric.id);
    final clear = AnimatedSwitcher(
      duration: Motion.fast,
      child: value == null
          ? const SizedBox.shrink()
          : InkLink('Clear', key: const ValueKey('clear'), size: 12.5, color: p.ink2, onTap: () => _set(null)),
    );
    final header = _SectionTitle(title: metric.title, color: color, trailing: clear);

    Widget section(List<Widget> children) => _Ruled(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, Gap.v4, ...children]),
        );

    if (metric.id == 'energy') {
      const labels = ['Very low', 'Low', 'Okay', 'Good', 'Great'];
      return section([
        Gap.v4,
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (var i = 1; i <= 5; i++)
              SelectChip(
                label: labels[i - 1],
                color: color,
                showCheck: false,
                selected: value?.round() == i,
                onSelected: (on) => _set(on ? i.toDouble() : null),
              ),
          ],
        ),
      ]);
    }

    final display = value == null ? 'Not logged' : view.format(value!);
    final displayStep = view.step;

    void bump(int dir) {
      Almanac.tick();
      if (value == null && dir > 0 && metric.id != 'water' && metric.id != 'steps') {
        _set(_startValue());
        return;
      }
      final current = view.toDisplay(value ?? _startValue());
      final next = current + dir * displayStep;
      if (dir < 0 && value != null && (metric.id == 'water' || metric.id == 'steps') && next <= 0) {
        _set(null);
        return;
      }
      _set(view.fromDisplay(next));
    }

    // A ledger row: the value in serif (tap to type) and a thin stepper.
    final row = Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: () => _typeValue(context, view),
            semanticLabel: '${metric.title}: $display. Tap to type a value',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: Motion.fast,
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                    child: Text(
                      display,
                      key: ValueKey(display),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: value == null
                          ? Almanac.italic(context, size: 20, color: p.ink2)
                          : Almanac.serif(size: 22, weight: 360, color: p.ink, tabular: true),
                    ),
                  ),
                  Text(metric.id == 'water' ? '1 glass = 250 ml · tap to type' : 'Tap to type',
                      style: Almanac.data(context, size: 11)),
                ],
              ),
            ),
          ),
        ),
        ThinStepper(
          minusTooltip: 'Decrease ${metric.title.toLowerCase()}',
          plusTooltip: 'Increase ${metric.title.toLowerCase()}',
          onMinus: value == null ? null : () => bump(-1),
          onPlus: () => bump(1),
        ),
      ],
    );

    if (metric.id == 'water') {
      final glasses = ((value ?? 0) / _glass).round();
      final extra = math.max(0, glasses - _glassGoal);
      return section([
        row,
        Gap.v8,
        Row(
          children: [
            for (var i = 0; i < _glassGoal; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Set water to ${i + 1} glasses',
                  excludeSemantics: true,
                  child: Pressable(
                    // Tapping the last filled glass empties it.
                    onTap: () => _set(i + 1 == glasses ? (i == 0 ? null : i * _glass) : (i + 1) * _glass),
                    child: SizedBox(
                      height: 32,
                      child: Center(
                        child: AnimatedContainer(
                          duration: Motion.medium,
                          curve: Motion.curve,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: i < glasses ? 3 : 1,
                          color: i < glasses ? p.ink : p.hairline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (extra > 0) ...[Gap.h8, Text('+$extra', style: Almanac.data(context))],
          ],
        ),
      ]);
    }

    if (metric.id == 'sleep') {
      return section([
        row,
        Slider(
          value: (value ?? 0).clamp(0.0, _sleepMax),
          min: 0,
          max: _sleepMax,
          divisions: 24,
          label: value == null ? null : view.format(value!),
          onChanged: (v) => _set(v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in ['0 h', '6 h', '12 h']) Text(l, style: Almanac.data(context, size: 11)),
            ],
          ),
        ),
      ]);
    }

    return section([row]);
  }
}

class _NoteField extends StatefulWidget {
  const _NoteField({super.key, required this.day, required this.initial});
  final DateTime day;
  final String initial;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final _ctrl = TextEditingController(text: widget.initial);
  late final AppStore _store;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _store = context.read<AppStore>();
  }

  void _save() {
    _debounce?.cancel();
    if (_ctrl.text != _store.logFor(widget.day).note) _store.setNote(widget.day, _ctrl.text);
  }

  @override
  void dispose() {
    // Save pending text after the tree is unlocked; the store outlives this widget.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      final store = _store, day = widget.day, text = _ctrl.text;
      Future.microtask(() {
        if (text != store.logFor(day).note) store.setNote(day, text);
      });
    }
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Ruled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(title: 'Note', color: BloomColors.ink2),
          Gap.v4,
          LinedPaperField(
            controller: _ctrl,
            minLines: 4,
            maxLines: 12,
            hintText: 'How are you feeling today?',
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), _save);
            },
          ),
        ],
      ),
    );
  }
}
