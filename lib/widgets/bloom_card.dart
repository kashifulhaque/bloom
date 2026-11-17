/// Surfaces: [BloomCard], [IconBadge], and [StatTile].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Visual style of a [BloomCard].
enum BloomCardVariant {
  /// White (light) or raised plum (dark) surface with a soft shadow.
  plain,

  /// A soft wash of a category color with no shadow.
  tinted,

  /// A bold gradient with white content. Use for one hero card per screen.
  gradient,

  /// Transparent with a hairline border, for secondary content.
  outlined,
}

/// Bloom's card: 24-px corners, generous padding, an optional ink ripple, and
/// four variants (see [BloomCardVariant]).
///
/// ```dart
/// BloomCard(child: ...);                                    // plain
/// BloomCard.tinted(color: BloomColors.fertile, child: ...);
/// BloomCard.gradient(gradient: BloomGradients.period, onTap: ..., child: ...);
/// BloomCard.outlined(child: ...);
/// ```
class BloomCard extends StatelessWidget {
  const BloomCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = Insets.card,
    this.radius = Radii.lg,
    this.clip = true,
  })  : variant = BloomCardVariant.plain,
        color = null,
        gradient = null;

  /// A card washed with [color] at low opacity.
  const BloomCard.tinted({
    super.key,
    required Color this.color,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = Insets.card,
    this.radius = Radii.lg,
    this.clip = true,
  })  : variant = BloomCardVariant.tinted,
        gradient = null;

  /// A hero card filled with [gradient]. Text and icons inside turn white.
  const BloomCard.gradient({
    super.key,
    this.gradient = BloomGradients.brand,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = Insets.card,
    this.radius = Radii.lg,
    this.clip = true,
  })  : variant = BloomCardVariant.gradient,
        color = null;

  /// A transparent card with a hairline border.
  const BloomCard.outlined({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = Insets.card,
    this.radius = Radii.lg,
    this.clip = true,
  })  : variant = BloomCardVariant.outlined,
        color = null,
        gradient = null;

  final Widget child;
  final BloomCardVariant variant;

  /// Tint color for [BloomCardVariant.tinted].
  final Color? color;

  /// Fill for [BloomCardVariant.gradient].
  final Gradient? gradient;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Clips the content to the rounded shape.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final tokens = BloomTokens.of(context);
    final shape = BorderRadius.circular(radius);

    final (Color? bg, Gradient? grad, BoxBorder? border, List<BoxShadow> shadow) = switch (variant) {
      BloomCardVariant.plain => (
          theme.cardTheme.color,
          null,
          dark ? Border.all(color: tokens.border) : null,
          tokens.cardShadow,
        ),
      BloomCardVariant.tinted => (
          color!.withValues(alpha: dark ? 0.16 : 0.10),
          null,
          Border.all(color: color!.withValues(alpha: dark ? 0.22 : 0.14)),
          const <BoxShadow>[],
        ),
      BloomCardVariant.gradient => (
          null,
          gradient,
          null,
          dark ? const <BoxShadow>[] : BloomShadows.glow(gradient!.colors.first),
        ),
      BloomCardVariant.outlined => (
          Colors.transparent,
          null,
          Border.all(color: dark ? tokens.border : theme.colorScheme.outlineVariant, width: 1.2),
          const <BoxShadow>[],
        ),
    };

    Widget content = Padding(padding: padding, child: child);
    if (variant == BloomCardVariant.gradient) {
      content = IconTheme.merge(
        data: const IconThemeData(color: Colors.white),
        child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: content),
      );
    }

    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.curve,
      decoration: BoxDecoration(color: bg, gradient: grad, border: border, borderRadius: shape, boxShadow: shadow),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: onTap == null && onLongPress == null
            ? content
            : InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: shape,
                splashColor: variant == BloomCardVariant.gradient ? Colors.white24 : null,
                highlightColor: variant == BloomCardVariant.gradient ? Colors.white10 : null,
                child: content,
              ),
      ),
    );
  }
}

/// A rounded-square badge holding an icon or an emoji on a soft tint of
/// [color]. Used as the leading element of tiles and menu rows.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, this.icon, this.emoji, this.color, this.size = 40, this.filled = false})
      : assert(icon != null || emoji != null, 'Pass an icon or an emoji');

  final IconData? icon;
  final String? emoji;

  /// Category color. Defaults to the primary color.
  final Color? color;

  final double size;

  /// Solid [color] background with a white icon instead of a soft tint.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final c = color ?? theme.colorScheme.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: dark ? 0.22 : 0.13),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: emoji != null
          ? Text(emoji!, style: TextStyle(fontSize: size * 0.5, height: 1))
          : Icon(icon, size: size * 0.55, color: filled ? BloomColors.onColor(c) : readableTint(c, theme.brightness)),
    );
  }
}

/// A version of [color] dark (light mode) or light (dark mode) enough to read
/// as text or an icon on a soft tint of itself.
Color readableTint(Color color, Brightness brightness) => brightness == Brightness.dark
    ? Color.lerp(color, Colors.white, 0.25)!
    : Color.lerp(color, const Color(0xFF2A1F2D), 0.25)!;

/// A metric: a big number with a label, and an optional icon and caption.
///
/// ```dart
/// StatTile(value: '28', unit: 'days', label: 'Average cycle',
///     icon: Icons.loop_rounded, color: BloomColors.luteal)
/// ```
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.caption,
    this.icon,
    this.emoji,
    this.color,
    this.tinted = false,
    this.onTap,
  });

  final String value;
  final String label;

  /// Small unit after the value, for example "days".
  final String? unit;

  /// Muted line under the label, for example "Normal range: 21–35".
  final String? caption;

  final IconData? icon;
  final String? emoji;
  final Color? color;

  /// Uses a tinted card instead of a plain one.
  final bool tinted;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final c = color ?? theme.colorScheme.primary;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null || emoji != null) ...[IconBadge(icon: icon, emoji: emoji, color: c, size: 36), Gap.v12],
        Text.rich(
          TextSpan(children: [
            TextSpan(text: value, style: theme.textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w700)),
            if (unit != null)
              TextSpan(text: ' $unit', style: theme.textTheme.bodyMedium!.copyWith(color: tokens.muted, fontWeight: FontWeight.w600)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Gap.v4,
        Text(label, style: theme.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600)),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xxs),
            child: Text(caption!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
    return tinted
        ? BloomCard.tinted(color: c, padding: Insets.cardCompact, onTap: onTap, child: body)
        : BloomCard(padding: Insets.cardCompact, onTap: onTap, child: body);
  }
}
