/// Perimenopause home: score, score history, stage estimate, relief
/// options, and symptom frequency.
library;

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'modes_common.dart';
import 'perimenopause_data.dart';

List<ScoreResult> readScores(AppStore s) {
  final raw = (s.feature<Map>('perimenopause') ?? const {})['scores'] as List? ?? const [];
  return [for (final r in raw) ScoreResult.fromJson(r as Map)]..sort((a, b) => a.date.compareTo(b.date));
}

void _saveScore(AppStore s, ScoreResult r) {
  final data = Map<String, dynamic>.from(s.feature<Map>('perimenopause') ?? const {});
  final scores = [
    for (final x in readScores(s))
      if (!sameDay(x.date, r.date)) x.toJson(),
    r.toJson(),
  ];
  data['scores'] = scores;
  s.setFeature('perimenopause', data);
}

/// Counts of `menopause` log options in the last [days] days, most frequent first.
List<MapEntry<String, int>> menopauseFrequency(AppStore s, {int days = 30}) {
  final counts = <String, int>{};
  for (final l in s.logsBetween(addDays(today(), -(days - 1)), today())) {
    for (final o in l.get('menopause')) {
      counts[o] = (counts[o] ?? 0) + 1;
    }
  }
  return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// Top symptom ids from the latest score, or from logs when there is none.
List<String> topSymptoms(AppStore s) {
  final scores = readScores(s);
  if (scores.isNotEmpty) return scores.last.topSymptoms();
  return menopauseFrequency(s).map((e) => kLogToItem[e.key]).nonNulls.toSet().take(3).toList();
}

Color severityColor(Severity sev, ColorScheme cs) => switch (sev) {
  Severity.minimal => BloomColors.fertile,
  Severity.mild => BloomColors.success,
  Severity.moderate => BloomColors.warning,
  Severity.severe => InfoBanner.toneColor(BannerTone.error),
};

const _bandText = {
  Severity.minimal: 'Your symptoms seem to have little effect on you right now.',
  Severity.mild: 'Your symptoms are noticeable but mild. Lifestyle and self-care steps may be enough.',
  Severity.moderate: 'Your symptoms are having a real effect. It is worth discussing options with a clinician.',
  Severity.severe: 'Your symptoms are affecting you a lot. Please talk to a clinician; effective treatments exist.',
};

const _periColor = BloomColors.luteal;

class PerimenopauseHome extends StatelessWidget {
  const PerimenopauseHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = Theme.of(context);
    final scores = readScores(store);
    final latest = scores.lastOrNull;
    final birthYear = store.profile.birthYear;
    final stage = estimateStage(
      periodStarts: [for (final p in store.engine.periods) p.start],
      cycleLengths: store.engine.cycleLengths,
      today: today(),
      age: birthYear == null ? null : today().year - birthYear,
    );
    final freq = menopauseFrequency(store);
    final top = topSymptoms(store);
    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    String itemTitle(String id) => kScoreItems.firstWhereOrNull((i) => i.id == id)?.title ?? id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Perimenopause score',
          icon: Icons.insights_rounded,
          accent: _periColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (latest == null) ...[
                Row(
                  children: [
                    const IconBadge(emoji: '🌸', color: _periColor, size: 52),
                    Gap.h16,
                    Expanded(
                      child: Text(
                        'Answer 11 quick questions to see how much your symptoms affect you, and track it over time.',
                        style: t.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _ScoreSummary(result: latest),
                Gap.v16,
                for (final s in Subscale.values) _SubscaleBar(subscale: s, score: latest.subscore(s)),
              ],
              if (scores.length >= 2) ...[
                Gap.v16,
                Text('Over time', style: t.textTheme.labelLarge),
                Gap.v8,
                SizedBox(height: 160, child: ScoreChart(scores: scores)),
              ],
              Gap.v16,
              FilledButton(
                onPressed: () => open(const PerimenopauseScoreScreen()),
                child: Text(latest == null ? 'Take the check-in' : 'Check in again'),
              ),
            ],
          ),
        ),
        Gap.v16,
        SectionCard(
          title: 'Your stage',
          icon: Icons.timeline_rounded,
          accent: _periColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stage.title, style: t.textTheme.titleLarge),
              Gap.v16,
              _StageTrack(stage: stage.stage),
              Gap.v16,
              Text(stage.explanation),
              if (stage.note != null) ...[Gap.v8, Text(stage.note!, style: t.textTheme.bodySmall)],
              Gap.v8,
              const EduNote(
                text:
                    'This estimate is based only on your logged periods. It is educational, not a diagnosis. '
                    'Hormonal contraception, pregnancy, and some conditions affect bleeding patterns.',
              ),
            ],
          ),
        ),
        Gap.v16,
        SectionCard(
          title: 'Relief options',
          icon: Icons.spa_rounded,
          accent: BloomColors.fertile,
          trailing: const CardChevron(),
          onTap: () => open(const ReliefOptionsScreen()),
          child: top.isEmpty
              ? const Text('Explore lifestyle, self-care, therapy, and medical options.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Options matched to your top symptoms:'),
                    Gap.v8,
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [for (final id in top) PillChip(itemTitle(id), color: _periColor)],
                    ),
                  ],
                ),
        ),
        Gap.v16,
        SectionCard(
          title: 'Symptoms in the last 30 days',
          icon: Icons.bar_chart_rounded,
          accent: BloomColors.coral,
          child: freq.isEmpty
              ? const Text(
                  'Log symptoms like hot flashes and night sweats in the daily log to see how often they happen.',
                )
              : Column(
                  children: [
                    for (final e in freq)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(optionLabel('menopause', e.key), style: t.textTheme.bodyMedium)),
                                Text('${e.value} ${e.value == 1 ? 'day' : 'days'}', style: t.textTheme.labelLarge),
                              ],
                            ),
                            Gap.v4,
                            SoftBar(value: e.value / 30, color: BloomColors.coral),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Ring gauge with the total score, band chip, and band text.
