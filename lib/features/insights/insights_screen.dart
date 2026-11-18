/// The Library tab: a small literary magazine of essays, an index of
/// topics, saved essays, a puzzles page, and a private journal.
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
    final read = InsightsData.readIds(store).length;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MaxWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: double.infinity),
                      MonoLabel('${kArticles.length} essays · $read read'),
                      Gap.v8,
                      Text('Library', style: Theme.of(context).textTheme.headlineLarge),
                    ],
                  ),
                ),
              ),
              Gap.v8,
              const MaxWidth(
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.symmetric(horizontal: Space.gutter - Space.md),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'For you'),
                    Tab(text: 'Explore'),
                    Tab(text: 'Saved'),
                    Tab(text: 'Quizzes'),
                    Tab(text: 'Journal'),
                  ],
                ),
              ),
              const MaxWidth(
                child: Padding(padding: Insets.pageH, child: Hairline()),
              ),
              const Expanded(
                child: TabBarView(children: [_ForYouTab(), _ExploreTab(), _SavedTab(), _QuizzesTab(), JournalView()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Body padding for a tab: the page gutter, with room on top.
const _tabPadding = EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, Space.xxl);

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
        if (recs.isNotEmpty) _Lead(article: recs.first),
        SectionHeader(
          'Picked for you',
          label: 'Contents',
          subtitle: showPhase
              ? 'Chosen for your ${phase.label.toLowerCase()}'
              : 'Chosen for you: ${goal.label.toLowerCase()}',
          padding: const EdgeInsets.only(top: Space.xxl),
        ),
        ArticleList(articles: recs.skip(1).toList(), start: 2),
        if (quiz != null) ...[
          const SectionHeader(
            'A puzzle for today',
            label: 'Pastimes',
            padding: EdgeInsets.only(top: Space.xxl),
          ),
          Column(
            children: [
              const Hairline(),
              _QuizRow(quiz: quiz, number: kQuizzes.indexOf(quiz) + 1),
              const Hairline(),
            ],
          ),
        ],
        Gap.v8,
        const Footnote('Educational content, not medical advice. See a clinician about your own health.'),
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

/// The featured essay, set as an editorial lead: mono category and read
/// time, a large serif title, and an italic standfirst.
class _Lead extends StatelessWidget {
  const _Lead({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final a = article;
    final read = InsightsData.isRead(context.watch<AppStore>(), a.id);
    return Pressable(
      semanticLabel: 'Lead essay: ${a.title}',
      onTap: () => openArticle(context, a.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MonoLabel('The lead'),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  child: Hairline(color: p.ink2.withValues(alpha: 0.4)),
                ),
              ),
              MonoLabel('No. ${tocNumber(1)}'),
            ],
          ),
          Gap.v20,
          Text(a.title, style: Almanac.serif(size: 32, weight: 340, color: p.ink, height: 1.1)),
          Gap.v12,
          Text(
            shortStandfirst(a, max: 170),
            style: Almanac.italic(context, size: 18, color: p.ink2).copyWith(height: 1.4),
          ),
          Gap.v16,
          MonoLabel('${a.category.label} · ${a.minutes} min read${read ? ' · Read' : ''}'),
          Gap.v8,
          InkLink(
            read ? 'Read again' : 'Begin reading',
            arrow: true,
            size: 14,
            onTap: () => openArticle(context, a.id),
          ),
        ],
      ),
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
    final p = BloomColors.of(context);
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
          style: Almanac.serif(size: 19, weight: 350, color: p.ink),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search, size: 20, color: p.ink2),
            prefixIconConstraints: const BoxConstraints(minWidth: 32),
            hintText: 'Search the library',
            hintStyle: Almanac.italic(context, size: 19, color: p.ink2),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: Icon(Icons.close, size: 18, color: p.ink2),
                    onPressed: _clear,
                  ),
          ),
        ),
        AnimatedSwitcher(
          duration: Motion.medium,
          switchInCurve: Motion.curve,
          child: searching
              ? _SearchResults(key: const ValueKey('results'), query: _query, results: results, onClear: _clear)
              : const _CategoryIndex(key: ValueKey('index')),
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
        glyph: Botanical.seedHead,
        title: 'Nothing on that page',
        body: 'No essay mentions "${query.trim()}". Try a simpler word, such as cramps or sleep.',
        actionLabel: 'Clear search',
        onAction: onClear,
        compact: true,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap.v8,
        MonoLabel('${results.length} essay${results.length == 1 ? '' : 's'} for “${query.trim()}”'),
        Gap.v12,
        ArticleList(articles: results),
      ],
    );
  }
}

/// The topics as a back-of-book index: alphabetical, with the initial in
/// the margin, a dotted leader, and the essay count.
class _CategoryIndex extends StatelessWidget {
  const _CategoryIndex({super.key});

