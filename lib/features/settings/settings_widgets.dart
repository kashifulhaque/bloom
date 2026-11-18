/// Almanac layout helpers shared by the profile, settings, reminders,
/// reports, and partner screens: settings pages, editorial index rows,
/// steppers, underlined text choices, and confirmation dialogs.
library;

import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';

/// Centers [child] and limits its width to about 640 px on wide screens.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.maxWidth = Space.maxContentWidth});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// A pushed settings page: a [BloomPage] with a back link, an optional mono
/// [eyebrow], a serif title, and [children] in the editorial column.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    required this.children,
    this.actions = const [],
    this.spacing = Space.xxl,
    this.header,
  });
  final String title;
  final String? subtitle;
  final String? eyebrow;

  /// Replaces the serif title, for example with a `PhaseTitle`. [title]
  /// still names the page for screen readers.
  final Widget? header;
  final List<Widget> children;
  final List<Widget> actions;

  /// Vertical space between sections.
  final double spacing;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BloomPage(
      title: title,
      subtitle: subtitle,
      eyebrow: eyebrow,
      header: header == null
          ? null
          : Semantics(
              header: true,
              label: title,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: header!),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: BloomColors.of(context).ink2),
                      ),
                    ),
                ],
              ),
            ),
      actions: actions,
      spacing: spacing,
      children: children,
    ),
  );
}

/// A scrolling page body with a centered, width-limited list of [children].
class SettingsList extends StatelessWidget {
  const SettingsList({super.key, required this.children, this.padding = Insets.page});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: [
      MaxWidth(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap.v16, children[i]],
            ],
          ),
        ),
      ),
    ],
  );
}

/// A group of rows ruled with hairlines (no box), like [MenuSection] without
/// a label.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children, this.padding, this.dividers = true});
  final List<Widget> children;
  final EdgeInsets? padding;
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0 && dividers) const Hairline(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Muted explanatory text.
class HelpText extends StatelessWidget {
  const HelpText(this.text, {super.key, this.padding = EdgeInsets.zero});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(height: 1.5)),
  );
}

/// One entry in an editorial index: an optional mono [number] in the
/// margin, a Fraunces [title], a muted [subtitle], and a mono [value] or a
/// thin arrow. Put several in a [MenuSection] so hairlines separate them.
class IndexEntry extends StatelessWidget {
  const IndexEntry({
    super.key,
    required this.title,
    this.number,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.color,
  });

  final String title;

  /// Shown in the margin, for example "01".
  final String? number;
  final String? subtitle;

  /// Short mono value before the arrow, for example "On".
  final String? value;

  /// Replaces [value] and the arrow.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Title color. Leave null for ink; pass a meaning color only (oxblood for
  /// a destructive entry).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final c = color == null ? p.ink : readableTint(color!, theme.brightness);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (number != null)
              SizedBox(
                width: 40,
                child: Text(number!, style: Almanac.label(context, size: 10.5), semanticsLabel: ''),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Almanac.serif(size: 19, weight: 380, color: c, height: 1.2)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(subtitle!, style: theme.textTheme.bodySmall!.copyWith(fontSize: 13, height: 1.4)),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[Gap.h12, trailing!],
            if (trailing == null && value != null) ...[
              Gap.h12,
              Text(value!.toUpperCase(), style: Almanac.label(context, size: 10.5)),
            ],
            if (trailing == null && onTap != null) ...[
              Gap.h12,
              Text('→', style: Almanac.sans(size: 15, color: p.ink2, height: 1)),
            ],
          ],
        ),
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

