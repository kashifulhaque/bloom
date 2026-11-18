/// Building blocks shared by the calendar and the edit-period screen, drawn
/// as a printed almanac page: serif numerals, mono marginalia, and color only
/// where it means something.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../widgets/widgets.dart';

/// First day of [d]'s month.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// Adds [n] months to the first day of [d]'s month.
DateTime addMonths(DateTime d, int n) => DateTime(d.year, d.month + n);

/// Number of whole months from [a] to [b].
int monthsBetween(DateTime a, DateTime b) => (b.year - a.year) * 12 + b.month - a.month;

int daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

/// Blank cells before day 1 so the grid starts on [firstDayOfWeek].
int leadingBlanks(DateTime month, int firstDayOfWeek) => (month.weekday - firstDayOfWeek + 7) % 7;

/// Short weekday names starting at [firstDayOfWeek] (1 = Monday ... 7 = Sunday).
List<String> weekdayLabels(int firstDayOfWeek, {int letters = 2}) {
  // 2024-01-01 was a Monday.
  final monday = DateTime(2024, 1, 1);
  return [
    for (var i = 0; i < 7; i++)
      DateFormat.E().format(addDays(monday, (firstDayOfWeek - 1 + i) % 7)).substring(0, letters),
  ];
}

/// The mono weekday row above a month grid.
class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key, required this.firstDayOfWeek, this.compact = false});
  final int firstDayOfWeek;

  /// One-letter labels in a smaller size, for the year view's mini months.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Almanac.label(context, size: compact ? 8.5 : 10.5);
    return Row(
      children: [
        for (final l in weekdayLabels(firstDayOfWeek, letters: compact ? 1 : 3))
          Expanded(
            child: Center(
              child: Text(l.toUpperCase(), style: style, maxLines: 1, overflow: TextOverflow.clip),
            ),
          ),
      ],
    );
  }
}

/// Draws a dotted circle; used for predicted period days.
class DashedCirclePainter extends CustomPainter {
  DashedCirclePainter(this.color, {this.strokeWidth = 1.2});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final center = Offset(size.width / 2, size.height / 2);
    // A dot about every 3.6 px of circumference: reads as a printed dotted rule.
    final dots = (2 * math.pi * r / 3.6).clamp(10, 48).round();
    for (var i = 0; i < dots; i++) {
      final a = i * 2 * math.pi / dots - math.pi / 2;
      canvas.drawCircle(center + Offset(math.cos(a), math.sin(a)) * r, strokeWidth * 0.62, paint);
    }
  }

  @override
  bool shouldRepaint(DashedCirclePainter old) => old.color != color || old.strokeWidth != strokeWidth;
}

/// Visual style of one calendar day, derived from [DayInfo].
class DayStyle {
  const DayStyle({
    this.period = false,
    this.predictedPeriod = false,
    this.fertile = false,
    this.ovulation = false,
    this.pregnancy = false,
  });

  factory DayStyle.fromInfo(DayInfo info, {bool pregnancy = false}) => pregnancy
      ? DayStyle(period: info.isPeriod, pregnancy: true)
      : DayStyle(
          period: info.isPeriod,
          predictedPeriod: info.isPredictedPeriod,
          fertile: info.isFertile,
          ovulation: info.isOvulation,
        );

  final bool period;
  final bool predictedPeriod;
  final bool fertile;
  final bool ovulation;
  final bool pregnancy;

  bool get isPredictedOnly => predictedPeriod && !period;

  /// Days that sit on a soft wash band (the fertile window or a pregnancy).
  bool get washed => !period && (fertile || ovulation || pregnancy);
}

/// One day's mark: a serif numeral styled by meaning.
///
/// A logged period day is a filled oxblood circle with a paper numeral; a
/// predicted one is a dotted oxblood outline; ovulation is a thin sage ring;
/// fertile days are a sage numeral (the wash band is drawn by the grid).
/// Today is shown by the grid with an ink underline, so [isToday] only makes
/// the numeral a little heavier here.
class DayCircle extends StatelessWidget {
  const DayCircle({
    super.key,
    required this.style,
    this.label,
    this.isToday = false,
    this.size = 34,
    this.textStyle,
    bool? compact,
  }) : compact = compact ?? size < 24;

  /// Kept for older layouts; the Almanac grid draws no outer today ring.
  static const todayRingExtent = 0.0;

  final DayStyle style;
  final String? label;
  final bool isToday;
  final double size;
  final TextStyle? textStyle;

  /// Thinner strokes for tiny circles such as the year view and the legend.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final b = Theme.of(context).brightness;
    var color = p.ink;
    Color? fill;
    BoxBorder? border;
    var italic = false;
    if (style.period) {
      fill = p.period;
      color = BloomColors.onColor(p.period);
    } else if (style.pregnancy) {
      color = readableTint(BloomColors.pregnancy, b);
    } else if (style.ovulation) {
      color = readableTint(BloomColors.ovulation, b);
      border = Border.all(color: p.ovulation, width: compact ? 0.9 : 1.2);
    } else if (style.fertile) {
      color = readableTint(BloomColors.fertile, b);
    } else if (style.predictedPeriod) {
      color = readableTint(BloomColors.period, b);
      italic = true;
    }
    final base = textStyle ?? Almanac.serif(size: (size * 0.5).clamp(9.0, 19.0), tabular: true);
    Widget out = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: border),
      child: label == null
          ? null
          : Text(
              label!,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: base
                  .copyWith(color: color, height: 1, fontStyle: italic ? FontStyle.italic : null)
                  .weight(style.period || isToday ? 460 : 380),
            ),
    );
    if (style.isPredictedOnly) {
      out = CustomPaint(
        painter: DashedCirclePainter(p.period.withValues(alpha: 0.85), strokeWidth: compact ? 0.9 : 1.3),
        child: out,
      );
    }
    return out;
  }
}

