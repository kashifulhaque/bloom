/// Insights tab: recommended reading, library, bookmarks, quizzes, journal.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/engine.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'article_screen.dart';
import 'content.dart';
import 'insight_rules.dart';
import 'insights_data.dart';
import 'journal.dart';
import 'quiz_screen.dart';
import 'widgets.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final read = InsightsData.readIds(store).length;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(width: double.infinity),
                  Text(
                    'LIBRARY · $read OF ${kArticles.length} READ',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Gap.v4,
                  Text('Insights', style: theme.textTheme.headlineLarge),
                ]),
              ),
            ),
            Gap.v8,
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'For you'),
                    Tab(text: 'Explore'),
                    Tab(text: 'Saved'),
                    Tab(text: 'Quizzes'),
                    Tab(text: 'Journal'),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: BloomTokens.of(context).border),
            const Expanded(
              child: TabBarView(children: [
                _ForYouTab(),
                _ExploreTab(),
                _SavedTab(),
                _QuizzesTab(),
                JournalView(),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Body padding for a tab: the page gutter, with a little room on top.
const _tabPadding = EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xxl);

class _ForYouTab extends StatelessWidget {
  const _ForYouTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final phase = store.engine.info(store.engine.today).phase;
    final recs = recommendedArticles(store, limit: 8);
    final goal = store.profile.goal;
    final showPhase = phase != null && goal != Goal.trackPregnancy && goal != Goal.postpartum;
    final quiz = _suggestedQuiz(store);

    return BloomPage(
      showBack: false,
      padding: _tabPadding,
      children: [
        if (recs.isNotEmpty) _FeaturedCard(article: recs.first),
        SectionHeader(
          'Picked for you',
          subtitle: showPhase ? 'Based on ${goal.label.toLowerCase()} · ${phase.label.toLowerCase()}' : 'Based on ${goal.label.toLowerCase()}',
        ),
        for (final a in recs.skip(1)) ArticleTile(article: a),
        if (quiz != null) ...[
          const SectionHeader('Test yourself'),
          _QuizCard(quiz: quiz, color: _quizColor(kQuizzes.indexOf(quiz))),
        ],
        const Disclaimer(text: 'Educational content, not medical advice. See a clinician about your own health.'),
      ],
    );
  }

  /// The first quiz the user hasn't taken, or null when all are done.
  static Quiz? _suggestedQuiz(AppStore store) {
    for (final q in kQuizzes) {
      if (!q.couples && InsightsData.quizResult(store, q.id) == null) return q;
    }
    return null;
  }
}

/// The one gradient hero on the "For you" tab.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const white = Colors.white;
    return BloomCard.gradient(
      gradient: categoryGradient(article.category),
      padding: EdgeInsets.zero,
      onTap: () => openArticle(context, article.id),
      child: Stack(children: [
        // Decorative emoji art in the top-right corner.
        Positioned(
          right: -28,
          top: -28,
          child: Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: 0.12)),
          ),
        ),
        Positioned(
          right: 36,
          top: 96,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: 0.10)),
          ),
        ),
        Positioned(
          right: Space.xxl,
          top: Space.xxl,
          child: Text(article.emoji, style: const TextStyle(fontSize: 64, height: 1)),
        ),
        Padding(
          padding: Insets.all24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PillChip('Featured read', icon: Icons.auto_awesome_rounded, color: white, solid: true, dense: true),
            const SizedBox(height: 72),
            Text(
              article.category.label.toUpperCase(),
              style: t.labelMedium?.copyWith(color: white.withValues(alpha: 0.85), letterSpacing: 1.1),
            ),
            Gap.v4,
            Text(article.title, style: t.headlineSmall?.copyWith(color: white, height: 1.2)),
            Gap.v16,
            Row(children: [
              Icon(Icons.schedule_rounded, size: 16, color: white.withValues(alpha: 0.85)),
              Gap.h4,
              Expanded(
                child: Text('${article.minutes} min read',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(color: white.withValues(alpha: 0.9))),
              ),
              Gap.h8,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                decoration: BoxDecoration(color: white, borderRadius: Radii.pillAll),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Read now',
                      style: t.labelLarge?.copyWith(color: categoryGradient(article.category).colors.first)),
                  Gap.h4,
                  Icon(Icons.arrow_forward_rounded, size: 18, color: categoryGradient(article.category).colors.first),
                ]),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ExploreTab extends StatefulWidget {
  const _ExploreTab();

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _ctrl.clear();
        _query = '';
      });

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final results = searchArticles(_query);
    return BloomPage(
      showBack: false,
      padding: _tabPadding,
      children: [
        TextField(
          controller: _ctrl,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Search cramps, PCOS, sleep...',
            border: const OutlineInputBorder(borderRadius: Radii.pillAll),
            enabledBorder: OutlineInputBorder(
              borderRadius: Radii.pillAll,
              borderSide: BorderSide(color: BloomTokens.of(context).border),
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: _clear),
          ),
        ),
        AnimatedSwitcher(
          duration: Motion.medium,
          switchInCurve: Motion.curve,
          child: searching
              ? _SearchResults(key: const ValueKey('results'), query: _query, results: results, onClear: _clear)
              : const _CategoryGrid(key: ValueKey('grid')),
        ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({super.key, required this.query, required this.results, required this.onClear});
  final String query;
  final List<Article> results;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return EmptyState(
        emoji: '🤔',
        title: 'No matches',
        body: 'Nothing matches "${query.trim()}". Try a simpler word, such as cramps or sleep.',
        actionLabel: 'Clear search',
        onAction: onClear,
        compact: true,
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${results.length} result${results.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.labelLarge),
      Gap.v12,
      for (final a in results) ...[ArticleTile(article: a), Gap.v12],
    ]);
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Browse topics', padding: EdgeInsets.only(bottom: Space.md)),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 480 ? 3 : 2;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: Space.md,
            crossAxisSpacing: Space.md,
            mainAxisExtent: 136,
          ),
          children: [
            for (final cat in ArticleCategory.values)
              BloomCard.tinted(
                color: categoryColor(cat),
                padding: Insets.cardCompact,
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => _CategoryScreen(category: cat))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconBadge(emoji: cat.emoji, color: categoryColor(cat), size: 44),
                  const Spacer(),
                  Text(cat.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(height: 1.2)),
                  Gap.v4,
                  Text('${articlesIn(cat).length} articles', style: t.bodySmall),
                ]),
              ),
          ],
        );
      }),
    ]);
  }
}