class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.result, this.large = false});
  final ScoreResult result;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = severityColor(result.severity, t.colorScheme);
    final ring = ProgressRing(
      value: result.total / maxScore(),
      size: large ? 168 : 112,
      stroke: large ? 14 : 11,
      gradient: BloomGradients.of(c),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${result.total}',
            style: (large ? t.textTheme.displayMedium : t.textTheme.headlineMedium)!.copyWith(height: 1),
          ),
          Text('of ${maxScore()}', style: t.textTheme.bodySmall),
        ],
      ),
    );
    final info = [
      PillChip(result.severity.label, color: c, icon: Icons.circle),
      Gap.v8,
      Text(_bandText[result.severity]!, style: t.textTheme.bodyMedium, textAlign: large ? TextAlign.center : null),
      Gap.v4,
      Text('Checked ${fmtFull(result.date)}', style: t.textTheme.bodySmall),
    ];
    if (large) {
      return Column(children: [ring, Gap.v16, ...info]);
    }
    return Row(
      children: [
        ring,
        Gap.h16,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: info),
        ),
      ],
    );
  }
}

class _SubscaleBar extends StatelessWidget {
  const _SubscaleBar({required this.subscale, required this.score});
  final Subscale subscale;
  final int score;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sev = bandFor(score, subscale);
    final c = severityColor(sev, t.colorScheme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(subscale.label, style: t.textTheme.bodyMedium)),
              Text('$score/${maxScore(subscale)}', style: t.textTheme.labelLarge),
              Gap.h8,
              PillChip(sev.label, color: c, dense: true),
            ],
          ),
          Gap.v8,
          SoftBar(value: score / maxScore(subscale), color: c),
        ],
      ),
    );
  }
}