/// The soft wash behind fertile (or pregnancy) days, joined into a band
/// across neighbouring days in the same week row.
class WashBand extends StatelessWidget {
  const WashBand({
    super.key,
    required this.color,
    required this.height,
    required this.joinLeft,
    required this.joinRight,
  });

  final Color color;
  final double height;
  final bool joinLeft;
  final bool joinRight;

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(height / 2);
    return LayoutBuilder(
      builder: (context, box) {
        final inset = (box.maxWidth - height) / 2;
        return Padding(
          padding: EdgeInsets.only(left: joinLeft ? 0 : inset, right: joinRight ? 0 : inset),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.horizontal(
                left: joinLeft ? Radius.zero : r,
                right: joinRight ? Radius.zero : r,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The wash color for fertile days.
Color fertileWash(BuildContext context) {
  final p = BloomColors.of(context);
  return Theme.of(context).brightness == Brightness.dark
      ? p.fertile.withValues(alpha: 0.16)
      : p.fertileSoft.withValues(alpha: 0.75);
}

/// The wash color for pregnancy days.
Color pregnancyWash(BuildContext context) {
  final p = BloomColors.of(context);
  return Theme.of(context).brightness == Brightness.dark
      ? p.pregnancy.withValues(alpha: 0.16)
      : p.pregnancySoft.withValues(alpha: 0.8);
}

/// The short ink rule under today's numeral.
class TodayRule extends StatelessWidget {
  const TodayRule({super.key, required this.visible, this.width = 16, this.thickness = 1.5});
  final bool visible;
  final double width;
  final double thickness;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: thickness,
    child: visible ? ColoredBox(color: BloomColors.of(context).ink) : null,
  );
}

/// A key to the calendar marks, set as a printed legend: small marks with
/// mono captions, left-aligned.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key, this.showPregnancy = false});
  final bool showPregnancy;

  @override
  Widget build(BuildContext context) {
    final style = Almanac.data(context, size: 11.5);
    Widget item(Widget swatch, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 22, height: 18, child: Center(child: swatch)),
        const SizedBox(width: 6),
        Text(text, style: style),
      ],
    );
    const mark = 16.0;
    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.sm,
      children: [
        item(const DayCircle(style: DayStyle(period: true), size: mark, compact: true), 'Period'),
        item(const DayCircle(style: DayStyle(predictedPeriod: true), size: mark, compact: true), 'Predicted period'),
        item(
          SizedBox(
            width: 22,
            height: 12,
            child: WashBand(color: fertileWash(context), height: 12, joinLeft: false, joinRight: false),
          ),
          'Fertile',
        ),
        item(const DayCircle(style: DayStyle(fertile: true, ovulation: true), size: mark, compact: true), 'Ovulation'),
        if (showPregnancy)
          item(
            SizedBox(
              width: 22,
              height: 12,
              child: WashBand(color: pregnancyWash(context), height: 12, joinLeft: false, joinRight: false),
            ),
            'Pregnancy',
          ),
        item(const TodayRule(visible: true, width: 14), 'Today'),
        item(const LoggedDot(visible: true), 'Logged'),
      ],
    );
  }
}

/// The tiny dot under a day that has a log entry.
class LoggedDot extends StatelessWidget {
  const LoggedDot({super.key, required this.visible, this.size = 3.5});
  final bool visible;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: visible ? 1 : 0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: BloomColors.of(context).ink2, shape: BoxShape.circle),
      ),
    );
  }
}

/// Underlined text-link tabs ("Month · Year"): the selected one is ink with
/// an underline, the others ink2.
class TextTabs<T> extends StatelessWidget {
  const TextTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.size = 14.5,
  });

  /// Value and label for each tab, in order.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: Text('·', style: Almanac.data(context)),
            ),
          Builder(
            builder: (context) {
              final (value, label) = options[i];
              final on = value == selected;
              return Pressable(
                onTap: on
                    ? null
                    : () {
                        Almanac.tick();
                        onSelected(value);
                      },
                selected: on,
                borderRadius: Radii.smAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                    child: Center(
                      widthFactor: 1,
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.fast,
                        style:
                            Almanac.sans(
                              size: size,
                              weight: on ? FontWeight.w600 : FontWeight.w500,
                              color: on ? p.ink : p.ink2,
                              height: 1.3,
                            ).copyWith(
                              decoration: on ? TextDecoration.underline : TextDecoration.none,
                              decorationColor: p.ink,
                              decorationThickness: 1.5,
                            ),
                        child: Text(label),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
