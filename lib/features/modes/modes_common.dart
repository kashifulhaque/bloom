/// Layout, input, and display helpers shared by the mode screens.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../widgets/widgets.dart';

/// A pushed mode screen: a [Scaffold] whose body is a [BloomPage].
///
/// Prefer an in-page button for the main action. [fab] is kept for
/// compatibility but is not used by the mode screens.
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
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? fab;
  final Color? heroColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: fab,
      body: BloomPage(
        title: title,
        subtitle: subtitle,
        eyebrow: eyebrow,
        actions: actions ?? const [],
        heroColor: heroColor,
        children: children,
      ),
    );
  }
}

/// A [BloomCard] with an optional header row: an [IconBadge], a title, and a
/// trailing widget. Pass [color] for a tinted card.
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
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;

  /// Tints the whole card with this color.
  final Color? color;

  /// Color of the header badge. Defaults to [color], then the primary color.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              if (icon != null) ...[IconBadge(icon: icon, color: accent ?? color, size: 36), Gap.h12],
              Expanded(child: Text(title!, style: t.textTheme.titleMedium)),
              if (trailing != null) ...[Gap.h8, trailing!],
            ],
          ),
          Gap.v12,
        ],
        DefaultTextStyle.merge(style: t.textTheme.bodyMedium, child: child),
      ],
    );
    return color == null
        ? BloomCard(onTap: onTap, child: body)
        : BloomCard.tinted(color: color!, onTap: onTap, child: body);
  }
}

/// The trailing chevron used on tappable cards.
class CardChevron extends StatelessWidget {
  const CardChevron({super.key});

  @override
  Widget build(BuildContext context) => Icon(Icons.chevron_right_rounded, color: BloomTokens.of(context).muted);
}

/// Small "educational, not medical advice" footnote.
class EduNote extends StatelessWidget {
  const EduNote({super.key, this.text});
  final String? text;

  @override
  Widget build(BuildContext context) => Disclaimer(text: text ?? Disclaimer.defaultText);
}

/// One shortcut in a [ToolGrid].
class ToolItem {
  const ToolItem(this.icon, this.label, this.color, this.onTap, {this.caption});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? caption;
}

/// A tidy grid of icon shortcuts in three equal columns.
class ToolGrid extends StatelessWidget {
  const ToolGrid({super.key, required this.items});
  final List<ToolItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const cols = 3;
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i += cols) {
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) Gap.h12,
                    Expanded(child: i + j < items.length ? _ToolTile(items[i + j]) : const SizedBox()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[if (r > 0) Gap.v12, rows[r]],
          ],
        );
      },
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile(this.item);
  final ToolItem item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return BloomCard(
      onTap: item.onTap,
      padding: const EdgeInsets.symmetric(vertical: Space.lg, horizontal: Space.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: item.icon, color: item.color, size: 44),
          Gap.v8,
          Text(item.label, style: t.textTheme.labelMedium, textAlign: TextAlign.center, maxLines: 2),
          if (item.caption != null)
            Text(item.caption!, style: t.textTheme.bodySmall, textAlign: TextAlign.center, maxLines: 1),
        ],
      ),
    );
  }
}

/// A big round button with a gradient fill that shrinks a little on press.
class BigRoundButton extends StatefulWidget {
  const BigRoundButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = BloomGradients.brand,
    this.size = 180,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final LinearGradient gradient;
  final double size;
  final String? semanticLabel;

  @override
  State<BigRoundButton> createState() => _BigRoundButtonState();
}

class _BigRoundButtonState extends State<BigRoundButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = BloomColors.onColor(widget.gradient.colors.first);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: Motion.fast,
        curve: Motion.curve,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.gradient,
            boxShadow: dark ? const [] : BloomShadows.glow(widget.gradient.colors.first),
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onPressed,
              onTapDown: (_) => _set(true),
              onTapUp: (_) => _set(false),
              onTapCancel: () => _set(false),
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: fg),
                  textAlign: TextAlign.center,
                  child: Center(child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A checklist row with an animated round check.
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.label, required this.checked, required this.onChanged, this.color});
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final c = color ?? t.colorScheme.primary;
    return Semantics(
      checked: checked,
      child: InkWell(
        onTap: () => onChanged(!checked),
        borderRadius: Radii.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.spring,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? c : Colors.transparent,
                  border: Border.all(color: checked ? c : tokens.muted.withValues(alpha: 0.5), width: 2),
                ),
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: checked
                      ? Icon(Icons.check_rounded, key: const ValueKey(1), size: 16, color: BloomColors.onColor(c))
                      : const SizedBox(key: ValueKey(0)),
                ),
              ),
              Gap.h12,
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: Motion.medium,
                  style: t.textTheme.bodyLarge!.copyWith(
                    color: checked ? tokens.muted : t.colorScheme.onSurface,
                    decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: tokens.muted,
                  ),
                  child: Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded, animated horizontal bar from 0 to 1.
class SoftBar extends StatelessWidget {
  const SoftBar({super.key, required this.value, required this.color, this.height = 8});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Radii.pillAll,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: BloomTokens.of(context).subtle)),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0.0, 1.0)),
              duration: Motion.slow,
              curve: Motion.emphasized,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: Radii.pillAll,
                    gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.25)!]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row in a history list: a badge, a title, a subtitle, and a trailing widget.
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        child: Row(
          children: [
            IconBadge(icon: icon, emoji: emoji, color: color, size: 40),
            Gap.h12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    const SizedBox(height: Space.xxs),
                    Text(subtitle!, style: t.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
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

/// A card holding [children] separated by hairline dividers.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children, this.indent = 68});
  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final border = BloomTokens.of(context).border;
    return BloomCard(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: indent, endIndent: Space.lg, color: border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A tappable card row showing a labeled date, for date pickers in forms.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.date, required this.onTap, this.icon, this.color});
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return BloomCard(
      onTap: onTap,
      padding: Insets.cardCompact,
      child: Row(
        children: [
          IconBadge(icon: icon ?? Icons.event_rounded, color: color),
          Gap.h12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.textTheme.bodySmall),
                AnimatedSwitcher(
                  duration: Motion.medium,
                  layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
                  child: Text(fmtFull(date), key: ValueKey(date), style: t.textTheme.titleMedium),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_calendar_rounded, color: BloomTokens.of(context).muted),
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
