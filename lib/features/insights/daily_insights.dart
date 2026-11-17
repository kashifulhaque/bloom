/// Today-screen "stories" carousel, the full-screen story viewer, and the
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

/// The background gradient of a story. Every stop is dark enough for white
/// text, and a scrim adds more contrast where the text sits.
LinearGradient _kindGradient(InsightKind k) => switch (k) {
      InsightKind.wellbeing => const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD9822B), Color(0xFFF2B347)]),
      InsightKind.period => BloomGradients.period,
      InsightKind.fertile => BloomGradients.fertile,
      InsightKind.pattern => BloomGradients.luteal,
      InsightKind.cycle => const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4767D6), Color(0xFF7E9CF0)]),
      InsightKind.habit => const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1F8FA3), Color(0xFF4FC0CF)]),
      InsightKind.tip => BloomGradients.brand,
      InsightKind.quiz => BloomGradients.dusk,
      InsightKind.article => const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2F8257), Color(0xFF5DB585)]),
    };

String _kindLabel(InsightKind k) => switch (k) {
      InsightKind.wellbeing => 'Well-being',
      InsightKind.period => 'Your period',
      InsightKind.fertile => 'Fertility',
      InsightKind.pattern => 'Pattern',
      InsightKind.cycle => 'Your cycle',
      InsightKind.habit => 'Habit',
      InsightKind.tip => 'Daily tip',
      InsightKind.quiz => 'Quiz',
      InsightKind.article => 'Read',
    };

/// Horizontal carousel of personalized story cards. Unseen stories get a
/// gradient ring, like a story app; seen ones fade back.
class DailyInsightsStrip extends StatelessWidget {
  const DailyInsightsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cards = buildInsights(store);
    final seen = InsightsData.seenToday(store);

    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: cards.length,
        separatorBuilder: (_, _) => Gap.h12,
        itemBuilder: (context, i) {
          final c = cards[i];
          return _StoryTile(
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
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.card, required this.seen, required this.onTap});
  final InsightCard card;
  final bool seen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final c = card;
    const white = Colors.white;
    final ringGap = theme.scaffoldBackgroundColor;

    return Semantics(
      button: true,
      label: '${_kindLabel(c.kind)}${seen ? ', seen' : ', new'}',
      child: AnimatedContainer(
        duration: Motion.medium,
        width: 128,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md + 5),
          gradient: seen ? null : BloomGradients.brand,
          color: seen ? BloomTokens.of(context).border : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: ringGap, borderRadius: BorderRadius.circular(Radii.md + 2)),
          child: AnimatedOpacity(
            duration: Motion.medium,
            opacity: seen ? 0.72 : 1,
            child: ClipRRect(
              borderRadius: Radii.mdAll,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: _kindGradient(c.kind)),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    child: Stack(children: [
                      // Scrim behind the title.
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.35, 1],
                              colors: [Color(0x00000000), Color(0x59000000)],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: Insets.all12,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (c.wellbeing != null)
                            ProgressRing(
                              value: c.wellbeing!.score / 100,
                              size: 48,
                              stroke: 5,
                              color: white,
                              trackColor: ringTrackOn(_kindGradient(c.kind)),
                              child: Text('${c.wellbeing!.score}',
                                  style: t.labelLarge?.copyWith(color: white, fontWeight: FontWeight.w800)),
                            )
                          else
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: white.withValues(alpha: 0.2), shape: BoxShape.circle),
                              child: Text(c.emoji, style: const TextStyle(fontSize: 26, height: 1)),
                            ),
                          const Spacer(),
                          // Skip the label when the title already starts with it.
                          if (!c.title.toLowerCase().startsWith(_kindLabel(c.kind).toLowerCase())) ...[
                            Text(
                              _kindLabel(c.kind).toUpperCase(),
                              style: t.labelSmall?.copyWith(
                                  color: white.withValues(alpha: 0.85), letterSpacing: 0.8, fontWeight: FontWeight.w800),
                            ),
                            Gap.v4,
                          ],
                          Text(
                            c.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelLarge?.copyWith(color: white, fontWeight: FontWeight.w800, height: 1.2),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void openStories(BuildContext context, List<InsightCard> cards, int start) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: true,
    pageBuilder: (_, _, _) => StoryViewer(cards: cards, start: start),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
    ),
  ));
}

void openWellbeing(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WellbeingScreen()));
}

/// Full-screen stories: tap right to advance, left to go back, auto-advances.
class StoryViewer extends StatefulWidget {
  const StoryViewer({super.key, required this.cards, this.start = 0});
  final List<InsightCard> cards;
  final int start;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int _index = widget.start;
  late final AnimationController _timer = AnimationController(vsync: this, duration: const Duration(seconds: 7))
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
    final t = Theme.of(context).textTheme;
    const white = Colors.white;
    final grad = _kindGradient(c.kind);

