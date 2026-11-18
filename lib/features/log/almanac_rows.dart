/// Small Almanac pieces shared by the log sheet and the Today screen: a thin
/// stepper, a colored dot, and a lined-paper note field.
library;

import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';

/// A small dot in a meaning color, for text tags and row labels.
class ToneDot extends StatelessWidget {
  const ToneDot(this.color, {super.key, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: BloomColors.resolve(context, color)),
      );
}

/// A pair of thin hairline buttons for numeric values: minus and plus.
///
/// Each button is a 32-px hairline square with a thin glyph inside a 44-px
/// touch target.
class ThinStepper extends StatelessWidget {
  const ThinStepper({
    super.key,
    required this.onMinus,
    required this.onPlus,
    required this.minusTooltip,
    required this.plusTooltip,
  });

  /// Null disables the minus button.
  final VoidCallback? onMinus;

  /// Null disables the plus button.
  final VoidCallback? onPlus;
  final String minusTooltip;
  final String plusTooltip;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThinIconButton(icon: Icons.remove, tooltip: minusTooltip, onTap: onMinus),
          ThinIconButton(icon: Icons.add, tooltip: plusTooltip, onTap: onPlus),
        ],
      );
}

/// One hairline-square icon button with a 44-px touch target.
class ThinIconButton extends StatelessWidget {
  const ThinIconButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.boxed = true});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// Draws the hairline square around the icon.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        tooltip: tooltip,
        borderRadius: Radii.mdAll,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedOpacity(
              duration: Motion.fast,
              opacity: enabled ? 1 : 0.35,
              child: Container(
                width: 32,
                height: 32,
                decoration: boxed
                    ? BoxDecoration(borderRadius: Radii.smAll, border: Border.all(color: p.hairline))
                    : null,
                child: Icon(icon, size: boxed ? 16 : 20, color: p.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text field drawn on lined paper: hairline rules under each line of text.
class LinedPaperField extends StatelessWidget {
  const LinedPaperField({
    super.key,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.minLines = 4,
    this.maxLines = 10,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;
  final bool autofocus;

  static const double _size = 17;
  static const double _height = 1.7;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final style = Almanac.serif(size: _size, weight: 330, color: p.ink, height: _height);
    return CustomPaint(
      painter: _RulesPainter(color: p.hairline, lineHeight: _size * _height),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines,
        style: style,
        cursorColor: p.ink,
        cursorWidth: 1.2,
        textCapitalization: TextCapitalization.sentences,
        onChanged: onChanged,
        decoration: InputDecoration.collapsed(
          hintText: hintText,
          hintStyle: Almanac.italic(context, size: _size, color: p.ink2).copyWith(height: _height),
        ),
      ),
    );
  }
}

class _RulesPainter extends CustomPainter {
  _RulesPainter({required this.color, required this.lineHeight});

  final Color color;
  final double lineHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = lineHeight - 3; y <= size.height + 0.5; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RulesPainter old) => old.color != color || old.lineHeight != lineHeight;
}