  @override
  Widget build(BuildContext context) {
    final cats = [...ArticleCategory.values]..sort((a, b) => a.label.compareTo(b.label));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          'Index of topics',
          label: 'A to Z',
          padding: EdgeInsets.only(top: Space.lg, bottom: Space.md),
        ),
        LayoutBuilder(
          builder: (context, box) {
            final rows = [
              for (var i = 0; i < cats.length; i++)
                _IndexRow(category: cats[i], showInitial: i == 0 || cats[i - 1].label[0] != cats[i].label[0]),
            ];
            if (box.maxWidth < 520) {
              return Column(children: [const Hairline(), ...rows, const Hairline()]);
            }
            final half = (rows.length / 2).ceil();
            return Column(
              children: [
                const Hairline(),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: rows.sublist(0, half))),
                      const Hairline(vertical: true, spacing: Space.lg),
                      Expanded(child: Column(children: rows.sublist(half))),
                    ],
                  ),
                ),
                const Hairline(),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _IndexRow extends StatelessWidget {
  const _IndexRow({required this.category, required this.showInitial});
  final ArticleCategory category;
  final bool showInitial;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final n = articlesIn(category).length;
    return Pressable(
      semanticLabel: '${category.label}, $n essays',
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _CategoryScreen(category: category))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                child: showInitial
                    ? Text(category.label[0], style: Almanac.italic(context, size: 22, color: p.ink2))
                    : null,
              ),
              // The leader runs the full width behind the entry and the count,
              // which sit on paper, as in a printed index.
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    const SizedBox(width: double.infinity),
                    const Positioned.fill(child: _DottedLeader()),
                    Padding(
                      padding: const EdgeInsets.only(right: 40),
                      child: ColoredBox(
                        color: p.paper,
                        child: Padding(
                          padding: const EdgeInsets.only(right: Space.sm),
                          child: Text(
                            category.label,
                            style: Almanac.serif(size: 18, weight: 360, color: p.ink, height: 1.2),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: ColoredBox(
                        color: p.paper,
                        child: Padding(
                          padding: const EdgeInsets.only(left: Space.sm),
                          child: Text(n.toString(), style: Almanac.data(context)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dotted leader line, as between an index entry and its page number.
class _DottedLeader extends StatelessWidget {
  const _DottedLeader();

  @override
  Widget build(BuildContext context) {
    final c = BloomColors.of(context).ink2.withValues(alpha: 0.45);
    return Align(
      alignment: const Alignment(0, 0.45),
      child: SizedBox(
        height: 2,
        width: double.infinity,
        child: CustomPaint(painter: _DotsPainter(c)),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = size.width - 1.0; x > 0; x -= 5) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

class _CategoryScreen extends StatelessWidget {
  const _CategoryScreen({required this.category});
  final ArticleCategory category;

  @override
  Widget build(BuildContext context) {
    final articles = articlesIn(category);
    final minutes = articles.fold<int>(0, (a, x) => a + x.minutes);
    return Scaffold(
      body: BloomPage(
        eyebrow: 'Index · ${articles.length} essays · $minutes min',
        title: category.label,
        children: [ArticleList(articles: articles)],
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
      children: [
        if (saved.isEmpty)
          EmptyState(
            glyph: Botanical.sprig,
            title: 'Nothing saved yet',
            body: 'Tap the bookmark beside any essay to keep it here, like a ribbon in a book.',
            actionLabel: 'Browse the index',
            onAction: () => DefaultTabController.of(context).animateTo(1),
          )
        else ...[
          MonoLabel('${saved.length} saved essay${saved.length == 1 ? '' : 's'}'),
          ArticleList(articles: saved),
        ],
      ],
    );
  }
}

class _QuizzesTab extends StatelessWidget {
  const _QuizzesTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final couples = kQuizzes.where((q) => q.couples).toList();
    final solo = kQuizzes.where((q) => !q.couples).toList();
    final done = kQuizzes.where((q) => InsightsData.quizResult(store, q.id) != null).length;
    final p = BloomColors.of(context);
    return BloomPage(
      showBack: false,
      padding: _tabPadding,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Puzzles & pastimes. ', style: Almanac.italic(context, size: 20)),
              TextSpan(
                text: 'Short, playful checks of what you know. $done of ${kQuizzes.length} played.',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.ink2),
              ),
            ],
          ),
        ),
        if (couples.isNotEmpty) ...[
          const SectionHeader(
            'Play together',
            label: 'For two',
            padding: EdgeInsets.only(top: Space.xl),
          ),
          _QuizList(quizzes: couples),
        ],
        const SectionHeader(
          'Solo puzzles',
          label: 'For one',
          padding: EdgeInsets.only(top: Space.xl),
        ),
        _QuizList(quizzes: solo),
      ],
    );
  }
}

class _QuizList extends StatelessWidget {
  const _QuizList({required this.quizzes});
  final List<Quiz> quizzes;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < quizzes.length; i++) ...[
        const Hairline(),
        _QuizRow(quiz: quizzes[i], number: kQuizzes.indexOf(quizzes[i]) + 1),
      ],
      const Hairline(),
    ],
  );
}

/// One puzzle: "No. 3" in mono, the serif title, a muted description, and
/// mono metadata with the last score.
class _QuizRow extends StatelessWidget {
  const _QuizRow({required this.quiz, required this.number});
  final Quiz quiz;
  final int number;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = BloomColors.of(context);
    final t = Theme.of(context).textTheme;
    final r = InsightsData.quizResult(store, quiz.id);
    final q = quiz;
    final meta = [
      q.couples ? 'Pass the phone' : null,
      '${q.questions.length} questions',
      if (r != null) 'Last ${r['score']}/${r['total']}${q.couples ? ' matches' : ''}',
    ].whereType<String>().join(' · ');

    return Pressable(
      semanticLabel: '${q.title}. $meta',
      onTap: () => openQuiz(context, q.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('No. $number', style: Almanac.data(context, size: 11.5)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.title, style: Almanac.serif(size: 19, weight: 380, color: p.ink, height: 1.25)),
                  Gap.v4,
                  Text(q.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                  Gap.v8,
                  MonoLabel(meta, size: 10, maxLines: 1),
                ],
              ),
            ),
            Gap.h12,
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: r == null ? 'Play' : 'Again',
                      style: Almanac.sans(
                        size: 13.5,
                        weight: FontWeight.w500,
                        color: p.ink,
                      ).copyWith(decoration: TextDecoration.underline, decorationColor: p.ink.withValues(alpha: 0.5)),
                    ),
                    TextSpan(
                      text: ' →',
                      style: Almanac.sans(size: 13.5, weight: FontWeight.w500, color: p.ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
