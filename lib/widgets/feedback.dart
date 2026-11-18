/// Messages: [EmptyState], [InfoBanner], and [Disclaimer].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'bloom_card.dart' show readableTint;
import 'botanical.dart';
import 'ink.dart';

/// A quiet placeholder for screens and sections with no data yet: a small
/// botanical drawing, a serif title, a muted body, and an action.
///
/// ```dart
/// EmptyState(
///   title: 'No cycles yet',
///   body: 'Log your last period to see predictions.',
///   actionLabel: 'Log period',
///   onAction: () => ...,
/// )
/// ```
///
/// [emoji] is no longer drawn (decorative emoji are de-emphasized in
/// Almanac); pass [glyph] to pick the drawing. [icon] is drawn thin instead
/// of the drawing.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.emoji,
    this.icon,
    this.color,
    this.actionLabel,
    this.onAction,
    this.action,
    this.compact = false,
    this.glyph = Botanical.sprig,
  });

  final String title;
  final String? body;

  /// Kept for older code; not drawn.
  final String? emoji;

  /// A thin icon in place of the botanical drawing.
  final IconData? icon;

  /// Accent color for the drawing. Defaults to ink2.
  final Color? color;

  /// Label of an ink call-to-action button.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Custom action widget. Overrides [actionLabel].
  final Widget? action;

  /// Smaller drawing and padding, for use inside a section.
  final bool compact;

  /// The botanical drawing to show.
  final Botanical glyph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final art = compact ? 36.0 : 56.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.lg, vertical: compact ? Space.lg : Space.huge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.slow,
            curve: Motion.curve,
            builder: (context, v, child) => Opacity(opacity: v, child: child),
            child: icon != null
                ? Icon(icon, size: art * 0.7, color: color == null ? p.ink2 : readableTint(color!, theme.brightness))
                : BotanicalGlyph(glyph, size: art, accent: color),
          ),
          SizedBox(height: compact ? Space.md : Space.lg),
          Text(
            title,
            style: compact ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (body != null) ...[
            Gap.v8,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(body!, style: theme.textTheme.bodyMedium!.copyWith(color: p.ink2), textAlign: TextAlign.center),
            ),
          ],
          if (action != null || actionLabel != null) ...[
            SizedBox(height: compact ? Space.lg : Space.xxl),
            action ?? InkButton(label: actionLabel!, onPressed: onAction, dense: compact),
          ],
        ],
      ),
    );
  }
}

/// Tone of an [InfoBanner].
enum BannerTone { info, success, warning, error, brand }

/// An inline note: a thin colored rule on the left, an optional title, the
/// message, an optional underlined action, and an optional close button.
/// No box and no fill beyond a faint wash.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = BannerTone.info,
    this.icon,
    this.emoji,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  final String message;
  final String? title;
  final BannerTone tone;

  /// A small thin icon before the title.
  final IconData? icon;

  /// Shown small before the title instead of an icon.
  final String? emoji;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shows a close button when set.
  final VoidCallback? onClose;

  /// The light-mode color of [tone]. Shared widgets resolve it for dark mode.
  static Color toneColor(BannerTone tone) => switch (tone) {
        BannerTone.info => BloomColors.info,
        BannerTone.success => BloomColors.success,
        BannerTone.warning => BloomColors.warning,
        BannerTone.error => BloomColors.error,
        BannerTone.brand => BloomColors.brand,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final dark = theme.brightness == Brightness.dark;
    final c = BloomColors.resolve(context, toneColor(tone));
    final fg = readableTint(toneColor(tone), theme.brightness);
    return Container(
      decoration: BoxDecoration(
        color: c.withValues(alpha: dark ? 0.08 : 0.05),
        border: Border(left: BorderSide(color: c, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.xs, Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null || icon != null || emoji != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.xxs + 1),
                      child: Row(
                        children: [
                          if (emoji != null) ...[Text(emoji!, style: const TextStyle(fontSize: 13, height: 1.2)), Gap.h8]
                          else if (icon != null) ...[Icon(icon, size: 16, color: fg), Gap.h8],
                          if (title != null)
                            Expanded(child: Text(title!, style: theme.textTheme.titleSmall!.copyWith(color: fg))),
                        ],
                      ),
                    ),
                  Text(message, style: theme.textTheme.bodyMedium!.copyWith(color: p.ink)),
                  if (actionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: InkLink(actionLabel!, onTap: onAction, color: fg, arrow: true, size: 14),
                    ),
                ],
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, size: 16, color: p.ink2),
            ),
        ],
      ),
    );
  }
}

/// A small, muted "not medical advice" note with a mono "Note" label in the
/// margin. Put it at the bottom of health content.
class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key, this.text = defaultText, this.center = false});

  static const defaultText =
      'Bloom offers general information, not medical advice. Talk to a clinician about any health concern.';

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final note = Text(
      text,
      style: theme.textTheme.bodySmall!.copyWith(color: p.ink2),
      textAlign: center ? TextAlign.center : TextAlign.start,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: center
          ? note
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: Space.margin,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('NOTE', style: Almanac.label(context, size: 10), semanticsLabel: 'Note'),
                  ),
                ),
                Expanded(child: note),
              ],
            ),
    );
  }
}
