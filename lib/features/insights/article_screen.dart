/// Article reader with bookmark, mark-as-read, and related articles.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'content.dart';
import 'insights_data.dart';
import 'widgets.dart';

void openArticle(BuildContext context, String id) {
  final a = articleById(id);
  if (a == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ArticleScreen(article: a)));
}

/// Articles in the same category first, then ones sharing the most tags.
List<Article> relatedArticles(Article a, {int limit = 3}) {
  final scored = <(Article, int)>[];
  for (final o in kArticles) {
    if (o.id == a.id) continue;
    var s = o.tags.where(a.tags.contains).length;
    if (o.category == a.category) s += 3;
    if (s > 0) scored.add((o, s));
  }
  scored.sort((x, y) => y.$2.compareTo(x.$2));
  return [for (final s in scored.take(limit)) s.$1];
}

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final a = article;
    final bookmarked = InsightsData.isBookmarked(store, a.id);
    final read = InsightsData.isRead(store, a.id);
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final muted = BloomTokens.of(context).muted;
    final color = categoryColor(a.category);
    final related = relatedArticles(a);

    return Scaffold(
      body: BloomPage(
        heroColor: color,
        actions: [
          IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            icon: AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (c, anim) => ScaleTransition(scale: anim, child: c),
              child: Icon(
                bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                key: ValueKey(bookmarked),
                color: bookmarked ? theme.colorScheme.primary : null,
              ),
            ),
            onPressed: () => InsightsData.toggleBookmark(store, a.id),
          ),
        ],
        children: [
          // Header.
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            EmojiArt(emoji: a.emoji, color: color, size: 80),
            Gap.v20,
            PillChip(a.category.label, emoji: a.category.emoji, color: color),
            Gap.v12,
            Text(a.title, style: t.headlineMedium?.copyWith(height: 1.2)),
            Gap.v12,
            Row(children: [
              Icon(Icons.schedule_rounded, size: 16, color: muted),
              Gap.h4,
              Text('${a.minutes} min read', style: t.bodyMedium?.copyWith(color: muted)),
              AnimatedSwitcher(
                duration: Motion.medium,
                child: read
                    ? Padding(
                        key: const ValueKey('read'),
                        padding: const EdgeInsets.only(left: Space.md),
                        child: PillChip('Read', icon: Icons.check_rounded, color: BloomColors.success, dense: true),
                      )
                    : const SizedBox.shrink(key: ValueKey('unread')),
              ),
            ]),
            Gap.v8,
            Divider(color: BloomTokens.of(context).border, height: Space.xxl),
          ]),
          ArticleBody(a.body, accent: color),
          AnimatedSwitcher(
            duration: Motion.medium,
            child: read
                ? OutlinedButton.icon(
                    key: const ValueKey('read'),
                    onPressed: () => InsightsData.setRead(store, a.id, false),
                    icon: const Icon(Icons.check_circle_rounded, color: BloomColors.success),
                    label: const Text('Read · tap to undo'),
                  )
                : FilledButton.icon(
                    key: const ValueKey('unread'),
                    onPressed: () => InsightsData.setRead(store, a.id, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Mark as read'),
                  ),
          ),
          const Disclaimer(text: 'Educational content, not medical advice. See a clinician about your own health.'),
          if (related.isNotEmpty) ...[
            const SectionHeader('Keep reading'),
            for (final r in related) ArticleTile(article: r, replace: true),
          ],
        ],
      ),
    );
  }
}

/// List card for an article: cover emoji, category, title, read time, and
/// read and bookmark state.
class ArticleTile extends StatelessWidget {
  const ArticleTile({super.key, required this.article, this.replace = false});
  final Article article;

  /// Replaces the current route instead of pushing (used by "Related").
  final bool replace;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final read = InsightsData.isRead(store, article.id);
    final bookmarked = InsightsData.isBookmarked(store, article.id);
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final muted = BloomTokens.of(context).muted;
    final color = categoryColor(article.category);

    return BloomCard(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.xs, Space.md),
      onTap: () {
        final route = MaterialPageRoute<void>(builder: (_) => ArticleScreen(article: article));
        replace ? Navigator.of(context).pushReplacement(route) : Navigator.of(context).push(route);
      },
      child: Row(children: [
        EmojiArt(emoji: article.emoji, color: color, size: 64),
        Gap.h12,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              article.category.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.labelSmall?.copyWith(
                color: readableTint(color, theme.brightness),
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            Gap.v4,
            Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(height: 1.25)),
            Gap.v4,
            Row(children: [
              Icon(Icons.schedule_rounded, size: 14, color: muted),
              Gap.h4,
              Text('${article.minutes} min', style: t.bodySmall),
              if (read) ...[
                Gap.h8,
                const Icon(Icons.check_circle_rounded, size: 14, color: BloomColors.success),
                Gap.h4,
                Flexible(
                  child: Text('Read',
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: readableTint(BloomColors.success, theme.brightness))),
                ),
              ],
            ]),
          ]),
        ),
        IconButton(
          tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
          onPressed: () => InsightsData.toggleBookmark(store, article.id),
          icon: AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: (c, anim) => ScaleTransition(scale: anim, child: c),
            child: Icon(
              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              key: ValueKey(bookmarked),
              size: 22,
              color: bookmarked ? theme.colorScheme.primary : muted,
            ),
          ),
        ),
      ]),
    );
  }
}
