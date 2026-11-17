/// Chips: [PillChip] (a static tag) and [SelectChip] (a selectable option).
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'bloom_card.dart' show readableTint;

/// A small, non-interactive tag: "Fertile", "Day 14", "🔥 3-day streak".
class PillChip extends StatelessWidget {
  const PillChip(this.label, {super.key, this.color, this.icon, this.emoji, this.solid = false, this.dense = false});

  final String label;

  /// Category color. Defaults to the primary color.
  final Color? color;
  final IconData? icon;
  final String? emoji;

  /// Solid [color] fill with contrasting text, for use on gradients and photos.
  final bool solid;

  /// Smaller padding and text.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final c = color ?? theme.colorScheme.primary;
    final fg = solid ? BloomColors.onColor(c) : readableTint(c, theme.brightness);
    final style = (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)!.copyWith(color: fg);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? Space.sm : Space.md, vertical: dense ? 3 : Space.xs + 1),
      decoration: BoxDecoration(
        color: solid ? c : c.withValues(alpha: dark ? 0.2 : 0.12),
        borderRadius: Radii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[Text(emoji!, style: TextStyle(fontSize: dense ? 11 : 13, height: 1.1)), Gap.h4],
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: fg), Gap.h4],
          Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// A selectable chip with an optional emoji or icon and a category color.
///
/// Selection animates the fill, the border, and a check mark. Use it in a
/// `Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [...])` for
/// symptom, mood, and filter pickers.
///
/// ```dart
/// SelectChip(
///   label: 'Cramps',
///   emoji: '😣',
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

  final String? emoji;
  final IconData? icon;

  /// Category color. Defaults to the primary color.
  final Color? color;

  /// Shows a check mark when selected (in place of nothing, not the emoji).
  final bool showCheck;

  /// Taller chip with a bigger emoji, for primary pickers (flow, mood).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final tokens = BloomTokens.of(context);
    final c = color ?? theme.colorScheme.primary;
    final enabled = onSelected != null;
    final fg = selected ? readableTint(c, theme.brightness) : theme.colorScheme.onSurface;
    final bg = selected ? c.withValues(alpha: dark ? 0.26 : 0.16) : (dark ? theme.colorScheme.surfaceContainer : Colors.white);
    final borderColor = selected ? c.withValues(alpha: dark ? 0.8 : 0.65) : tokens.border;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.98,
        duration: Motion.medium,
        curve: Motion.spring,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          constraints: BoxConstraints(minHeight: large ? 52 : 44),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: Radii.pillAll,
            border: Border.all(color: borderColor, width: selected ? 1.6 : 1.2),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: enabled ? () => onSelected!(!selected) : null,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: large ? Space.lg : Space.md + 2, vertical: Space.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji != null) ...[
                      Text(emoji!, style: TextStyle(fontSize: large ? 20 : 16, height: 1.1)),
                      Gap.h8,
                    ] else if (icon != null) ...[
                      Icon(icon, size: large ? 20 : 18, color: selected ? fg : c),
                      Gap.h8,
                    ],
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.medium,
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: enabled ? fg : fg.withValues(alpha: 0.4),
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        ),
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
                                child: Icon(Icons.check_circle_rounded, size: 18, color: fg),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
