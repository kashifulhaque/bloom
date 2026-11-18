/// Graphs and reports: cycle summary, history, charts, symptom statistics,
/// and pattern notes, set as the pages of a personal almanac.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/units.dart';
import '../../widgets/widgets.dart';
import '../calendar/calendar_widgets.dart' show TextTabs;
import 'analysis_charts.dart';
import 'analysis_data.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: Space.maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (canPop)
                              Padding(
                                padding: const EdgeInsets.only(bottom: Space.md),
                                child: Transform.translate(
                                  offset: const Offset(-Space.md, 0),
                                  child: IconButton(
                                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                                    onPressed: () => Navigator.maybePop(context),
                                    icon: Icon(Icons.arrow_back, size: 20, color: p.ink),
                                  ),
                                ),
                              ),
                            const MonoLabel('Ledger · from your own logs'),
                            Gap.v8,
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'My '),
                                  TextSpan(
                                    text: 'cycles',
                                    style: Almanac.serif(size: 34, weight: 300, italic: true, color: p.ink),
                                  ),
                                ],
                              ),
                              style: theme.textTheme.headlineLarge,
                              semanticsLabel: 'My cycles',
                            ),
                            Gap.v8,
                            Text(
                              'Averages, charts, and patterns, kept on this device.',
                              style: theme.textTheme.bodyLarge?.copyWith(color: p.ink2),
                            ),
                          ],
                        ),
                      ),
                      const _Tabs(),
                    ],
                  ),
                ),
              ),
              const Expanded(
                child: TabBarView(children: [_SummaryTab(), _ChartsTab(), _SymptomsTab(), _PatternsTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text-link tabs with an ink underline, starting at the page margin.
class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter - Space.md),
      tabs: [
        for (final t in const ['Summary', 'Charts', 'Symptoms', 'Patterns']) Tab(height: 44, text: t),
      ],
    );
  }
}

// ---------------------------------------------------------------- shared UI

/// One tab's scrolling body, centered at the content width.
class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => BloomPage(
    showBack: false,
    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, Space.xxl),
    children: children,
  );
}

/// A ruled section of the page, like a figure in a printed report: a mono
/// figure label, a serif title, an optional muted note, and the content.
class _Section extends StatelessWidget {
  const _Section({required this.title, this.figure, this.subtitle, required this.child});
  final String title;
  final String? figure;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm, bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Hairline(),
          Gap.v16,
          if (figure != null) ...[MonoLabel(figure!), const SizedBox(height: Space.xs + 2)],
          Text(title, style: theme.textTheme.titleLarge!.copyWith(fontSize: 22)),
          if (subtitle != null) ...[
            const SizedBox(height: Space.xs),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          Gap.v16,
          child,
        ],
      ),
    );
  }
}

/// A quiet "nothing here yet" line in italic serif.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.sm),
    child: Text(message, style: Almanac.italic(context, size: 16.5, color: BloomColors.of(context).ink2)),
  );
}

const _disclaimer = Disclaimer(
  text: 'For education only, not medical advice. Talk to a clinician about anything that worries you.',
);

// ---------------------------------------------------------------- summary

class _SummaryTab extends StatelessWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final engine = store.engine;
    if (!engine.hasData) {
      return const _Page(
        children: [
          EmptyState(
            glyph: Botanical.bud,
            color: BloomColors.period,
            title: 'No cycles yet',
            body: 'Log your period to see your cycle summary and history.',
          ),
        ],
      );
    }
    final h = engine.health();
    return _Page(
      children: [
        if (engine.cycleLengths.isEmpty)
          const InfoBanner(
            tone: BannerTone.info,
            message: 'These averages use your settings until you log more cycles.',
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Figure(label: 'Average cycle', value: '${engine.avgCycleLength}', unit: 'days'),
              ),
              const Hairline(vertical: true, spacing: Space.md),
              Expanded(
                child: _Figure(
                  label: 'Average period',
                  value: '${engine.avgPeriodLength}',
                  unit: 'days',
                  color: BloomColors.period,
                ),
              ),
              const Hairline(vertical: true, spacing: Space.md),
              Expanded(
                child: _Figure(
                  label: 'Variation',
                  value: h.enoughData ? '${h.variation}' : '–',
                  unit: h.enoughData ? (h.variation == 1 ? 'day' : 'days') : null,
                  caption: h.enoughData ? 'shortest to longest' : 'needs 3 cycles',
                ),
              ),
            ],
          ),
        ),
        _Section(
          figure: 'Verdicts',
          title: 'Cycle health',
          subtitle: 'How your recent cycles compare to typical ranges.',
          child: _HealthCard(health: h),
        ),
        _Section(
          figure: 'Ledger',
          title: 'Cycle history',
          subtitle: 'Long-press a past cycle, or use its menu, to exclude it from averages.',
          child: _HistoryCard(store: store),
        ),
        _disclaimer,
      ],
    );
  }
}

