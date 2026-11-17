/// Graphs and reports: cycle summary, history, charts, symptom statistics,
/// and pattern cards.
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
import 'analysis_charts.dart';
import 'analysis_data.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (canPop)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.sm),
                            child: Transform.translate(
                              offset: const Offset(-Space.sm, 0),
                              child: IconButton(
                                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                            ),
                          ),
                        Text('My cycles', style: theme.textTheme.headlineLarge),
                        Padding(
                          padding: const EdgeInsets.only(top: Space.xs),
                          child: Text(
                            'Graphs and reports from your own logs',
                            style: theme.textTheme.bodyLarge?.copyWith(color: tokens.muted),
                          ),
                        ),
                        Gap.v16,
                        const _Tabs(),
                      ],
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [_SummaryTab(), _ChartsTab(), _SymptomsTab(), _PatternsTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped segmented tab bar.
class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final light = theme.brightness == Brightness.light;
    return Container(
      height: 46,
      width: double.infinity,
      padding: Insets.all4,
      decoration: BoxDecoration(color: tokens.subtle, borderRadius: Radii.pillAll),
      child: TabBar(
        dividerHeight: 0,
        tabAlignment: TabAlignment.fill,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: Radii.pillAll,
        labelPadding: const EdgeInsets.symmetric(horizontal: Space.xs),
        indicator: BoxDecoration(
          color: light ? Colors.white : theme.colorScheme.primary.withValues(alpha: 0.2),
          borderRadius: Radii.pillAll,
          boxShadow: light ? tokens.cardShadow : null,
        ),
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: tokens.muted,
        labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        tabs: [
          for (final t in const ['Summary', 'Charts', 'Symptoms', 'Patterns'])
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text(t))),
        ],
      ),
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
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: children,
      );
}

/// A card with an icon, a title, an optional subtitle, and content.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, this.subtitle, required this.child, this.icon, this.color});
  final String title;
  final String? subtitle;
  final Widget child;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[IconBadge(icon: icon, color: color, size: 36), Gap.h12],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: Space.xxs),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Gap.v16,
          child,
        ],
      ),
    );
  }
}

