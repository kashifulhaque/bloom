/// Pregnancy quick tools: kick counter, contraction timer, weight tracker,
/// checklist, and appointments.
library;

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/units.dart';
import '../../widgets/widgets.dart';
import 'modes_common.dart';
import 'pregnancy_content.dart';
import 'pregnancy_math.dart';

// ------------------------------------------------------------------ kicks

const int kKickGoal = 10;

class KickCounterScreen extends StatefulWidget {
  const KickCounterScreen({super.key});

  @override
  State<KickCounterScreen> createState() => _KickCounterScreenState();
}

class _KickCounterScreenState extends State<KickCounterScreen> {
  late final AppStore _store = context.read<AppStore>();
  DateTime? _start;
  int _count = 0;
  Timer? _ticker;

  bool get _running => _start != null;

  void _begin() {
    setState(() {
      _start = DateTime.now();
      _count = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _kick() {
    setState(() => _count++);
    if (_count == kKickGoal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$kKickGoal movements in ${fmtDuration(DateTime.now().difference(_start!))}. Nice!')),
      );
    }
  }

  void _finish({bool save = true}) {
    _ticker?.cancel();
    final start = _start;
    if (start != null && save && _count > 0) {
      final end = DateTime.now();
      final list = [...(_store.feature<List>('kicks') ?? const [])];
      list.add({
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'count': _count,
        'seconds': end.difference(start).inSeconds,
      });
      _store.setFeature('kicks', list);
    }
    if (mounted) {
      setState(() {
        _start = null;
        _count = 0;
      });
    }
  }

  @override
  void dispose() {
    if (_running && _count > 0) _finish();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = BloomTokens.of(context).muted;
    final store = context.watch<AppStore>();
    final history = [...(store.feature<List>('kicks') ?? const [])].reversed.toList();
    final elapsed = _running ? DateTime.now().difference(_start!) : Duration.zero;
    final reached = _count >= kKickGoal;
    final onPreg = BloomColors.onColor(BloomGradients.pregnancy.colors.first);

    return ModePage(
      title: 'Kick counter',
      subtitle:
          'Pick a time when your baby is usually active, get comfortable, and tap once for each movement: '
          'kicks, rolls, or flutters.',
      heroColor: BloomColors.pregnancy,
      children: [
        BloomCard(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.xxl, Space.xl, Space.xl),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: muted),
                  Gap.h8,
                  Text(
                    fmtDuration(elapsed),
                    style: t.textTheme.titleLarge!.copyWith(fontFeatures: tabular, color: muted),
                  ),
                ],
              ),
              Gap.v20,
              ProgressRing(
                value: _count / kKickGoal,
                size: 252,
                stroke: 14,
                gradient: reached ? BloomGradients.fertile : BloomGradients.pregnancy,
                child: BigRoundButton(
                  size: 196,
                  gradient: BloomGradients.pregnancy,
                  semanticLabel: _running ? 'Record a movement' : 'Start counting',
                  onPressed: _running ? _kick : _begin,
                  child: _running
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: Motion.medium,
                              switchInCurve: Motion.spring,
                              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                              child: Text(
                                '$_count',
                                key: ValueKey(_count),
                                style: t.textTheme.displayLarge!.copyWith(
                                  color: BloomColors.onColor(BloomGradients.pregnancy.colors.first),
                                  height: 1,
                                ),
                              ),
                            ),
                            Text('Tap for each movement', style: t.textTheme.labelMedium!.copyWith(color: onPreg)),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app_rounded, size: 44),
                            Gap.v8,
                            Text('Start', style: t.textTheme.headlineSmall!.copyWith(color: onPreg)),
                          ],
                        ),
                ),
              ),
              Gap.v20,
              AnimatedSwitcher(
                duration: Motion.medium,
                child: reached
                    ? const PillChip(
                        'Goal reached',
                        key: ValueKey('done'),
                        color: BloomColors.success,
                        icon: Icons.check_rounded,
                      )
                    : Text(
                        '$_count of $kKickGoal movements',
                        key: const ValueKey('count'),
                        style: t.textTheme.titleMedium,
                      ),
              ),
              AnimatedSize(
                duration: Motion.medium,
                curve: Motion.curve,
                child: _running
                    ? Padding(
                        padding: const EdgeInsets.only(top: Space.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              onPressed: _finish,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Finish and save'),
                            ),
                            Gap.v8,
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _count > 0 ? () => setState(() => _count--) : null,
                                    icon: const Icon(Icons.undo_rounded),
                                    label: const Text('Undo'),
                                  ),
                                ),
                                Gap.h8,
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => _finish(save: false),
                                    child: const Text('Discard'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        const InfoBanner(
          tone: BannerTone.warning,
          message:
              'If you notice your baby moving less than usual, or not at all, contact your care provider or '
              'maternity unit right away. Don\'t wait until the next day.',
        ),
        const SectionHeader('History'),
        if (history.isEmpty)
          const BloomCard(
            child: EmptyState(
              compact: true,
              emoji: '👶',
              color: BloomColors.pregnancy,
              title: 'No sessions yet',
              body: 'Many care providers suggest timing how long it takes to feel 10 movements.',
            ),
          )
        else
          ListCard(
            children: [
              for (final h in history.take(30))
                HistoryRow(
                  icon: Icons.touch_app_rounded,
                  color: BloomColors.pregnancy,
                  title: '${h['count']} movements in ${fmtDuration(Duration(seconds: (h['seconds'] as num).toInt()))}',
                  subtitle: _when(DateTime.parse(h['start'])),
                ),
            ],
          ),
      ],
    );
  }
}