class _CategoryScreen extends StatelessWidget {
  const _CategoryScreen({required this.category});
  final ArticleCategory category;

  @override
  Widget build(BuildContext context) {
    final articles = articlesIn(category);
    return Scaffold(
      body: BloomPage(
        heroColor: categoryColor(category),
        eyebrow: '${category.emoji}  TOPIC',
        title: category.label,
        subtitle: '${articles.length} articles · about ${articles.fold<int>(0, (a, x) => a + x.minutes)} min in all',
        spacing: Space.md,
        children: [for (final a in articles) ArticleTile(article: a)],
      ),
    );
  }
}

class _SavedTab extends StatelessWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final ids = InsightsData.bookmarks(store);
    final saved = kArticles.where((a) => ids.contains(a.id)).toList();
    return BloomPage(
      showBack: false,
      padding: _tabPadding,
      spacing: Space.md,
      children: [
        if (saved.isEmpty)
          EmptyState(
            emoji: '📚',
            title: 'Nothing saved yet',
            body: 'Tap the bookmark icon on any article to keep it here for later.',
            actionLabel: 'Browse articles',
            onAction: () => DefaultTabController.of(context).animateTo(1),
          )
        else ...[
          Text('${saved.length} saved article${saved.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelLarge),
          for (final a in saved) ArticleTile(article: a),
        ],
      ],
    );
  }
}

/// Accent color for a quiz card, cycling through a soft palette.
Color _quizColor(int i) => const [
      BloomColors.luteal,
      BloomColors.fertile,
      BloomColors.follicular,
      BloomColors.info,
      BloomColors.brand,
      BloomColors.pregnancy,
    ][i % 6];

class _QuizzesTab extends StatelessWidget {
  const _QuizzesTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final couples = kQuizzes.where((q) => q.couples).toList();
    final solo = kQuizzes.where((q) => !q.couples).toList();
    final done = kQuizzes.where((q) => InsightsData.quizResult(store, q.id) != null).length;
    return BloomPage(
      showBack: false,
      padding: _tabPadding,
      spacing: Space.md,
      children: [
        Row(children: [
          Expanded(
            child: Text('Quick, playful checks of what you know. $done of ${kQuizzes.length} played.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BloomTokens.of(context).muted)),
          ),
        ]),
        if (couples.isNotEmpty) ...[
          const SectionHeader('Play together'),
          for (final q in couples) _QuizCard(quiz: q, color: BloomColors.coral),
        ],
        const SectionHeader('Solo quizzes'),
        for (var i = 0; i < solo.length; i++) _QuizCard(quiz: solo[i], color: _quizColor(i)),
      ],
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.quiz, required this.color});
  final Quiz quiz;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final r = InsightsData.quizResult(store, quiz.id);
    final q = quiz;
    final perfect = r != null && r['score'] == r['total'];

    return BloomCard.tinted(
      color: color,
      padding: Insets.cardCompact,
      onTap: () => openQuiz(context, q.id),
      child: Row(children: [
        IconBadge(emoji: q.emoji, color: color, size: 56),
        Gap.h16,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.title, style: t.titleMedium),
            Gap.v4,
            Text(q.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
            Gap.v8,
            Wrap(spacing: Space.xs + 2, runSpacing: Space.xs + 2, children: [
              PillChip(
                q.couples ? 'Pass the phone · ${q.questions.length} questions' : '${q.questions.length} questions',
                color: color,
                dense: true,
              ),
              if (r != null)
                PillChip(
                  'Last: ${r['score']}/${r['total']}${q.couples ? ' matches' : ''}',
                  icon: perfect ? Icons.emoji_events_rounded : Icons.star_rounded,
                  color: perfect ? BloomColors.pregnancy : BloomColors.success,
                  dense: true,
                ),
            ]),
          ]),
        ),
        Gap.h8,
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: readableTint(color, Brightness.light),
            shape: BoxShape.circle,
            boxShadow: BloomShadows.glow(color),
          ),
          child: Icon(r == null ? Icons.play_arrow_rounded : Icons.replay_rounded, color: Colors.white, size: 22),
        ),
      ]),
    );
  }
}
