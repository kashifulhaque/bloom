/// Page scaffolding: [BloomPage] and [SectionHeader].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ink.dart';

/// The standard scrolling body for a Bloom screen: an editorial column on
/// paper.
///
/// It adds a [SafeArea], centers content at [maxWidth] on wide screens, adds
/// an optional header (a mono [eyebrow], a large serif [title], and a muted
/// [subtitle]), and leaves room at the bottom so the last item clears the
/// navigation bar. Use it as a `Scaffold.body`:
///
/// ```dart
/// Scaffold(
///   body: BloomPage(
///     eyebrow: 'Cycle 07 · Wednesday, 18 Nov',
///     title: 'Insights',
///     subtitle: 'Patterns from your last 6 cycles',
///     actions: [IconButton(onPressed: ..., icon: Icon(Icons.tune))],
///     children: [ ... ],
///   ),
/// )
/// ```
///
/// Children are laid out in a column with [spacing] between them. To build a
/// lazy list or grid, pass [slivers] instead of [children]. Pass [header] to
/// replace the standard title block with your own (for example a
/// `PhaseTitle`).
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
    this.header,
  });

  /// Large serif page title.
  final String? title;

  /// Muted line under the title.
  final String? subtitle;

  /// Small mono label above the title, for example today's date. It's
  /// uppercased for you.
  final String? eyebrow;

  /// Trailing header actions, usually [IconButton]s or an `InkLink`.
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

  /// Ignored in Almanac (pages are plain paper); kept for older code.
  final Color? heroColor;

  /// Shows a back link in the header. Defaults to true when the route can pop.
  final bool? showBack;

  /// Enables pull-to-refresh.
  final Future<void> Function()? onRefresh;

  /// Scroll controller for the page.
  final ScrollController? controller;

  /// Custom content under the eyebrow, in place of [title] and [subtitle].
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    final pad = padding ?? Insets.page;
    final hasHeader = title != null || header != null || eyebrow != null || canPop || actions.isNotEmpty;

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
              padding: h.copyWith(bottom: Space.xxl),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  title: title,
                  subtitle: subtitle,
                  eyebrow: eyebrow,
                  actions: actions,
                  showBack: canPop,
                  custom: header,
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
      scroll = RefreshIndicator(onRefresh: onRefresh!, strokeWidth: 1.5, child: scroll);
    }

    return SafeArea(bottom: false, child: scroll);
  }
}

class _Header extends StatelessWidget {
  const _Header({this.title, this.subtitle, this.eyebrow, required this.actions, required this.showBack, this.custom});

  final String? title;
  final String? subtitle;
  final String? eyebrow;
  final List<Widget> actions;
  final bool showBack;
  final Widget? custom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Transform.translate(
              offset: const Offset(-Space.md, 0),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back, size: 20, color: p.ink),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: Text(eyebrow!.toUpperCase(), style: Almanac.label(context), semanticsLabel: eyebrow),
                    ),
                  ?custom,
                  if (custom == null && title != null) Text(title!, style: theme.textTheme.headlineLarge),
                  if (custom == null && subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: Text(subtitle!, style: theme.textTheme.bodyLarge!.copyWith(color: p.ink2)),
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

/// A section opener: an optional mono [label] in the margin style, a serif
/// title, an optional muted subtitle, and an optional underlined link on the
/// right ("See all →").
///
/// ```dart
/// SectionHeader('Your cycle', label: 'Ledger', actionLabel: 'See all', onAction: ...)
/// ```
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.label,
    this.padding = const EdgeInsets.only(top: Space.lg),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Custom trailing widget. Overrides [actionLabel].
  final Widget? trailing;

  /// A small mono label above the title ("Ledger", "No. 3"). Uppercased.
  final String? label;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs + 2),
                    child: Text(label!.toUpperCase(), style: Almanac.label(context), semanticsLabel: label),
                  ),
                Text(title, style: theme.textTheme.titleLarge!.copyWith(fontSize: 22)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xxs),
                    child: Text(subtitle!, style: theme.textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2)),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (actionLabel != null)
            Padding(padding: const EdgeInsets.only(left: Space.md), child: InkLink(actionLabel!, onTap: onAction, arrow: true, size: 13.5)),
        ],
      ),
    );
  }
}
