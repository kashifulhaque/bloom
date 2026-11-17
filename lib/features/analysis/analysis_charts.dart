/// Chart widgets for the analysis screen, built on fl_chart and themed to
/// the design system.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../widgets/widgets.dart';

/// Shared chart styling: muted gridlines, readable axis labels, and tooltips.
class _ChartStyle {
  _ChartStyle(BuildContext context)
      : theme = Theme.of(context),
        tokens = BloomTokens.of(context);

  final ThemeData theme;
  final BloomTokens tokens;

  bool get dark => theme.brightness == Brightness.dark;

  TextStyle get axis => theme.textTheme.labelSmall!.copyWith(color: tokens.muted, fontWeight: FontWeight.w600);

  FlLine grid(double _) => FlLine(color: tokens.border, strokeWidth: 1, dashArray: const [4, 4]);

  Color tooltipColor(Object _) => dark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF2A1F2D);

  TextStyle get tooltipText =>
      theme.textTheme.labelMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1.35);

  static const tooltipRadius = BorderRadius.all(Radius.circular(Radii.sm));
  static const tooltipPadding = EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm);
}

/// One bar in a [SimpleBarChart].
class BarItem {
  const BarItem(this.label, this.value, {this.color, this.muted = false});
  final String label;
  final double value;
  final Color? color;

  /// Drawn faded, for example an excluded cycle.
  final bool muted;
}

/// A compact bar chart with an optional dashed average line and a shaded
/// typical-range band.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.items,
    required this.color,
    this.average,
    this.unit = '',
    this.height = 200,
    this.bandMin,
    this.bandMax,
  });

  final List<BarItem> items;
  final Color color;
  final double? average;
  final String unit;
  final double height;

  /// Optional typical range, drawn as a soft band behind the bars.
  final double? bandMin;
  final double? bandMax;

  @override
  Widget build(BuildContext context) {
    final s = _ChartStyle(context);
    final maxV = [
      ...items.map((e) => e.value),
      ?average,
      ?bandMax,
    ].fold<double>(1, math.max);
    final top = (maxV * 1.15).ceilToDouble();
    final step = math.max(1, (items.length / 6).ceil());
    final interval = _niceInterval(top);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: top,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: interval, getDrawingHorizontalLine: s.grid),
          rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
            if (bandMin != null && bandMax != null)
              HorizontalRangeAnnotation(
                y1: bandMin!,
                y2: bandMax!,
                color: BloomColors.fertile.withValues(alpha: s.dark ? 0.12 : 0.08),
              ),
          ]),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: s.tooltipColor,
              tooltipBorderRadius: _ChartStyle.tooltipRadius,
              tooltipPadding: _ChartStyle.tooltipPadding,
              tooltipMargin: Space.sm,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${items[group.x].label}\n',
                s.tooltipText.copyWith(fontWeight: FontWeight.w600, color: Colors.white70),
                children: [TextSpan(text: '${_fmt(rod.toY)}$unit', style: s.tooltipText)],
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(horizontalLines: [
            if (average != null)
              HorizontalLine(
                y: average!,
                color: s.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                strokeWidth: 1.4,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(bottom: 2),
                  style: s.axis.copyWith(color: s.theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800),
                  labelResolver: (l) => 'avg ${_fmt(l.y)}',
                ),
              ),
          ]),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: interval,
                getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox.shrink() : Text(_fmt(v), style: s.axis),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= items.length || (items.length - 1 - i) % step != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(items[i].label, style: s.axis));
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < items.length; i++)
              BarChartGroupData(x: i, barRods: [
                () {
                  final c = (items[i].color ?? color).withValues(alpha: items[i].muted ? 0.3 : 1);
                  final w = math.min(24.0, 220 / math.max(1, items.length));
                  return BarChartRodData(
                    toY: items[i].value,
                    width: w,
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [c.withValues(alpha: c.a * 0.75), c],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(w / 2.5), bottom: const Radius.circular(3)),
                  );
                }(),
              ]),
          ],
        ),
        duration: Motion.slow,
        curve: Motion.curve,
      ),
    );
  }
}