/// A horizontal stepper: reproductive, early transition, late transition,
/// postmenopause, with the estimate highlighted.
class _StageTrack extends StatelessWidget {
  const _StageTrack({required this.stage});
  final MenoStage stage;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tokens = BloomTokens.of(context);
    const steps = [
      (MenoStage.reproductive, 'Reproductive'),
      (MenoStage.earlyTransition, 'Early transition'),
      (MenoStage.lateTransition, 'Late transition'),
      (MenoStage.postmenopause, 'Post-\nmenopause'),
    ];
    final idx = steps.indexWhere((s) => s.$1 == stage);
    final accent = readableTint(_periColor, t.brightness);
    const dot = 28.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: dot,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              color: i == 0 ? Colors.transparent : (i <= idx ? _periColor : tokens.subtle),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 3,
                              color: i == steps.length - 1
                                  ? Colors.transparent
                                  : (i < idx ? _periColor : tokens.subtle),
                            ),
                          ),
                        ],
                      ),
                      AnimatedContainer(
                        duration: Motion.medium,
                        width: i == idx ? dot : 14,
                        height: i == idx ? dot : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: i <= idx ? BloomGradients.luteal : null,
                          color: i <= idx ? null : tokens.subtle,
                          boxShadow: i == idx && t.brightness == Brightness.light
                              ? BloomShadows.glow(_periColor)
                              : null,
                        ),
                        child: i == idx ? const Icon(Icons.place_rounded, size: 16, color: Colors.white) : null,
                      ),
                    ],
                  ),
                ),
                Gap.v8,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
                  child: Builder(
                    builder: (context) {
                      final label = Text(
                        steps[i].$2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: t.textTheme.labelSmall!.copyWith(
                          color: i == idx ? accent : tokens.muted,
                          fontWeight: i == idx ? FontWeight.w800 : null,
                        ),
                      );
                      // Single words shrink to fit instead of breaking mid-word.
                      return steps[i].$2.contains(RegExp(r'\s'))
                          ? label
                          : FittedBox(fit: BoxFit.scaleDown, child: label);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ScoreChart extends StatelessWidget {
  const ScoreChart({super.key, required this.scores});
  final List<ScoreResult> scores;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final first = scores.first.date;
    final line = readableTint(_periColor, t.brightness);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxScore().toDouble(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 11,
          getDrawingHorizontalLine: (_) => FlLine(color: tokens.border, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => t.colorScheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${s.y.round()}',
                  t.textTheme.labelMedium!.copyWith(color: t.colorScheme.onInverseSurface),
                ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 11,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(meta.formattedValue, style: t.textTheme.bodySmall),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (daysBetween(first, scores.last.date) / 3).clamp(1, 10000).toDouble(),
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(fmtShort(addDays(first, v.round())), style: t.textTheme.bodySmall),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final s in scores) FlSpot(daysBetween(first, s.date).toDouble(), s.total.toDouble())],
            color: line,
            barWidth: 3,
            isCurved: true,
            preventCurveOverShooting: true,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_periColor.withValues(alpha: 0.28), _periColor.withValues(alpha: 0)],
              ),
            ),
            dotData: FlDotData(
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: line,
                strokeWidth: 2,
                strokeColor: t.brightness == Brightness.dark ? t.colorScheme.surfaceContainer : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PerimenopauseScoreScreen extends StatefulWidget {
  const PerimenopauseScoreScreen({super.key});

  @override
  State<PerimenopauseScoreScreen> createState() => _PerimenopauseScoreScreenState();
}

class _PerimenopauseScoreScreenState extends State<PerimenopauseScoreScreen> {
  final List<int?> _answers = List.filled(kScoreItems.length, null);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final answered = _answers.where((a) => a != null).length;
    final complete = answered == _answers.length;
    return ModePage(
      title: 'Perimenopause check-in',
      subtitle: 'How much has each of these bothered you over the past two weeks?',
      heroColor: _periColor,
      children: [
        Row(
          children: [
            Expanded(
              child: SoftBar(value: answered / _answers.length, color: _periColor),
            ),
            Gap.h12,
            Text('$answered of ${_answers.length}', style: t.textTheme.labelLarge),
          ],
        ),
        for (var i = 0; i < kScoreItems.length; i++)
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: Motion.medium,
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _answers[i] != null ? BloomGradients.luteal : null,
                        color: _answers[i] != null ? null : BloomTokens.of(context).subtle,
                      ),
                      child: _answers[i] != null
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : Text('${i + 1}', style: t.textTheme.labelMedium),
                    ),
                    Gap.h12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kScoreItems[i].title, style: t.textTheme.titleMedium),
                          const SizedBox(height: Space.xxs),
                          Text(kScoreItems[i].question, style: t.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                Gap.v12,
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (var v = 0; v < kAnswerLabels.length; v++)
                      SelectChip(
                        label: kAnswerLabels[v],
                        color: _periColor,
                        showCheck: false,
                        selected: _answers[i] == v,
                        onSelected: (_) => setState(() => _answers[i] = v),
                      ),
                  ],
                ),
              ],
            ),
          ),
        GradientButton(
          label: complete ? 'See my score' : 'Answer all ${kScoreItems.length} questions',
          gradient: BloomGradients.luteal,
          expanded: true,
          onPressed: complete
              ? () {
                  final r = ScoreResult(today(), [for (final a in _answers) a!]);
                  _saveScore(context.read<AppStore>(), r);
                  Navigator.of(context)
                      .pushReplacement(MaterialPageRoute<void>(builder: (_) => ScoreResultScreen(result: r)));
                }
              : null,
        ),
        const EduNote(
          text:
              'This check-in is an educational self-assessment, not a diagnosis. If symptoms affect your daily '
              'life, talk to a clinician.',
        ),
      ],
    );
  }
}

class ScoreResultScreen extends StatelessWidget {
  const ScoreResultScreen({super.key, required this.result});
  final ScoreResult result;