/// A short, muted "nothing here yet" note for use inside a card.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message, {this.icon = Icons.insights_rounded});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = BloomTokens.of(context);
    return Container(
      width: double.infinity,
      padding: Insets.all16,
      decoration: BoxDecoration(color: tokens.subtle, borderRadius: Radii.mdAll),
      child: Row(children: [
        Icon(icon, color: tokens.muted, size: 22),
        Gap.h12,
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.muted)),
        ),
      ]),
    );
  }
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
      return const _Page(children: [
        EmptyState(
          icon: Icons.water_drop_rounded,
          color: BloomColors.period,
          title: 'No cycles yet',
          body: 'Log your period to see your cycle summary and history.',
        ),
      ]);
    }
    final h = engine.health();
    return _Page(children: [
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
              child: StatTile(
                value: '${engine.avgCycleLength}',
                label: 'Average cycle',
                caption: 'days',
                icon: Icons.autorenew_rounded,
                color: BloomColors.luteal,
              ),
            ),
            Gap.h12,
            Expanded(
              child: StatTile(
                value: '${engine.avgPeriodLength}',
                label: 'Average period',
                caption: 'days',
                icon: Icons.water_drop_rounded,
                color: BloomColors.period,
              ),
            ),
            Gap.h12,
            Expanded(
              child: StatTile(
                value: h.enoughData ? '±${h.variation}' : '–',
                label: 'Variation',
                caption: h.enoughData ? 'days' : 'needs 3 cycles',
                icon: Icons.swap_vert_rounded,
                color: BloomColors.fertile,
              ),
            ),
          ],
        ),
      ),
      const SectionHeader('Cycle health', subtitle: 'How your recent cycles compare to typical ranges'),
      _HealthCard(health: h),
      const SectionHeader(
        'Cycle history',
        subtitle: 'Long-press a past cycle, or use its menu, to exclude it from averages.',
      ),
      _HistoryCard(store: store),
      _disclaimer,
    ]);
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health});
  final CycleHealth health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final h = health;
    Widget row(IconData icon, String title, String badge, bool good, String explanation) {
      final color = good ? BloomColors.success : BloomColors.warning;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, color: color, size: 40),
            Gap.h12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                    Gap.h8,
                    PillChip(
                      badge,
                      color: color,
                      icon: good ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      dense: true,
                    ),
                  ]),
                  Gap.v4,
                  Text(explanation, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return BloomCard(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!h.enoughData)
            const Padding(
              padding: EdgeInsets.only(top: Space.md),
              child: _EmptyNote(
                'Log at least 3 periods to see how your cycles compare to typical ranges.',
                icon: Icons.hourglass_bottom_rounded,
              ),
            )
          else ...[
            row(
              Icons.autorenew_rounded,
              'Cycle length',
              h.cycleNormal ? 'Normal' : 'Check',
              h.cycleNormal,
              h.cycleNormal
                  ? 'Your recent cycles fall within 21 to 35 days, the typical adult range.'
                  : 'At least one recent cycle was shorter than 21 or longer than 35 days.',
            ),
            Divider(height: 1, color: tokens.border),
            row(
              Icons.water_drop_rounded,
              'Period length',
              h.periodNormal ? 'Normal' : 'Check',
              h.periodNormal,
              h.periodNormal
                  ? 'Your recent periods lasted 2 to 7 days, the typical range.'
                  : 'At least one recent period lasted less than 2 or more than 7 days.',
            ),
            Divider(height: 1, color: tokens.border),
            row(
              Icons.timeline_rounded,
              'Regularity',
              h.regular ? 'Regular' : 'Irregular',
              h.regular,
              h.regular
                  ? 'Your shortest and longest recent cycles differ by ${h.variation} days (7 or less is regular).'
                  : 'Your shortest and longest recent cycles differ by ${h.variation} days, more than the 7 days '
                      'usually considered regular.',
            ),
          ],
          Gap.v12,
          Text(
            'Ranges follow guidance from the American College of Obstetricians and Gynecologists (ACOG).',
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(excluded ? 'Cycle included in averages' : 'Cycle excluded from averages'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final engine = store.engine;
    final tokens = BloomTokens.of(context);
    final cycles = engine.cycles.reversed.toList();
    return BloomCard(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.lg),
      child: Column(children: [
        for (var i = 0; i < cycles.length; i++) ...[
          if (i > 0) Padding(padding: const EdgeInsets.only(right: Space.sm), child: Divider(height: 1, color: tokens.border)),
          _CycleRow(
            cycle: cycles[i],
            engine: engine,
            excluded: store.profile.excludedCycleStarts.contains(dayKey(cycles[i].start)),
            onToggleExclude: cycles[i].isCurrent ? null : () => _toggleExclude(context, cycles[i]),
          ),
        ],
        Gap.v12,
        Padding(
          padding: const EdgeInsets.only(right: Space.sm),
          child: Wrap(spacing: Space.lg, runSpacing: Space.xs, alignment: WrapAlignment.center, children: [
            _legendDot(context, BloomColors.period, 'Period'),
            _legendDot(context, BloomColors.fertile, 'Fertile'),
            _legendDot(context, BloomColors.ovulation, 'Ovulation', round: true),
          ]),
        ),
      ]),
    );
  }
}

Widget _legendDot(BuildContext context, Color color, String label, {bool round = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: round ? 10 : 14,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(round ? 5 : 3)),
        ),
        Gap.h8,
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: BloomTokens.of(context).muted)),
      ],
    );

