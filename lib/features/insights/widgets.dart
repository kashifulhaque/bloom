/// Small widgets and styling helpers shared by the Library (insights) and
/// Ask (assistant) screens.
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

/// The color of an article category.
///
/// In Almanac, categories are ink on paper; only the categories that are
/// about a cycle meaning carry its color (period health in oxblood,
/// fertility in sage); the rest return ink2. Use it for small dots, never
/// for fills.
Color categoryColor(ArticleCategory c) => switch (c) {
      ArticleCategory.periodHealth => BloomColors.period,
      ArticleCategory.fertility => BloomColors.fertile,
      _ => BloomColors.ink2,
    };

/// A flat fill for an article category. Kept for older code; Almanac pages
/// don't draw category fills.
LinearGradient categoryGradient(ArticleCategory c) => switch (c) {
      ArticleCategory.periodHealth => BloomGradients.period,
      ArticleCategory.fertility || ArticleCategory.contraception => BloomGradients.fertile,
      ArticleCategory.perimenopause || ArticleCategory.mentalHealth => BloomGradients.luteal,
      ArticleCategory.pregnancy || ArticleCategory.afterBirth => BloomGradients.pregnancy,
      _ => BloomGradients.brand,
    };

/// Strips the `**bold**` markers from article markup.
String plainText(String markup) => markup.replaceAll('**', '');

/// Splits an article body into a standfirst (its first sentence) and the
/// rest of the body, so the reader can set the opening line in italics
/// above the text without repeating it.
({String standfirst, String rest}) splitStandfirst(String body) {
  final text = body.trim();
  final firstBreak = text.indexOf('\n');
  final firstPara = firstBreak < 0 ? text : text.substring(0, firstBreak);
  if (firstPara.startsWith('## ') || firstPara.startsWith('- ')) return (standfirst: '', rest: text);
  final m = RegExp(r'[.?!](\s+)').allMatches(firstPara).where((m) => m.start >= 30).firstOrNull;
  if (m == null) {
    return (standfirst: plainText(firstPara), rest: firstBreak < 0 ? '' : text.substring(firstBreak).trim());
  }
  final lead = firstPara.substring(0, m.start + 1);
  final remainder = firstPara.substring(m.end);
  final after = firstBreak < 0 ? '' : text.substring(firstBreak);
  return (standfirst: plainText(lead), rest: '$remainder$after'.trim());
}

/// A short standfirst for list and lead use: the first sentence, cut to
/// about [max] characters at a word boundary.
String shortStandfirst(Article a, {int max = 150}) {
  final s = splitStandfirst(a.body).standfirst;
  if (s.length <= max) return s;
  final cut = s.lastIndexOf(' ', max);
  return '${s.substring(0, cut < 0 ? max : cut)}…';
}

/// Formats [n] as a two-digit table-of-contents number ("07").
String tocNumber(int n) => n.toString().padLeft(2, '0');

/// A rule-thin progress line: a hairline track with a 2-px ink fill that
/// animates between values. Used for quiz, checker, and story progress.
class RuleProgress extends StatelessWidget {
  const RuleProgress({super.key, required this.value, this.color, this.animate = true});
  final double value;

  /// Fill color. Defaults to ink.
  final Color? color;

  /// Animates changes in [value]. Turn off when [value] is driven by a
  /// ticker already.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final fill = color == null ? p.ink : BloomColors.resolve(context, color!);
    Widget bar(double v) => SizedBox(
          height: 3,
          child: Stack(children: [
            Positioned(left: 0, right: 0, top: 1, child: Container(height: 1, color: p.hairline)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                child: Container(height: 2, color: fill),
              ),
            ),
          ]),
        );
    if (!animate) return bar(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: Motion.medium,
      curve: Motion.curve,
      builder: (_, v, _) => bar(v),
    );
  }
}

/// A slim progress bar. Kept for older code; it now draws a [RuleProgress].
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
  Widget build(BuildContext context) => RuleProgress(value: value, color: color);
}

