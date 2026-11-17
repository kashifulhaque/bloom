/// Custom-painted rings: [ProgressRing] and [CycleRing].
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/dates.dart';
import '../core/engine.dart';
import '../theme/app_theme.dart';

/// A circular progress ring with a gradient stroke, a rounded cap, and a
/// center child. Changes to [value] animate.
///
/// ```dart
/// ProgressRing(value: 0.6, gradient: BloomGradients.fertile,
///     child: Text('60%'))
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
  final double stroke;

  /// Stroke gradient. Takes precedence over [color].
  final Gradient? gradient;

  /// Solid stroke color. Defaults to the primary color.
  final Color? color;

  /// Track color. Defaults to the subtle token.
  final Color? trackColor;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    final colors = gradient?.colors ?? [c, c];
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: Motion.slow,
        curve: Motion.emphasized,
        builder: (context, v, child) => CustomPaint(
          painter: _ProgressPainter(
            value: v,
            stroke: stroke,
            colors: colors,
            track: trackColor ?? BloomTokens.of(context).subtle,
          ),
          child: child,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({required this.value, required this.stroke, required this.colors, required this.track});

  final double value;
  final double stroke;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = track);
    if (value <= 0) return;
    final sweep = math.pi * 2 * value;
    // The shader supplies color, but the paint's alpha still applies, so reset
    // it; otherwise a translucent track color would dim the progress arc too.
    base.color = const Color(0xFFFFFFFF);
    base.shader = SweepGradient(
      startAngle: 0,
      endAngle: math.max(sweep, 0.01),
      colors: colors,
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, base);
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.value != value || old.stroke != stroke || old.track != track || old.colors != colors;
}

/// A full-cycle ring: colored segments for the period, follicular, fertile,
/// ovulation, and luteal days, with a marker on today. It sweeps in when it
/// first appears and animates when its inputs change.
///
/// Build it from the engine:
///
/// ```dart
/// final ring = CycleRing.fromEngine(store.engine, size: 260,
///     child: Column(mainAxisSize: MainAxisSize.min, children: [...]));
/// ```
///
/// Days already passed are drawn at full strength and upcoming days are
/// lighter, so the ring reads as "where you are" at a glance.
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

  /// Builds a ring for the current cycle. Returns a ring without a today
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

  /// Days in the cycle (the ring's full circle).
  final int cycleLength;

  /// Days of bleeding, starting at day 1.
  final int periodLength;

  /// 1-based ovulation day. The fertile window is the 5 days before it and
  /// the day after, matching `Cycle.fertileStart` and `Cycle.fertileEnd`.
  final int ovulationDay;

  /// 1-based cycle day for the marker. Null hides the marker. Values past
  /// [cycleLength] (a late period) pin the marker to the end of the ring.
  final int? today;

  final double size;
  final double stroke;

  /// Content in the middle of the ring.
  final Widget? child;

  /// Draws days after [today] lighter.
  final bool dimFuture;

  /// Marker color when the period is late. Defaults to the warning color.
  final Color? lateColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = _segments();
    return Semantics(
      label: today == null ? 'Cycle of $cycleLength days' : 'Cycle day $today of $cycleLength',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          curve: Motion.emphasized,
          builder: (context, t, child) => CustomPaint(
            painter: _CyclePainter(
              progress: t,
              segments: segments,
              length: cycleLength,
              today: today,
              stroke: stroke,
              dimFuture: dimFuture,
              track: BloomTokens.of(context).subtle,
              markerFill: theme.brightness == Brightness.dark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
              lateColor: lateColor ?? BloomColors.warning,
            ),
            child: child,
          ),
          child: Center(
            child: Padding(padding: EdgeInsets.all(stroke * 2), child: child),
          ),
        ),
      ),
    );
  }

  List<_Segment> _segments() {
    final len = math.max(cycleLength, 1);
    final ov = ovulationDay.clamp(1, len);
    final fStart = (ov - 5).clamp(1, len);
    final fEnd = (ov + 1).clamp(1, len);
    final pEnd = periodLength.clamp(1, len);
    final out = <_Segment>[];
    void add(int from, int to, Color c) {
      if (to >= from) out.add(_Segment(from, to, c));
    }

    add(1, pEnd, BloomColors.period);
    add(pEnd + 1, fStart - 1, BloomColors.follicular);
    add(math.max(fStart, pEnd + 1), ov - 1, BloomColors.fertile);
    add(ov, ov, BloomColors.ovulation);
    add(ov + 1, fEnd, BloomColors.fertile);
    add(fEnd + 1, len, BloomColors.luteal);
    return out;
  }
}

class _Segment {
  const _Segment(this.from, this.to, this.color);
  final int from;
  final int to;
  final Color color;
}

class _CyclePainter extends CustomPainter {
  _CyclePainter({
    required this.progress,
    required this.segments,
    required this.length,
    required this.today,
    required this.stroke,
    required this.dimFuture,
    required this.track,
    required this.markerFill,
    required this.lateColor,
  });

  final double progress;
  final List<_Segment> segments;
  final int length;
  final int? today;
  final double stroke;
  final bool dimFuture;
  final Color track;
  final Color markerFill;
  final Color lateColor;

  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke / 2 - 4;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final perDay = math.pi * 2 / length;
    // A small gap between segments, in radians, sized to the stroke.
    final gap = math.min(stroke / radius * 0.3, perDay * 0.6);
    final sweepLimit = math.pi * 2 * progress;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track.withValues(alpha: 0.6),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final todayIdx = today?.clamp(1, length);
    for (final s in segments) {
      final a0 = (s.from - 1) * perDay + gap / 2;
      final a1 = s.to * perDay - gap / 2;
      // Round caps extend past the arc by half the stroke; trim the sweep to
      // compensate so gaps stay visible.
      final capTrim = stroke / 2 / radius;
      var from = a0 + capTrim;
      var to = a1 - capTrim;
      if (to < from) {
        final mid = (a0 + a1) / 2;
        from = mid;
        to = mid + 0.0001;
      }
      if (from >= sweepLimit) continue;
      to = math.min(to, sweepLimit);

      if (dimFuture && todayIdx != null) {
        final split = todayIdx * perDay;
        if (split > from) {
          _arc(canvas, arcRect, paint, from, math.min(to, split), s.color);
        }
        if (split < to) {
          _arc(canvas, arcRect, paint, math.max(from, split), to, s.color.withValues(alpha: 0.38));
        }
      } else {
        _arc(canvas, arcRect, paint, from, to, s.color);
      }
    }

    // Today marker.
    if (todayIdx != null && progress > 0.6) {
      final appear = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
      final late = today! > length;
      final angle = _start + (late ? length * perDay : (todayIdx - 0.5) * perDay);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final segColor = late
          ? lateColor
          : segments
              .firstWhere((s) => todayIdx >= s.from && todayIdx <= s.to, orElse: () => segments.last)
              .color;
      final r = (stroke / 2 + 6) * Curves.easeOutBack.transform(appear);
      canvas.drawCircle(
        pos + const Offset(0, 2),
        r + 1,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(pos, r, Paint()..color = markerFill);
      canvas.drawCircle(pos, r * 0.55, Paint()..color = segColor);
    }
  }

  void _arc(Canvas canvas, Rect rect, Paint paint, double from, double to, Color color) {
    if (to <= from) return;
    canvas.drawArc(rect, _start + from, to - from, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_CyclePainter old) =>
      old.progress != progress ||
      old.length != length ||
      old.today != today ||
      old.track != track ||
      old.markerFill != markerFill ||
      old.segments.length != segments.length ||
      old.stroke != stroke;
}
