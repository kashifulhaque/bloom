/// Custom-painted rings: [ProgressRing] and [CycleRing] (the Almanac dial).
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/dates.dart';
import '../core/engine.dart';
import '../theme/app_theme.dart';

/// A thin progress ring: a hairline track with an ink arc and a center
/// child. Changes to [value] animate.
///
/// ```dart
/// ProgressRing(value: 0.6, color: BloomColors.fertile, child: Text('60%'))
/// ```
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 120,
    this.stroke = 12,
    this.gradient,
    this.color,
    this.trackColor,
    this.child,
  });

  /// Progress from 0 to 1.
  final double value;
  final double size;

  /// Scales the arc: the drawn width is about a quarter of this, 2 to 4 px.
  final double stroke;

  /// Kept for older code: its first color is used as [color].
  final Gradient? gradient;

  /// Arc color. Defaults to ink.
  final Color? color;

  /// Track color. Defaults to the hairline color.
  final Color? trackColor;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final raw = color ?? gradient?.colors.first;
    final c = raw == null ? p.ink : BloomColors.resolve(context, raw);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: Motion.slow,
        curve: Motion.emphasized,
        builder: (context, v, child) => CustomPaint(
          painter: _ProgressPainter(
            value: v,
            width: (stroke * 0.28).clamp(2.0, 4.0),
            color: c,
            track: trackColor ?? p.hairline,
          ),
          child: child,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({required this.value, required this.width, required this.color, required this.track});

  final double value;
  final double width;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - width / 2 - 1;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = track,
    );
    if (value <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.value != value || old.width != width || old.track != track || old.color != color;
}

/// The Almanac dial: the whole cycle as a thin hairline circle with one
/// tick per day (a longer tick and a tiny mono day number every 7 days).
///
/// * The period is a thick oxblood ink arc on the circle.
/// * The fertile window is a sage arc just inside it, with a dot on the
///   ovulation day.
/// * The luteal phase is a thin dotted plum arc.
/// * Days after today are predictions, drawn dotted.
/// * Today is a small filled ink dot.
///
/// The arcs draw in like ink on first build. Put a serif numeral and an
/// italic caption in [child]:
///
/// ```dart
/// CycleRing.fromEngine(store.engine, size: 260, child: Column(
///   mainAxisSize: MainAxisSize.min,
///   children: [
///     Text('14', style: Almanac.numeral(context)),
///     Text('of twenty-nine', style: Almanac.italic(context, size: 15,
///         color: BloomColors.of(context).ink2)),
///   ],
/// ));
/// ```
class CycleRing extends StatelessWidget {
  const CycleRing({
    super.key,
    required this.cycleLength,
    required this.periodLength,
    required this.ovulationDay,
    this.today,
    this.size = 240,
    this.stroke = 18,
    this.child,
    this.dimFuture = true,
    this.lateColor,
  });

  /// Builds a dial for the current cycle. Returns a dial without a today
  /// marker when there is no data.
  factory CycleRing.fromEngine(
    CycleEngine engine, {
    Key? key,
    double size = 240,
    double stroke = 18,
    Widget? child,
    bool dimFuture = true,
  }) {
    final cycle = engine.currentCycle;
    final length = engine.avgCycleLength;
    if (cycle == null) {
      return CycleRing(
        key: key,
        cycleLength: length,
        periodLength: engine.avgPeriodLength,
        ovulationDay: length - 13,
        size: size,
        stroke: stroke,
        dimFuture: dimFuture,
        child: child,
      );
    }
    return CycleRing(
      key: key,
      cycleLength: length,
      periodLength: cycle.period.length,
      ovulationDay: daysBetween(cycle.start, cycle.ovulation) + 1,
      today: daysBetween(cycle.start, engine.today) + 1,
      size: size,
      stroke: stroke,
      dimFuture: dimFuture,
      child: child,
    );
  }

  /// Days in the cycle (the dial's full circle).
  final int cycleLength;

  /// Days of bleeding, starting at day 1.
  final int periodLength;

  /// 1-based ovulation day. The fertile window is the 5 days before it and
  /// the day after, matching `Cycle.fertileStart` and `Cycle.fertileEnd`.
  final int ovulationDay;

  /// 1-based cycle day for the marker. Null hides the marker. Values past
  /// [cycleLength] (a late period) pin the marker to the end of the dial.
  final int? today;

  final double size;

  /// Scales the period arc: it's drawn at about a quarter of this width.
  final double stroke;

  /// Content in the middle of the dial.
  final Widget? child;

  /// Draws days after [today] dotted, as predictions.
  final bool dimFuture;

  /// Marker color when the period is late. Defaults to the warning color.
  final Color? lateColor;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final s = size / 250;
    final r = 99 * s;
    return Semantics(
      label: today == null ? 'Cycle of $cycleLength days' : 'Cycle day $today of $cycleLength',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Motion.ink,
          curve: Curves.linear,
          builder: (context, t, child) => CustomPaint(
            painter: _DialPainter(
              t: t,
              length: math.max(cycleLength, 1),
              periodLength: periodLength,
              ovulationDay: ovulationDay,
              today: today,
              periodWidth: (stroke / 4.5).clamp(3.0, 6.0) * s.clamp(0.7, 1.3),
              dotted: dimFuture,
              palette: p,
              lateColor: lateColor == null ? p.warning : BloomColors.resolve(context, lateColor!),
              numberStyle: Almanac.mono(size: (9 * s).clamp(8.0, 11.0), color: p.ink2),
            ),
            child: child,
          ),
          child: Center(
            child: Padding(padding: EdgeInsets.all(size / 2 - (r - 16 * s)), child: child),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.t,
    required this.length,
    required this.periodLength,
    required this.ovulationDay,
    required this.today,
    required this.periodWidth,
    required this.dotted,
    required this.palette,
    required this.lateColor,
    required this.numberStyle,
  });

