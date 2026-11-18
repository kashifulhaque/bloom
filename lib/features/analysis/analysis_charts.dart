/// Chart widgets for the analysis screen, built on fl_chart and drawn like
/// figures in a printed almanac: thin ink lines, dotted hairline grids, mono
/// axis labels, and no gradient fills.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../widgets/widgets.dart';

/// Shared Almanac chart styling: dotted hairline gridlines, mono axis
/// labels, and paper tooltips with a hairline border.
class _ChartStyle {
  _ChartStyle(BuildContext context) : theme = Theme.of(context), p = BloomColors.of(context);

  final ThemeData theme;
  final BloomPalette p;

  bool get dark => theme.brightness == Brightness.dark;

  TextStyle get axis => Almanac.mono(size: 10, color: p.ink2, letterSpacing: 0.3);

  /// A dotted hairline, like the faint rules of a printed graph.
  FlLine grid(double _) => FlLine(
    color: p.ink2.withValues(alpha: dark ? 0.4 : 0.35),
    strokeWidth: 0.8,
    dashArray: const [1, 3],
  );

  Color tooltipColor(Object _) => p.raised;

  BorderSide get tooltipBorder => BorderSide(color: p.hairline);

  /// The small mono heading line of a tooltip (a date or a label).
  TextStyle get tooltipHead => Almanac.mono(size: 10.5, color: p.ink2, letterSpacing: 0.4);

  /// The value line of a tooltip.
  TextStyle get tooltipText => Almanac.serif(size: 15, weight: 400, color: p.ink, height: 1.4, tabular: true);

  /// Resolves a light-mode constant for the current brightness.
  Color resolve(Color c) => BloomColors.adapt(c, theme.brightness);

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
    final maxV = [...items.map((e) => e.value), ?average, ?bandMax].fold<double>(1, math.max);
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
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              if (bandMin != null && bandMax != null)
                HorizontalRangeAnnotation(y1: bandMin!, y2: bandMax!, color: _bandColor(s)),
            ],
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: s.tooltipColor,
              tooltipBorder: s.tooltipBorder,
              tooltipBorderRadius: _ChartStyle.tooltipRadius,
              tooltipPadding: _ChartStyle.tooltipPadding,
              tooltipMargin: Space.sm,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${items[group.x].label.toUpperCase()}\n',
                s.tooltipHead,
                children: [TextSpan(text: '${_fmt(rod.toY)}$unit', style: s.tooltipText)],
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (average != null)
                HorizontalLine(
                  y: average!,
                  color: s.p.ink.withValues(alpha: 0.75),
                  strokeWidth: 1,
                  dashArray: [5, 3],
                  // The value is given in the ChartLegend under the chart, so it never collides with a bar.
                ),
            ],
          ),
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
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(items[i].label.toUpperCase(), style: s.axis),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < items.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  () {
                    final c = s.resolve(items[i].color ?? color).withValues(alpha: items[i].muted ? 0.25 : 1);
                    // Thin printed rules rather than fat bars.
                    final w = math.min(7.0, 140 / math.max(1, items.length));
                    return BarChartRodData(toY: items[i].value, width: w, color: c, borderRadius: BorderRadius.zero);
                  }(),
                ],
              ),
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
    final style = Almanac.data(context, size: 11.5);
    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.xs,
      children: [
        if (band != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 16, height: 10, color: _bandColor(s)),
              Gap.h8,
              Flexible(child: Text(band!, style: style)),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 16, height: 10, child: CustomPaint(painter: _DashPainter(s.p.ink.withValues(alpha: 0.75)))),
            Gap.h8,
            Flexible(child: Text(average, style: style)),
          ],
        ),
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
      ..strokeWidth = 1;
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(5, y), p);
    canvas.drawLine(Offset(8, y), Offset(size.width, y), p);
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// A dated series of values, drawn as a thin ink line with no fill.
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
    final dotFill = s.p.paper;
    final c = s.resolve(color);
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
                  FlLine(color: s.p.ink2.withValues(alpha: 0.6), strokeWidth: 1, dashArray: const [1, 3]),
                  FlDotData(
                    getDotPainter: (_, _, _, _) =>
                        FlDotCirclePainter(radius: 3.5, color: c, strokeColor: dotFill, strokeWidth: 1.5),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: s.tooltipColor,
              tooltipBorder: s.tooltipBorder,
              tooltipBorderRadius: _ChartStyle.tooltipRadius,
              tooltipPadding: _ChartStyle.tooltipPadding,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final sp in spots)
                  LineTooltipItem(
                    '${fmtShort(addDays(from, sp.x.round())).toUpperCase()}\n',
                    s.tooltipHead,
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
                // fl_chart adds a label at the axis end; skip it when it would crowd the last tick.
                getTitlesWidget: (v, meta) =>
                    v > span || (v == meta.max && v % math.max(1, span / 3).floorToDouble() != 0)
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(DateFormat('MMM d').format(addDays(from, v.round())).toUpperCase(), style: s.axis),
                      ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: c,
              barWidth: 1.4,
              isCurved: spots.length > 2,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: spots.length <= 31,
                getDotPainter: (_, _, _, _) =>
                    FlDotCirclePainter(radius: 2.4, color: dotFill, strokeColor: c, strokeWidth: 1.2),
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
    final dotFill = s.p.paper;
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
              tooltipBorder: s.tooltipBorder,
              tooltipBorderRadius: _ChartStyle.tooltipRadius,
              tooltipPadding: _ChartStyle.tooltipPadding,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final sp in spots)
                  LineTooltipItem(
                    'DAY ${sp.x.round()}\n',
                    s.tooltipHead,
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
                  color: s.p.luteal,
                  strokeWidth: 1,
                  dashArray: [5, 3],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topLeft,
                    style: s.axis.copyWith(color: lutealLabel, fontWeight: FontWeight.w500),
                    labelResolver: (l) => 'COVER LINE ${l.y.toStringAsFixed(2)}',
                  ),
                ),
            ],
            verticalLines: [
              if (ovulationDay != null)
                VerticalLine(
                  x: ovulationDay!.toDouble(),
                  color: s.p.ovulation,
                  strokeWidth: 1,
                  dashArray: [1, 3],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: s.axis.copyWith(color: ovulationLabel, fontWeight: FontWeight.w500),
                    labelResolver: (_) => 'OVULATION',
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
              axisNameWidget: Text('CYCLE DAY', style: s.axis),
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
              color: s.p.ink,
              barWidth: 1.2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                getDotPainter: (sp, _, _, _) {
                  final period = periodDays.contains(sp.x.round());
                  return FlDotCirclePainter(
                    radius: period ? 3.2 : 2.6,
                    color: period ? s.p.period : dotFill,
                    strokeColor: period ? s.p.period : s.p.ink,
                    strokeWidth: 1.1,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The faint wash of a typical-range band: ink, not a phase color, since a
/// range isn't a phase.
Color _bandColor(_ChartStyle s) => s.p.ink.withValues(alpha: s.dark ? 0.07 : 0.05);

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
