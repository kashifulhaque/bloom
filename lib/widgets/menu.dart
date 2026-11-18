/// Editorial lists: [MenuSection] and [MenuTile].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'bloom_card.dart' show readableTint;
import 'ink.dart';

/// A group of [MenuTile]s under a mono label, ruled with hairlines. There's
/// no card around it.
///
/// ```dart
/// MenuSection(
///   title: 'Privacy',
///   children: [
///     MenuTile(icon: Icons.lock_outline, title: 'App lock', onTap: ...),
///     MenuTile.toggle(title: 'Hide notifications', value: hide, onChanged: setHide),
///   ],
/// )
/// ```
class MenuSection extends StatelessWidget {
  const MenuSection({super.key, this.title, this.footer, required this.children});

  /// Shown as an uppercase mono label above the rows.
  final String? title;

  /// Muted note under the rows.
  final String? footer;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Text(title!.toUpperCase(), style: Almanac.label(context), semanticsLabel: title),
          ),
        Container(height: 1, color: p.hairline),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Container(height: 1, color: p.hairline),
          children[i],
        ],
        Container(height: 1, color: p.hairline),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(footer!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// One row in a [MenuSection]: an optional thin icon, a title, an optional
/// subtitle, and a trailing value (in mono), switch, or arrow.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.title,
    this.icon,
    this.emoji,
    this.color,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron,
  });

  /// A row with a trailing [InkSwitch]. Tapping anywhere on the row toggles
  /// it.
  factory MenuTile.toggle({
    Key? key,
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    IconData? icon,
    String? emoji,
    Color? color,
    String? subtitle,
  }) =>
      MenuTile(
        key: key,
        title: title,
        icon: icon,
        emoji: emoji,
        color: color,
        subtitle: subtitle,
        showChevron: false,
        onTap: onChanged == null ? null : () => onChanged(!value),
        trailing: ExcludeSemantics(child: InkSwitch(value: value, onChanged: onChanged)),
      );

  final String title;

  /// A thin leading icon in ink2 (or the tint of [color]).
  final IconData? icon;

  /// Shown small in place of an icon.
  final String? emoji;

  /// Tints the icon. Usually leave it null: rows are ink.
  final Color? color;

  final String? subtitle;

  /// Short value before the arrow, for example "28 days". Set in mono.
  final String? value;

  /// Custom trailing widget. Replaces [value] and the arrow.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Draws the title and icon in the error color.
  final bool destructive;

  /// Shows an arrow. Defaults to true when [onTap] is set and [trailing] isn't.
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final chevron = showChevron ?? (onTap != null && trailing == null);
    final iconColor = destructive
        ? p.error
        : color == null
            ? p.ink2
            : readableTint(color!, theme.brightness);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md - 1),
        child: Row(
          children: [
            if (emoji != null) ...[
              SizedBox(width: 24, child: Text(emoji!, style: const TextStyle(fontSize: 16, height: 1))),
              Gap.h12,
            ] else if (icon != null) ...[
              Icon(icon, size: 20, color: iconColor),
              Gap.h16,
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: destructive ? p.error : p.ink,
                      height: 1.35,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: theme.textTheme.bodyMedium!.copyWith(color: p.ink2, height: 1.4)),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[Gap.h8, trailing!],
            if (trailing == null && value != null) ...[
              Gap.h8,
              Text(value!, style: Almanac.data(context, size: 12.5)),
            ],
            if (chevron) ...[
              Gap.h8,
              Icon(Icons.arrow_forward, size: 16, color: p.ink2.withValues(alpha: 0.8)),
            ],
          ],
        ),
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}