  final double t;
  final int length;
  final int periodLength;
  final int ovulationDay;
  final int? today;
  final double periodWidth;
  final bool dotted;
  final BloomPalette palette;
  final Color lateColor;
  final TextStyle numberStyle;

  static const _start = -math.pi / 2;

  /// Progress of a stage that runs from [a] to [b] of the whole animation.
  double _stage(double a, double b) => Curves.easeOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 250;
    final c = size.center(Offset.zero);
    final r = 99 * s;
    final inner = r - 12 * s;
    final per = math.pi * 2 / length;
    double angle(num day) => _start + (day - 0.5) * per;
    Offset at(double radius, double a) => c + Offset(math.cos(a), math.sin(a)) * radius;

    // 1. The hairline circle, ticks, and day numbers fade in first.
    final base = _stage(0, 0.25);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.hairline.withValues(alpha: palette.hairline.a * base),
    );
    final tick = Paint()..strokeCap = StrokeCap.butt;
    for (var d = 1; d <= length; d++) {
      final long = d % 7 == 1;
      final a = angle(d);
      final len = (long ? 8 : 4.5) * s;
      tick
        ..strokeWidth = long ? 1 : 0.7
        ..color = palette.ink2.withValues(alpha: (long ? 0.85 : 0.55) * base);
      canvas.drawLine(at(r - len, a), at(r + len, a), tick);
      if (long && base > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '$d', style: numberStyle.copyWith(color: numberStyle.color!.withValues(alpha: base))),
          textDirection: TextDirection.ltr,
        )..layout();
        final pos = at(r + 18 * s, a);
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }

    final len = length;
    final ov = ovulationDay.clamp(1, len);
    final pEnd = periodLength.clamp(1, len);
    final fStart = math.max((ov - 5).clamp(1, len), pEnd + 1);
    final fEnd = (ov + 1).clamp(1, len);
    final now = today?.clamp(1, len);

    // 2. Period: a thick oxblood arc on the circle.
    _arc(canvas, c, r, angle, 1, pEnd, palette.period, periodWidth, now, _stage(0.12, 0.45));

    // 3. Fertile window: a sage arc just inside, with the ovulation day.
    if (fStart <= fEnd) {
      _arc(canvas, c, inner, angle, fStart, fEnd, palette.fertile, 2.4 * s, now, _stage(0.35, 0.7));
    }
    final ovIn = _stage(0.6, 0.8);
    if (ovIn > 0) {
      final future = dotted && now != null && ov > now;
      final pos = at(inner, angle(ov));
      final dot = Paint()..color = palette.ovulation.withValues(alpha: ovIn);
      if (future) {
        canvas.drawCircle(pos, 3.6 * s, Paint()..color = palette.paper.withValues(alpha: ovIn));
        canvas.drawCircle(
          pos,
          3.6 * s,
          dot
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      } else {
        canvas.drawCircle(pos, 3.6 * s, dot);
      }
    }

    // 4. Luteal: a thin plum arc, dotted while it's a prediction.
    if (fEnd + 1 <= len) {
      _arc(canvas, c, inner, angle, fEnd + 1, len, palette.luteal, 1.3 * s, now, _stage(0.55, 0.9), alwaysDotted: true);
    }

    // 5. Today: a small filled ink dot on the circle.
    final dotIn = _stage(0.8, 1);
    if (today != null && dotIn > 0) {
      final late = today! > length;
      final a = late ? _start + length * per : angle(now!);
      final pos = at(r, a);
      final rad = 5.5 * s * dotIn;
      canvas.drawCircle(pos, rad + 2.2 * s, Paint()..color = palette.paper);
      canvas.drawCircle(pos, rad, Paint()..color = late ? lateColor : palette.ink);
    }
  }

  /// Draws days [from] to [to] (inclusive) as an arc through their tick
  /// centers. The part after [now] is dotted when [dotted] is on. [reveal]
  /// sweeps the arc in from its start.
  void _arc(
    Canvas canvas,
    Offset c,
    double radius,
    double Function(num) angle,
    int from,
    int to,
    Color color,
    double width,
    int? now,
    double reveal, {
    bool alwaysDotted = false,
  }) {
    if (reveal <= 0 || to < from) return;
    final a0 = angle(from) - (from == to ? 0.02 : 0);
    final a1 = angle(to) + (from == to ? 0.02 : 0);
    final end = a0 + (a1 - a0) * reveal;
    final rect = Rect.fromCircle(center: c, radius: radius);
    final solid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;

    // Where predictions begin: just after today's tick.
    // Without a today marker, only always-dotted arcs are dotted.
    final double split = (!dotted || now == null) ? (alwaysDotted ? a0 : double.infinity) : angle(now) + 0.0001;
    final solidEnd = math.min(end, split);
    if (solidEnd > a0) canvas.drawArc(rect, a0, solidEnd - a0, false, solid);
    if (end > split) _dots(canvas, c, radius, math.max(a0, split), end, width, color);
  }

  void _dots(Canvas canvas, Offset c, double radius, double a0, double a1, double width, Color color) {
    final paint = Paint()..color = color;
    final step = (width * 2.4 + 2) / radius;
    final dotR = math.max(width * 0.5, 0.9);
    for (var a = a0 + step / 2; a <= a1 + 1e-6; a += step) {
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * radius, dotR, paint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.t != t ||
      old.length != length ||
      old.periodLength != periodLength ||
      old.ovulationDay != ovulationDay ||
      old.today != today ||
      old.periodWidth != periodWidth ||
      old.dotted != dotted ||
      old.palette != palette ||
      old.lateColor != lateColor;
}