String _when(DateTime d) => '${fmtFull(d)}, ${fmtTime(d)}';

// ------------------------------------------------------------------ contractions

/// One timed contraction. [end] is null while it is in progress.
class Contraction {
  Contraction(this.start, this.end);
  final DateTime start;
  final DateTime? end;
  Duration? get duration => end?.difference(start);

  Map<String, dynamic> toJson() => {'start': start.toIso8601String(), if (end != null) 'end': end!.toIso8601String()};

  static Contraction fromJson(Map j) =>
      Contraction(DateTime.parse(j['start']), j['end'] == null ? null : DateTime.parse(j['end']));
}

/// True when the 5-1-1 pattern is met: contractions about 5 minutes apart
/// or closer, lasting about 1 minute, for about 1 hour. [list] is oldest first.
bool meets511(List<Contraction> list) {
  final done = list.where((c) => c.end != null).toList();
  if (done.length < 4) return false;
  final ref = done.last.start;
  final window = done.where((c) => !c.start.isBefore(ref.subtract(const Duration(minutes: 65)))).toList();
  if (window.length < 4) return false;
  if (ref.difference(window.first.start) < const Duration(minutes: 55)) return false;
  for (var i = 1; i < window.length; i++) {
    if (window[i].start.difference(window[i - 1].start) > const Duration(seconds: 330)) return false;
  }
  final avg = window.map((c) => c.duration!.inSeconds).reduce((a, b) => a + b) / window.length;
  return avg >= 55;
}

class ContractionTimerScreen extends StatefulWidget {
  const ContractionTimerScreen({super.key});

  @override
  State<ContractionTimerScreen> createState() => _ContractionTimerScreenState();
}