class _CycleRow extends StatelessWidget {
  const _CycleRow({required this.cycle, required this.engine, required this.excluded, this.onToggleExclude});
  final Cycle cycle;
  final CycleEngine engine;
  final bool excluded;
  final VoidCallback? onToggleExclude;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final len = cycle.length ?? daysBetween(cycle.start, engine.today) + 1;
    final title = cycle.isCurrent
        ? 'Current cycle'
        : '${fmtShort(cycle.start)} – ${fmtFull(addDays(cycle.nextStart!, -1))}';
    final details = cycle.isCurrent
        ? 'Since ${fmtShort(cycle.start)} · day $len · ${cycle.period.length}-day period'
        : '${cycle.period.length}-day period';
    return InkWell(
      onLongPress: onToggleExclude,
      borderRadius: Radii.smAll,
      child: AnimatedOpacity(
        duration: Motion.medium,
        opacity: excluded ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: Space.xxs),
                  Text(details, style: theme.textTheme.bodySmall),
                ]),
              ),
              if (cycle.isCurrent) const PillChip('Now', color: BloomColors.brand, dense: true),
              if (excluded) PillChip('Excluded', color: tokens.muted, dense: true),
              if (onToggleExclude != null)
                PopupMenuButton<int>(
                  tooltip: 'Cycle options',
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: tokens.muted),
                  onSelected: (_) => onToggleExclude!(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Text(excluded ? 'Include in averages' : 'Exclude from averages')),
                  ],
                )
              else
                const SizedBox(width: Space.sm),
            ]),
            Gap.v8,
            Padding(
              padding: EdgeInsets.only(right: onToggleExclude != null ? Space.sm : Space.sm),
              child: Row(children: [
                Expanded(child: CycleBar(cycle: cycle, length: len)),
                Gap.h12,
                SizedBox(
                  width: 52,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$len', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      TextSpan(text: ' days', style: theme.textTheme.bodySmall),
                    ]),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A horizontal bar showing period, fertile, and ovulation days in a cycle.
///
/// All bars share a 45-day scale so cycles can be compared at a glance.
class CycleBar extends StatelessWidget {
  const CycleBar({super.key, required this.cycle, required this.length});
  final Cycle cycle;
  final int length;

  @override
  Widget build(BuildContext context) {
    final n = math.min(length, 120);
    int? idx(DateTime d) {
      final i = daysBetween(cycle.start, d);
      return i < 0 || i >= n ? null : i;
    }

    final periodEnd = math.min(cycle.period.length, n);
    final fs = math.max(0, daysBetween(cycle.start, cycle.fertileStart));
    final fe = math.min(n - 1, daysBetween(cycle.start, cycle.fertileEnd));
    return SizedBox(
      height: 12,
      child: CustomPaint(
        size: Size.infinite,
        painter: _CycleBarPainter(
          length: n,
          period: periodEnd,
          fertile: fe >= fs && fs < n ? (fs, fe) : null,
          ovulation: idx(cycle.ovulation),
          track: BloomTokens.of(context).subtle,
          ring: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainer
              : Colors.white,
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
    required this.track,
    required this.ring,
  });

  final int length;
  final int period;
  final (int, int)? fertile;
  final int? ovulation;
  final Color track;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    if (length <= 0) return;
    // A fixed scale of 45 days keeps bars comparable between cycles.
    final scale = math.max(45, length);
    final w = size.width / scale;
    final h = size.height;
    final r = Radius.circular(h / 2);
    final full = Rect.fromLTWH(0, 0, w * length, h);
    canvas.drawRRect(RRect.fromRectAndRadius(full, r), Paint()..color = track);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(full, r));
    if (fertile != null) {
      final (a, b) = fertile!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(a * w, 0, (b - a + 1) * w, h), r),
        Paint()..color = BloomColors.fertile.withValues(alpha: 0.55),
      );
    }
    if (period > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, period * w, h), r),
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFFE8396E), BloomColors.period])
              .createShader(Rect.fromLTWH(0, 0, period * w, h)),
      );
    }
    canvas.restore();
    if (ovulation != null) {
      final c = Offset((ovulation! + 0.5) * w, h / 2);
      canvas.drawCircle(c, h / 2 + 1.5, Paint()..color = ring);
      canvas.drawCircle(c, h / 2 - 0.5, Paint()..color = BloomColors.ovulation);
    }
  }

  @override
  bool shouldRepaint(_CycleBarPainter old) =>
      old.length != length ||
      old.period != period ||
      old.fertile != fertile ||
      old.ovulation != ovulation ||
      old.track != track ||
      old.ring != ring;
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

    final completed = engine.cycles.where((c) => !c.isCurrent).toList();
    final shown = completed.reversed.take(12).toList().reversed.toList();
    final periods = engine.periods.where((p) => p.end.isBefore(engine.today)).toList().reversed.take(12).toList().reversed;

    final now = engine.today;
    final from = addDays(now, -_trendDays + 1);
    final trendLogs = store.logsBetween(from, now);
    Map<DateTime, double> series(String id, [double Function(double)? convert]) => {
          for (final l in trendLogs)
            if (l.metrics[id] != null) l.date: convert == null ? l.metrics[id]! : convert(l.metrics[id]!),
        };

    final lb = profile.weightUnit == WeightUnit.lb;
    Widget trend(String title, String id, Color color, IconData icon,
        {String unit = '', int decimals = 0, double Function(double)? convert, bool zeroBased = false}) {
      final pts = series(id, convert);
      return _ChartCard(
        title: title,
        icon: icon,
        color: color,
        subtitle: pts.isEmpty ? 'Last $_trendDays days' : 'Last $_trendDays days · ${pts.length} entries',
        child: pts.isEmpty
            ? _EmptyNote('No ${title.toLowerCase()} logged in the last $_trendDays days.', icon: Icons.show_chart_rounded)
            : TrendLineChart(
                points: pts, from: from, to: now, color: color, unit: unit, decimals: decimals, zeroBased: zeroBased),
      );
    }

    return _Page(children: [
      _ChartCard(
        title: 'Cycle length',
        icon: Icons.autorenew_rounded,
        color: BloomColors.luteal,
        subtitle: shown.isEmpty ? null : 'Last ${shown.length} completed cycles. Faded bars are excluded.',
        child: shown.isEmpty
            ? const _EmptyNote('Log at least two periods to chart your cycle length.')
            : Column(children: [
                SimpleBarChart(
                  color: BloomColors.luteal,
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
                const ChartLegend(band: 'Typical range (21–35 days)'),
              ]),
      ),
      _ChartCard(
        title: 'Period length',
        icon: Icons.water_drop_rounded,
        color: BloomColors.period,
        subtitle: periods.isEmpty ? null : 'Last ${periods.length} finished periods',
        child: periods.isEmpty
            ? const _EmptyNote('Finish logging a period to chart its length.')
            : SimpleBarChart(
                color: BloomColors.period,
                average: engine.avgPeriodLength.toDouble(),
                unit: ' days',
                items: [for (final p in periods) BarItem(DateFormat('MMM').format(p.start), p.length.toDouble())],
              ),
      ),
      _buildBbt(context, store),
      SectionHeader(
        'Trends',
        trailing: SegmentedButton<int>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            minimumSize: WidgetStatePropertyAll(Size(52, 40)),
          ),
          segments: const [
            ButtonSegment(value: 30, label: Text('30d')),
            ButtonSegment(value: 90, label: Text('90d')),
            ButtonSegment(value: 365, label: Text('1y')),
          ],
          selected: {_trendDays},
          onSelectionChanged: (s) => setState(() => _trendDays = s.first),
        ),
      ),
      trend('Weight', 'weight', BloomColors.brand, Icons.monitor_weight_rounded,
          unit: lb ? ' lb' : ' kg', decimals: 1, convert: lb ? kgToLb : null),
      trend('Sleep', 'sleep', BloomColors.luteal, Icons.bedtime_rounded, unit: ' h', decimals: 1, zeroBased: true),
      trend('Water', 'water', BloomColors.info, Icons.local_drink_rounded, unit: ' ml', zeroBased: true),
      trend('Steps', 'steps', BloomColors.fertile, Icons.directions_walk_rounded, zeroBased: true),
      trend('Energy', 'energy', BloomColors.pregnancy, Icons.bolt_rounded, unit: '/5'),
    ]);
  }

  Widget _buildBbt(BuildContext context, AppStore store) {
    final engine = store.engine;
    if (engine.cycles.isEmpty) {
      return const _ChartCard(
        title: 'Basal body temperature',
        icon: Icons.thermostat_rounded,
        color: BloomColors.brand,
        child: _EmptyNote('Log a period and your morning temperature to see your BBT chart.', icon: Icons.thermostat_rounded),
      );
    }
    final theme = Theme.of(context);
    final index = (_bbtCycle ?? engine.cycles.length - 1).clamp(0, engine.cycles.length - 1);
    final cycle = engine.cycles[index];
    final end = cycleEnd(engine, cycle);
    final temps = cycleTemps(cycle, store.logs, end);
    final f = store.profile.tempUnit == TempUnit.fahrenheit;
    double conv(double c) => f ? cToF(c) : c;
    final cover = coverLine(temps, cycle.ovulation);
    final ovDay = daysBetween(cycle.start, cycle.ovulation) + 1;
    final hasShift = cover != null && temps.entries.any((e) => e.key.isAfter(cycle.ovulation));
    final picker = Container(
      padding: const EdgeInsets.only(left: Space.md, right: Space.xs),
      decoration: BoxDecoration(color: BloomTokens.of(context).subtle, borderRadius: Radii.pillAll),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: index,
          isDense: true,
          borderRadius: Radii.mdAll,
          icon: const Icon(Icons.expand_more_rounded, size: 20),
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface),
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
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
    );
    return _ChartCard(
      title: 'Basal body temperature',
      icon: Icons.thermostat_rounded,
      color: BloomColors.brand,
      subtitle: temps.isEmpty ? null : 'Cover line: highest of the 6 readings up to ovulation. Filled dots are period days.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          picker,
          Gap.v16,
          if (temps.length < 2)
            const _EmptyNote('Log your temperature each morning, before getting up, to see your BBT chart.',
                icon: Icons.thermostat_rounded)
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
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final start = windowStart(engine, _cycles) ?? addDays(engine.today, -180);
    final logs = store.logsBetween(start, engine.today);
    final symptoms = optionCounts(logs, categories: const ['symptoms']);
    final moods = optionCounts(logs, categories: const ['mood']);
    final all = optionCounts(logs);
    final freq = phaseFrequency(engine, logs);

    return _Page(children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last $_cycles cycles', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('Since ${fmtFull(start)}', style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted)),
              ],
            ),
          ),
          Gap.h8,
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              minimumSize: WidgetStatePropertyAll(Size(48, 40)),
            ),
            segments: const [
              ButtonSegment(value: 3, label: Text('3')),
              ButtonSegment(value: 6, label: Text('6')),
              ButtonSegment(value: 12, label: Text('12')),
            ],
            selected: {_cycles},
            onSelectionChanged: (s) => setState(() => _cycles = s.first),
          ),
        ],
      ),
      _ChartCard(
        title: 'Top symptoms',
        icon: Icons.healing_rounded,
        color: Color(categoryById('symptoms')!.colorHex),
        subtitle: symptoms.isEmpty ? null : 'Days logged',
        child: symptoms.isEmpty
            ? const _EmptyNote('No symptoms logged in this period yet.', icon: Icons.healing_rounded)
            : _CountBars(entries: symptoms.take(8).toList(), color: Color(categoryById('symptoms')!.colorHex)),
      ),
      _ChartCard(
        title: 'Top moods',
        icon: Icons.mood_rounded,
        color: Color(categoryById('mood')!.colorHex),
        subtitle: moods.isEmpty ? null : 'Days logged',
        child: moods.isEmpty
            ? const _EmptyNote('No moods logged in this period yet.', icon: Icons.mood_rounded)
            : _CountBars(entries: moods.take(8).toList(), color: Color(categoryById('mood')!.colorHex)),
      ),
      _ChartCard(
        title: 'By cycle phase',
        icon: Icons.grid_on_rounded,
        color: BloomColors.luteal,
        subtitle: 'Days each entry was logged in each phase. Darker cells mean more often.',
        child: all.isEmpty
            ? const _EmptyNote('Log symptoms and moods to see when they show up in your cycle.')
            : _PhaseTable(rows: all.take(10).map((e) => e.key).toList(), freq: freq),
      ),
      _disclaimer,
    ]);
  }
}

