/// Small layout helpers shared by the profile, settings, reminders,
/// reports, and partner screens.
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

/// A pushed settings page: a [BloomPage] with a back button, a large title,
/// and [children] spaced on the 4-pt grid.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, this.subtitle, required this.children, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BloomPage(title: title, subtitle: subtitle, actions: actions, children: children),
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

/// A card that holds a group of rows, with inset hairline dividers.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children, this.padding, this.dividers = true});
  final List<Widget> children;
  final EdgeInsets? padding;
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final tokens = BloomTokens.of(context);
    return BloomCard(
      padding: padding ?? const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0 && dividers && padding == null)
              Divider(height: 1, indent: Space.lg, endIndent: Space.lg, color: tokens.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Muted explanatory text.
class HelpText extends StatelessWidget {
  const HelpText(this.text, {super.key, this.padding = const EdgeInsets.symmetric(horizontal: Space.xs)});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: BloomTokens.of(context).muted, height: 1.45),
    ),
  );
}

/// A compact `-  value  +` pill. The value change animates.
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
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final c = color ?? theme.colorScheme.primary;
    final fg = readableTint(c, theme.brightness);
    Widget button(IconData icon, String tip, VoidCallback? onTap) => SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: tip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: onTap == null ? Colors.transparent : c.withValues(alpha: 0.14),
          foregroundColor: fg,
          disabledForegroundColor: tokens.muted.withValues(alpha: 0.4),
        ),
        icon: Icon(icon, size: 20),
        onPressed: onTap,
      ),
    );
    return Container(
      padding: const EdgeInsets.all(Space.xxs),
      decoration: BoxDecoration(color: tokens.subtle, borderRadius: Radii.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, 'Decrease', value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 68,
            child: AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: child),
              ),
              child: Text(
                display?.call(value) ?? format(value, suffix),
                key: ValueKey(value),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: theme.textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          button(Icons.add_rounded, 'Increase', value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

/// A row with a label, optional subtitle and badge, and a [BloomStepper].
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
  final IconData? icon;
  final Color? color;
  final String Function(int value)? display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    return LayoutBuilder(
      builder: (context, box) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        child: Row(
          children: [
            // On narrow phones the badge gives way to the label.
            if (icon != null && box.maxWidth >= 340) ...[IconBadge(icon: icon, color: color, size: 40), Gap.h16],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xxs),
                      child: Text(subtitle!, style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted)),
                    ),
                ],
              ),
            ),
            Gap.h8,
            BloomStepper(
              value: value,
              min: min,
              max: max,
              suffix: suffix,
              onChanged: onChanged,
              color: color,
              display: display,
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled [SegmentedButton] for a settings card, stretched to full width.
class SegmentedSetting<T> extends StatelessWidget {
  const SegmentedSetting({
    super.key,
    required this.label,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.icon,
    this.color,
  });
  final String label;
  final IconData? icon;
  final Color? color;
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[IconBadge(icon: icon, color: color, size: 32), Gap.h12],
              Expanded(
                child: Text(label, style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          Gap.v12,
          SegmentedButton<T>(
            showSelectedIcon: false,
            segments: segments,
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
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
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(c).colorScheme.error,
                  foregroundColor: Theme.of(c).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirm),
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
