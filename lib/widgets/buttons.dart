/// Buttons and brand marks: [GradientButton] and [BloomLogo].
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ink.dart';

/// The one primary action on a screen ("Log today", "Get started").
///
/// In Almanac it's a flat ink button (an [InkButton]); the name is kept so
/// older code compiles. [gradient] is ignored: primary actions are always
/// ink. Use [InkButton] directly in new code.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = BloomGradients.brand,
    this.expanded = false,
    this.loading = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final IconData? icon;

  /// Ignored; kept for older code.
  final LinearGradient gradient;

  /// Stretches to the available width.
  final bool expanded;

  /// Replaces the label with a spinner and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) =>
      InkButton(label: label, onPressed: onPressed, icon: icon, expanded: expanded, loading: loading);
}

/// Bloom's mark: a line-drawn five-petal flower in oxblood on a thin ink
/// stem. Optionally shows the "Bloom" wordmark in Fraunces beside it.
class BloomLogo extends StatelessWidget {
  const BloomLogo({super.key, this.size = 40, this.wordmark = false});

  final double size;

  /// Shows the "Bloom" wordmark to the right of the mark.
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final mark = Semantics(
      label: wordmark ? null : 'Bloom',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: BloomMarkPainter(petal: p.period, stem: p.ink)),
      ),
    );
    if (!wordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.22),
        Text('Bloom', style: Almanac.serif(size: size * 0.66, weight: 360, color: p.ink, height: 1)),
      ],
    );
  }
}

/// Paints the Bloom mark on a 100 x 100 grid: five outlined petals, a small
/// center, and a short stem with one leaf. The web splash and app icons use
/// the same drawing.
class BloomMarkPainter extends CustomPainter {
  const BloomMarkPainter({required this.petal, required this.stem});

  final Color petal;
  final Color stem;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 100;
    canvas.save();
    canvas.scale(k);
    final w = (size.shortestSide < 32 ? 5.0 : 3.6);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w;
    const c = Offset(50, 40);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final dir = Offset(math.cos(a), math.sin(a));
      final n = Offset(-dir.dy, dir.dx);
      final base = c + dir * 6;
      final tip = c + dir * 30;
      final mid = c + dir * 19;
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo((mid + n * 13).dx, (mid + n * 13).dy, tip.dx, tip.dy)
          ..quadraticBezierTo((mid - n * 13).dx, (mid - n * 13).dy, base.dx, base.dy),
        line..color = petal,
      );
    }
    canvas.drawCircle(c, 3.6, Paint()..color = petal);
    line.color = stem;
    canvas.drawPath(Path()..moveTo(50, 70)..quadraticBezierTo(47, 82, 51, 96), line);
    canvas.drawPath(
      Path()
        ..moveTo(49.5, 86)
        ..quadraticBezierTo(58, 76, 68, 79)
        ..quadraticBezierTo(60, 88, 49.5, 86),
      line,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BloomMarkPainter old) => old.petal != petal || old.stem != stem;
}