/// A headline figure: a mono label, a serif numeral, and an italic unit.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.unit, this.caption, this.color});
  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two lines tall for every label, so the numerals share a baseline.
        SizedBox(
          height: 30,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (color != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: BloomColors.resolve(context, color!), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(child: MonoLabel(label, maxLines: 2)),
            ],
          ),
        ),
        Gap.v8,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: Almanac.numeral(context, size: 44, weight: 300)),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: Almanac.italic(context, size: 16, color: p.ink2),
                  ),
              ],
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!, style: Almanac.data(context, size: 10.5), maxLines: 2),
        ],
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health});
  final CycleHealth health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final h = health;
    Widget row(String title, String verdict, bool good, String explanation) {
      final mark = good
          ? Icon(Icons.check, size: 15, color: p.fertile)
          : Icon(Icons.priority_high, size: 14, color: readableTint(BloomColors.warning, theme.brightness));
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Padding(padding: const EdgeInsets.only(top: 1), child: mark),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Almanac.sans(size: 13.5, weight: FontWeight.w600, color: p.ink, height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(verdict, style: Almanac.italic(context, size: 20)),
                  Gap.v4,
                  Text(explanation, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!h.enoughData)
          const _EmptyNote('Log at least 3 periods to see how your cycles compare to typical ranges.')
        else ...[
          row(
            'Cycle length',
            h.cycleNormal ? 'Within the usual range.' : 'Outside the usual range.',
            h.cycleNormal,
            h.cycleNormal
                ? 'Your recent cycles fall within 21 to 35 days, the typical adult range.'
                : 'At least one recent cycle was shorter than 21 or longer than 35 days.',
          ),
          const Hairline(indent: 28),
          row(
            'Period length',
            h.periodNormal ? 'Within the usual range.' : 'Outside the usual range.',
            h.periodNormal,
            h.periodNormal
                ? 'Your recent periods lasted 2 to 7 days, the typical range.'
                : 'At least one recent period lasted less than 2 or more than 7 days.',
          ),
          const Hairline(indent: 28),
          row(
            'Regularity',
            h.regular ? 'Regular.' : 'Irregular.',
            h.regular,
            h.regular
                ? 'Your shortest and longest recent cycles differ by ${h.variation} days (7 or less is regular).'
                : 'Your shortest and longest recent cycles differ by ${h.variation} days, more than the 7 days '
                      'usually considered regular.',
          ),
        ],
        Gap.v12,
        Marginalia(
          label: 'Source',
          child: Text(
            'Ranges follow guidance from the American College of Obstetricians and Gynecologists (ACOG).',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.store});
  final AppStore store;

  void _toggleExclude(BuildContext context, Cycle c) {
    final key = dayKey(c.start);
    final excluded = store.profile.excludedCycleStarts.contains(key);
    store.updateProfile((p) {
      p.excludedCycleStarts = excluded
          ? p.excludedCycleStarts.where((k) => k != key).toList()
          : [...p.excludedCycleStarts, key];
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(excluded ? 'Cycle included in averages' : 'Cycle excluded from averages')));
  }

  @override
  Widget build(BuildContext context) {
    final engine = store.engine;
    final cycles = engine.cycles.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column heads of the ledger.
        Row(
          children: [
            const SizedBox(width: _CycleRow.dateWidth, child: MonoLabel('Began')),
            const Expanded(child: MonoLabel('Cycle')),
            SizedBox(
              width: _CycleRow.daysWidth,
              child: MonoLabel('Days', textAlign: TextAlign.end),
            ),
            const SizedBox(width: _CycleRow.menuWidth),
          ],
        ),
        Gap.v8,
        const Hairline(),
        for (var i = 0; i < cycles.length; i++) ...[
          _CycleRow(
            cycle: cycles[i],
            engine: engine,
            excluded: store.profile.excludedCycleStarts.contains(dayKey(cycles[i].start)),
            onToggleExclude: cycles[i].isCurrent ? null : () => _toggleExclude(context, cycles[i]),
          ),
          const Hairline(),
        ],
        Gap.v12,
        const _HistoryLegend(),
      ],
    );
  }
}

