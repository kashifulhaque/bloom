/// Small widgets and styling helpers shared by the insights and assistant
/// screens.
library;

import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';
import 'content.dart';

/// Centers [child] with a max width of 640 px for wide screens.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = Space.maxContentWidth});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child),
      );
}

/// The accent color of an article category, used for tiles, chips, and the
/// reader's hero wash.
Color categoryColor(ArticleCategory c) => switch (c) {
      ArticleCategory.cycleBasics => BloomColors.brand,
      ArticleCategory.periodHealth => BloomColors.period,
      ArticleCategory.fertility => BloomColors.fertile,
      ArticleCategory.sexRelationships => BloomColors.coral,
      ArticleCategory.pregnancy => BloomColors.pregnancy,
      ArticleCategory.afterBirth => BloomColors.follicular,
      ArticleCategory.perimenopause => BloomColors.luteal,
      ArticleCategory.mentalHealth => BloomColors.info,
      ArticleCategory.nutritionFitness => BloomColors.success,
      ArticleCategory.contraception => BloomColors.ovulation,
      ArticleCategory.conditions => BloomColors.brandDeep,
    };

/// A hero gradient for an article category. Every stop is dark enough for
/// white text.
LinearGradient categoryGradient(ArticleCategory c) => switch (c) {
      ArticleCategory.cycleBasics => BloomGradients.brand,
      ArticleCategory.periodHealth => BloomGradients.period,
      ArticleCategory.fertility || ArticleCategory.contraception => BloomGradients.fertile,
      ArticleCategory.perimenopause || ArticleCategory.mentalHealth => BloomGradients.luteal,
      ArticleCategory.pregnancy || ArticleCategory.afterBirth => BloomGradients.follicular,
      _ => BloomGradients.dusk,
    };

/// A rounded tile with a large emoji on a soft wash of [color], used as
/// article "cover art".
class EmojiArt extends StatelessWidget {
  const EmojiArt({super.key, required this.emoji, required this.color, this.size = 56});
  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: dark ? 0.34 : 0.22),
            color.withValues(alpha: dark ? 0.14 : 0.08),
          ],
        ),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.48, height: 1)),
    );
  }
}

/// A slim, rounded progress bar that animates between values.
class SoftProgressBar extends StatelessWidget {
  const SoftProgressBar({
    super.key,
    required this.value,
    this.color,
    this.gradient,
    this.trackColor,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final Gradient? gradient;
  final Color? trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: Radii.pillAll,
      child: Container(
        height: height,
        color: trackColor ?? BloomTokens.of(context).subtle,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: Motion.slow,
          curve: Motion.emphasized,
          builder: (_, v, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: gradient == null ? c : null,
                  gradient: gradient,
                  borderRadius: Radii.pillAll,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the article markup: paragraphs, `## ` headings, `- ` bullets,
/// and `**bold**`.
class ArticleBody extends StatelessWidget {
  const ArticleBody(this.text, {super.key, this.accent});
  final String text;

  /// Bullet color. Defaults to the primary color.
  final Color? accent;

  static List<TextSpan> spans(String line, TextStyle? base) {
    final out = <TextSpan>[];
    final parts = line.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      out.add(TextSpan(
          text: parts[i], style: i.isOdd ? base?.copyWith(fontWeight: FontWeight.w800) : base));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final dot = accent ?? theme.colorScheme.primary;
    final body = t.bodyLarge?.copyWith(height: 1.6, fontSize: 17);
    final children = <Widget>[];
    final para = StringBuffer();

    void flush() {
      if (para.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: Space.lg),
        child: Text.rich(TextSpan(children: spans(para.toString().trim(), body))),
      ));
      para.clear();
    }

    for (final raw in text.trim().split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        flush();
      } else if (line.startsWith('## ')) {
        flush();
        children.add(Padding(
          padding: const EdgeInsets.only(top: Space.sm, bottom: Space.md),
          child: Text(line.substring(3), style: t.titleLarge),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        flush();
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 11, left: Space.xs, right: Space.md),
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            Expanded(child: Text.rich(TextSpan(children: spans(line.substring(2), body)))),
          ]),
        ));
      } else {
        if (para.isNotEmpty) para.write(' ');
        para.write(line);
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// An opaque ring track that looks like a 25% white wash over [g].
///
/// `ProgressRing` multiplies its arc by the track color's alpha, so a
/// translucent track would dim the arc too. Use this on gradient cards.
Color ringTrackOn(LinearGradient g, {double alpha = 0.25}) =>
    Color.alphaBlend(Colors.white.withValues(alpha: alpha), Color.lerp(g.colors.first, g.colors.last, 0.5)!);