/// A small hairline-boxed tag, the Almanac quick reply or option: Hanken
/// text, an optional thin icon or meaning dot, and quiet press feedback.
class HairlineTag extends StatelessWidget {
  const HairlineTag({super.key, required this.label, this.onTap, this.icon, this.dot, this.tooltip});
  final String label;
  final VoidCallback? onTap;

  /// A thin leading icon.
  final IconData? icon;

  /// A meaning-color dot, shown when there's no [icon].
  final Color? dot;

  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.smAll,
      tooltip: tooltip,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        decoration: BoxDecoration(borderRadius: Radii.smAll, border: Border.all(color: p.hairline)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: p.ink2),
            Gap.h8,
          ] else if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: BloomColors.resolve(context, dot!), shape: BoxShape.circle),
            ),
            Gap.h8,
          ],
          Flexible(
            child: Text(label, style: Almanac.sans(size: 13.5, weight: FontWeight.w500, color: p.ink, height: 1.3)),
          ),
        ]),
      ),
    );
  }
}

/// A footnote: a short hairline rule, then small muted text with an
/// optional mark ("*"). Used for disclaimers at the end of an essay or a
/// conversation.
class Footnote extends StatelessWidget {
  const Footnote(this.text, {super.key, this.mark = '*'});
  final String text;
  final String mark;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 48, height: 1, color: p.ink2.withValues(alpha: 0.5)),
      Gap.v8,
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 14,
          child: Text(mark, style: Almanac.serif(size: 13, color: p.ink2, height: 1.45)),
        ),
        Expanded(child: Text(text, style: Almanac.sans(size: 12.5, color: p.ink2, height: 1.5))),
      ]),
    ]);
  }
}

/// Renders the article markup: paragraphs, `## ` headings, `- ` bullets,
/// and `**bold**`, set like a book page. With [dropCap], the first
/// paragraph opens with a three-line serif initial.
class ArticleBody extends StatelessWidget {
  const ArticleBody(this.text, {super.key, this.accent, this.dropCap = false, this.size = 17});
  final String text;

  /// Bullet color. Defaults to ink2.
  final Color? accent;

  /// Sets a drop cap on the first paragraph.
  final bool dropCap;

  /// Body text size.
  final double size;

