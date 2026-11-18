/// Pressed-flower ornaments: [BotanicalGlyph].
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/engine.dart';
import '../theme/app_theme.dart';

/// The botanical line drawings. Each cycle phase has one (see [forPhase]).
enum Botanical {
  /// A closed bud: the menstrual phase.
  bud,

  /// A sprouting stem with two new leaves: the follicular phase.
  sprout,

  /// An open six-petal flower: ovulation.
  flower,

  /// A seed head: the luteal phase.
  seedHead,

  /// A plain leafy sprig, for neutral ornaments and empty states.
  sprig;

  /// The drawing for [phase].
  static Botanical forPhase(Phase phase) => switch (phase) {
        Phase.menstrual => Botanical.bud,
        Phase.follicular => Botanical.sprout,
        Phase.ovulation => Botanical.flower,
        Phase.luteal => Botanical.seedHead,
      };
}

/// A small original line drawing in thin ink strokes, like a pressed flower
/// in a field guide. Use it as an ornament beside phase names, in empty
/// states, and in place of decorative emoji.
///
/// ```dart
/// BotanicalGlyph(Botanical.forPhase(info.phase), size: 32,
///     accent: BloomColors.of(context).phase(info.phase))
/// BotanicalGlyph.phase(Phase.luteal)
/// ```
class BotanicalGlyph extends StatelessWidget {
  const BotanicalGlyph(this.kind, {super.key, this.size = 28, this.color, this.accent, this.strokeWidth});

  /// The drawing for [phase], with the phase color on the flower head.
  BotanicalGlyph.phase(Phase phase, {Key? key, double size = 28, Color? color, bool colored = true})
      : this(Botanical.forPhase(phase), key: key, size: size, color: color, accent: colored ? phaseColor(phase) : null);

  final Botanical kind;
  final double size;

  /// Stroke color for the stem and leaves. Defaults to ink2.
  final Color? color;

  /// Color for the bloom (bud, petals, seeds). Defaults to [color].
  final Color? accent;

  /// Defaults to a hairline that scales gently with [size].
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final stroke = color == null ? p.ink2 : BloomColors.resolve(context, color!);
    final head = accent == null ? stroke : BloomColors.resolve(context, accent!);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BotanicalPainter(
            kind: kind,
            stroke: stroke,
            accent: head,
            width: strokeWidth ?? (size / 24 * 1.1).clamp(1.0, 2.2),
          ),
        ),
      ),
    );
  }
}

class _BotanicalPainter extends CustomPainter {
  _BotanicalPainter({required this.kind, required this.stroke, required this.accent, required this.width});

  final Botanical kind;
  final Color stroke;
  final Color accent;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 24 x 24 grid, then scaled.
    final k = size.shortestSide / 24;
    canvas.save();
    canvas.scale(k);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width / k
      ..color = stroke;
    final head = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width / k
      ..color = accent;
    final fill = Paint()..color = accent;

    switch (kind) {
      case Botanical.bud:
        _stem(canvas, line, const Offset(12, 22.5), const Offset(12, 11.5), bend: -1.2);
        _leaf(canvas, line, const Offset(11.6, 18), const Offset(6.5, 14.5), 1.6);
        final bud = Path()
          ..moveTo(12, 11.5)
          ..cubicTo(8.2, 10.2, 8.8, 5.2, 12, 2.8)
          ..cubicTo(15.2, 5.2, 15.8, 10.2, 12, 11.5);
        canvas.drawPath(bud, head);
        canvas.drawPath(Path()..moveTo(12, 11.2)..quadraticBezierTo(11.2, 7, 12, 4.2), head);
        canvas.drawPath(Path()..moveTo(12, 11.5)..quadraticBezierTo(9.6, 11.4, 8.4, 9.6), line);
        canvas.drawPath(Path()..moveTo(12, 11.5)..quadraticBezierTo(14.4, 11.4, 15.6, 9.6), line);
      case Botanical.sprout:
        _stem(canvas, line, const Offset(12, 22.5), const Offset(12.4, 9.5), bend: 1.4);
        _leaf(canvas, head, const Offset(12.2, 13), const Offset(4.5, 8.5), 2.6, rib: true, ribPaint: line);
        _leaf(canvas, head, const Offset(12.4, 10), const Offset(19, 4.2), 2.3, rib: true, ribPaint: line);
        canvas.drawPath(Path()..moveTo(12.4, 9.5)..quadraticBezierTo(12.9, 7.2, 11.8, 6.4), line);
        canvas.drawLine(const Offset(8.5, 22.5), const Offset(15.5, 22.5), line);
      case Botanical.flower:
        _stem(canvas, line, const Offset(12, 22.5), const Offset(12, 12.2), bend: 0.8);
        _leaf(canvas, line, const Offset(12.2, 18.5), const Offset(17.5, 15.2), 1.6);
        const c = Offset(12, 8);
        for (var i = 0; i < 6; i++) {
          final a = -math.pi / 2 + i * math.pi / 3;
          final tip = c + Offset(math.cos(a), math.sin(a)) * 5.4;
          _leaf(canvas, head, c + Offset(math.cos(a), math.sin(a)) * 1.3, tip, 1.55);
        }
        canvas.drawCircle(c, 1.05, fill);
      case Botanical.seedHead:
        _stem(canvas, line, const Offset(12, 22.5), const Offset(12, 10.6), bend: -0.9);
        _leaf(canvas, line, const Offset(11.8, 17.5), const Offset(6.8, 15.2), 1.4);
        const c = Offset(12, 7.6);
        canvas.drawCircle(c, 0.9, fill);
        for (var i = 0; i < 11; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 11 + 0.15;
          final dir = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + dir * 1.4, c + dir * 4.9, head);
          canvas.drawCircle(c + dir * 5.5, 0.55, fill);
        }
      case Botanical.sprig:
        _stem(canvas, line, const Offset(12, 22.5), const Offset(12.5, 2.5), bend: 1.6);
        for (final (y, left) in [(18.5, true), (15.0, false), (11.5, true), (8.0, false), (5.0, true)]) {
          final base = Offset(12.3 + (22.5 - y) * 0.02, y);
          final len = 3.2 + (y - 4) * 0.12;
          final tip = base + Offset(left ? -len : len, -len * 0.75);
          _leaf(canvas, head, base, tip, 1.2 + (y - 4) * 0.035);
        }
    }
    canvas.restore();
  }

  void _stem(Canvas canvas, Paint p, Offset from, Offset to, {double bend = 0}) {
    final mid = Offset.lerp(from, to, 0.5)! + Offset(bend, 0);
    canvas.drawPath(Path()..moveTo(from.dx, from.dy)..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy), p);
  }

  /// An almond leaf or petal from [a] to [b], [w] wide.
  void _leaf(Canvas canvas, Paint p, Offset a, Offset b, double w, {bool rib = false, Paint? ribPaint}) {
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final m = Offset.lerp(a, b, 0.5)!;
    final c1 = m + n * w;
    final c2 = m - n * w;
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(c1.dx, c1.dy, b.dx, b.dy)
        ..quadraticBezierTo(c2.dx, c2.dy, a.dx, a.dy),
      p,
    );
    if (rib) {
      final r = Offset.lerp(a, b, 0.72)!;
      canvas.drawLine(a, r, ribPaint ?? p);
    }
  }

  @override
  bool shouldRepaint(_BotanicalPainter old) =>
      old.kind != kind || old.stroke != stroke || old.accent != accent || old.width != width;
}
