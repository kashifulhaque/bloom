/// Ink controls: [Pressable], [InkButton], [InkLink], and [InkSwitch].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Quiet press feedback for anything tappable: the child dims while pressed
/// instead of showing a Material ripple.
///
/// It keeps keyboard focus, Enter and Space activation, the click cursor on
/// the web, and button semantics.
///
/// ```dart
/// Pressable(onTap: open, child: Text('Read more'));
/// ```
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.pressedOpacity = 0.55,
    this.semanticLabel,
    this.selected,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Shape of the keyboard focus highlight.
  final BorderRadius? borderRadius;

  /// Opacity of the child while pressed.
  final double pressedOpacity;

  final String? semanticLabel;

  /// Marks the control as selected for screen readers.
  final bool? selected;

  final String? tooltip;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    Widget out = InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onHighlightChanged: (v) => setState(() => _down = v),
      borderRadius: widget.borderRadius,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: AnimatedOpacity(
        opacity: _down && enabled ? widget.pressedOpacity : 1,
        duration: _down ? const Duration(milliseconds: 60) : Motion.fast,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
    if (widget.semanticLabel != null || widget.selected != null) {
      out = Semantics(label: widget.semanticLabel, selected: widget.selected, button: true, child: out);
    }
    if (widget.tooltip != null) out = Tooltip(message: widget.tooltip!, child: out);
    return Material(type: MaterialType.transparency, child: out);
  }
}

/// A flat Almanac button. The default is the primary style: an ink-filled
/// rectangle with paper text. [InkButton.outlined] is the secondary style: a
/// 1-px ink outline.
///
/// ```dart
/// InkButton(label: 'Log today', icon: Icons.add, onPressed: log);
/// InkButton.outlined(label: 'Edit cycle', onPressed: edit);
/// ```
class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.loading = false,
    this.dense = false,
    this.color,
  }) : outlined = false;

  const InkButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.loading = false,
    this.dense = false,
    this.color,
  }) : outlined = true;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Stretches to the available width.
  final bool expanded;

  /// Replaces the label with a thin spinner and ignores taps.
  final bool loading;

  /// 40 px tall instead of 50, with smaller text.
  final bool dense;

  /// Secondary style: outline only.
  final bool outlined;

  /// Fill (or outline) color. Defaults to ink. Pass a meaning color only when
  /// the action is about that meaning, for example "Log period" in oxblood.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final enabled = onPressed != null && !loading;
    final c = color == null ? p.ink : BloomColors.resolve(context, color!);
    final fg = outlined ? c : (color == null ? p.paper : BloomColors.onColor(c));
    final style = Almanac.sans(size: dense ? 14 : 15, weight: FontWeight.w600, color: fg, height: 1.2, letterSpacing: 0.1);
    final content = AnimatedSwitcher(
      duration: Motion.fast,
      child: loading
          ? SizedBox.square(
              key: const ValueKey('loading'),
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, color: fg, size: dense ? 16 : 18), Gap.h8],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: style)),
              ],
            ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: onPressed == null ? 0.4 : 1,
        child: Pressable(
          onTap: enabled ? onPressed : null,
          borderRadius: Radii.mdAll,
          child: Container(
            width: expanded ? double.infinity : null,
            constraints: BoxConstraints(minHeight: dense ? 40 : 50, minWidth: dense ? 64 : 96),
            padding: EdgeInsets.symmetric(horizontal: dense ? Space.lg : Space.xl, vertical: Space.sm),
            decoration: BoxDecoration(
              color: outlined ? Colors.transparent : c,
              borderRadius: Radii.mdAll,
              border: Border.all(color: c),
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

/// An underlined text link with an optional trailing arrow, for "See all",
/// "Edit", and inline actions.
///
/// ```dart
/// InkLink('See all', onTap: openAll, arrow: true);
/// ```
class InkLink extends StatelessWidget {
  const InkLink(this.label, {super.key, this.onTap, this.arrow = false, this.color, this.size = 14.5, this.icon});

  final String label;
  final VoidCallback? onTap;

  /// Adds a "→" after the label.
  final bool arrow;

  /// Text color. Defaults to ink.
  final Color? color;

  final double size;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final c = color == null ? p.ink : BloomColors.resolve(context, color!);
    final style = Almanac.sans(size: size, weight: FontWeight.w500, color: c, height: 1.3).copyWith(
      decoration: TextDecoration.underline,
      decorationColor: c.withValues(alpha: 0.55),
      decorationThickness: 1,
    );
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.smAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: size + 2, color: c), Gap.h4],
              Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
              if (arrow) Text('  →', style: style.copyWith(decoration: TextDecoration.none)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small hairline toggle: an outlined track with an ink knob. When on, the
/// track fills with ink and the knob turns paper.
///
/// `MenuTile.toggle` uses it. Stock `Switch` widgets are also themed flat,
/// but prefer this one in new code.
class InkSwitch extends StatelessWidget {
  const InkSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final enabled = onChanged != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final outline = dark ? const Color(0xFF6B6157) : const Color(0xFFB3A693);
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Pressable(
          onTap: enabled
              ? () {
                  Almanac.tick();
                  onChanged!(!value);
                }
              : null,
          pressedOpacity: 0.75,
          borderRadius: Radii.pillAll,
          child: SizedBox(
            width: 48,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.curve,
                width: 40,
                height: 22,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: value ? p.ink : Colors.transparent,
                  borderRadius: Radii.pillAll,
                  border: Border.all(color: value ? p.ink : outline),
                ),
                child: AnimatedAlign(
                  duration: Motion.medium,
                  curve: Motion.curve,
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: Motion.medium,
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: value ? p.paper : p.ink2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