class _CountBars extends StatelessWidget {
  const _CountBars({required this.entries, required this.color});
  final List<MapEntry<OptionRef, int>> entries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final max = entries.first.value;
    final fg = readableTint(color, theme.brightness);
    return Column(children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(optionRefLabel(e.key), overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                ),
                Gap.h8,
                Text(
                  e.value == 1 ? '1 day' : '${e.value} days',
                  style: theme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800),
                ),
              ]),
              Gap.v4,
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: e.value / max),
                duration: Motion.slow,
                curve: Motion.emphasized,
                builder: (context, v, _) => Container(
                  height: 8,
                  decoration: BoxDecoration(color: tokens.subtle, borderRadius: Radii.pillAll),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: Radii.pillAll,
                        gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ]);
  }
}

class _PhaseTable extends StatelessWidget {
  const _PhaseTable({required this.rows, required this.freq});
  final List<OptionRef> rows;
  final Map<OptionRef, Map<Phase, int>> freq;

  static const _colors = {
    Phase.menstrual: BloomColors.period,
    Phase.follicular: BloomColors.follicular,
    Phase.ovulation: BloomColors.fertile,
    Phase.luteal: BloomColors.luteal,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final dark = theme.brightness == Brightness.dark;
    final max = freq.values.expand((m) => m.values).fold<int>(1, math.max);
    return Table(
      columnWidths: const {0: FlexColumnWidth(2.4)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          const SizedBox.shrink(),
          for (final p in tablePhases)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Column(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: _colors[p], shape: BoxShape.circle),
                ),
                Gap.v4,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    phaseShort(p),
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: tokens.muted),
                  ),
                ),
              ]),
            ),
        ]),
        for (final r in rows)
          TableRow(children: [
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Text(optionRefLabel(r), overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              )),
            ),
            for (final p in tablePhases)
              Builder(builder: (context) {
                final n = freq[r]?[p] ?? 0;
                final t = n / max;
                final c = _colors[p]!;
                return Container(
                  height: 32,
                  margin: const EdgeInsets.all(2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.xs),
                    color: n == 0 ? tokens.subtle : c.withValues(alpha: (dark ? 0.2 : 0.14) + 0.76 * t),
                  ),
                  child: Text(
                    n == 0 ? '' : '$n',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: t > 0.55 ? Colors.white : readableTint(c, theme.brightness),
                    ),
                  ),
                );
              }),
          ]),
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
    final theme = Theme.of(context);
    if (patterns.isEmpty) {
      return const _Page(children: [
        EmptyState(
          icon: Icons.auto_awesome_rounded,
          color: BloomColors.luteal,
          title: 'No patterns yet',
          body: 'As you log periods, symptoms, and moods over a few cycles, patterns will show up here.',
        ),
      ]);
    }
    final attention = patterns.where((p) => p.tone == PatternTone.attention).length;
    return _Page(children: [
      Text(
        attention == 0
            ? '${patterns.length == 1 ? '1 observation' : '${patterns.length} observations'} from your history'
            : '${patterns.length} observations · $attention worth a closer look',
        style: theme.textTheme.bodyMedium?.copyWith(color: BloomTokens.of(context).muted),
      ),
      for (final p in patterns) _PatternCard(pattern: p),
      _disclaimer,
    ]);
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.pattern});
  final PatternInsight pattern;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attention = pattern.tone == PatternTone.attention;
    final color = attention ? BloomColors.warning : BloomColors.luteal;
    final body = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      IconBadge(emoji: pattern.icon, color: color, size: 44),
      Gap.h16,
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (attention) ...[
            const PillChip('Worth a look', color: BloomColors.warning, icon: Icons.flag_rounded, dense: true),
            Gap.v8,
          ],
          Text(pattern.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          Gap.v4,
          Text(pattern.body, style: theme.textTheme.bodyMedium),
        ]),
      ),
    ]);
    return attention ? BloomCard.tinted(color: color, child: body) : BloomCard(child: body);
  }
}
