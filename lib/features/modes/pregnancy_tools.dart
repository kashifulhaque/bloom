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
  // Read in initState: dispose() saves an unfinished session, and the
  // context can't be used for lookups by then.
  late final AppStore _store;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _store = context.read<AppStore>();
  }

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
      // From dispose() the tree is locked, so save after this frame.
      _disposed ? Future.microtask(() => _store.setFeature('kicks', list)) : _store.setFeature('kicks', list);
    }
    if (mounted && !_disposed) {
      setState(() {
        _start = null;
        _count = 0;
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_running && _count > 0) _finish();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = BloomColors.of(context);
    final store = context.watch<AppStore>();
    final history = [...(store.feature<List>('kicks') ?? const [])].reversed.toList();
    final elapsed = _running ? DateTime.now().difference(_start!) : Duration.zero;
    final reached = _count >= kKickGoal;

    return ModePage(
      eyebrow: 'Pregnancy · Tools',
      title: 'Kick counter',
      subtitle:
          'Pick a time when your baby is usually active, get comfortable, and tap once for each movement: '
          'kicks, rolls, or flutters.',
      children: [
        Gap.v8,
        Center(
          child: Column(
            children: [
              MonoLabel(_running ? 'Elapsed' : 'Session'),
              Gap.v4,
              Text(
                fmtDuration(elapsed),
                style: Almanac.mono(size: 20, color: p.ink).copyWith(fontFeatures: tabular),
              ),
              Gap.v20,
              BigRoundButton(
                size: 236,
                emphasis: _running,
                semanticLabel: _running ? 'Record a movement' : 'Start counting',
                onPressed: _running ? _kick : _begin,
                child: _running
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: Motion.medium,
                            transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                            child: Text('$_count', key: ValueKey(_count), style: Almanac.numeral(context, size: 88)),
                          ),
                          Gap.v4,
                          Text('tap for each movement', style: Almanac.italic(context, size: 15, color: p.ink2)),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Begin', style: Almanac.serif(size: 34, weight: 330, color: p.ink)),
                          Gap.v4,
                          Text('tap to start counting', style: Almanac.italic(context, size: 15, color: p.ink2)),
                        ],
                      ),
              ),
              Gap.v24,
              _Tally(count: _count, goal: kKickGoal),
              Gap.v12,
              AnimatedSwitcher(
                duration: Motion.medium,
                child: reached
                    ? Text(
                        'Ten movements. Well counted.',
                        key: const ValueKey('done'),
                        style: Almanac.italic(
                          context,
                          size: 18,
                          color: readableTint(BloomColors.success, t.brightness),
                        ),
                      )
                    : Text(
                        '$_count of $kKickGoal movements',
                        key: const ValueKey('count'),
                        style: Almanac.data(context),
                      ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          child: _running
              ? Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Space.lg,
                    runSpacing: Space.sm,
                    children: [
                      InkButton(label: 'Finish and save', icon: Icons.check, onPressed: _finish),
                      InkButton.outlined(label: 'Undo', onPressed: _count > 0 ? () => setState(() => _count--) : null),
                      InkLink('Discard', onTap: () => _finish(save: false)),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Gap.v8,
        const InfoBanner(
          tone: BannerTone.warning,
          message:
              'If you notice your baby moving less than usual, or not at all, contact your care provider or '
              'maternity unit right away. Don\'t wait until the next day.',
        ),
        const SectionHeader('History', label: 'Ledger'),
        if (history.isEmpty)
          const EmptyState(
            compact: true,
            glyph: Botanical.sprout,
            title: 'No sessions yet',
            body: 'Many care providers suggest timing how long it takes to feel 10 movements.',
          )
        else
          LedgerTable(
            columns: const [
              LedgerColumn('Date', flex: 5),
              LedgerColumn('Moves', flex: 3, end: true),
              LedgerColumn('Time', flex: 3, end: true),
            ],
            rows: [
              for (final h in history.take(30))
                LedgerRow([
                  Text(_when(DateTime.parse(h['start'])), maxLines: 1, overflow: TextOverflow.ellipsis),
                  LedgerTable.serif(context, '${h['count']}'),
                  Text(fmtDuration(Duration(seconds: (h['seconds'] as num).toInt()))),
                ]),
            ],
          ),
      ],
    );
  }
}

/// Ten short tally marks under the kick counter: ink for each movement
/// counted, hairline for the rest.
class _Tally extends StatelessWidget {
  const _Tally({required this.count, required this.goal});
  final int count;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Semantics(
      label: '$count of $goal',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < goal; i++)
            AnimatedContainer(
              duration: Motion.medium,
              margin: EdgeInsets.only(left: i == 0 ? 0 : (i % 5 == 0 ? Space.md : Space.sm)),
              width: 1.5,
              height: i < count ? 20 : 14,
              color: i < count ? p.ink : p.hairline,
            ),
        ],
      ),
    );
  }
}