/// A quiet "−  28  +" stepper: thin glyph buttons around a serif numeral,
/// with the unit set in italic.
class BloomStepper extends StatelessWidget {
  const BloomStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = 'days',
    this.color,
    this.display,
  });
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  /// Ignored in Almanac (steppers are ink); kept for older code.
  final Color? color;

  /// Formats the value. Overrides [suffix].
  final String Function(int value)? display;

  static String format(int value, String suffix) {
    if (suffix.isEmpty) return '$value';
    if (suffix.startsWith(':')) return '$value$suffix';
    final unit = value == 1 && suffix.endsWith('s') ? suffix.substring(0, suffix.length - 1) : suffix;
    return '$value $unit';
  }

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final text = display?.call(value) ?? format(value, suffix);
    // Split "28 days" into a numeral and an italic unit.
    final space = text.indexOf(' ');
    final numeral = space < 0 ? text : text.substring(0, space);
    final unit = space < 0 ? null : text.substring(space + 1);

    Widget button(String glyph, String tip, VoidCallback? onTap) => Pressable(
      onTap: onTap == null
          ? null
          : () {
              Almanac.tick();
              onTap();
            },
      tooltip: tip,
      semanticLabel: tip,
      borderRadius: Radii.smAll,
      child: SizedBox(
        width: 40,
        height: 44,
        child: Center(
          child: Text(
            glyph,
            style: Almanac.sans(size: 22, weight: FontWeight.w400, color: onTap == null ? p.hairline : p.ink, height: 1),
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button('−', 'Decrease', value > min ? () => onChanged(value - 1) : null),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56),
          child: AnimatedSwitcher(
            duration: Motion.fast,
            transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: numeral, style: Almanac.numeral(context, size: 26, weight: 340)),
                if (unit != null) TextSpan(text: ' $unit', style: Almanac.italic(context, size: 14, color: p.ink2)),
              ]),
              key: ValueKey(text),
              textAlign: TextAlign.center,
              maxLines: 1,
              semanticsLabel: text,
            ),
          ),
        ),
        button('+', 'Increase', value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

/// A row with a label, an optional subtitle, and a [BloomStepper].
class StepperTile extends StatelessWidget {
  const StepperTile({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.subtitle,
    this.suffix = 'days',
    this.icon,
    this.color,
    this.display,
  });
  final String title;
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  /// Ignored in Almanac (no icon badges); kept for older code.
  final IconData? icon;

  /// Ignored in Almanac; kept for older code.
  final Color? color;
  final String Function(int value)? display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w500, height: 1.35)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          Gap.h8,
          BloomStepper(value: value, min: min, max: max, suffix: suffix, onChanged: onChanged, display: display),
        ],
      ),
    );
  }
}

/// One option for [TextChoices].
class TextChoice<T> {
  const TextChoice(this.value, this.label, {this.semanticLabel});
  final T value;
  final String label;
  final String? semanticLabel;
}

/// A row of text options in place of a segmented control: the selected one
/// is ink with an ink underline, the others are ink2.
class TextChoices<T> extends StatelessWidget {
  const TextChoices({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.serif = false,
    this.spacing = Space.lg,
  });
  final List<TextChoice<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Sets the options in Fraunces (for tabs) instead of Hanken Grotesk.
  final bool serif;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Wrap(
      spacing: spacing,
      runSpacing: 0,
      children: [
        for (final o in options)
          Builder(builder: (context) {
            final on = o.value == selected;
            final style = serif
                ? Almanac.serif(size: 19, weight: on ? 400 : 340, color: on ? p.ink : p.ink2, height: 1.2)
                : Almanac.sans(size: 15, weight: on ? FontWeight.w600 : FontWeight.w500, color: on ? p.ink : p.ink2, height: 1.2);
            return Semantics(
              inMutuallyExclusiveGroup: true,
              checked: on,
              child: Pressable(
                onTap: on
                    ? null
                    : () {
                        Almanac.tick();
                        onChanged(o.value);
                      },
                semanticLabel: o.semanticLabel,
                borderRadius: Radii.smAll,
                child: SizedBox(
                  height: 44,
                  child: Center(
                    widthFactor: 1,
                    child: AnimatedContainer(
                      duration: Motion.medium,
                      curve: Motion.curve,
                      padding: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: on ? p.ink : Colors.transparent, width: 1.5)),
                      ),
                      child: Text(o.label, style: style),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// A labelled [TextChoices] row for a settings list: the label on the left
/// and the options on the right (they wrap below on narrow screens).
class SegmentedSetting<T> extends StatelessWidget {
  const SegmentedSetting({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.subtitle,
  });
  final String label;
  final String? subtitle;
  final List<TextChoice<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w500, height: 1.35)),
        if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
      ],
    );
    final choices = TextChoices<T>(options: options, selected: selected, onChanged: onChanged);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth < 420
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Padding(padding: const EdgeInsets.only(top: Space.xs), child: title), choices],
              )
            : Row(children: [Expanded(child: title), Gap.h16, choices]),
      ),
    );
  }
}

/// A section ruled in oxblood with a mono "Danger" label, for destructive
/// actions.
class DangerSection extends StatelessWidget {
  const DangerSection({super.key, required this.title, required this.body, required this.action, this.label = 'Danger'});
  final String label;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final theme = Theme.of(context);
    final c = readableTint(BloomColors.error, theme.brightness);
    return Container(
      padding: const EdgeInsets.only(top: Space.md),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.error, width: 1.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label, color: c),
          Gap.v8,
          Text(title, style: theme.textTheme.titleLarge!.copyWith(color: c)),
          Gap.v4,
          Text(body, style: theme.textTheme.bodyMedium!.copyWith(color: p.ink2)),
          Gap.v16,
          action,
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks a yes/no question. Returns true when the user confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirm',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        InkButton(
          label: confirm,
          dense: true,
          color: destructive ? BloomColors.error : null,
          onPressed: () => Navigator.pop(c, true),
        ),
      ],
    ),
  );
  return ok ?? false;
}

String fmtTimeOfDay(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final m = minute.toString().padLeft(2, '0');
  return '$h:$m ${hour < 12 ? 'AM' : 'PM'}';
}
