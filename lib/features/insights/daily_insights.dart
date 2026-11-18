/// Today-screen "almanac entries", the full-page story viewer, and the
/// well-being breakdown screen.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'article_screen.dart';
import 'insight_rules.dart';
import 'insights_data.dart';
import 'quiz_screen.dart';
import 'widgets.dart';

String _kindLabel(InsightKind k) => switch (k) {
      InsightKind.wellbeing => 'Well-being',
      InsightKind.period => 'Your period',
      InsightKind.fertile => 'Fertility',
      InsightKind.pattern => 'Pattern',
      InsightKind.cycle => 'Your cycle',
      InsightKind.habit => 'Habit',
      InsightKind.tip => 'Daily note',
      InsightKind.quiz => 'Puzzle',
      InsightKind.article => 'Essay',
    };

/// The drawing for an entry. Only cycle meanings get a color.
BotanicalGlyph _glyph(InsightKind k, {double size = 22}) => switch (k) {
      InsightKind.period => BotanicalGlyph(Botanical.bud, size: size, accent: BloomColors.period),
      InsightKind.fertile => BotanicalGlyph(Botanical.flower, size: size, accent: BloomColors.fertile),
      InsightKind.pattern => BotanicalGlyph(Botanical.seedHead, size: size),
      InsightKind.cycle => BotanicalGlyph(Botanical.sprout, size: size),
      InsightKind.tip => BotanicalGlyph(Botanical.sprout, size: size),
      _ => BotanicalGlyph(Botanical.sprig, size: size),
    };

/// The title without a prefix that repeats the entry's label.
String _oneLiner(InsightCard c) {
  for (final prefix in const ['Read: ', 'Quiz of the day: ']) {
    if (c.title.startsWith(prefix)) return c.title.substring(prefix.length);
  }
  return c.title;
}

/// A horizontal row of small almanac entries: a mono label, a serif
/// one-liner, and a botanical drawing, divided by hairlines. Unseen entries
/// carry a small ink dot; seen ones fade back.
class DailyInsightsStrip extends StatelessWidget {
  const DailyInsightsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cards = buildInsights(store);
    final seen = InsightsData.seenToday(store);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Hairline(),
      SizedBox(
        height: 164,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: cards.length,
          separatorBuilder: (_, _) => const Hairline(vertical: true, spacing: Space.md, indent: Space.lg, endIndent: Space.lg),
          itemBuilder: (context, i) {
            final c = cards[i];
            return _Entry(
              card: c,
              seen: seen.contains(c.id),
              onTap: () {
                if (c.kind == InsightKind.wellbeing) {
                  InsightsData.markSeen(store, c.id);
                  openWellbeing(context);
                } else {
                  openStories(context, cards, i);
                }
              },
            );
          },
        ),
      ),
      const Hairline(),
    ]);
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.card, required this.seen, required this.onTap});
  final InsightCard card;
  final bool seen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final c = card;
    final wb = c.wellbeing;

    return Pressable(
      semanticLabel: '${_kindLabel(c.kind)}: ${_oneLiner(c)}${seen ? ', seen' : ', new'}',
      onTap: onTap,
      child: AnimatedOpacity(
        duration: Motion.medium,
        opacity: seen ? 0.62 : 1,
        child: SizedBox(
          width: 132,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: MonoLabel(_kindLabel(c.kind), size: 9.5, maxLines: 1)),
                if (!seen) ...[
                  Gap.h4,
                  Container(width: 5, height: 5, decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle)),
                ],
              ]),
              Gap.v8,
              if (wb != null) ...[
                Text('${wb.score}', style: Almanac.numeral(context, size: 44)),
                Gap.v4,
                Text('Well-being, ${wb.label.toLowerCase()}.',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: Almanac.italic(context, size: 15)),
              ] else
                Text(
                  _oneLiner(c),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Almanac.serif(size: 16, weight: 360, color: p.ink, height: 1.28),
                ),
              const Spacer(),
              if (wb == null) _glyph(c.kind, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

void openStories(BuildContext context, List<InsightCard> cards, int start) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: Motion.medium,
    reverseTransitionDuration: Motion.medium,
    pageBuilder: (_, _, _) => StoryViewer(cards: cards, start: start),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Motion.curve), child: child),
  ));
}

void openWellbeing(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WellbeingScreen()));
}

