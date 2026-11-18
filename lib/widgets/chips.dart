/// Tags: [PillChip] (a static tag) and [SelectChip] (a selectable option).
///
/// The names are historical: Almanac tags are small hairline rectangles,
/// not pills.
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'bloom_card.dart' show readableTint;
import 'ink.dart';

/// A small, non-interactive tag: "Fertile", "Day 14". A colored dot carries
/// the category; the text stays ink.
class PillChip extends StatelessWidget {
  const PillChip(this.label, {super.key, this.color, this.icon, this.emoji, this.solid = false, this.dense = false});

  final String label;

  /// Category color, shown as a dot. Null shows no dot.
  final Color? color;
  final IconData? icon;
  final String? emoji;

  /// A solid [color] fill with paper (or ink) text, for use on inked blocks.
  final bool solid;

  /// Smaller padding and text.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final c = color == null ? null : BloomColors.resolve(context, color!);
    final fill = solid ? (c ?? p.ink) : null;
    final fg = fill != null ? BloomColors.onColor(fill) : p.ink;
    final style = Almanac.sans(size: dense ? 11.5 : 12.5, weight: FontWeight.w500, color: fg, height: 1.2, letterSpacing: 0.1);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? Space.xs + 2 : Space.sm, vertical: dense ? 2 : Space.xs),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: Radii.smAll,
        border: fill != null ? null : Border.all(color: _outline(theme.brightness, p)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c != null && !solid && emoji == null && icon == null) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          if (emoji != null) ...[Text(emoji!, style: TextStyle(fontSize: dense ? 10 : 11.5, height: 1.1)), Gap.h4],
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 13, color: c == null || solid ? fg : readableTint(c, theme.brightness)),
            Gap.h4,
          ],
          Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  static Color _outline(Brightness b, BloomPalette p) =>
      b == Brightness.dark ? const Color(0xFF4A433A) : const Color(0xFFD6CCBA);
}

/// A selectable tag with an optional emoji, icon, or category color.
///
/// Unselected, it's a hairline outline with ink text. Selected, it fills
/// with ink and the text turns paper; a category [color] shows as a dot.
/// Use it in a `Wrap(spacing: Space.sm, runSpacing: Space.sm, children:
/// [...])` for symptom, mood, and filter pickers.
///
/// ```dart
/// SelectChip(
///   label: 'Cramps',
///   color: BloomColors.period,
///   selected: picked.contains('cramps'),
///   onSelected: (v) => toggle('cramps', v),
/// )
/// ```
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.emoji,
    this.icon,
    this.color,
    this.showCheck = true,
    this.large = false,
  });

  final String label;
  final bool selected;

  /// Called with the new selection state. Null disables the chip.
  final ValueChanged<bool>? onSelected;

  /// Shown small before the label. Prefer [color] or [icon] for app-defined
  /// options; emoji are fine for user-defined ones.
  final String? emoji;
  final IconData? icon;

  /// Category color, shown as a dot when there's no emoji or icon.
  final Color? color;

  /// Shows a small check mark when selected.
  final bool showCheck;

  /// A taller tag with larger text, for primary pickers (flow, mood).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final c = color == null ? null : BloomColors.resolve(context, color!);
    final enabled = onSelected != null;
    final fg = selected ? p.paper : p.ink;
    final outline = theme.brightness == Brightness.dark ? const Color(0xFF4A433A) : const Color(0xFFD6CCBA);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Pressable(
          onTap: enabled
              ? () {
                  Almanac.tick();
                  onSelected!(!selected);
                }
              : null,
          borderRadius: Radii.smAll,
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.curve,
            constraints: BoxConstraints(minHeight: large ? 48 : 40),
            padding: EdgeInsets.symmetric(horizontal: large ? Space.lg : Space.md, vertical: Space.xs + 2),
            decoration: BoxDecoration(
              color: selected ? p.ink : Colors.transparent,
              borderRadius: Radii.smAll,
              border: Border.all(color: selected ? p.ink : outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null) ...[
                  Text(emoji!, style: TextStyle(fontSize: large ? 16 : 14, height: 1.1)),
                  Gap.h8,
                ] else if (icon != null) ...[
                  Icon(icon, size: large ? 18 : 16, color: selected ? fg : (c == null ? p.ink2 : readableTint(c, theme.brightness))),
                  Gap.h8,
                ] else if (c != null) ...[
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  Gap.h8,
                ],
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: Motion.medium,
                    style: Almanac.sans(size: large ? 15 : 14, weight: FontWeight.w500, color: fg, height: 1.2),
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (showCheck)
                  AnimatedSize(
                    duration: Motion.medium,
                    curve: Motion.curve,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: Space.xs + 2),
                            child: Icon(Icons.check, size: 15, color: fg),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