    String? actionLabel;
    VoidCallback? onAction;
    if (c.wellbeing != null) {
      actionLabel = 'See breakdown';
      onAction = () => _openLink(
          () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WellbeingScreen())));
    } else if (c.quizId != null) {
      actionLabel = 'Take the quiz';
      onAction = () => _openLink(() async => openQuiz(context, c.quizId!));
    } else if (c.articleId != null) {
      actionLabel = 'Read more';
      onAction = () => _openLink(() async => openArticle(context, c.articleId!));
    }

    return Scaffold(
      backgroundColor: grad.colors.first,
      body: AnimatedContainer(
        duration: Motion.slow,
        curve: Motion.curve,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [grad.colors.first, Color.lerp(grad.colors.last, Colors.black, 0.2)!],
          ),
        ),
        child: Stack(children: [
          // Soft decorative circles.
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(size: 260, color: white.withValues(alpha: 0.10)),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _Blob(size: 300, color: Colors.black.withValues(alpha: 0.08)),
          ),
          // Tap zones.
          Positioned.fill(
            child: Row(children: [
              Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _prev)),
              Expanded(flex: 2, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _next)),
            ]),
          ),
          SafeArea(
            child: MaxWidth(
              width: 520,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
                  child: AnimatedBuilder(
                    animation: _timer,
                    builder: (_, _) => Row(children: [
                      for (var i = 0; i < widget.cards.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _StoryBar(value: i < _index ? 1 : i == _index ? _timer.value : 0),
                          ),
                        ),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.xs, 0),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 1),
                      decoration: BoxDecoration(color: white.withValues(alpha: 0.2), borderRadius: Radii.pillAll),
                      child: Text(_kindLabel(c.kind), style: t.labelMedium?.copyWith(color: white)),
                    ),
                    Gap.h8,
                    Text('${_index + 1} of ${widget.cards.length}',
                        style: t.labelMedium?.copyWith(color: white.withValues(alpha: 0.75))),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, color: white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ]),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.xxl + 4, 0, Space.xxl + 4, Space.lg),
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey(_index),
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IgnorePointer(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (c.wellbeing != null)
                                ProgressRing(
                                  value: c.wellbeing!.score / 100,
                                  size: 120,
                                  stroke: 10,
                                  color: white,
                                  trackColor: ringTrackOn(grad),
                                  child: Text('${c.wellbeing!.score}',
                                      style: t.displayMedium?.copyWith(color: white, height: 1)),
                                )
                              else
                                Container(
                                  width: 104,
                                  height: 104,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: white.withValues(alpha: 0.18), shape: BoxShape.circle),
                                  child: Text(c.emoji, style: const TextStyle(fontSize: 56, height: 1)),
                                ),
                              Gap.v32,
                              Text(c.title, style: t.headlineLarge?.copyWith(color: white, height: 1.15)),
                              Gap.v16,
                              Text(c.body,
                                  style: t.titleMedium?.copyWith(
                                      color: white.withValues(alpha: 0.94), height: 1.5, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          if (actionLabel != null) ...[
                            Gap.v32,
                            FilledButton.icon(
                              onPressed: onAction,
                              style: FilledButton.styleFrom(backgroundColor: white, foregroundColor: grad.colors.first),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                              label: Text(actionLabel),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Text(
                      'Educational, not medical advice.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: white.withValues(alpha: 0.75)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StoryBar extends StatelessWidget {
  const _StoryBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Radii.pillAll,
      child: Container(
        height: 3.5,
        color: Colors.white.withValues(alpha: 0.3),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      );
}

/// Breakdown of the well-being score by factor.
class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});

  static const _color = BloomColors.pregnancy;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wb = computeWellbeing(store);
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final muted = BloomTokens.of(context).muted;
    final logged = wb.factors.where((f) => f.hasData).length;

    return Scaffold(
      body: BloomPage(
        heroColor: _color,
        eyebrow: 'TODAY',
        title: 'Well-being score',
        children: [
          BloomCard(
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xxl, Space.xxl, Space.xl),
            child: Column(children: [
              ProgressRing(
                value: wb.score / 100,
                size: 184,
                stroke: 16,
                gradient: _kindGradient(InsightKind.wellbeing),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${wb.score}', style: t.displayLarge?.copyWith(height: 1)),
                  Text('of 100', style: t.bodySmall),
                ]),
              ),
              Gap.v16,
              PillChip(wb.label, icon: Icons.bolt_rounded, color: _color),
              Gap.v12,
              Text(
                'A rough daily estimate of your energy from what you logged in the last few days. '
                'Log sleep, energy, mood, symptoms, activity, and water to make it more personal.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: muted),
              ),
            ]),
          ),
          SectionHeader('What goes into it', subtitle: '$logged of ${wb.factors.length} factors have recent logs'),
          BloomCard(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.sm),
            child: Column(children: [
              for (var i = 0; i < wb.factors.length; i++) ...[
                if (i > 0) Divider(height: 1, color: BloomTokens.of(context).border),
                _FactorRow(factor: wb.factors[i]),
              ],
            ]),
          ),
          const Disclaimer(text: 'This score is for reflection, not a medical measure.'),
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
    final t = Theme.of(context).textTheme;
    final f = factor;
    final ratio = f.max == 0 ? 0.0 : f.points / f.max;
    final color = !f.hasData
        ? BloomTokens.of(context).muted
        : ratio >= .7
            ? BloomColors.success
            : ratio >= .4
                ? BloomColors.pregnancy
                : BloomColors.period;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md + 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(emoji: f.emoji, color: f.hasData ? color : BloomColors.luteal, size: 40),
        Gap.h12,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(f.name, style: t.titleSmall)),
              if (!f.hasData) ...[
                const PillChip('No data', dense: true, color: BloomColors.luteal),
                Gap.h8,
              ],
              Text.rich(TextSpan(children: [
                TextSpan(text: '${f.points}', style: t.titleSmall),
                TextSpan(text: '/${f.max}', style: t.bodySmall),
              ])),
            ]),
            Gap.v8,
            SoftProgressBar(value: ratio, color: color, height: 8),
            Gap.v8,
            Text(f.note, style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}