/// Full-page stories on paper: tap right to turn the page, left to go
/// back. Pages turn on their own after a few seconds.
class StoryViewer extends StatefulWidget {
  const StoryViewer({super.key, required this.cards, this.start = 0});
  final List<InsightCard> cards;
  final int start;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int _index = widget.start;
  late final AnimationController _timer = AnimationController(vsync: this, duration: const Duration(seconds: 8))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  void _show() {
    _timer.forward(from: 0);
    final id = widget.cards[_index].id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) InsightsData.markSeen(context.read<AppStore>(), id);
    });
  }

  void _next() {
    if (_index + 1 >= widget.cards.length) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index++);
    _show();
  }

  void _prev() {
    if (_index == 0) {
      _timer.forward(from: 0);
      return;
    }
    setState(() => _index--);
    _show();
  }

  Future<void> _openLink(Future<void> Function() open) async {
    _timer.stop();
    await open();
    if (mounted) _timer.forward();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cards[_index];
    final p = BloomColors.of(context);

    String? actionLabel;
    VoidCallback? onAction;
    if (c.wellbeing != null) {
      actionLabel = 'See the breakdown';
      onAction = () => _openLink(
          () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WellbeingScreen())));
    } else if (c.quizId != null) {
      actionLabel = 'Take the puzzle';
      onAction = () => _openLink(() async => openQuiz(context, c.quizId!));
    } else if (c.articleId != null) {
      actionLabel = 'Read the essay';
      onAction = () => _openLink(() async => openArticle(context, c.articleId!));
    }

    return Scaffold(
      body: Stack(children: [
        // Tap zones.
        Positioned.fill(
          child: Row(children: [
            Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _prev)),
            Expanded(flex: 2, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _next)),
          ]),
        ),
        SafeArea(
          child: MaxWidth(
            width: 560,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                child: AnimatedBuilder(
                  animation: _timer,
                  builder: (_, _) => Row(children: [
                    for (var i = 0; i < widget.cards.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: RuleProgress(value: i < _index ? 1 : i == _index ? _timer.value : 0, animate: false),
                        ),
                      ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.sm, 0),
                child: Row(children: [
                  Expanded(
                    child: MonoLabel('${_kindLabel(c.kind)} · ${_index + 1} of ${widget.cards.length}', maxLines: 1),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close, color: p.ink2, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter + 4, 0, Space.gutter + 4, Space.lg),
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    switchInCurve: Motion.curve,
                    transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                    child: Column(
                      key: ValueKey(_index),
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IgnorePointer(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (c.wellbeing != null)
                              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('${c.wellbeing!.score}', style: Almanac.numeral(context, size: 96)),
                                Padding(
                                  padding: const EdgeInsets.only(left: Space.sm, bottom: Space.md),
                                  child: Text('of 100', style: Almanac.italic(context, size: 20, color: p.ink2)),
                                ),
                              ])
                            else
                              _glyph(c.kind, size: 48),
                            Gap.v24,
                            Text(c.title, style: Almanac.serif(size: 34, weight: 350, color: p.ink, height: 1.12)),
                            Gap.v20,
                            Container(width: 40, height: 1, color: p.ink2.withValues(alpha: 0.5)),
                            Gap.v20,
                            Text(c.body, style: Almanac.serif(size: 20, weight: 320, color: p.ink, height: 1.5)),
                          ]),
                        ),
                        if (actionLabel != null) ...[
                          Gap.v24,
                          InkLink(actionLabel, arrow: true, size: 15.5, onTap: onAction),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.lg),
                  child: MonoLabel('Educational, not medical advice', size: 9.5, textAlign: TextAlign.center),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Breakdown of the well-being score by factor: a serif score numeral and
/// thin factor bars.
class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wb = computeWellbeing(store);
    final p = BloomColors.of(context);
    final logged = wb.factors.where((f) => f.hasData).length;

    return Scaffold(
      body: BloomPage(
        eyebrow: 'Today · Well-being',
        header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: wb.score.toDouble()),
              duration: Motion.slow,
              curve: Motion.curve,
              builder: (_, v, _) => Text('${v.round()}', style: Almanac.numeral(context, size: 96)),
            ),
            Gap.h8,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const MonoLabel('of 100'),
                  Gap.v4,
                  Text('${wb.label}.', style: Almanac.italic(context, size: 24)),
                ]),
              ),
            ),
          ]),
          Gap.v8,
          Text('Well-being score', style: Almanac.serif(size: 20, weight: 380, color: p.ink)),
        ]),
        children: [
          Text(
            'A rough daily estimate of your energy from what you logged in the last few days. '
            'Log sleep, energy, mood, symptoms, activity, and water to make it more personal.',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.ink2),
          ),
          SectionHeader('What goes into it', label: 'Ledger', subtitle: '$logged of ${wb.factors.length} factors have recent logs'),
          Column(children: [
            for (final f in wb.factors) ...[const Hairline(), _FactorRow(factor: f)],
            const Hairline(),
          ]),
          const Footnote('This score is for reflection, not a medical measure.'),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});
  final WellbeingFactor factor;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final f = factor;
    final ratio = f.max == 0 ? 0.0 : f.points / f.max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md + 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text(f.name, style: Almanac.serif(size: 18, weight: 380, color: p.ink))),
          if (!f.hasData) ...[const MonoLabel('No data', size: 9.5), Gap.h12],
          Text.rich(TextSpan(children: [
            TextSpan(text: '${f.points}', style: Almanac.data(context, color: p.ink, size: 13)),
            TextSpan(text: ' / ${f.max}', style: Almanac.data(context, size: 13)),
          ])),
        ]),
        Gap.v8,
        Opacity(opacity: f.hasData ? 1 : 0.5, child: RuleProgress(value: ratio)),
        Gap.v8,
        Text(f.note, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
