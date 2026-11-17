/// Building blocks shared by the calendar and the edit-period screen.
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
List<String> weekdayLabels(int firstDayOfWeek) {
  // 2024-01-01 was a Monday.
  final monday = DateTime(2024, 1, 1);
  return [
    for (var i = 0; i < 7; i++)
      DateFormat.E().format(addDays(monday, (firstDayOfWeek - 1 + i) % 7)).substring(0, 2),
  ];
}

/// Row of weekday initials above a month grid.
class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key, required this.firstDayOfWeek, this.compact = false});
  final int firstDayOfWeek;

  /// One-letter labels in a small style, for the year view's mini months.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = BloomTokens.of(context).muted;
    final style = compact
        ? theme.textTheme.labelSmall?.copyWith(color: muted, fontSize: 9, fontWeight: FontWeight.w700, height: 1)
        : theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w700, letterSpacing: 0.4);
    return Row(
      children: [
        for (final l in weekdayLabels(firstDayOfWeek))
          Expanded(
            child: Center(
              child: Text(compact ? l.substring(0, 1) : l.toUpperCase(), style: style),
            ),
          ),
      ],
    );
  }
}

/// Draws a dashed circle; used for predicted period days.
class DashedCirclePainter extends CustomPainter {
  DashedCirclePainter(this.color, {this.strokeWidth = 1.6});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    final r = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final center = Offset(size.width / 2, size.height / 2);
    // About one dash per 6 px of circumference, so small and large circles
    // both read as dashed.
    final dashes = (2 * math.pi * r / 6).clamp(8, 24).round();
    final sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), i * sweep - math.pi / 2, sweep * 0.55, false, paint);
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
}

/// A circular day marker used by the month grid, the mini months, and the
/// legend.
///
/// Logged period days are filled, predicted ones get a dashed outline,
/// fertile days a soft teal tint, and ovulation a teal ring. Today gets a
/// thin outer ring (or, below 24 px, a bold outline) in the primary color.
class DayCircle extends StatelessWidget {
  const DayCircle({
    super.key,
    required this.style,
    this.label,
    this.isToday = false,
    this.size = 40,
    this.textStyle,
    bool? compact,
  }) : compact = compact ?? size < 24;

  /// Extra width and height the today ring adds around a non-compact circle.
  static const todayRingExtent = 8.0;

  final DayStyle style;
  final String? label;
  final bool isToday;
  final double size;
  final TextStyle? textStyle;

  /// Draws a flat style without a gradient, glow, or outer today ring, for
  /// tiny circles such as the year view and the legend.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = theme.brightness;
    final dark = b == Brightness.dark;
    final small = compact;

    Color? fill;
    Gradient? gradient;
    Color textColor = scheme.onSurface;
    BoxBorder? border;
    var weight = FontWeight.w600;

    if (style.period) {
      gradient = small ? null : BloomGradients.period;
      fill = small ? BloomColors.period : null;
      textColor = Colors.white;
      weight = FontWeight.w800;
    } else if (style.pregnancy) {
      fill = BloomColors.pregnancy.withValues(alpha: dark ? 0.3 : 0.28);
      textColor = readableTint(BloomColors.pregnancy, b);
    } else if (style.ovulation) {
      fill = BloomColors.fertile.withValues(alpha: dark ? 0.32 : 0.26);
      border = Border.all(color: BloomColors.ovulation, width: small ? 1.2 : math.max(1.8, size / 18));
      textColor = readableTint(BloomColors.ovulation, b);
      weight = FontWeight.w800;
    } else if (style.fertile) {
      fill = dark ? BloomColors.fertile.withValues(alpha: 0.3) : BloomColors.fertileSoft.withValues(alpha: 0.85);
      textColor = readableTint(BloomColors.fertile, b);
    } else if (style.predictedPeriod) {
      textColor = readableTint(BloomColors.period, b);
    }

    if (isToday) {
      weight = FontWeight.w900;
      if (!style.period && !style.fertile && !style.ovulation && !style.predictedPeriod && !style.pregnancy) {
        textColor = scheme.primary;
      }
      if (small && border == null) border = Border.all(color: scheme.primary, width: 1.2);
    }

    Widget circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        gradient: gradient,
        border: border,
        boxShadow: style.period && !small && !dark ? BloomShadows.glow(BloomColors.period).take(1).toList() : null,
      ),
      child: label == null
          ? null
          : Text(
              label!,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: (textStyle ?? theme.textTheme.bodyMedium)?.copyWith(
                color: textColor,
                fontWeight: weight,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
    );
    if (style.isPredictedOnly) {
      circle = CustomPaint(
        painter: DashedCirclePainter(
          BloomColors.period.withValues(alpha: dark ? 0.9 : 0.8),
          strokeWidth: small ? 1.0 : math.max(1.4, size / 24),
        ),
        child: circle,
      );
    }
    if (isToday && !small) {
      circle = Container(
        padding: const EdgeInsets.all(todayRingExtent / 2 - 1.8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.primary, width: 1.8),
        ),
        child: circle,
      );
    }
    return circle;
  }
}

/// Legend explaining the calendar colors, laid out as wrapping swatches.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key, this.showPregnancy = false});
  final bool showPregnancy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(color: BloomTokens.of(context).muted);
    Widget item(Widget swatch, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(dimension: 18, child: Center(child: swatch)),
            Gap.h8,
            Text(text, style: style),
          ],
        );
    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.sm,
      alignment: WrapAlignment.center,
      children: [
        item(const DayCircle(style: DayStyle(period: true), size: 16), 'Period'),
        item(const DayCircle(style: DayStyle(predictedPeriod: true), size: 16), 'Predicted period'),
        item(const DayCircle(style: DayStyle(fertile: true), size: 16), 'Fertile'),
        item(const DayCircle(style: DayStyle(fertile: true, ovulation: true), size: 16), 'Ovulation'),
        if (showPregnancy) item(const DayCircle(style: DayStyle(pregnancy: true), size: 16), 'Pregnancy'),
        item(
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primary, width: 1.8),
            ),
          ),
          'Today',
        ),
        item(const LoggedDot(visible: true), 'Logged'),
      ],
    );
  }
}

/// The small dot under a day that has a log entry.
class LoggedDot extends StatelessWidget {
  const LoggedDot({super.key, required this.visible, this.size = 5});
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
        decoration: const BoxDecoration(color: BloomColors.brand, shape: BoxShape.circle),
      ),
    );
  }
}
