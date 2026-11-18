/// Layout, input, and display helpers shared by the mode screens, in the
/// Almanac style: ruled sections, numbered index lists, ledger tables,
/// underline inputs, and hand-ticked checkboxes.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../widgets/widgets.dart';

/// A pushed mode screen: a [Scaffold] whose body is a [BloomPage].
///
/// Pass [header] to replace the serif title with a custom hero, such as a
/// [PhaseTitle]. [fab] and [heroColor] are kept for compatibility; the mode
/// screens don't use them.
class ModePage extends StatelessWidget {
  const ModePage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.eyebrow,
    this.actions,
    this.fab,
    this.heroColor,
    this.header,
    this.spacing = Space.lg,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? fab;
  final Color? heroColor;
  final Widget? header;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: fab,
      body: BloomPage(
        title: title,
        subtitle: subtitle,
        eyebrow: eyebrow,
        header: header,
        actions: actions ?? const [],
        spacing: spacing,
        children: children,
      ),
    );
  }
}

/// A ruled section with an optional serif title and trailing widget.
///
/// [icon], [color], and [accent] are kept for compatibility and aren't drawn:
/// Almanac sections carry no badges or washes.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.icon,
    this.trailing,
    required this.child,
    this.onTap,
    this.color,
    this.accent,
    this.label,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? accent;

  /// A mono label above the title.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return BloomCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[MonoLabel(label!), Gap.v8],
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text(title!, style: t.textTheme.titleLarge)),
                if (trailing != null) ...[Gap.h8, trailing!],
              ],
            ),
            Gap.v8,
          ],
          DefaultTextStyle.merge(style: t.textTheme.bodyMedium, child: child),
        ],
      ),
    );
  }
}

/// The trailing arrow on tappable rows: a thin "→" in ink2.
class CardChevron extends StatelessWidget {
  const CardChevron({super.key});

  @override
  Widget build(BuildContext context) =>
      Text('→', style: Almanac.sans(size: 17, color: BloomColors.of(context).ink2, height: 1));
}

/// Small "educational, not medical advice" footnote.
class EduNote extends StatelessWidget {
  const EduNote({super.key, this.text});
  final String? text;

  @override
  Widget build(BuildContext context) => Disclaimer(text: text ?? Disclaimer.defaultText);
}

/// Two-digit mono numbering for index lists: 1 → "01".
String indexNumber(int n) => n.toString().padLeft(2, '0');

/// One entry in a numbered index, like a line on a contents page: a mono
/// number in the margin, a serif title, an optional italic caption, and a
/// trailing mark. The caller adds the hairlines between entries.
class IndexEntry extends StatelessWidget {
  const IndexEntry({
    super.key,
    required this.number,
    required this.title,
    this.caption,
    this.trailing,
    this.onTap,
    this.selected,
    this.titleSize = 21,
  });

  final int number;
  final String title;
  final String? caption;

  /// Defaults to an arrow when [onTap] is set.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Exposed to screen readers when not null.
  final bool? selected;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Pressable(
      onTap: onTap,
      selected: selected,
      borderRadius: Radii.smAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Padding(
                  padding: EdgeInsets.only(top: titleSize * 0.32),
                  child: Text(indexNumber(number), style: Almanac.label(context, size: 11)),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Almanac.serif(size: titleSize, weight: 360, color: p.ink, height: 1.2),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: Space.xxs + 1),
                      Text(caption!, style: Almanac.italic(context, size: 15, color: p.ink2)),
                    ],
                  ],
                ),
              ),
              Gap.h12,
              Padding(
                padding: EdgeInsets.only(top: titleSize * 0.18),
                child: trailing ?? (onTap != null ? const CardChevron() : const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One shortcut in a [ToolGrid].
class ToolItem {
  const ToolItem(this.icon, this.label, this.color, this.onTap, {this.caption});

  /// Kept for compatibility; the index list doesn't draw icons.
  final IconData icon;
  final String label;

  /// Kept for compatibility; not drawn.
  final Color color;
  final VoidCallback onTap;
  final String? caption;
}

/// Shortcuts as a numbered index list separated by hairlines (the name is
/// historical: it's no longer a grid of icon tiles).
class ToolGrid extends StatelessWidget {
  const ToolGrid({super.key, required this.items});
  final List<ToolItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Hairline(),
        for (var i = 0; i < items.length; i++) ...[
          IndexEntry(number: i + 1, title: items[i].label, caption: items[i].caption, onTap: items[i].onTap),
          const Hairline(),
        ],
      ],
    );
  }
}