/// A legend row for charts with a typical-range band and an average line.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, this.band, this.average = 'Your average'});
  final String? band;
  final String average;

  @override
  Widget build(BuildContext context) {
    final s = _ChartStyle(context);
    final style = s.theme.textTheme.labelMedium?.copyWith(color: s.tokens.muted);
    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.xs,
      alignment: WrapAlignment.center,
      children: [
        if (band != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 16,
              height: 10,
              decoration: BoxDecoration(
                color: BloomColors.fertile.withValues(alpha: s.dark ? 0.25 : 0.18),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Gap.h8,
            Flexible(child: Text(band!, style: style)),
          ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 16,
            height: 10,
            child: CustomPaint(painter: _DashPainter(s.theme.colorScheme.onSurfaceVariant)),
          ),
          Gap.h8,
          Flexible(child: Text(average, style: style)),
        ]),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(6, y), p);
    canvas.drawLine(Offset(10, y), Offset(size.width, y), p);
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// A dated series of values, shown as a smooth line with a gradient fill.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    required this.from,
    required this.to,
    required this.color,
    this.unit = '',
    this.decimals = 0,
    this.height = 180,
    this.zeroBased = false,
  });

  final Map<DateTime, double> points;
  final DateTime from;
  final DateTime to;
  final Color color;
  final String unit;
  final int decimals;
  final double height;
  final bool zeroBased;

  @override
  Widget build(BuildContext context) {
    final s = _ChartStyle(context);
    final entries = points.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final spots = [for (final e in entries) FlSpot(daysBetween(from, e.key).toDouble(), e.value)];
    final values = entries.map((e) => e.value);
    var lo = values.reduce(math.min), hi = values.reduce(math.max);
    final pad = math.max((hi - lo) * 0.15, hi.abs() * 0.02 + 0.1);
    lo = zeroBased ? 0 : lo - pad;
    hi = hi + pad;
    final span = daysBetween(from, to).toDouble();
    final dotFill = s.dark ? s.theme.colorScheme.surfaceContainer : Colors.white;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: span,
          minY: lo,
          maxY: hi,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: s.grid),
          lineTouchData: LineTouchData(
            getTouchedSpotIndicator: (bar, idx) => [
              for (final _ in idx)
                TouchedSpotIndicatorData(
                  FlLine(color: color.withValues(alpha: 0.4), strokeWidth: 1.5, dashArray: const [3, 3]),
                  FlDotData(
                    getDotPainter: (_, _, _, _) =>
                        FlDotCirclePainter(radius: 5, color: color, strokeColor: dotFill, strokeWidth: 2.5),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: s.tooltipColor,
              tooltipBorderRadius: _ChartStyle.tooltipRadius,
              tooltipPadding: _ChartStyle.tooltipPadding,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final sp in spots)
                  LineTooltipItem(
                    '${fmtShort(addDays(from, sp.x.round()))}\n',
                    s.tooltipText.copyWith(fontWeight: FontWeight.w600, color: Colors.white70),
                    children: [TextSpan(text: '${sp.y.toStringAsFixed(decimals)}$unit', style: s.tooltipText)],
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
                reservedSize: 44,
                getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
                    ? const SizedBox.shrink()
                    : Text(_compact(v, decimals), style: s.axis),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: math.max(1, span / 3).floorToDouble(),
                getTitlesWidget: (v, meta) => v > span
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(DateFormat('MMM d').format(addDays(from, v.round())), style: s.axis),
                      ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: color,
              barWidth: 2.5,
              isCurved: spots.length > 2,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: spots.length <= 31,
                getDotPainter: (_, _, _, _) =>
                    FlDotCirclePainter(radius: 3, color: color, strokeColor: dotFill, strokeWidth: 1.5),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: s.dark ? 0.32 : 0.24), color.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
        duration: Motion.slow,
        curve: Motion.curve,
      ),
    );
  }
}