  @override
  Widget build(BuildContext context) {
    return ModePage(
      title: 'Your score',
      heroColor: severityColor(result.severity, Theme.of(context).colorScheme),
      children: [
        BloomCard(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.xxl, Space.xl, Space.xl),
          child: _ScoreSummary(result: result, large: true),
        ),
        const SectionHeader('By area'),
        BloomCard(
          child: Column(
            children: [for (final s in Subscale.values) _SubscaleBar(subscale: s, score: result.subscore(s))],
          ),
        ),
        GradientButton(
          label: 'See relief options',
          icon: Icons.spa_rounded,
          gradient: BloomGradients.luteal,
          expanded: true,
          onPressed: () =>
              Navigator.of(context)
                  .pushReplacement(MaterialPageRoute<void>(builder: (_) => const ReliefOptionsScreen())),
        ),
        const EduNote(),
      ],
    );
  }
}

const _categoryStyle = {
  'Lifestyle': (Icons.directions_walk_rounded, BloomColors.fertile),
  'Self-care': (Icons.spa_rounded, BloomColors.coral),
  'Therapy': (Icons.psychology_rounded, BloomColors.luteal),
  'Medical': (Icons.medication_rounded, BloomColors.info),
};

class ReliefOptionsScreen extends StatefulWidget {
  const ReliefOptionsScreen({super.key});

  @override
  State<ReliefOptionsScreen> createState() => _ReliefOptionsScreenState();
}

class _ReliefOptionsScreenState extends State<ReliefOptionsScreen> {
  /// `mine`, `all`, or a category name.
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final store = context.watch<AppStore>();
    final top = topSymptoms(store);
    final filter = _filter ?? (top.isEmpty ? 'all' : 'mine');
    final options = kReliefOptions
        .where(
          (o) => switch (filter) {
            'all' => true,
            'mine' => o.tags.any(top.contains),
            final c => o.category == c,
          },
        )
        .toList();
    if (filter == 'mine') {
      options.sort((a, b) => b.tags.where(top.contains).length.compareTo(a.tags.where(top.contains).length));
    }
    String itemTitle(String id) => kScoreItems.firstWhereOrNull((i) => i.id == id)?.title ?? id;
    void set(String f) => setState(() => _filter = f);

    return ModePage(
      title: 'Relief options',
      subtitle: filter == 'mine'
          ? 'Matched to: ${top.map(itemTitle).join(', ')}'
          : 'Ways to ease perimenopause symptoms',
      heroColor: _periColor,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            if (top.isNotEmpty)
              SelectChip(
                label: 'For my symptoms',
                icon: Icons.favorite_rounded,
                color: BloomColors.brand,
                showCheck: false,
                selected: filter == 'mine',
                onSelected: (_) => set('mine'),
              ),
            SelectChip(label: 'All', showCheck: false, selected: filter == 'all', onSelected: (_) => set('all')),
            for (final c in kReliefCategories)
              SelectChip(
                label: c,
                icon: _categoryStyle[c]?.$1,
                color: _categoryStyle[c]?.$2,
                showCheck: false,
                selected: filter == c,
                onSelected: (_) => set(c),
              ),
          ],
        ),
        if (options.isEmpty)
          const EmptyState(
            emoji: '🌿',
            color: BloomColors.fertile,
            title: 'Nothing here yet',
            body: 'Try another filter to see more options.',
          ),
        for (final o in options)
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: _categoryStyle[o.category]?.$1 ?? Icons.spa_rounded,
                      color: _categoryStyle[o.category]?.$2,
                    ),
                    Gap.h12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.title, style: t.textTheme.titleMedium),
                          Text(
                            o.category,
                            style: t.textTheme.labelMedium!.copyWith(
                              color: readableTint(_categoryStyle[o.category]?.$2 ?? _periColor, t.brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Gap.v12,
                Text(o.body, style: t.textTheme.bodyMedium),
                Gap.v12,
                Wrap(
                  spacing: Space.xs + 2,
                  runSpacing: Space.xs + 2,
                  children: [
                    for (final tag in o.tags)
                      PillChip(
                        itemTitle(tag),
                        dense: true,
                        icon: top.contains(tag) ? Icons.check_rounded : null,
                        color: top.contains(tag) ? BloomColors.brand : BloomTokens.of(context).muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
        const EduNote(
          text:
              'These options are educational. Medicines, including hormone therapy, need a conversation with a '
              'clinician about your health history.',
        ),
      ],
    );
  }
}
