/// Page scaffolding: [BloomPage] and [SectionHeader].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The standard scrolling body for a Bloom screen.
///
/// It adds a [SafeArea], centers content at [maxWidth] on wide screens, adds
/// an optional large title header, and leaves room at the bottom so the last
/// item clears the navigation bar. Use it as a `Scaffold.body`:
///
/// ```dart
/// Scaffold(
///   body: BloomPage(
///     title: 'Insights',
///     subtitle: 'Patterns from your last 6 cycles',
///     actions: [IconButton(onPressed: ..., icon: Icon(Icons.tune_rounded))],
///     children: [ ... ],
///   ),
/// )
/// ```
///
/// Children are laid out in a column with [spacing] between them. To build a
/// lazy list or grid, pass [slivers] instead of [children].
class BloomPage extends StatelessWidget {
  const BloomPage({
    super.key,
    this.title,
    this.subtitle,
    this.eyebrow,
    this.actions = const [],
    this.children = const [],
    this.slivers,
    this.spacing = Space.lg,
    this.maxWidth = Space.maxContentWidth,
    this.padding,
    this.heroColor,
    this.showBack,
    this.onRefresh,
    this.controller,
  });

  /// Large page title, drawn in the display face.
  final String? title;

  /// Muted line under the title.
  final String? subtitle;

  /// Small label above the title, for example today's date.
  final String? eyebrow;

  /// Trailing header actions, usually [IconButton]s.
  final List<Widget> actions;

  /// Page content, laid out top to bottom with [spacing] between items.
  final List<Widget> children;

  /// Use instead of [children] for lazy lists. Each sliver is centered and
  /// padded like the other content.
  final List<Widget>? slivers;

  /// Vertical space between [children].
  final double spacing;

  /// Maximum content width on wide screens.
  final double maxWidth;

  /// Overrides the default page padding ([Insets.page]).
  final EdgeInsets? padding;

  /// Tints the top of the page with a soft wash of this color.
  final Color? heroColor;

  /// Shows a back button in the header. Defaults to true when the route can pop.
  final bool? showBack;

  /// Enables pull-to-refresh.
  final Future<void> Function()? onRefresh;

  /// Scroll controller for the page.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = showBack ?? (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    final pad = padding ?? Insets.page;
    final hasHeader = title != null || canPop || actions.isNotEmpty;

    Widget scroll = LayoutBuilder(builder: (context, box) {
      final side = ((box.maxWidth - maxWidth) / 2).clamp(0.0, double.infinity);
      final h = EdgeInsets.only(left: pad.left + side, right: pad.right + side);
      final bottom = pad.bottom + Space.navClearance + MediaQuery.paddingOf(context).bottom;
      return CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverPadding(padding: EdgeInsets.only(top: pad.top)),
          if (hasHeader)
            SliverPadding(
              padding: h.copyWith(bottom: Space.xl),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  title: title,
                  subtitle: subtitle,
                  eyebrow: eyebrow,
                  actions: actions,
                  showBack: canPop,
                ),
              ),
            ),
          if (slivers != null)
            for (final s in slivers!) SliverPadding(padding: h, sliver: s)
          else
            SliverPadding(
              padding: h,
              sliver: SliverList.separated(
                itemCount: children.length,
                itemBuilder: (_, i) => children[i],
                separatorBuilder: (_, _) => SizedBox(height: spacing),
              ),
            ),
          SliverPadding(padding: EdgeInsets.only(bottom: bottom)),
        ],
      );
    });

    if (onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: onRefresh!, child: scroll);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: heroColor == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.35],
                colors: [
                  heroColor!.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.09),
                  heroColor!.withValues(alpha: 0),
                ],
              ),
      ),
      child: SafeArea(bottom: false, child: scroll),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.title, this.subtitle, this.eyebrow, required this.actions, required this.showBack});

  final String? title;
  final String? subtitle;
  final String? eyebrow;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Transform.translate(
              offset: const Offset(-Space.sm, 0),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.xs),
                      child: Text(
                        eyebrow!.toUpperCase(),
                        style: theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.primary, letterSpacing: 1),
                      ),
                    ),
                  if (title != null) Text(title!, style: theme.textTheme.headlineLarge),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Text(subtitle!, style: theme.textTheme.bodyLarge!.copyWith(color: tokens.muted)),
                    ),
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[Gap.h8, ...actions],
          ],
        ),
      ],
    );
  }
}

/// A section title with an optional trailing action, placed above a group of
/// cards. Pass [actionLabel] and [onAction] for a "See all" style link.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.only(top: Space.sm),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Custom trailing widget. Overrides [actionLabel].
  final Widget? trailing;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xxs),
                    child: Text(subtitle!, style: theme.textTheme.bodyMedium!.copyWith(color: BloomTokens.of(context).muted)),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(actionLabel!), const Icon(Icons.chevron_right_rounded, size: 20)],
              ),
            ),
        ],
      ),
    );
  }
}