/// A large round tap target: one ink-outlined circle on paper, with no fill,
/// gradient, or shadow. Pressing dims it.
class BigRoundButton extends StatelessWidget {
  const BigRoundButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = 200,
    this.semanticLabel,
    this.emphasis = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double size;
  final String? semanticLabel;

  /// Draws a second, inner hairline circle, for example while a timer runs.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Pressable(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      borderRadius: BorderRadius.circular(size),
      pressedOpacity: 0.55,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _CirclePainter(ink: p.ink, hairline: p.hairline, emphasis: emphasis),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: p.ink),
            textAlign: TextAlign.center,
            child: IconTheme.merge(
              data: IconThemeData(color: p.ink),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  _CirclePainter({required this.ink, required this.hairline, required this.emphasis});
  final Color ink;
  final Color hairline;
  final bool emphasis;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ink,
    );
    if (emphasis) {
      canvas.drawCircle(
        c,
        r - 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ink.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) => old.ink != ink || old.emphasis != emphasis || old.hairline != hairline;
}

/// A small square box with a hand-drawn ink tick, like a pencil mark in a
/// printed checklist.
class HandTick extends StatelessWidget {
  const HandTick({super.key, required this.checked, this.size = 20});
  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: checked ? 1 : 0),
      duration: Motion.medium,
      curve: Motion.curve,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _TickPainter(progress: v, box: p.ink2.withValues(alpha: 0.7), ink: p.ink),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({required this.progress, required this.box, required this.ink});
  final double progress;
  final Color box;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Rect.fromLTWH(0.5, s * 0.12, s * 0.8, s * 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = box,
    );
    if (progress <= 0) return;
    // A slightly uneven stroke that runs past the box, as if drawn by hand.
    final path = Path()
      ..moveTo(s * 0.14, s * 0.52)
      ..quadraticBezierTo(s * 0.27, s * 0.62, s * 0.36, s * 0.80)
      ..quadraticBezierTo(s * 0.58, s * 0.34, s * 1.0, s * 0.02);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress || old.ink != ink || old.box != box;
}

/// A checklist row: a hand-ticked box and a label that's struck through
/// once it's done. [color] is kept for compatibility and isn't drawn.
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.label, required this.checked, required this.onChanged, this.color});
  final String label;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = BloomColors.of(context);
    return Semantics(
      checked: checked,
      child: Pressable(
        onTap: onChanged == null
            ? null
            : () {
                Almanac.tick();
                onChanged!(!checked);
              },
        borderRadius: Radii.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: HandTick(checked: checked),
                ),
                Gap.h12,
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: Motion.medium,
                    style: t.textTheme.bodyLarge!.copyWith(
                      color: checked ? p.ink2 : p.ink,
                      decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: p.ink2,
                      decorationThickness: 1,
                    ),
                    child: Text(label),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A list of [CheckRow]s separated by hairlines.
class CheckList extends StatelessWidget {
  const CheckList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Hairline(),
      for (final c in children) ...[c, const Hairline()],
    ],
  );
}

/// A thin, animated horizontal bar from 0 to 1: a hairline track with a
/// short ink (or colored) rule on it.
class SoftBar extends StatelessWidget {
  const SoftBar({super.key, required this.value, this.color, this.height = 3});
  final double value;

  /// Null is ink.
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final c = color == null ? p.ink : BloomColors.resolve(context, color!);
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: Center(child: Container(height: 1, color: p.hairline)),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0.0, 1.0)),
            duration: Motion.slow,
            curve: Motion.emphasized,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: ColoredBox(color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row in a history list: a title, a muted subtitle, and a trailing
/// widget. [icon], [emoji], and [color] are kept for compatibility; only
/// [color] is drawn, as a small dot.
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.emoji,
    this.color,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? emoji;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            if (color != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: BloomColors.resolve(context, color!), shape: BoxShape.circle),
              ),
              Gap.h12,
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    const SizedBox(height: Space.xxs),
                    Text(
                      subtitle!,
                      style: Almanac.data(context, size: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[Gap.h8, trailing!],
          ],
        ),
      ),
    );
  }
}

/// [children] separated by hairlines, with a rule above and below.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children, this.indent = 0});
  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Hairline(),
        for (var i = 0; i < children.length; i++) ...[if (i > 0) Hairline(indent: indent), children[i]],
        const Hairline(),
      ],
    );
  }
}

/// A column in a [LedgerTable].
class LedgerColumn {
  const LedgerColumn(this.label, {this.flex = 1, this.end = false});
  final String label;
  final int flex;

