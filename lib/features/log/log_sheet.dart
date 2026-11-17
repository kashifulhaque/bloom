/// The daily log sheet: period toggle, every tracker, numeric metrics, and a
/// note for one day. Every change saves to the store immediately.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/units.dart';
import '../../widgets/widgets.dart';
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
    return fmtLong(d);
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
    final tokens = BloomTokens.of(context);
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
    final subtitle = [
      if (daysBetween(_day, today()) <= 1 && daysBetween(_day, today()) >= -1) fmtLong(_day),
      if (info.cycleDay != null) 'Cycle day ${info.cycleDay}',
    ].join(' · ');

    final children = <Widget>[
      if (showPeriod) _PeriodToggle(day: _day),
      ...sections,
      if (sections.isEmpty && q.isNotEmpty)
        EmptyState(
          compact: true,
          icon: Icons.search_off_rounded,
          title: 'No matches',
          body: 'Nothing matches "$_query". Try another word, or turn on more categories.',
          action: TextButton(onPressed: _editTrackers, child: const Text('Edit categories')),
        ),
      if (q.isEmpty) ...[
        _NoteField(key: ValueKey(dayKey(_day)), day: _day, initial: log.note),
        Center(
          child: TextButton.icon(
            onPressed: _editTrackers,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Edit categories'),
          ),
        ),
      ],
    ];

    return Column(
      children: [
        // Day switcher.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Previous day',
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.emphasized,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: Offset(0.15 * _dir, 0), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(dayKey(_day)),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dayLabel(_day),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted)),
                    ],
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Next day',
                onPressed: _day.isBefore(today()) ? () => _shift(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.md, Space.sm),
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
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
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
                icon: const Icon(Icons.tune_rounded),
                onPressed: _editTrackers,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.xxl),
            itemCount: children.length,
            itemBuilder: (_, i) => children[i],
            separatorBuilder: (_, _) => Gap.v12,
          ),
        ),
        // Sticky Done button.
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Done'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The header row of a tracker card: badge, title, and a trailing widget.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.emoji, required this.title, required this.color, this.trailing});
  final String emoji;
  final String title;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconBadge(emoji: emoji, color: color, size: 36),
          Gap.h12,
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
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
    void toggle(bool v) => store.setPeriodDay(day, v);
    final content = Row(
      children: [
        IconBadge(emoji: '🩸', color: BloomColors.period, filled: on),
        Gap.h12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Period day', style: theme.textTheme.titleMedium),
              Text(
                on ? 'Marked as a day of your period' : 'Mark this day as a day of your period',
                style: theme.textTheme.bodySmall!.copyWith(color: BloomTokens.of(context).muted),
              ),
            ],
          ),
        ),
        Switch(value: on, activeThumbColor: BloomColors.period, onChanged: toggle),
      ],
    );
    return on
        ? BloomCard.tinted(color: BloomColors.period, padding: Insets.cardCompact, onTap: () => toggle(false), child: content)
        : BloomCard(padding: Insets.cardCompact, onTap: () => toggle(true), child: content);
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
    final color = Color(category.colorHex);
    final single = category.kind == CategoryKind.single;
    final picked = options.where((o) => log.has(category.id, o.id)).length;
    return BloomCard(
      padding: Insets.cardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            emoji: category.emoji,
            title: category.title,
            color: color,
            trailing: AnimatedSwitcher(
              duration: Motion.medium,
              child: picked > 0
                  ? PillChip(single ? 'Picked' : '$picked selected', key: ValueKey(picked), color: color, dense: true)
                  : single
                      ? const PillChip('Pick one', key: ValueKey('one'), dense: true, color: BloomColors.info)
                      : const SizedBox.shrink(),
            ),
          ),
          Gap.v12,
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final o in options)
                SelectChip(
                  emoji: o.emoji,
                  label: o.label,
                  color: color,
                  selected: log.has(category.id, o.id),
                  onSelected: (_) => store.toggleOption(day, category.id, o.id, single: single),
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
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final color = metricColor(metric.id);
    final clear = AnimatedSwitcher(
      duration: Motion.fast,
      child: value == null
          ? const SizedBox.shrink()
          : IconButton(
              key: const ValueKey('clear'),
              tooltip: 'Clear ${metric.title.toLowerCase()}',
              visualDensity: VisualDensity.compact,
              onPressed: () => _set(null),
              icon: Icon(Icons.close_rounded, size: 18, color: tokens.muted),
            ),
    );
    final header = _SectionTitle(emoji: metric.emoji, title: metric.title, color: color, trailing: clear);

    Widget card(List<Widget> children) => BloomCard(
          padding: Insets.cardCompact,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, Gap.v12, ...children]),
        );

    if (metric.id == 'energy') {
      const labels = ['Very low', 'Low', 'Okay', 'Good', 'Great'];
      const icons = [
        Icons.battery_1_bar_rounded,
        Icons.battery_2_bar_rounded,
        Icons.battery_4_bar_rounded,
        Icons.battery_5_bar_rounded,
        Icons.battery_full_rounded,
      ];
      return card([
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (var i = 1; i <= 5; i++)
              SelectChip(
                label: labels[i - 1],
                icon: icons[i - 1],
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

    final valueText = AnimatedSwitcher(
      duration: Motion.fast,
      child: Text(
        display,
        key: ValueKey(display),
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge!.copyWith(color: value == null ? tokens.muted : null),
      ),
    );

    final stepper = Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Decrease ${metric.title.toLowerCase()}',
          onPressed: value == null ? null : () => bump(-1),
          icon: const Icon(Icons.remove_rounded),
        ),
        Expanded(
          child: InkWell(
            borderRadius: Radii.smAll,
            onTap: () => _typeValue(context, view),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Column(
                children: [
                  valueText,
                  Text(metric.id == 'water' ? '1 glass = 250 ml' : 'Tap to type',
                      style: theme.textTheme.labelSmall!.copyWith(color: tokens.muted)),
                ],
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Increase ${metric.title.toLowerCase()}',
          onPressed: () => bump(1),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );

    if (metric.id == 'water') {
      final glasses = ((value ?? 0) / _glass).round();
      final extra = math.max(0, glasses - _glassGoal);
      return card([
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (var i = 0; i < _glassGoal; i++)
              Semantics(
                button: true,
                label: 'Set water to ${i + 1} glasses',
                excludeSemantics: true,
                child: InkResponse(
                  radius: 22,
                  // Tapping the last filled glass empties it.
                  onTap: () => _set(i + 1 == glasses ? (i == 0 ? null : i * _glass) : (i + 1) * _glass),
                  child: SizedBox(
                    width: 34,
                    height: 44,
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Icon(
                        i < glasses ? Icons.local_drink_rounded : Icons.local_drink_outlined,
                        key: ValueKey(i < glasses),
                        size: 28,
                        color: i < glasses ? color : tokens.muted.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            if (extra > 0) PillChip('+$extra', color: color, dense: true),
          ],
        ),
        Gap.v8,
        stepper,
      ]);
    }

    if (metric.id == 'sleep') {
      return card([
        stepper,
        SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: color, thumbColor: color),
          child: Slider(
            value: (value ?? 0).clamp(0.0, _sleepMax),
            min: 0,
            max: _sleepMax,
            divisions: 24,
            label: value == null ? null : view.format(value!),
            onChanged: (v) => _set(v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in ['0 h', '6 h', '12 h'])
                Text(l, style: theme.textTheme.labelSmall!.copyWith(color: tokens.muted)),
            ],
          ),
        ),
      ]);
    }

    return card([stepper]);
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
    return BloomCard(
      padding: Insets.cardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(emoji: '📝', title: 'Note', color: BloomColors.pregnancy),
          Gap.v12,
          TextField(
            controller: _ctrl,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'How are you feeling today?'),
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
