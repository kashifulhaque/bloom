/// Settings-style lists: [MenuSection] and [MenuTile].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'bloom_card.dart';

/// A titled group of [MenuTile]s inside one card, with inset dividers.
///
/// ```dart
/// MenuSection(
///   title: 'Privacy',
///   children: [
///     MenuTile(icon: Icons.lock_rounded, color: BloomColors.luteal, title: 'App lock', onTap: ...),
///     MenuTile.toggle(icon: Icons.visibility_off_rounded, title: 'Hide notifications',
///         value: hide, onChanged: setHide),
///   ],
/// )
/// ```
class MenuSection extends StatelessWidget {
  const MenuSection({super.key, this.title, this.footer, required this.children});

  final String? title;

  /// Muted note under the card.
  final String? footer;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.sm),
            child: Text(
              title!.toUpperCase(),
              style: theme.textTheme.labelMedium!.copyWith(color: tokens.muted, letterSpacing: 1),
            ),
          ),
        BloomCard(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(indent: 72, endIndent: Space.lg, color: tokens.border),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
            child: Text(footer!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// One row in a [MenuSection]: a colored [IconBadge], a title, an optional
/// subtitle, and a trailing value, switch, or chevron.
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

  /// A row with a trailing [Switch]. Tapping anywhere on the row toggles it.
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
        trailing: Switch(value: value, onChanged: onChanged),
      );

  final String title;
  final IconData? icon;
  final String? emoji;

  /// Badge color. Defaults to the primary color.
  final Color? color;

  final String? subtitle;

  /// Short muted value shown before the chevron, for example "28 days".
  final String? value;

  /// Custom trailing widget. Replaces [value] and the chevron.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Draws the title and badge in the error color.
  final bool destructive;

  /// Shows a chevron. Defaults to true when [onTap] is set and [trailing] isn't.
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final c = destructive ? theme.colorScheme.error : color;
    final chevron = showChevron ?? (onTap != null && trailing == null);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm + 2),
          child: Row(
            children: [
              if (icon != null || emoji != null) ...[
                IconBadge(icon: icon, emoji: emoji, color: c, size: 40),
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
                        fontWeight: FontWeight.w700,
                        color: destructive ? theme.colorScheme.error : null,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(subtitle!, style: theme.textTheme.bodyMedium!.copyWith(color: tokens.muted)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[Gap.h8, trailing!],
              if (trailing == null && value != null) ...[
                Gap.h8,
                Text(value!, style: theme.textTheme.bodyMedium!.copyWith(color: tokens.muted, fontWeight: FontWeight.w600)),
              ],
              if (chevron) ...[
                Gap.h4,
                Icon(Icons.chevron_right_rounded, color: tokens.muted.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
