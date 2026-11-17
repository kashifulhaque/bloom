/// Messages: [EmptyState], [InfoBanner], and [Disclaimer].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'bloom_card.dart' show readableTint;

/// A friendly placeholder for screens and sections with no data yet.
///
/// ```dart
/// EmptyState(
///   emoji: '🌱',
///   title: 'No cycles yet',
///   body: 'Log your last period to see predictions.',
///   actionLabel: 'Log period',
///   onAction: () => ...,
/// )
/// ```
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
  });

  final String title;
  final String? body;

  /// Illustration emoji. Takes precedence over [icon].
  final String? emoji;
  final IconData? icon;

  /// Color of the illustration halo. Defaults to the brand color.
  final Color? color;

  /// Label of a filled call-to-action button.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Custom action widget. Overrides [actionLabel].
  final Widget? action;

  /// Smaller illustration and padding, for use inside a card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final c = color ?? BloomColors.brand;
    final art = compact ? 72.0 : 112.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.xxl, vertical: compact ? Space.lg : Space.huge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: Motion.slow,
            curve: Motion.spring,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: art,
              height: art,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  c.withValues(alpha: dark ? 0.32 : 0.22),
                  c.withValues(alpha: dark ? 0.08 : 0.05),
                ]),
              ),
              child: emoji != null
                  ? Text(emoji!, style: TextStyle(fontSize: art * 0.42, height: 1))
                  : Icon(icon ?? Icons.spa_rounded, size: art * 0.42, color: readableTint(c, theme.brightness)),
            ),
          ),
          SizedBox(height: compact ? Space.lg : Space.xxl),
          Text(title, style: compact ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          if (body != null) ...[
            Gap.v8,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                body!,
                style: theme.textTheme.bodyLarge!.copyWith(color: BloomTokens.of(context).muted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (action != null || actionLabel != null) ...[
            SizedBox(height: compact ? Space.lg : Space.xxl),
            action ?? FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Tone of an [InfoBanner].
enum BannerTone { info, success, warning, error, brand }

/// An inline message strip with a tone color, an icon, optional title and
/// action, and an optional close button.
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

  /// Overrides the tone's default icon.
  final IconData? icon;

  /// Shown instead of an icon.
  final String? emoji;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shows a close button when set.
  final VoidCallback? onClose;

  static Color toneColor(BannerTone tone) => switch (tone) {
        BannerTone.info => BloomColors.info,
        BannerTone.success => BloomColors.success,
        BannerTone.warning => BloomColors.warning,
        BannerTone.error => const Color(0xFFD9434F),
        BannerTone.brand => BloomColors.brand,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final c = toneColor(tone);
    final fg = readableTint(c, theme.brightness);
    final defaultIcon = switch (tone) {
      BannerTone.info => Icons.info_rounded,
      BannerTone.success => Icons.check_circle_rounded,
      BannerTone.warning => Icons.warning_amber_rounded,
      BannerTone.error => Icons.error_rounded,
      BannerTone.brand => Icons.auto_awesome_rounded,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md + 2, Space.sm, Space.md + 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: dark ? 0.16 : 0.09),
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.withValues(alpha: dark ? 0.3 : 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: emoji != null
                ? Text(emoji!, style: const TextStyle(fontSize: 18, height: 1.2))
                : Icon(icon ?? defaultIcon, size: 20, color: fg),
          ),
          Gap.h12,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.xxs),
                      child: Text(title!, style: theme.textTheme.titleSmall!.copyWith(color: fg)),
                    ),
                  Text(message, style: theme.textTheme.bodyMedium),
                  if (actionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: InkWell(
                        onTap: onAction,
                        borderRadius: Radii.smAll,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.xs),
                          child: Text(actionLabel!, style: theme.textTheme.labelLarge!.copyWith(color: fg)),
                        ),
                      ),
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
              icon: Icon(Icons.close_rounded, size: 18, color: BloomTokens.of(context).muted),
            ),
        ],
      ),
    );
  }
}

/// A small, muted "not medical advice" note. Put it at the bottom of health
/// content.
class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key, this.text = defaultText, this.center = false});

  static const defaultText =
      'Bloom offers general information, not medical advice. Talk to a clinician about any health concern.';

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = BloomTokens.of(context).muted;
    final note = Text(
      text,
      style: theme.textTheme.bodySmall!.copyWith(color: muted),
      textAlign: center ? TextAlign.center : TextAlign.start,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: center
          ? note
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.info_outline_rounded, size: 15, color: muted),
                ),
                Gap.h8,
                Expanded(child: note),
              ],
            ),
    );
  }
}