  static List<TextSpan> spans(String line, TextStyle? base) {
    final out = <TextSpan>[];
    final parts = line.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      out.add(TextSpan(text: parts[i], style: i.isOdd ? base?.copyWith(fontWeight: FontWeight.w700) : base));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final body = Almanac.sans(size: size, color: p.ink, height: 1.6);
    final dash = accent == null ? p.ink2 : BloomColors.resolve(context, accent!);
    final children = <Widget>[];
    final para = StringBuffer();
    var capUsed = !dropCap;

    void flush() {
      if (para.isEmpty) return;
      final line = para.toString().trim();
      para.clear();
      if (!capUsed && line.length > 60) {
        capUsed = true;
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: _DropCapParagraph(text: line, style: body),
        ));
        return;
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: Space.lg),
        child: Text.rich(TextSpan(children: spans(line, body))),
      ));
    }

    for (final raw in text.trim().split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        flush();
      } else if (line.startsWith('## ')) {
        flush();
        children.add(Padding(
          padding: const EdgeInsets.only(top: Space.md, bottom: Space.md),
          child: Text(line.substring(3), style: Almanac.serif(size: size + 4, weight: 380, color: p.ink, height: 1.25)),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        flush();
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: Text('–', style: body.copyWith(color: dash))),
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

/// A paragraph that opens with a serif initial three lines tall. The text
/// beside the initial is measured and split so the rest of the paragraph
/// runs the full measure underneath, as in a printed book.
class _DropCapParagraph extends StatelessWidget {
  const _DropCapParagraph({required this.text, required this.style});
  final String text;
  final TextStyle style;

  static const _lines = 3;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final plain = plainText(text);
    final initial = plain.characters.first;
    // A one-letter first word ("A 28-day cycle") keeps its space as the gap
    // after the initial.
    var skip = initial.length;
    while (skip < plain.length && plain[skip] == ' ') {
      skip++;
    }
    final restPlain = plain.substring(skip);
    final textScaler = MediaQuery.textScalerOf(context);
    final fontSize = textScaler.scale(style.fontSize!);
    final lineHeight = fontSize * style.height!;

    return LayoutBuilder(builder: (context, box) {
      // Size the initial so its cap height runs from the cap height of the
      // first line down to the baseline of the third.
      const capRatio = 0.7; // Cap height of Fraunces and Hanken, in ems.
      final capSize = (lineHeight * (_lines - 1) + fontSize * capRatio) / capRatio;
      final capStyle = Almanac.serif(size: capSize, weight: 320, color: p.ink, height: 1, letterSpacing: 0);
      final capPainter = TextPainter(
        text: TextSpan(text: initial, style: capStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final capWidth = capPainter.width + Space.sm + 2;
      final capBaseline = capPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final sideWidth = box.maxWidth - capWidth;

      // Find how much of the text fits in the lines beside the initial.
      final sidePainter = TextPainter(
        text: TextSpan(text: restPlain, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: sideWidth);
      final metrics = sidePainter.computeLineMetrics();
      var split = restPlain.length;
      if (metrics.length > _lines) {
        final y = metrics.take(_lines).fold<double>(0, (a, m) => a + m.height) + 1;
        split = sidePainter.getPositionForOffset(Offset(0, y)).offset;
        // Break at the word boundary the painter chose.
        while (split > 0 && split < restPlain.length && restPlain[split - 1] != ' ') {
          split--;
        }
      }
      final lastBaseline = metrics.isEmpty
          ? lineHeight * 0.75
          : metrics[(_lines - 1).clamp(0, metrics.length - 1)].baseline;
      capPainter.dispose();
      sidePainter.dispose();

      final (side, below) = _splitSpans(text, skip, split);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: capWidth,
            height: lineHeight * _lines,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                top: lastBaseline - capBaseline,
                child: ExcludeSemantics(child: Text(initial, style: capStyle, textScaler: TextScaler.noScaling)),
              ),
            ]),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: ArticleBody.spans(side, style)),
              semanticsLabel: '$initial${skip > initial.length ? ' ' : ''}${plainText(side)}',
            ),
          ),
        ]),
        if (below.trim().isNotEmpty) Text.rich(TextSpan(children: ArticleBody.spans(below.trimLeft(), style))),
      ]);
    });
  }

  /// Splits the markup [text] (with `**` markers) into the part beside the
  /// initial and the part below, at [split] characters of plain text after
  /// skipping the [skip]-character initial. Bold runs that cross the split
  /// are closed and reopened.
  static (String, String) _splitSpans(String text, int skip, int split) {
    final a = StringBuffer();
    final b = StringBuffer();
    var bold = false;
    var plainIndex = 0;
    var i = 0;
    while (i < text.length) {
      if (text.startsWith('**', i)) {
        bold = !bold;
        (plainIndex - skip < split ? a : b).write('**');
        i += 2;
        continue;
      }
      final ch = text[i];
      if (plainIndex >= skip) {
        final pos = plainIndex - skip;
        if (pos == split && bold) {
          a.write('**');
          b.write('**');
        }
        (pos < split ? a : b).write(ch);
      }
      plainIndex++;
      i++;
    }
    return (a.toString(), b.toString());
  }
}

/// An opaque ring track. Kept for older code.
Color ringTrackOn(LinearGradient g, {double alpha = 0.25}) =>
    Color.alphaBlend(Colors.white.withValues(alpha: alpha), Color.lerp(g.colors.first, g.colors.last, 0.5)!);

/// The emoji cover art of older layouts. Almanac doesn't draw article
/// emoji as decoration; this now renders a small botanical drawing.
class EmojiArt extends StatelessWidget {
  const EmojiArt({super.key, required this.emoji, required this.color, this.size = 56});
  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => BotanicalGlyph(Botanical.sprig, size: size * 0.6);
}