class _ContractionTimerScreenState extends State<ContractionTimerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  List<Contraction> _read(AppStore s) => [
    for (final c in (s.feature<List>('contractions') ?? const [])) Contraction.fromJson(c as Map),
  ];

  void _write(AppStore s, List<Contraction> l) => s.setFeature('contractions', [for (final c in l) c.toJson()]);

  void _toggle(AppStore s) {
    final list = _read(s);
    if (list.isNotEmpty && list.last.end == null) {
      list[list.length - 1] = Contraction(list.last.start, DateTime.now());
    } else {
      list.add(Contraction(DateTime.now(), null));
    }
    _write(s, list);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = BloomTokens.of(context).muted;
    final store = context.watch<AppStore>();
    final list = _read(store);
    final active = list.isNotEmpty && list.last.end == null;
    final now = DateTime.now();
    final recent = list.isNotEmpty && now.difference(list.last.end ?? now) < const Duration(minutes: 30);
    final show511 = recent && meets511(list);

    // Averages over the last hour of finished contractions.
    final hour = list.where((c) => c.end != null && now.difference(c.start) < const Duration(hours: 1)).toList();
    final avgDur = hour.isEmpty
        ? null
        : Duration(seconds: hour.map((c) => c.duration!.inSeconds).reduce((a, b) => a + b) ~/ hour.length);
    Duration? avgGap;
    if (hour.length >= 2) {
      final span = hour.last.start.difference(hour.first.start).inSeconds;
      avgGap = Duration(seconds: span ~/ (hour.length - 1));
    }

    final status = active
        ? 'Contraction in progress'
        : list.isEmpty
        ? 'Tap Start when a contraction begins'
        : 'Since the last one started: ${fmtDuration(now.difference(list.last.start))}';

    return ModePage(
      title: 'Contraction timer',
      subtitle: 'Tap Start when a contraction begins and Stop when it ends.',
      heroColor: active ? BloomColors.period : BloomColors.pregnancy,
      actions: [
        if (list.isNotEmpty)
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirmDialog(
                context,
                title: 'Clear contraction history?',
                body: 'This removes every timed contraction.',
                confirm: 'Clear',
              )) {
                store.setFeature('contractions', null);
              }
            },
          ),
      ],
      children: [
        BloomCard(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.xxl, Space.xl, Space.xxl),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: Motion.medium,
                child: Text(
                  active ? fmtDuration(now.difference(list.last.start)) : 'Ready',
                  key: ValueKey(active),
                  style: t.textTheme.displayMedium!.copyWith(fontFeatures: tabular),
                ),
              ),
              Gap.v4,
              Text(
                status,
                style: t.textTheme.bodyMedium!.copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
              Gap.v24,
              BigRoundButton(
                size: 184,
                gradient: active ? BloomGradients.period : BloomGradients.pregnancy,
                semanticLabel: active ? 'Stop contraction' : 'Start contraction',
                onPressed: () => _toggle(store),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(active ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 52),
                    Text(
                      active ? 'Stop' : 'Start',
                      style: t.textTheme.headlineSmall!.copyWith(
                        color: BloomColors.onColor(
                          (active ? BloomGradients.period : BloomGradients.pregnancy).colors.first,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (avgDur != null)
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: fmtDuration(avgDur),
                  label: 'Avg. length',
                  caption: 'Last hour',
                  icon: Icons.hourglass_bottom_rounded,
                  color: BloomColors.pregnancy,
                ),
              ),
              Gap.h12,
              Expanded(
                child: StatTile(
                  value: avgGap == null ? '–' : fmtDuration(avgGap),
                  label: 'Avg. interval',
                  caption: 'Start to start',
                  icon: Icons.swap_horiz_rounded,
                  color: BloomColors.info,
                ),
              ),
            ],
          ),
        if (show511)
          const InfoBanner(
            tone: BannerTone.error,
            icon: Icons.local_hospital_rounded,
            title: 'Your contractions match the 5-1-1 pattern',
            message:
                'They have been about 5 minutes apart or closer, lasting about 1 minute, for about '
                '1 hour. Consider contacting your care provider or birth place now.',
          )
        else
          const InfoBanner(
            title: 'The 5-1-1 guide',
            message:
                'A common guide is contractions 5 minutes apart, lasting 1 minute, for 1 hour. '
                'Your care provider may give you different advice. Call them right away if your water breaks, '
                'you bleed, or your baby moves less.',
          ),
        if (list.isNotEmpty) ...[
          const SectionHeader('History', subtitle: 'Interval is measured from start to start'),
          BloomCard(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                  child: DefaultTextStyle.merge(
                    style: t.textTheme.labelMedium!.copyWith(color: muted),
                    child: const Row(
                      children: [
                        Expanded(flex: 4, child: Text('Started')),
                        Expanded(flex: 3, child: Text('Length', textAlign: TextAlign.right)),
                        Expanded(flex: 3, child: Text('Interval', textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                ),
                for (var i = list.length - 1; i >= 0 && i >= list.length - 40; i--) ...[
                  Divider(height: 1, indent: Space.lg, endIndent: Space.lg, color: BloomTokens.of(context).border),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                    child: DefaultTextStyle.merge(
                      style: t.textTheme.bodyMedium!.copyWith(fontFeatures: tabular),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: fmtTime(list[i].start), style: t.textTheme.titleSmall),
                                  TextSpan(text: '  ${fmtShort(list[i].start)}', style: t.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: list[i].duration == null
                                ? const Align(
                                    alignment: Alignment.centerRight,
                                    child: PillChip('Now', color: BloomColors.period, dense: true),
                                  )
                                : Text(fmtDuration(list[i].duration!), textAlign: TextAlign.right),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              i == 0 ? '–' : fmtDuration(list[i].start.difference(list[i - 1].start)),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ weight

class PregnancyWeightScreen extends StatelessWidget {
  const PregnancyWeightScreen({super.key});

  Future<void> _add(BuildContext context, AppStore store) async {
    final unit = store.profile.weightUnit;
    final ctrl = TextEditingController();
    var date = today();
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Log weight'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Weight', suffixText: unit == WeightUnit.kg ? 'kg' : 'lb'),
              ),
              Gap.v8,
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(fmtFull(date)),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: () async {
                  final d = await pickDay(c, initial: date, first: addDays(today(), -400), last: today());
                  if (d != null) setS(() => date = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
    ctrl.dispose();
    if (saved != true || v == null || v <= 0) return;
    final kg = unit == WeightUnit.kg ? v : lbToKg(v);
    store.setMetric(date, 'weight', double.parse(kg.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final store = context.watch<AppStore>();
    final p = readPregnancy(store);
    final unit = store.profile.weightUnit;
    final unitLabel = unit == WeightUnit.kg ? 'kg' : 'lb';
    final lmp = p?.lmp ?? addDays(today(), -kPregnancyDays);
    final entries = store
        .logsBetween(addDays(lmp, -60), today())
        .where((l) => l.metrics['weight'] != null)
        .map((l) => (date: l.date, kg: l.metrics['weight']!))
        .toList();
    double show(double kg) => unit == WeightUnit.kg ? kg : kgToLb(kg);
    final baseline = entries.where((e) => !e.date.isAfter(addDays(lmp, 14))).lastOrNull ?? entries.firstOrNull;
    final latest = entries.lastOrNull;
    final spots = [
      for (final e in entries) FlSpot(daysBetween(lmp, e.date) / 7, double.parse(show(e.kg).toStringAsFixed(1))),
    ];
    final lineColor = readableTint(BloomColors.pregnancy, t.brightness);

    return ModePage(
      title: 'Pregnancy weight',
      subtitle: 'Your weight by pregnancy week',
      children: [
        FilledButton.icon(
          onPressed: () => _add(context, store),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Log weight'),
        ),
        if (latest != null)
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: show(latest.kg).toStringAsFixed(1),
                  unit: unitLabel,
                  label: 'Latest',
                  caption: fmtShort(latest.date),
                  icon: Icons.monitor_weight_rounded,
                  color: BloomColors.fertile,
                ),
              ),
              if (baseline != null && baseline != latest) ...[
                Gap.h12,
                Expanded(
                  child: StatTile(
                    value:
                        '${latest.kg >= baseline.kg ? '+' : '−'}${show((latest.kg - baseline.kg).abs()).toStringAsFixed(1)}',
                    unit: unitLabel,
                    label: 'Change',
                    caption: 'Since ${fmtShort(baseline.date)}',
                    icon: Icons.trending_up_rounded,
                    color: BloomColors.pregnancy,
                  ),
                ),
              ],
            ],
          ),
        if (entries.length >= 2)
          SectionCard(
            title: 'Weight by pregnancy week',
            icon: Icons.show_chart_rounded,
            accent: BloomColors.pregnancy,
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: (daysBetween(lmp, entries.first.date) / 7).floorToDouble(),
                  maxX: (daysBetween(lmp, entries.last.date) / 7).ceilToDouble().clamp(1, 44),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: tokens.border, strokeWidth: 1, dashArray: [4, 4]),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => t.colorScheme.inverseSurface,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${s.y.toStringAsFixed(1)} $unitLabel\nweek ${s.x.floor()}',
                            t.textTheme.labelMedium!.copyWith(color: t.colorScheme.onInverseSurface),
                          ),
                      ],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(meta.formattedValue, style: t.textTheme.bodySmall),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text('Week', style: t.textTheme.labelSmall!.copyWith(color: tokens.muted)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 4,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(v.round() % 4 == 0 ? v.round().toString() : '', style: t.textTheme.bodySmall),
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: lineColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            BloomColors.pregnancy.withValues(alpha: 0.28),
                            BloomColors.pregnancy.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      dotData: FlDotData(
                        show: spots.length <= 24,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 4,
                          color: lineColor,
                          strokeWidth: 2,
                          strokeColor: t.brightness == Brightness.dark ? t.colorScheme.surfaceContainer : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          BloomCard(
            child: EmptyState(
              compact: true,
              emoji: '⚖️',
              color: BloomColors.fertile,
              title: entries.isEmpty ? 'No weight logged yet' : 'One more to see a chart',
              body: 'Log your weight regularly to see a chart of your pregnancy weight.',
            ),
          ),
        const InfoBanner(
          message:
              'Healthy weight gain depends on your weight before pregnancy and on how many babies you carry. '
              'Ask your care provider what range is right for you.',
        ),
        if (entries.isNotEmpty) ...[
          const SectionHeader('Entries'),
          ListCard(
            children: [
              for (final e in entries.reversed)
                HistoryRow(
                  icon: Icons.monitor_weight_rounded,
                  color: BloomColors.fertile,
                  title: fmtWeight(e.kg, unit),
                  subtitle:
                      '${fmtFull(e.date)}${e.date.isBefore(lmp) ? '' : ' · week ${gestationalAge(lmp, e.date).weeks}'}',
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline_rounded, color: tokens.muted),
                    onPressed: () => store.setMetric(e.date, 'weight', null),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ checklist

class PregnancyChecklistScreen extends StatelessWidget {
  const PregnancyChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final store = context.watch<AppStore>();
    final p = readPregnancy(store);
    if (p == null) {
      return const ModePage(
        title: 'Pregnancy checklist',
        children: [
          EmptyState(
            emoji: '🤰',
            color: BloomColors.pregnancy,
            title: 'No active pregnancy',
            body: 'Set up your pregnancy first.',
          ),
        ],
      );
    }
    final current = p.ageOn(today()).trimester;
    final doneCount = kPregnancyChecklist.where((i) => p.checklist.contains(i.id)).length;
    final total = kPregnancyChecklist.length;

    return ModePage(
      title: 'Pregnancy checklist',
      subtitle: 'Things to plan, trimester by trimester',
      children: [
        BloomCard(
          child: Row(
            children: [
              ProgressRing(
                value: doneCount / total,
                size: 72,
                stroke: 8,
                gradient: BloomGradients.pregnancy,
                child: Text('${(doneCount / total * 100).round()}%', style: t.textTheme.labelLarge),
              ),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$doneCount of $total done', style: t.textTheme.titleMedium),
                    Text('You\'re in your ${trimesterLabel(current).toLowerCase()}.', style: t.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final tri in [1, 2, 3]) ...[
          Builder(
            builder: (_) {
              final items = kPregnancyChecklist.where((i) => i.trimester == tri).toList();
              final n = items.where((i) => p.checklist.contains(i.id)).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    trimesterLabel(tri),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tri == current) ...[
                          const PillChip('Now', color: BloomColors.pregnancy, dense: true),
                          Gap.h8,
                        ],
                        Text('$n/${items.length}', style: t.textTheme.labelLarge),
                      ],
                    ),
                  ),
                  Gap.v12,
                  BloomCard(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Column(
                      children: [
                        for (final i in items)
                          CheckRow(
                            label: i.label,
                            checked: p.checklist.contains(i.id),
                            color: BloomColors.success,
                            onChanged: (v) {
                              v ? p.checklist.add(i.id) : p.checklist.remove(i.id);
                              savePregnancy(store, p);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        const EduNote(),
      ],
    );
  }
}

// ------------------------------------------------------------------ appointments

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  Future<void> _edit(BuildContext context, AppStore store, PregnancyData p, [Map<String, dynamic>? existing]) async {
    final title = TextEditingController(text: existing?['title'] ?? '');
    final note = TextEditingController(text: existing?['note'] ?? '');
    var date = existing?['date'] is String ? parseDayKey(existing!['date']) : today();
    String? time = existing?['time'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(existing == null ? 'New appointment or note' : 'Edit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  autofocus: true,
                ),
                Gap.v12,
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
                ),
                Gap.v8,
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(fmtFull(date)),
                  onTap: () async {
                    final d = await pickDay(
                      c,
                      initial: date,
                      first: addDays(today(), -400),
                      last: addDays(today(), 400),
                    );
                    if (d != null) setS(() => date = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(time ?? 'Add a time'),
                  onTap: () async {
                    final tod = await showTimePicker(context: c, initialTime: const TimeOfDay(hour: 9, minute: 0));
                    if (tod != null) {
                      setS(
                        () => time = '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}',
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final entry = {
      'id': existing?['id'] ?? newId(),
      'date': dayKey(date),
      'time': ?time,
      'title': title.text.trim(),
      'note': note.text.trim(),
    };
    title.dispose();
    note.dispose();
    if (ok != true || (entry['title'] as String).isEmpty) return;
    p.appointments.removeWhere((a) => a['id'] == entry['id']);
    p.appointments.add(entry);
    savePregnancy(store, p);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = readPregnancy(store);
    if (p == null) {
      return const ModePage(
        title: 'Appointments and notes',
        children: [
          EmptyState(
            emoji: '📅',
            color: BloomColors.info,
            title: 'No active pregnancy',
            body: 'Set up your pregnancy first.',
          ),
        ],
      );
    }
    final now = today();
    final sorted = [...p.appointments]
      ..sort((a, b) => '${a['date']} ${a['time'] ?? ''}'.compareTo('${b['date']} ${b['time'] ?? ''}'));
    final upcoming = sorted.where((a) => !parseDayKey(a['date']).isBefore(now)).toList();
    final past = sorted.where((a) => parseDayKey(a['date']).isBefore(now)).toList().reversed.toList();

    Widget tile(Map<String, dynamic> a, {required bool isPast}) => _AppointmentCard(
      a: a,
      week: p.ageOn(parseDayKey(a['date'])).weeks,
      past: isPast,
      onTap: () => _edit(context, store, p, a),
      onDelete: () {
        p.appointments.removeWhere((x) => x['id'] == a['id']);
        savePregnancy(store, p);
      },
    );

    return ModePage(
      title: 'Appointments and notes',
      subtitle: 'Checkups, scans, and questions for your care provider',
      children: [
        FilledButton.icon(
          onPressed: () => _edit(context, store, p),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
        if (sorted.isEmpty)
          const EmptyState(
            emoji: '📅',
            color: BloomColors.info,
            title: 'Nothing planned yet',
            body: 'Keep track of checkups, scans, and questions for your care provider. Tap Add to start.',
          ),
        if (upcoming.isNotEmpty) ...[const SectionHeader('Upcoming'), for (final a in upcoming) tile(a, isPast: false)],
        if (past.isNotEmpty) ...[const SectionHeader('Past'), for (final a in past) tile(a, isPast: true)],
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.a,
    required this.week,
    required this.past,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> a;
  final int week;
  final bool past;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final d = parseDayKey(a['date']);
    final c = past ? tokens.muted : BloomColors.info;
    final fg = readableTint(c, t.brightness);
    final note = (a['note'] ?? '') as String;
    return BloomCard(
      onTap: onTap,
      padding: Insets.cardCompact,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            decoration: BoxDecoration(
              color: c.withValues(alpha: t.brightness == Brightness.dark ? 0.22 : 0.12),
              borderRadius: Radii.mdAll,
            ),
            child: Column(
              children: [
                Text(DateFormat('MMM').format(d).toUpperCase(), style: t.textTheme.labelSmall!.copyWith(color: fg)),
                Text('${d.day}', style: t.textTheme.headlineSmall!.copyWith(color: fg, height: 1.1)),
              ],
            ),
          ),
          Gap.h12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a['title'] ?? '', style: t.textTheme.titleMedium),
                const SizedBox(height: Space.xxs),
                Text(
                  '${DateFormat('EEEE').format(d)}${a['time'] != null ? ', ${a['time']}' : ''} · week $week',
                  style: t.textTheme.bodySmall,
                ),
                if (note.isNotEmpty) ...[
                  Gap.v4,
                  Text(note, style: t.textTheme.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline_rounded, color: tokens.muted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
