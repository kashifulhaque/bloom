/// Surfaces: [BloomCard], [IconBadge], and [StatTile].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ink.dart';

/// Visual style of a [BloomCard].
enum BloomCardVariant {
  /// An un-boxed section: no fill, a hairline rule on top, vertical padding
  /// only, so content lines up with the page's editorial column.
  plain,

  /// A very faint flat wash of a category color, 6-px corners.
  tinted,

  /// An "inked" emphasis block: a flat fill of the gradient's first color
  /// (ink, oxblood, sage, plum, ochre) with paper text. Use one per screen at
  /// most. Almanac has no gradients, so the name is historical.
  gradient,

  /// A 1-px hairline box with 8-px corners and no fill.
  outlined,
}

/// Bloom's section container in the Almanac style. It is mostly *not* a
/// card: the default draws a hairline rule above the content and no box.
///
/// ```dart
/// BloomCard(child: ...);                                    // ruled section
/// BloomCard.tinted(color: BloomColors.fertile, child: ...); // faint wash
/// BloomCard.gradient(gradient: BloomGradients.period, child: ...); // inked block
/// BloomCard.outlined(child: ...);                           // hairline box
/// ```
///
/// Pass [onTap] for a quiet press state (the content dims; no ripple).
class BloomCard extends StatelessWidget {
  const BloomCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = Insets.card,
    this.radius = Radii.lg,
    this.clip = true,
    this.rule = true,
  })  : variant = BloomCardVariant.plain,
        color = null,
        gradient = null;

  /// A section washed with [color] at very low opacity.
  const BloomCard.tinted({
    super.key,
    required Color this.color,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = Insets.card,
    this.radius = Radii.md,
    this.clip = true,
  })  : variant = BloomCardVariant.tinted,
        gradient = null,
        rule = false;

  /// An inked emphasis block filled with the first color of [gradient].
  /// Text and icons inside turn paper (or ink on light fills).
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
        color = null,
        rule = false;

  /// A hairline box with no fill.
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
        gradient = null,
        rule = false;

  final Widget child;
  final BloomCardVariant variant;

  /// Wash color for [BloomCardVariant.tinted].
  final Color? color;

  /// Fill for [BloomCardVariant.gradient] (only its first color is used).
  final Gradient? gradient;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Content padding. For the plain variant only the top and bottom apply,
  /// so the content aligns with the page column.
  final EdgeInsetsGeometry padding;

  final double radius;

  /// Clips the content to the rounded shape (boxed variants).
  final bool clip;

  /// Draws the hairline rule above a plain section.
  final bool rule;

  /// The flat fill used for an inked block of [gradient] at [brightness].
  static Color inkedFill(Gradient? gradient, Brightness brightness) {
    final c = (gradient?.colors.isNotEmpty ?? false) ? gradient!.colors.first : BloomColors.ink;
    if (brightness == Brightness.dark && c.toARGB32() == BloomColors.ink.toARGB32()) {
      // An ink block on a dark page: a raised walnut panel keeps light text.
      return const Color(0xFF2E2924);
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final dark = b == Brightness.dark;
    final p = BloomColors.of(context);
    final shape = BorderRadius.circular(radius);

    var pad = padding.resolve(Directionality.of(context));
    if (variant == BloomCardVariant.plain) pad = EdgeInsets.only(top: pad.top, bottom: pad.bottom);

    final (Color? bg, BoxBorder? border, BorderRadius? r) = switch (variant) {
      BloomCardVariant.plain => (null, rule ? Border(top: BorderSide(color: p.hairline)) : null, null),
      BloomCardVariant.tinted => (
          BloomColors.adapt(color!, b).withValues(alpha: dark ? 0.10 : 0.07),
          null,
          shape,
        ),
      BloomCardVariant.gradient => (
          inkedFill(gradient, b),
          dark && inkedFill(gradient, b) == const Color(0xFF2E2924) ? Border.all(color: p.hairline) : null,
          shape,
        ),
      BloomCardVariant.outlined => (Colors.transparent, Border.all(color: p.hairline), shape),
    };

    Widget content = Padding(padding: pad, child: child);
    if (variant == BloomCardVariant.gradient) {
      final fg = BloomColors.onColor(bg!);
      content = IconTheme.merge(
        data: IconThemeData(color: fg),
        child: DefaultTextStyle.merge(style: TextStyle(color: fg), child: content),
      );
    }

    Widget box = AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.curve,
      decoration: BoxDecoration(color: bg, border: border, borderRadius: r),
      clipBehavior: clip && r != null ? Clip.antiAlias : Clip.none,
      child: content,
    );
    if (onTap != null || onLongPress != null) {
      box = Pressable(onTap: onTap, onLongPress: onLongPress, borderRadius: r, pressedOpacity: 0.6, child: box);
    }
    return box;
  }
}