/// The key under the cycle ledger: what each mark on a bar means.
class _HistoryLegend extends StatelessWidget {
  const _HistoryLegend();

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final style = Almanac.data(context, size: 11.5);
    Widget item(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 18, height: 12, child: Center(child: mark)),
        const SizedBox(width: 6),
        Text(text, style: style),
      ],
    );
    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.xs,
      children: [
        item(Container(width: 16, height: 4, color: p.period), 'Period'),
        item(Container(width: 16, height: 3, color: p.fertile), 'Fertile'),
        item(Container(width: 1.5, height: 11, color: p.ink), 'Ovulation'),
      ],
    );
  }
}

class _CycleRow extends StatelessWidget {
  const _CycleRow({required this.cycle, required this.engine, required this.excluded, this.onToggleExclude});
  final Cycle cycle;
  final CycleEngine engine;
  final bool excluded;
  final VoidCallback? onToggleExclude;

  static const dateWidth = 76.0;
  static const daysWidth = 40.0;
  static const menuWidth = 40.0;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final len = cycle.length ?? daysBetween(cycle.start, engine.today) + 1;
    final range = cycle.isCurrent
        ? 'Current cycle, since ${fmtShort(cycle.start)}, day $len'
        : '${fmtShort(cycle.start)} to ${fmtFull(addDays(cycle.nextStart!, -1))}, $len days';
    final note = cycle.isCurrent ? 'Now · day $len' : (excluded ? 'Excluded' : '${cycle.period.length}-day period');
    return Semantics(
      label: '$range, ${cycle.period.length}-day period${excluded ? ', excluded from averages' : ''}',
      child: Pressable(
        onLongPress: onToggleExclude,
        pressedOpacity: 0.7,
        child: AnimatedOpacity(
          duration: Motion.medium,
          opacity: excluded ? 0.45 : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                SizedBox(
                  width: dateWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMM d').format(cycle.start).toUpperCase(),
                        style: Almanac.mono(size: 12, weight: FontWeight.w500, color: p.ink, letterSpacing: 0.6),
                      ),
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Almanac.data(context, size: 10.5, color: cycle.isCurrent ? p.period : null),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CycleBar(cycle: cycle, length: len),
                ),
                SizedBox(
                  width: daysWidth,
                  child: Text(
                    '$len',
                    textAlign: TextAlign.end,
                    style: Almanac.numeral(
                      context,
                      size: 20,
                      weight: 360,
                    ).copyWith(fontStyle: cycle.isCurrent ? FontStyle.italic : null),
                  ),
                ),
                SizedBox(
                  width: menuWidth,
                  child: onToggleExclude == null
                      ? null
                      : PopupMenuButton<int>(
                          tooltip: 'Cycle options',
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_horiz, size: 18, color: p.ink2),
                          onSelected: (_) => onToggleExclude!(),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 0,
                              child: Text(excluded ? 'Include in averages' : 'Exclude from averages'),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin ledger bar for one cycle: a hairline for its length, a thick
/// oxblood stroke for the period, a sage stroke for the fertile window, and
/// an ink tick at ovulation.
///
/// All bars share a 45-day scale so cycles can be compared at a glance.
class CycleBar extends StatelessWidget {
  const CycleBar({super.key, required this.cycle, required this.length});
  final Cycle cycle;
  final int length;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final n = math.min(length, 120);
    int? idx(DateTime d) {
      final i = daysBetween(cycle.start, d);
      return i < 0 || i >= n ? null : i;
    }

    final periodEnd = math.min(cycle.period.length, n);
    final fs = math.max(0, daysBetween(cycle.start, cycle.fertileStart));
    final fe = math.min(n - 1, daysBetween(cycle.start, cycle.fertileEnd));
    return SizedBox(
      height: 14,
      child: CustomPaint(
        size: Size.infinite,
        painter: _CycleBarPainter(
          length: n,
          period: periodEnd,
          fertile: fe >= fs && fs < n ? (fs, fe) : null,
          ovulation: idx(cycle.ovulation),
          open: cycle.isCurrent,
          track: p.ink2.withValues(alpha: 0.4),
          periodColor: p.period,
          fertileColor: p.fertile,
          tick: p.ink,
        ),
      ),
    );
  }
}

class _CycleBarPainter extends CustomPainter {
  _CycleBarPainter({
    required this.length,
    required this.period,
    required this.fertile,
    required this.ovulation,
    required this.open,
    required this.track,
    required this.periodColor,
    required this.fertileColor,
    required this.tick,
  });

  final int length;
  final int period;
  final (int, int)? fertile;
  final int? ovulation;

  /// The cycle is still running: its end is drawn dotted instead of capped.
  final bool open;
  final Color track;
  final Color periodColor;
  final Color fertileColor;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    if (length <= 0) return;
    // A fixed scale of 45 days keeps bars comparable between cycles.
    final scale = math.max(45, length);
    final w = size.width / scale;
    final mid = size.height / 2;
    final end = w * length;
    final line = Paint()
      ..color = track
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(end, mid), line);
    if (open) {
      // A short dotted run past today: the cycle isn't finished.
      final dot = Paint()..color = track;
      for (var x = end + 3; x < math.min(size.width, end + 22); x += 4) {
        canvas.drawCircle(Offset(x, mid), 0.7, dot);
      }
    } else {
      canvas.drawLine(Offset(end, mid - 3), Offset(end, mid + 3), line);
    }
    if (fertile != null) {
      final (a, b) = fertile!;
      canvas.drawRect(Rect.fromLTWH(a * w, mid - 1.5, (b - a + 1) * w, 3), Paint()..color = fertileColor);
    }
    if (period > 0) {
      canvas.drawRect(Rect.fromLTWH(0, mid - 2.5, period * w, 5), Paint()..color = periodColor);
    }
    if (ovulation != null) {
      final x = (ovulation! + 0.5) * w;
      canvas.drawLine(
        Offset(x, mid - 6),
        Offset(x, mid + 6),
        Paint()
          ..color = tick
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_CycleBarPainter old) =>
      old.length != length ||
      old.period != period ||
      old.fertile != fertile ||
      old.ovulation != ovulation ||
      old.open != open ||
      old.track != track ||
      old.periodColor != periodColor ||
      old.fertileColor != fertileColor ||
      old.tick != tick;
}

// ---------------------------------------------------------------- charts

class _ChartsTab extends StatefulWidget {
  const _ChartsTab();

  @override
  State<_ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<_ChartsTab> {
  /// Index into `engine.cycles` for the BBT chart; null means the current cycle.
  int? _bbtCycle;
  int _trendDays = 90;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final engine = store.engine;
    final profile = store.profile;
    final p = BloomColors.of(context);

    final completed = engine.cycles.where((c) => !c.isCurrent).toList();
    final shown = completed.reversed.take(12).toList().reversed.toList();
    final periods = engine.periods
        .where((p) => p.end.isBefore(engine.today))
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed;

    final now = engine.today;
    final from = addDays(now, -_trendDays + 1);
    final trendLogs = store.logsBetween(from, now);
    Map<DateTime, double> series(String id, [double Function(double)? convert]) => {
      for (final l in trendLogs)
        if (l.metrics[id] != null) l.date: convert == null ? l.metrics[id]! : convert(l.metrics[id]!),
    };

    final lb = profile.weightUnit == WeightUnit.lb;
    var fig = 3;
    Widget trend(
      String title,
      String id, {
      String unit = '',
      int decimals = 0,
      double Function(double)? convert,
      bool zeroBased = false,
    }) {
      final pts = series(id, convert);
      fig++;
      return _Section(
        figure: 'Fig. $fig',
        title: title,
        subtitle: pts.isEmpty ? 'Last $_trendDays days' : 'Last $_trendDays days · ${pts.length} entries',
        child: pts.isEmpty
            ? _EmptyNote('No ${title.toLowerCase()} logged in the last $_trendDays days.')
            : TrendLineChart(
                points: pts,
                from: from,
                to: now,
                color: p.ink,
                unit: unit,
                decimals: decimals,
                zeroBased: zeroBased,
              ),
      );
    }

    return _Page(
      children: [
        _Section(
          figure: 'Fig. 1',
          title: 'Cycle length',
          subtitle: shown.isEmpty ? null : 'Last ${shown.length} completed cycles. Faded bars are excluded.',
          child: shown.isEmpty
              ? const _EmptyNote('Log at least two periods to chart your cycle length.')
              : Column(
                  children: [
                    SimpleBarChart(
                      color: BloomColors.ink,
                      average: engine.avgCycleLength.toDouble(),
                      unit: ' days',
                      bandMin: 21,
                      bandMax: 35,
                      items: [
                        for (final c in shown)
                          BarItem(
                            DateFormat('MMM').format(c.start),
                            c.length!.toDouble(),
                            muted: profile.excludedCycleStarts.contains(dayKey(c.start)),
                          ),
                      ],
                    ),
                    Gap.v12,
                    ChartLegend(
                      band: 'Typical range (21–35 days)',
                      average: 'Your average, ${engine.avgCycleLength} days',
                    ),
                  ],
                ),
        ),
        _Section(
          figure: 'Fig. 2',
          title: 'Period length',
          subtitle: periods.isEmpty ? null : 'Last ${periods.length} finished periods',
          child: periods.isEmpty
              ? const _EmptyNote('Finish logging a period to chart its length.')
              : Column(
                  children: [
                    SimpleBarChart(
                      color: BloomColors.period,
                      average: engine.avgPeriodLength.toDouble(),
                      unit: ' days',
                      items: [for (final p in periods) BarItem(DateFormat('MMM').format(p.start), p.length.toDouble())],
                    ),
                    Gap.v12,
                    ChartLegend(average: 'Your average, ${engine.avgPeriodLength} days'),
                  ],
                ),
        ),
        _buildBbt(context, store),
        SectionHeader(
          'Trends',
          label: 'Measures',
          trailing: TextTabs<int>(
            options: const [(30, '30d'), (90, '90d'), (365, '1y')],
            selected: _trendDays,
            onSelected: (v) => setState(() => _trendDays = v),
            size: 13.5,
          ),
        ),
        trend('Weight', 'weight', unit: lb ? ' lb' : ' kg', decimals: 1, convert: lb ? kgToLb : null),
        trend('Sleep', 'sleep', unit: ' h', decimals: 1, zeroBased: true),
        trend('Water', 'water', unit: ' ml', zeroBased: true),
        trend('Steps', 'steps', zeroBased: true),
        trend('Energy', 'energy', unit: '/5'),
      ],
    );
  }

  Widget _buildBbt(BuildContext context, AppStore store) {
    final engine = store.engine;
    if (engine.cycles.isEmpty) {
      return const _Section(
        figure: 'Fig. 3',
        title: 'Basal body temperature',
        child: _EmptyNote('Log a period and your morning temperature to see your BBT chart.'),
      );
    }
    final p = BloomColors.of(context);
    final index = (_bbtCycle ?? engine.cycles.length - 1).clamp(0, engine.cycles.length - 1);
    final cycle = engine.cycles[index];
    final end = cycleEnd(engine, cycle);
    final temps = cycleTemps(cycle, store.logs, end);
    final f = store.profile.tempUnit == TempUnit.fahrenheit;
    double conv(double c) => f ? cToF(c) : c;
    final cover = coverLine(temps, cycle.ovulation);
    final ovDay = daysBetween(cycle.start, cycle.ovulation) + 1;
    final hasShift = cover != null && temps.entries.any((e) => e.key.isAfter(cycle.ovulation));
    final picker = Row(
      children: [
        const MonoLabel('Cycle'),
        Gap.h12,
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.ink2.withValues(alpha: 0.6))),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: index,
              isDense: true,
              borderRadius: Radii.mdAll,
              dropdownColor: p.raised,
              icon: Icon(Icons.expand_more, size: 18, color: p.ink2),
              style: Almanac.sans(size: 14, weight: FontWeight.w500, color: p.ink, height: 1.3),
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              items: [
                for (var i = engine.cycles.length - 1; i >= math.max(0, engine.cycles.length - 12); i--)
                  DropdownMenuItem(
                    value: i,
                    child: Text(engine.cycles[i].isCurrent ? 'Current cycle' : fmtShort(engine.cycles[i].start)),
                  ),
              ],
              onChanged: (v) => setState(() => _bbtCycle = v),
            ),
          ),
        ),
      ],
    );
    return _Section(
      figure: 'Fig. 3',
      title: 'Basal body temperature',
      subtitle: temps.isEmpty
          ? null
          : 'Cover line: highest of the 6 readings up to ovulation. Filled dots are period days.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          picker,
          Gap.v16,
          if (temps.length < 2)
            const _EmptyNote('Log your temperature each morning, before getting up, to see your BBT chart.')
          else
            BbtChart(
              unit: f ? '°F' : '°C',
              cycleLength: daysBetween(cycle.start, end) + 1,
              temps: {for (final e in temps.entries) daysBetween(cycle.start, e.key) + 1: conv(e.value)},
              coverLine: hasShift ? conv(cover) : null,
              ovulationDay: ovDay,
              periodDays: {
                for (final e in temps.entries)
                  if (store.isPeriodDay(e.key)) daysBetween(cycle.start, e.key) + 1,
              },
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- symptoms

class _SymptomsTab extends StatefulWidget {
  const _SymptomsTab();

  @override
  State<_SymptomsTab> createState() => _SymptomsTabState();
}

class _SymptomsTabState extends State<_SymptomsTab> {
  int _cycles = 6;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final engine = store.engine;
    final start = windowStart(engine, _cycles) ?? addDays(engine.today, -180);
    final logs = store.logsBetween(start, engine.today);
    final symptoms = optionCounts(logs, categories: const ['symptoms']);
    final moods = optionCounts(logs, categories: const ['mood']);
    final all = optionCounts(logs);
    final freq = phaseFrequency(engine, logs);

    return _Page(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoLabel('Since ${fmtFull(start)}'),
                  const SizedBox(height: Space.xs),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Last ', style: Almanac.serif(size: 22, weight: 380)),
                        TextSpan(text: '$_cycles cycles', style: Almanac.serif(size: 22, weight: 300, italic: true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Gap.h8,
            TextTabs<int>(
              options: const [(3, '3'), (6, '6'), (12, '12')],
              selected: _cycles,
              onSelected: (v) => setState(() => _cycles = v),
            ),
          ],
        ),
        _Section(
          figure: 'Tally',
          title: 'Top symptoms',
          subtitle: symptoms.isEmpty ? null : 'Days logged',
          child: symptoms.isEmpty
              ? const _EmptyNote('No symptoms logged in this period yet.')
              : _CountBars(entries: symptoms.take(8).toList()),
        ),
        _Section(
          figure: 'Tally',
          title: 'Top moods',
          subtitle: moods.isEmpty ? null : 'Days logged',
          child: moods.isEmpty
              ? const _EmptyNote('No moods logged in this period yet.')
              : _CountBars(entries: moods.take(8).toList()),
        ),
        _Section(
          figure: 'Table',
          title: 'By cycle phase',
          subtitle: 'Days each entry was logged in each phase. Darker cells mean more often.',
          child: all.isEmpty
              ? const _EmptyNote('Log symptoms and moods to see when they show up in your cycle.')
              : _PhaseTable(rows: all.take(10).map((e) => e.key).toList(), freq: freq),
        ),
        _disclaimer,
      ],
    );
  }
}