/// Basal body temperature for one cycle, by cycle day, with a cover line
/// and an ovulation marker.
class BbtChart extends StatelessWidget {
  const BbtChart({
    super.key,
    required this.temps,
    required this.cycleLength,
    this.coverLine,
    this.ovulationDay,
    this.periodDays = const {},
    this.unit = '°C',
    this.height = 220,
  });

  /// Cycle day (1-based) → temperature in display units.
  final Map<int, double> temps;
  final int cycleLength;
  final double? coverLine;
  final int? ovulationDay;
  final Set<int> periodDays;
  final String unit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final s = _ChartStyle(context);
    final entries = temps.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final values = [...entries.map((e) => e.value), ?coverLine];
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final pad = math.max(0.15, (hi - lo) * 0.2);
    final dotFill = s.dark ? s.theme.colorScheme.surfaceContainer : Colors.white;
    final lutealLabel = readableTint(BloomColors.luteal, s.theme.brightness);
    final ovulationLabel = readableTint(BloomColors.ovulation, s.theme.brightness);
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: math.max(cycleLength, entries.last.key).toDouble(),
          minY: lo - pad,
          maxY: hi + pad,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: s.grid),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: s.tooltipColor,
              tooltipBorderRadius: _ChartStyle.tooltipRadius,
              tooltipPadding: _ChartStyle.tooltipPadding,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final sp in spots)
                  LineTooltipItem(
                    'Day ${sp.x.round()}\n',
                    s.tooltipText.copyWith(fontWeight: FontWeight.w600, color: Colors.white70),
                    children: [TextSpan(text: '${sp.y.toStringAsFixed(2)} $unit', style: s.tooltipText)],
                  ),
              ],
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (coverLine != null)
                HorizontalLine(
                  y: coverLine!,
                  color: BloomColors.luteal,
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topLeft,
                    style: s.axis.copyWith(color: lutealLabel, fontWeight: FontWeight.w800),
                    labelResolver: (l) => 'Cover line ${l.y.toStringAsFixed(2)}',
                  ),
                ),
            ],
            verticalLines: [
              if (ovulationDay != null)
                VerticalLine(
                  x: ovulationDay!.toDouble(),
                  color: BloomColors.ovulation.withValues(alpha: 0.8),
                  strokeWidth: 1.5,
                  dashArray: [3, 3],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: s.axis.copyWith(color: ovulationLabel, fontWeight: FontWeight.w800),
                    labelResolver: (_) => 'Ovulation',
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
                    ? const SizedBox.shrink()
                    : Text(v.toStringAsFixed(1), style: s.axis),
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text('Cycle day', style: s.axis),
              axisNameSize: 18,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 7,
                // Skip the end label when it would crowd the last weekly tick.
                getTitlesWidget: (v, meta) => v == meta.max && v % 7 != 0 && v % 7 < 4
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${v.round()}', style: s.axis),
                      ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final e in entries) FlSpot(e.key.toDouble(), e.value)],
              color: BloomColors.brand,
              barWidth: 2,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [BloomColors.brand.withValues(alpha: s.dark ? 0.22 : 0.14), BloomColors.brand.withValues(alpha: 0)],
                ),
              ),
              dotData: FlDotData(
                getDotPainter: (sp, _, _, _) => FlDotCirclePainter(
                  radius: 3.5,
                  color: periodDays.contains(sp.x.round()) ? BloomColors.period : dotFill,
                  strokeColor: BloomColors.brand,
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round step for gridlines and axis labels so about four lines show.
double _niceInterval(double top) {
  final raw = top / 4;
  for (final n in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]) {
    if (raw <= n) return n;
  }
  return (raw / 10).ceilToDouble() * 10;
}

String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

String _compact(double v, int decimals) {
  if (v.abs() >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
  if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(decimals);
}