/// A small thin-outline circle holding an icon or an emoji. Use it sparingly
/// as a leading mark; most Almanac rows need no badge at all.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, this.icon, this.emoji, this.color, this.size = 40, this.filled = false})
      : assert(icon != null || emoji != null, 'Pass an icon or an emoji');

  final IconData? icon;
  final String? emoji;

  /// Category color for the icon and outline. Defaults to ink2.
  final Color? color;

  final double size;

  /// A solid [color] disc with a paper icon instead of an outline.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final c = color == null ? p.ink2 : BloomColors.resolve(context, color!);
    final fg = filled ? BloomColors.onColor(c) : (color == null ? p.ink2 : readableTint(c, theme.brightness));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? c : null,
        shape: BoxShape.circle,
        border: filled ? null : Border.all(color: color == null ? p.hairline : c.withValues(alpha: 0.45)),
      ),
      child: emoji != null
          ? Text(emoji!, style: TextStyle(fontSize: size * 0.42, height: 1))
          : Icon(icon, size: size * 0.48, color: fg),
    );
  }
}

/// A version of [color] dark enough (light mode) or light enough (dark mode)
/// to read as text or a thin icon on paper or on a faint wash of itself.
/// Light-mode constants such as `BloomColors.period` are swapped for their
/// dark-mode equivalents first.
Color readableTint(Color color, Brightness brightness) {
  final c = BloomColors.adapt(color, brightness);
  if (brightness == Brightness.dark) return Color.lerp(c, const Color(0xFFEFE7DA), 0.12)!;
  var out = Color.lerp(c, BloomColors.ink, 0.2)!;
  // Light hues like ochre need more ink to reach text contrast.
  for (var i = 0; i < 4 && out.computeLuminance() > 0.16; i++) {
    out = Color.lerp(out, BloomColors.ink, 0.25)!;
  }
  return out;
}

/// A metric in the Almanac style: a large serif numeral, an italic unit, and
/// a mono label, set on a hairline rule rather than in a box.
///
/// ```dart
/// StatTile(value: '28', unit: 'days', label: 'Average cycle',
///     color: BloomColors.luteal)
/// ```
///
/// One small mark leads the label: [emoji], else [icon] (tinted by
/// [color]), else a dot of [color].
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

  /// Uses a faint wash of [color] instead of a ruled section.
  final bool tinted;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final c = color == null ? null : BloomColors.resolve(context, color!);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // One quiet leading mark: the emoji, else the icon, else a dot.
            if (emoji != null) ...[Text(emoji!, style: const TextStyle(fontSize: 11, height: 1)), const SizedBox(width: 6)]
            else if (icon != null) ...[
              Icon(icon, size: 13, color: c == null ? p.ink2 : readableTint(color!, theme.brightness)),
              const SizedBox(width: 6),
            ] else if (c != null) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: Almanac.label(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: label,
              ),
            ),
          ],
        ),
        Gap.v8,
        Text.rich(
          TextSpan(children: [
            TextSpan(text: value, style: Almanac.numeral(context, size: 36, weight: 320)),
            if (unit != null) TextSpan(text: ' $unit', style: Almanac.italic(context, size: 15, color: p.ink2)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(caption!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
    return tinted && color != null
        ? BloomCard.tinted(color: color!, padding: Insets.cardCompact, onTap: onTap, child: body)
        : BloomCard(padding: const EdgeInsets.symmetric(vertical: Space.md), onTap: onTap, child: body);
  }
}
