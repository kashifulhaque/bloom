/// Buttons and brand marks: [GradientButton] and [BloomLogo].
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// A pill-shaped call-to-action filled with a gradient and a soft glow.
///
/// Use it for the single most important action on a screen ("Log period",
/// "Get started"). Use [FilledButton] for everything else.
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
  final LinearGradient gradient;

  /// Stretches to the available width.
  final bool expanded;

  /// Replaces the label with a spinner and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null && !loading;
    final fg = BloomColors.onColor(gradient.colors.first);
    final content = AnimatedSwitcher(
      duration: Motion.fast,
      child: loading
          ? SizedBox.square(
              key: const ValueKey('loading'),
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, color: fg, size: 20), Gap.h8],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge!.copyWith(color: fg, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: onPressed == null ? 0.45 : 1,
        child: Container(
          width: expanded ? double.infinity : null,
          constraints: const BoxConstraints(minHeight: 54, minWidth: 120),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: Radii.pillAll,
            boxShadow: enabled && theme.brightness == Brightness.light ? BloomShadows.glow(gradient.colors.first) : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              onTap: enabled ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.md),
                child: Center(widthFactor: 1, heightFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloom's mark: five soft petals in a rose-to-coral circle. Optionally shows
/// the "Bloom" wordmark beside it.
class BloomLogo extends StatelessWidget {
  const BloomLogo({super.key, this.size = 40, this.wordmark = false});

  final double size;

  /// Shows the "Bloom" wordmark to the right of the mark.
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: BloomGradients.brand,
        boxShadow: Theme.of(context).brightness == Brightness.light ? BloomShadows.glow(BloomColors.brand) : null,
      ),
      child: CustomPaint(painter: _FlowerPainter()),
    );
    if (!wordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.3),
        Text(
          'Bloom',
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontSize: size * 0.6, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _FlowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final petal = Paint()..color = Colors.white;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.27;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.36, height: r * 0.56), petal);
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.14, Paint()..color = const Color(0xFFFFC2A8));
  }

  @override
  bool shouldRepaint(_FlowerPainter old) => false;
}
