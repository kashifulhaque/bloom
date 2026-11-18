/// Article reader with bookmark, mark-as-read, and related articles, set
/// like a page from a small book.
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

/// The reading measure: about 66 characters of 17-px text.
const double _measure = 560;

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final a = article;
    final p = BloomColors.of(context);
    final bookmarked = InsightsData.isBookmarked(store, a.id);
    final read = InsightsData.isRead(store, a.id);
    final related = relatedArticles(a);
    final split = splitStandfirst(a.body);
    final number = kArticles.indexOf(a) + 1;

    Widget measure(Widget child) => Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _measure), child: child),
        );

    return Scaffold(
      body: BloomPage(
        eyebrow: 'Essay ${tocNumber(number)} · ${a.category.label}',
        header: measure(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.title, style: Almanac.serif(size: 34, weight: 350, color: p.ink, height: 1.1)),
          if (split.standfirst.isNotEmpty) ...[
            Gap.v16,
            Text(split.standfirst, style: Almanac.italic(context, size: 20, color: p.ink2).copyWith(height: 1.4)),
          ],
        ])),
        children: [
          measure(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Hairline(),
            Gap.v12,
            Marginalia(label: 'Filed', labelWidth: 72, child: Text(a.category.label)),
            Gap.v4,
            Marginalia(label: 'Reading', labelWidth: 72, child: Text('${a.minutes} min, about ${_words(a.body)} words')),
            Gap.v4,
            Marginalia(
              label: 'Status',
              labelWidth: 72,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                    child: Text(
                      [read ? 'Read' : 'Unread', if (bookmarked) 'saved'].join(', '),
                      key: ValueKey('$read$bookmarked'),
                      style: Almanac.italic(context, size: 15.5),
                    ),
                  ),
                ),
                // Lifted so its text sits on the same line as the status.
                Transform.translate(
                  offset: const Offset(0, -9),
                  child: InkLink(
                    bookmarked ? 'Saved' : 'Save',
                    icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 13.5,
                    onTap: () => InsightsData.toggleBookmark(store, a.id),
                  ),
                ),
              ]),
            ),
            Gap.v4,
            const Hairline(),
          ])),
          Gap.v8,
          measure(ArticleBody(split.rest, dropCap: true)),
          measure(Row(children: [
            AnimatedSwitcher(
              duration: Motion.medium,
              child: read
                  ? InkButton.outlined(
                      key: const ValueKey('read'),
                      label: 'Read · tap to undo',
                      icon: Icons.check,
                      dense: true,
                      onPressed: () => InsightsData.setRead(store, a.id, false),
                    )
                  : InkButton(
                      key: const ValueKey('unread'),
                      label: 'Mark as read',
                      icon: Icons.check,
                      dense: true,
                      onPressed: () {
                        Almanac.tick();
                        InsightsData.setRead(store, a.id, true);
                      },
                    ),
            ),
          ])),
          Gap.v8,
          measure(const Footnote('Educational content, not medical advice. See a clinician about your own health.')),
          if (related.isNotEmpty) ...[
            const SectionHeader('Further reading', label: 'See also', padding: EdgeInsets.only(top: Space.xxl)),
            ArticleList(articles: related, replace: true),
          ],
        ],
      ),
    );
  }

  static int _words(String s) => (s.split(RegExp(r'\s+')).length / 10).round() * 10;
}

/// A numbered table of contents: [ArticleTile] rows between hairlines.
class ArticleList extends StatelessWidget {
  const ArticleList({super.key, required this.articles, this.replace = false, this.start = 1, this.numbered = true});
  final List<Article> articles;

  /// Replaces the current route instead of pushing (used by "Further reading").
  final bool replace;

  /// The number of the first row.
  final int start;

  final bool numbered;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < articles.length; i++) ...[
        const Hairline(),
        ArticleTile(article: articles[i], replace: replace, number: numbered ? start + i : null),
      ],
      const Hairline(),
    ]);
  }
}

/// One table-of-contents row: a mono number, the serif title, the category
/// and read time in mono, read state, and a bookmark.
class ArticleTile extends StatelessWidget {
  const ArticleTile({super.key, required this.article, this.replace = false, this.number});
  final Article article;

  /// Replaces the current route instead of pushing (used by "Related").
  final bool replace;

  /// The row number shown in the margin, or null for none.
  final int? number;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final read = InsightsData.isRead(store, article.id);
    final bookmarked = InsightsData.isBookmarked(store, article.id);
    final p = BloomColors.of(context);
    final dot = categoryColor(article.category);

    return Pressable(
      semanticLabel: '${article.title}, ${article.category.label}, ${article.minutes} minute read${read ? ', read' : ''}',
      onTap: () {
        final route = MaterialPageRoute<void>(builder: (_) => ArticleScreen(article: article));
        replace ? Navigator.of(context).pushReplacement(route) : Navigator.of(context).push(route);
      },
      child: Padding(
        padding: const EdgeInsets.only(top: Space.md + 2, bottom: Space.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (number != null)
            SizedBox(
              width: 36,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(tocNumber(number!), style: Almanac.data(context, size: 12)),
              ),
            ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Almanac.serif(size: 18.5, weight: 380, color: read ? p.ink2 : p.ink, height: 1.25),
              ),
              Gap.v8,
              Row(children: [
                if (dot != BloomColors.ink2) ...[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: BloomColors.resolve(context, dot), shape: BoxShape.circle),
                  ),
                  Gap.h8,
                ],
                Flexible(child: MonoLabel('${article.category.label} · ${article.minutes} min', maxLines: 1, size: 10)),
                if (read) ...[
                  Gap.h8,
                  Icon(Icons.check, size: 12, color: p.ink2),
                  Gap.h4,
                  const MonoLabel('Read', size: 10),
                ],
              ]),
            ]),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
              padding: EdgeInsets.zero,
              onPressed: () => InsightsData.toggleBookmark(store, article.id),
              icon: AnimatedSwitcher(
                duration: Motion.medium,
                child: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey(bookmarked),
                  size: 19,
                  color: bookmarked ? p.ink : p.ink2,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