/// A tally: each entry's name, a mono day count, and a thin ink rule whose
/// length is the count.
class _CountBars extends StatelessWidget {
  const _CountBars({required this.entries});
  final List<MapEntry<OptionRef, int>> entries;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final max = entries.first.value;
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        optionRefText(e.key),
                        overflow: TextOverflow.ellipsis,
                        style: Almanac.sans(size: 14.5, color: p.ink, height: 1.35),
                      ),
                    ),
                    Gap.h8,
                    Text(e.value == 1 ? '1 day' : '${e.value} days', style: Almanac.data(context, size: 12)),
                  ],
                ),
                const SizedBox(height: 5),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: e.value / max),
                  duration: Motion.slow,
                  curve: Motion.emphasized,
                  builder: (context, v, _) => SizedBox(
                    height: 3,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Center(child: Container(height: 1, color: p.hairline)),
                        ),
                        FractionallySizedBox(
                          widthFactor: v.clamp(0.02, 1.0),
                          child: Container(color: p.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A printed table of entries by cycle phase, with shaded cells.
class _PhaseTable extends StatelessWidget {
  const _PhaseTable({required this.rows, required this.freq});
  final List<OptionRef> rows;
  final Map<OptionRef, Map<Phase, int>> freq;

  static Color _colorOf(BloomPalette p, Phase phase) => switch (phase) {
    Phase.menstrual => p.period,
    Phase.follicular => p.follicular,
    Phase.ovulation => p.fertile,
    Phase.luteal => p.luteal,
  };

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final max = freq.values.expand((m) => m.values).fold<int>(1, math.max);
    return Table(
      columnWidths: const {0: FlexColumnWidth(2.4)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(horizontalInside: BorderSide(color: p.hairline)),
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            for (final ph in tablePhases)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Column(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: _colorOf(p, ph), shape: BoxShape.circle),
                    ),
                    Gap.v4,
                    FittedBox(fit: BoxFit.scaleDown, child: MonoLabel(phaseShort(ph), size: 9.5)),
                  ],
                ),
              ),
          ],
        ),
        for (final r in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: Text(
                  optionRefText(r),
                  overflow: TextOverflow.ellipsis,
                  style: Almanac.sans(size: 13.5, color: p.ink, height: 1.3),
                ),
              ),
              for (final ph in tablePhases)
                Builder(
                  builder: (context) {
                    final n = freq[r]?[ph] ?? 0;
                    final t = n / max;
                    final c = _colorOf(p, ph);
                    final fill = c.withValues(alpha: n == 0 ? 0 : (dark ? 0.14 : 0.1) + 0.72 * t);
                    final strong = n > 0 && t > 0.5;
                    return Container(
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
                      alignment: Alignment.center,
                      color: fill,
                      child: Text(
                        n == 0 ? '·' : '$n',
                        style: Almanac.mono(
                          size: 12,
                          weight: FontWeight.w500,
                          color: n == 0 ? p.ink2.withValues(alpha: 0.5) : (strong ? BloomColors.onColor(c) : p.ink),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- patterns

class _PatternsTab extends StatelessWidget {
  const _PatternsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final patterns = detectPatterns(store.engine, store.logs);
    final p = BloomColors.of(context);
    if (patterns.isEmpty) {
      return const _Page(
        children: [
          EmptyState(
            glyph: Botanical.seedHead,
            color: BloomColors.luteal,
            title: 'No patterns yet',
            body: 'As you log periods, symptoms, and moods over a few cycles, patterns will show up here.',
          ),
        ],
      );
    }
    final attention = patterns.where((p) => p.tone == PatternTone.attention).length;
    final count = patterns.length == 1
        ? 'One observation'
        : '${_capitalize(Almanac.spell(patterns.length))} observations';
    return _Page(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$count ', style: Almanac.serif(size: 22, weight: 380)),
              TextSpan(
                text: attention == 0 ? 'from your history.' : '· $attention worth a closer look.',
                style: Almanac.serif(size: 22, weight: 300, italic: true, color: p.ink2),
              ),
            ],
          ),
        ),
        for (var i = 0; i < patterns.length; i++) _PatternNote(number: i + 1, pattern: patterns[i]),
        const Hairline(),
        _disclaimer,
      ],
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// One observation, set as a numbered editorial note.
class _PatternNote extends StatelessWidget {
  const _PatternNote({required this.number, required this.pattern});
  final int number;
  final PatternInsight pattern;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final attention = pattern.tone == PatternTone.attention;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Hairline(),
        Gap.v16,
        Marginalia(
          label: 'No. $number',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (attention) ...[
                Row(
                  children: [
                    Icon(Icons.priority_high, size: 13, color: readableTint(BloomColors.warning, theme.brightness)),
                    const SizedBox(width: 4),
                    MonoLabel('Worth a look', color: readableTint(BloomColors.warning, theme.brightness)),
                  ],
                ),
                Gap.v8,
              ],
              Text(pattern.title, style: Almanac.serif(size: 20, weight: 380, color: p.ink, height: 1.2)),
              Gap.v8,
              Text(pattern.body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
