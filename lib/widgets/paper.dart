/// Paper and typography primitives: [PaperBackground], [Hairline],
/// [MonoLabel], [Marginalia], and [PhaseTitle].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Paints the paper color behind [child] and a faint, tileable grain over
/// it (about 4 % ink in light mode and 2.5 % lamplight in dark mode).
///
/// The app wraps every route in one (see `BloomApp`), so screens don't need
/// their own. The grain sits above the content but ignores pointers, so it
/// also covers sheets and dialogs. It's one repeated 192-px image in its own
/// repaint boundary, which is cheap on the web.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child, this.grain = true});

  /// Path of the grain texture asset.
  static const grainAsset = 'assets/textures/paper_grain.png';

  final Widget child;

  /// Draws the grain overlay.
  final bool grain;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: p.paper,
      child: Stack(
        children: [
          child,
          if (grain)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: const AssetImage(grainAsset),
                          repeat: ImageRepeat.repeat,
                          alignment: Alignment.topLeft,
                          scale: 2,
                          opacity: dark ? 0.025 : 0.04,
                          filterQuality: FilterQuality.none,
                          colorFilter: ColorFilter.mode(dark ? const Color(0xFFFFF4E0) : p.ink, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A 1-px hairline rule. Horizontal by default; set [vertical] for a column
/// divider (it then needs a bounded height).
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.endIndent = 0, this.vertical = false, this.color, this.spacing = 0});

  final double indent;
  final double endIndent;
  final bool vertical;

  /// Defaults to the hairline color.
  final Color? color;

  /// Empty space added on both sides of the rule (above and below when
  /// horizontal).
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final c = color ?? BloomColors.of(context).hairline;
    final line = vertical
        ? Container(width: 1, margin: EdgeInsets.only(top: indent, bottom: endIndent), color: c)
        : Container(height: 1, margin: EdgeInsets.only(left: indent, right: endIndent), color: c);
    if (spacing == 0) return line;
    return Padding(
      padding: vertical ? EdgeInsets.symmetric(horizontal: spacing) : EdgeInsets.symmetric(vertical: spacing),
      child: line,
    );
  }
}

/// Marginalia text: small, tracked, uppercase IBM Plex Mono in ink2.
///
/// ```dart
/// MonoLabel('Cycle 07 · Wednesday, 18 Nov')
/// ```
class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text, {super.key, this.color, this.size = 10.5, this.maxLines, this.textAlign});

  final String text;
  final Color? color;
  final double size;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Almanac.label(context, color: color == null ? null : BloomColors.resolve(context, color!), size: size),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: textAlign,
      semanticsLabel: text,
    );
  }
}

/// A two-column row: a small mono label in the left margin and content on
/// the right, like a note in the margin of a printed almanac.
///
/// ```dart
/// Marginalia(
///   label: 'Note',
///   child: Text.rich(TextSpan(children: [
///     TextSpan(text: 'Ovulatory. ', style: Almanac.italic(context)),
///     const TextSpan(text: 'Energy and confidence often peak now.'),
///   ])),
/// )
/// ```
class Marginalia extends StatelessWidget {
  const Marginalia({super.key, required this.label, required this.child, this.labelWidth = Space.margin, this.labelColor});

  final String label;
  final Widget child;

  /// Width of the label column.
  final double labelWidth;

  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Padding(
            // Lines the mono cap height up with the first line of body text.
            padding: const EdgeInsets.only(top: 4, right: Space.sm),
            child: MonoLabel(label, color: labelColor),
          ),
        ),
        Expanded(
          child: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyMedium,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The large serif title at the top of a day: an optional roman [lead]
/// followed by an italic [italic] phrase, such as "Day fourteen," /
/// "*ovulation likely.*"
///
/// ```dart
/// PhaseTitle(lead: 'Day fourteen,', italic: 'ovulation likely.')
/// PhaseTitle(italic: 'Follicular', color: BloomColors.follicular, size: 44)
/// ```
class PhaseTitle extends StatelessWidget {
  const PhaseTitle({
    super.key,
    this.lead,
    required this.italic,
    this.color,
    this.size = 34,
    this.breakLine = true,
    this.textAlign,
  });

  /// Roman text before the italic phrase.
  final String? lead;

  /// The italic phrase, usually the phase name.
  final String italic;

  /// Color of the italic phrase. Defaults to ink. Phase colors that are too
  /// light for text (ochre) are darkened automatically.
  final Color? color;

  final double size;

  /// Puts the italic phrase on its own line.
  final bool breakLine;

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final brightness = Theme.of(context).brightness;
    final c = color == null ? p.ink : _readable(BloomColors.adapt(color!, brightness), brightness);
    return Text.rich(
      TextSpan(children: [
        if (lead != null) TextSpan(text: breakLine ? '$lead\n' : '$lead ', style: Almanac.serif(size: size, weight: 350, color: p.ink, height: 1.08)),
        TextSpan(text: italic, style: Almanac.serif(size: size, weight: 300, italic: true, color: c, height: 1.08)),
      ]),
      textAlign: textAlign,
    );
  }

  static Color _readable(Color c, Brightness b) {
    if (b == Brightness.dark) return c;
    // Ochre and other light hues: deepen until they read as large text.
    var out = c;
    for (var i = 0; i < 4 && out.computeLuminance() > 0.22; i++) {
      out = Color.lerp(out, BloomColors.ink, 0.22)!;
    }
    return out;
  }
}