  /// Right-aligns the column, for numbers.
  final bool end;
}

/// One row in a [LedgerTable].
class LedgerRow {
  const LedgerRow(this.cells, {this.trailing, this.onTap, this.muted = false});
  final List<Widget> cells;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Draws the row in ink2, for past or inactive entries.
  final bool muted;
}

/// A printed table: mono column labels over an ink rule, then rows of mono
/// figures separated by hairlines. Use it for history logs.
///
/// Cell text defaults to [Almanac.data] in ink; pass [LedgerTable.serif] for
/// a lead figure.
class LedgerTable extends StatelessWidget {
  const LedgerTable({super.key, required this.columns, required this.rows, this.trailingWidth = 0});

  final List<LedgerColumn> columns;
  final List<LedgerRow> rows;

  /// Space reserved at the end of each row for [LedgerRow.trailing].
  final double trailingWidth;

  /// A serif figure for the lead cell of a row.
  static Widget serif(BuildContext context, String text, {double size = 18}) => Text(
    text,
    style: Almanac.numeral(context, size: size, weight: 340),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    Widget line(List<Widget> cells, {Widget? trailing}) => Row(
      children: [
        for (var i = 0; i < columns.length; i++)
          Expanded(
            flex: columns[i].flex,
            child: Align(
              alignment: columns[i].end ? Alignment.centerRight : Alignment.centerLeft,
              child: i < cells.length ? cells[i] : const SizedBox.shrink(),
            ),
          ),
        if (trailingWidth > 0)
          SizedBox(
            width: trailingWidth,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: line([
            for (final c in columns)
              Text(c.label.toUpperCase(), style: Almanac.label(context), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Container(height: 1, color: p.ink.withValues(alpha: 0.75)),
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const Hairline(),
          Pressable(
            onTap: rows[r].onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: DefaultTextStyle.merge(
                  style: Almanac.mono(
                    size: 13,
                    color: rows[r].muted ? p.ink2 : p.ink,
                  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  child: line(rows[r].cells, trailing: rows[r].trailing),
                ),
              ),
            ),
          ),
        ],
        const Hairline(),
      ],
    );
  }
}

/// A row of text options where the selected one is ink with an underline,
/// like filter links in a printed index. Wraps on narrow screens.
class UnderlineTabs<T> extends StatelessWidget {
  const UnderlineTabs({super.key, required this.options, required this.selected, required this.onChanged});

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Wrap(
      spacing: Space.xl,
      runSpacing: Space.xs,
      children: [
        for (final (value, label) in options)
          Pressable(
            onTap: () {
              if (value == selected) return;
              Almanac.tick();
              onChanged(value);
            },
            selected: value == selected,
            borderRadius: Radii.smAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: AnimatedDefaultTextStyle(
                  duration: Motion.medium,
                  style:
                      Almanac.sans(
                        size: 15,
                        weight: value == selected ? FontWeight.w600 : FontWeight.w400,
                        color: value == selected ? p.ink : p.ink2,
                        height: 1.6,
                      ).copyWith(
                        decoration: value == selected ? TextDecoration.underline : TextDecoration.none,
                        decorationColor: p.ink,
                        decorationThickness: 1.5,
                      ),
                  child: Text(label),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// An editorial form field: a mono label above a serif value on a hairline
/// underline, with a thin icon at the end. Tapping opens a picker.
class UnderlineField extends StatelessWidget {
  const UnderlineField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.calendar_today_outlined,
    this.placeholder = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData icon;

  /// Draws [value] as an italic placeholder in ink2.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: '$label: $value',
      borderRadius: Radii.smAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label),
          Padding(
            padding: const EdgeInsets.only(top: Space.sm, bottom: Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
                    child: Text(
                      value,
                      key: ValueKey(value),
                      style: placeholder
                          ? Almanac.italic(context, size: 20, color: p.ink2)
                          : Almanac.serif(size: 21, weight: 360, color: p.ink),
                    ),
                  ),
                ),
                Icon(icon, size: 18, color: p.ink2),
              ],
            ),
          ),
          Container(height: 1, color: p.ink.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

/// A labeled date as an [UnderlineField], for date pickers in forms.
/// [icon] and [color] are kept for compatibility and aren't drawn.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.date, required this.onTap, this.icon, this.color});
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => UnderlineField(label: label, value: fmtFull(date), onTap: onTap);
}

/// A thin horizontal ledger of [total] units (weeks), like a printed scale:
/// a hairline with a tick per unit, ink ticks up to [value], a taller ink
/// marker at [value], and mono labels at [marks].
class WeekLedger extends StatelessWidget {
  const WeekLedger({
    super.key,
    required this.total,
    required this.value,
    this.marks = const {},
    this.accent,
    this.semanticLabel,
  });

  final int total;

  /// Current position in units, from 0 to [total]. Fractions place the marker between ticks.
  final double value;

  /// Tick index to mono label, for example `{0: '0', 13: 'II', 27: 'III', 40: '40'}`.
  final Map<int, String> marks;

  /// Marker color. Defaults to ink.
  final Color? accent;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final label = Almanac.label(context, size: 9.5);
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        height: 46,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, total.toDouble())),
          duration: Motion.ink,
          curve: Motion.curve,
          builder: (context, v, _) => CustomPaint(
            size: const Size(double.infinity, 46),
            painter: _LedgerPainter(
              total: total,
              value: v,
              marks: marks,
              ink: p.ink,
              faint: p.ink2.withValues(alpha: 0.45),
              hairline: p.hairline,
              accent: accent == null ? p.ink : BloomColors.resolve(context, accent!),
              labelStyle: label,
              direction: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _LedgerPainter extends CustomPainter {
  _LedgerPainter({
    required this.total,
    required this.value,
    required this.marks,
    required this.ink,
    required this.faint,
    required this.hairline,
    required this.accent,
    required this.labelStyle,
    required this.direction,
  });

  final int total;
  final double value;
  final Map<int, String> marks;
  final Color ink;
  final Color faint;
  final Color hairline;
  final Color accent;
  final TextStyle labelStyle;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    const base = 22.0;
    final w = size.width - 2;
    double x(num i) => 1 + w * i / total;
    canvas.drawLine(
      Offset(x(0), base),
      Offset(x(total), base),
      Paint()
        ..color = hairline
        ..strokeWidth = 1,
    );
    final done = Paint()
      ..color = ink
      ..strokeWidth = 1;
    final todo = Paint()
      ..color = faint
      ..strokeWidth = 1;
    for (var i = 0; i <= total; i++) {
      final major = marks.containsKey(i);
      final h = major ? 9.0 : 5.0;
      canvas.drawLine(Offset(x(i), base - h), Offset(x(i), base), i <= value ? done : todo);
      final text = marks[i];
      if (text != null) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: labelStyle),
          textDirection: direction,
        )..layout();
        final left = (x(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(left, base + 7));
      }
    }
    // Ink rule over the elapsed part, and the marker.
    canvas.drawLine(
      Offset(x(0), base),
      Offset(x(value), base),
      Paint()
        ..color = ink
        ..strokeWidth = 1.5,
    );
    final mx = x(value);
    canvas.drawLine(
      Offset(mx, base - 16),
      Offset(mx, base + 3),
      Paint()
        ..color = accent
        ..strokeWidth = 1.5,
    );
    final tri = Path()
      ..moveTo(mx - 4, base - 21)
      ..lineTo(mx + 4, base - 21)
      ..lineTo(mx, base - 15)
      ..close();
    canvas.drawPath(tri, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_LedgerPainter old) =>
      old.value != value || old.ink != ink || old.accent != accent || old.total != total || old.hairline != hairline;
}

/// A serif hero numeral followed by an italic unit, for example
/// "193 *days to go*". It's one [Text], so the whole phrase is searchable.
class SerifFigure extends StatelessWidget {
  const SerifFigure({super.key, required this.value, required this.unit, this.size = 44, this.color});
  final String value;
  final String unit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: Almanac.numeral(context, size: size, color: color),
          ),
          TextSpan(
            text: ' $unit',
            style: Almanac.italic(context, size: math.max(15, size * 0.38), color: p.ink2),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> pickDay(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? help,
}) {
  DateTime clamp(DateTime d) => d.isBefore(first) ? first : (d.isAfter(last) ? last : d);
  return showDatePicker(
    context: context,
    initialDate: clamp(initial),
    firstDate: first,
    lastDate: last,
    helpText: help,
  ).then((d) => d == null ? null : dayOf(d));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirm = 'Confirm',
  String cancel = 'Cancel',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(confirm)),
      ],
    ),
  );
  return ok ?? false;
}

/// Formats a duration as `m:ss` or `h:mm:ss`.
String fmtDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

String fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Unique-enough id for list entries.
String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

/// Tabular figures, for timers and counters that change every second.
const tabular = [FontFeature.tabularFigures()];