String _when(DateTime d) => '${fmtShort(d)}, ${fmtTime(d)}';

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
    final p = BloomColors.of(context);
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
      eyebrow: 'Pregnancy · Tools',
      title: 'Contraction timer',
      subtitle: 'Tap Start when a contraction begins and Stop when it ends.',
      actions: [
        if (list.isNotEmpty)
          IconButton(
            tooltip: 'Clear history',
            icon: Icon(Icons.delete_outline, size: 20, color: p.ink2),
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
        Gap.v8,
        Center(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: Motion.medium,
                child: active
                    ? Text(
                        fmtDuration(now.difference(list.last.start)),
                        key: const ValueKey(true),
                        style: Almanac.numeral(context, size: 72),
                      )
                    : Text('Ready', key: const ValueKey(false), style: Almanac.italic(context, size: 52)),
              ),
              Gap.v8,
              Text(status, style: Almanac.data(context), textAlign: TextAlign.center),
              Gap.v24,
              BigRoundButton(
                size: 200,
                emphasis: active,
                semanticLabel: active ? 'Stop contraction' : 'Start contraction',
                onPressed: () {
                  Almanac.tick();
                  _toggle(store);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(active ? 'Stop' : 'Start', style: Almanac.serif(size: 36, weight: 330, color: p.ink)),
                    Gap.v4,
                    Text(
                      active ? 'when it eases' : 'as it begins',
                      style: Almanac.italic(context, size: 15, color: p.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Gap.v8,
        if (avgDur != null)
          Row(
            children: [
              Expanded(
                child: StatTile(value: fmtDuration(avgDur), label: 'Avg. length', caption: 'Last hour'),
              ),
              Gap.h16,
              Expanded(
                child: StatTile(
                  value: avgGap == null ? '–' : fmtDuration(avgGap),
                  label: 'Avg. interval',
                  caption: 'Start to start',
                ),
              ),
            ],
          ),
        if (show511)
          const InfoBanner(
            tone: BannerTone.error,
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
          const SectionHeader('History', label: 'Ledger', subtitle: 'Interval is measured from start to start.'),
          LedgerTable(
            columns: const [
              LedgerColumn('Started', flex: 4),
              LedgerColumn('Length', flex: 3, end: true),
              LedgerColumn('Interval', flex: 3, end: true),
            ],
            rows: [
              for (var i = list.length - 1; i >= 0 && i >= list.length - 40; i--)
                LedgerRow([
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: fmtTime(list[i].start)),
                        TextSpan(text: '  ${fmtShort(list[i].start)}', style: Almanac.data(context, size: 11)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  list[i].duration == null
                      ? Text('now', style: Almanac.italic(context, size: 15))
                      : Text(fmtDuration(list[i].duration!)),
                  Text(i == 0 ? '–' : fmtDuration(list[i].start.difference(list[i - 1].start))),
                ]),
            ],
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
              Gap.v20,
              DateField(
                label: 'Date',
                date: date,
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
    final pal = BloomColors.of(context);
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
    final axis = Almanac.data(context, size: 10.5);

    return ModePage(
      eyebrow: 'Pregnancy · Tools',
      title: 'Pregnancy weight',
      subtitle: 'Your weight by pregnancy week.',
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkButton(label: 'Log weight', icon: Icons.add, onPressed: () => _add(context, store)),
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
                ),
              ),
              if (baseline != null && baseline != latest) ...[
                Gap.h16,
                Expanded(
                  child: StatTile(
                    value:
                        '${latest.kg >= baseline.kg ? '+' : '−'}${show((latest.kg - baseline.kg).abs()).toStringAsFixed(1)}',
                    unit: unitLabel,
                    label: 'Change',
                    caption: 'Since ${fmtShort(baseline.date)}',
                  ),
                ),
              ],
            ],
          ),
        if (entries.length >= 2) ...[
          const SectionHeader('By pregnancy week', label: 'Chart'),
          Gap.v8,
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: (daysBetween(lmp, entries.first.date) / 7).floorToDouble(),
                maxX: (daysBetween(lmp, entries.last.date) / 7).ceilToDouble().clamp(1, 44),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: pal.hairline, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(bottom: BorderSide(color: pal.ink.withValues(alpha: 0.6))),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => pal.ink,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${s.y.toStringAsFixed(1)} $unitLabel\nweek ${s.x.floor()}',
                          Almanac.mono(size: 11.5, color: pal.paper),
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
                        child: Text(meta.formattedValue, style: axis),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text('WEEK', style: Almanac.label(context, size: 9.5)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 4,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(v.round() % 4 == 0 ? v.round().toString() : '', style: axis),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: pal.ink,
                    barWidth: 1.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length <= 24,
                      getDotPainter: (_, _, _, _) =>
                          FlDotCirclePainter(radius: 2.5, color: pal.ink, strokeWidth: 1.5, strokeColor: pal.paper),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else
          EmptyState(
            compact: true,
            title: entries.isEmpty ? 'No weight logged yet' : 'One more to see a chart',
            body: 'Log your weight regularly to see a chart of your pregnancy weight.',
          ),
        const InfoBanner(
          message:
              'Healthy weight gain depends on your weight before pregnancy and on how many babies you carry. '
              'Ask your care provider what range is right for you.',
        ),
        if (entries.isNotEmpty) ...[
          const SectionHeader('Entries', label: 'Ledger'),
          LedgerTable(
            trailingWidth: 44,
            columns: const [
              LedgerColumn('Date', flex: 4),
              LedgerColumn('Week', flex: 2, end: true),
              LedgerColumn('Weight', flex: 4, end: true),
            ],
            rows: [
              for (final e in entries.reversed)
                LedgerRow(
                  [
                    Text(fmtShort(e.date)),
                    Text(e.date.isBefore(lmp) ? '–' : '${gestationalAge(lmp, e.date).weeks}'),
                    LedgerTable.serif(context, fmtWeight(e.kg, unit)),
                  ],
                  trailing: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete',
                    icon: Icon(Icons.close, size: 18, color: pal.ink2),
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

  static const _roman = ['I', 'II', 'III'];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = readPregnancy(store);
    if (p == null) {
      return const ModePage(
        eyebrow: 'Pregnancy · Tools',
        title: 'Pregnancy checklist',
        children: [
          EmptyState(glyph: Botanical.sprout, title: 'No active pregnancy', body: 'Set up your pregnancy first.'),
        ],
      );
    }
    final current = p.ageOn(today()).trimester;
    final doneCount = kPregnancyChecklist.where((i) => p.checklist.contains(i.id)).length;
    final total = kPregnancyChecklist.length;

    return ModePage(
      eyebrow: 'Pregnancy · Tools',
      title: 'Pregnancy checklist',
      subtitle: 'Things to plan, trimester by trimester.',
      children: [
        SerifFigure(value: '$doneCount', unit: 'of $total done', size: 52),
        SoftBar(value: doneCount / total),
        Text('You\'re in your ${trimesterLabel(current).toLowerCase()}.', style: Theme.of(context).textTheme.bodySmall),
        for (final tri in [1, 2, 3]) ...[
          Builder(
            builder: (context) {
              final items = kPregnancyChecklist.where((i) => i.trimester == tri).toList();
              final n = items.where((i) => p.checklist.contains(i.id)).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    trimesterLabel(tri),
                    label: tri == current ? 'Part ${_roman[tri - 1]} · Now' : 'Part ${_roman[tri - 1]}',
                    trailing: Text('$n/${items.length}', style: Almanac.data(context)),
                  ),
                  Gap.v12,
                  CheckList(
                    children: [
                      for (final i in items)
                        CheckRow(
                          label: i.label,
                          checked: p.checklist.contains(i.id),
                          onChanged: (v) {
                            v ? p.checklist.add(i.id) : p.checklist.remove(i.id);
                            savePregnancy(store, p);
                          },
                        ),
                    ],
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
                Gap.v20,
                DateField(
                  label: 'Date',
                  date: date,
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
                Gap.v16,
                UnderlineField(
                  label: 'Time',
                  value: time ?? 'Add a time',
                  placeholder: time == null,
                  icon: Icons.schedule_outlined,
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
        eyebrow: 'Pregnancy · Tools',
        title: 'Appointments and notes',
        children: [
          EmptyState(glyph: Botanical.sprout, title: 'No active pregnancy', body: 'Set up your pregnancy first.'),
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

    Widget group(List<Map<String, dynamic>> list, {required bool isPast}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Hairline(),
        for (final a in list) ...[tile(a, isPast: isPast), const Hairline()],
      ],
    );

    return ModePage(
      eyebrow: 'Pregnancy · Tools',
      title: 'Appointments and notes',
      subtitle: 'Checkups, scans, and questions for your care provider.',
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkButton(label: 'Add', icon: Icons.add, onPressed: () => _edit(context, store, p)),
        ),
        if (sorted.isEmpty)
          const EmptyState(
            title: 'Nothing planned yet',
            body: 'Keep track of checkups, scans, and questions for your care provider. Tap Add to start.',
          ),
        if (upcoming.isNotEmpty) ...[const SectionHeader('Upcoming', label: 'Diary'), group(upcoming, isPast: false)],
        if (past.isNotEmpty) ...[const SectionHeader('Past', label: 'Diary'), group(past, isPast: true)],
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
    final p = BloomColors.of(context);
    final d = parseDayKey(a['date']);
    final fg = past ? p.ink2 : p.ink;
    final note = (a['note'] ?? '') as String;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM').format(d).toUpperCase(), style: Almanac.label(context)),
                  Gap.v4,
                  Text('${d.day}', style: Almanac.numeral(context, size: 30, color: fg)),
                ],
              ),
            ),
            Gap.h8,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['title'] ?? '', style: t.textTheme.titleMedium!.copyWith(color: fg)),
                  const SizedBox(height: Space.xxs),
                  Text(
                    '${DateFormat('EEEE').format(d)}${a['time'] != null ? ', ${a['time']}' : ''} · week $week',
                    style: Almanac.data(context, size: 12),
                  ),
                  if (note.isNotEmpty) ...[
                    Gap.v8,
                    Text(
                      note,
                      style: Almanac.italic(context, size: 15.5, color: p.ink2),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.close, size: 18, color: p.ink2),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
