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

class PerimenopauseHome extends StatelessWidget {
  const PerimenopauseHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = Theme.of(context);
    final p = BloomColors.of(context);
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
        const SectionHeader('Perimenopause score', label: 'Check-in', padding: EdgeInsets.zero),
        Gap.v16,
        if (latest == null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BotanicalGlyph(Botanical.seedHead, size: 36, accent: BloomColors.luteal),
              Gap.h16,
              Expanded(
                child: Text(
                  'Answer 11 quick questions to see how much your symptoms affect you, and track it over time.',
                  style: t.textTheme.bodyMedium,
                ),
              ),
            ],
          )
        else ...[
          _ScoreSummary(result: latest),
          Gap.v20,
          for (final s in Subscale.values) _SubscaleBar(subscale: s, score: latest.subscore(s)),
        ],
        if (scores.length >= 2) ...[
          Gap.v20,
          const MonoLabel('Over time'),
          Gap.v12,
          SizedBox(height: 150, child: ScoreChart(scores: scores)),
        ],
        Gap.v16,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkButton(
            label: latest == null ? 'Take the check-in' : 'Check in again',
            dense: true,
            onPressed: () => open(const PerimenopauseScoreScreen()),
          ),
        ),
        const SectionHeader(
          'Your stage',
          label: 'Estimate',
          padding: EdgeInsets.only(top: Space.xxxl),
        ),
        Gap.v8,
        Text(stage.title, style: Almanac.italic(context, size: 24, color: p.ink)),
        Gap.v20,
        _StageTrack(stage: stage.stage),
        Gap.v20,
        Text(stage.explanation),
        if (stage.note != null) ...[Gap.v8, Text(stage.note!, style: t.textTheme.bodySmall)],
        Gap.v12,
        const EduNote(
          text:
              'This estimate is based only on your logged periods. It is educational, not a diagnosis. '
              'Hormonal contraception, pregnancy, and some conditions affect bleeding patterns.',
        ),
        SectionHeader(
          'Relief options',
          label: 'Remedies',
          padding: const EdgeInsets.only(top: Space.xxxl),
          actionLabel: 'See all',
          onAction: () => open(const ReliefOptionsScreen()),
        ),
        Gap.v8,
        if (top.isEmpty)
          const Text('Explore lifestyle, self-care, therapy, and medical options.')
        else
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Options matched to your top symptoms: '),
                TextSpan(text: top.map(itemTitle).join(', '), style: Almanac.italic(context, size: 16.5)),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        const SectionHeader(
          'Symptoms in the last 30 days',
          label: 'Frequency',
          padding: EdgeInsets.only(top: Space.xxxl),
        ),
        Gap.v12,
        if (freq.isEmpty)
          const Text('Log symptoms like hot flashes and night sweats in the daily log to see how often they happen.')
        else
          Column(
            children: [
              for (final e in freq)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(optionLabel('menopause', e.key), style: t.textTheme.bodyMedium)),
                          Text('${e.value} ${e.value == 1 ? 'day' : 'days'}', style: Almanac.data(context)),
                        ],
                      ),
                      Gap.v8,
                      SoftBar(value: e.value / 30, height: 2),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// The total score as a serif numeral with an italic band name.
class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.result, this.large = false});
  final ScoreResult result;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = BloomColors.of(context);
    final c = readableTint(BloomColors.resolve(context, severityColor(result.severity, t.colorScheme)), t.brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${result.total}',
                style: Almanac.numeral(context, size: large ? 96 : 64),
              ),
              TextSpan(
                text: ' of ${maxScore()}',
                style: Almanac.italic(context, size: large ? 20 : 17, color: p.ink2),
              ),
            ],
          ),
        ),
        Gap.v8,
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            Gap.h8,
            Text(
              result.severity.label,
              style: Almanac.italic(context, size: large ? 26 : 22, color: c),
            ),
          ],
        ),
        Gap.v8,
        Text(_bandText[result.severity]!, style: t.textTheme.bodyMedium),
        Gap.v8,
        MonoLabel('Checked ${fmtFull(result.date)}'),
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
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(subscale.label, style: t.textTheme.bodyMedium)),
              Text(
                sev.label.toLowerCase(),
                style: Almanac.italic(
                  context,
                  size: 15,
                  color: readableTint(BloomColors.resolve(context, c), t.brightness),
                ),
              ),
              Gap.h12,
              SizedBox(
                width: 40,
                child: Text('$score/${maxScore(subscale)}', style: Almanac.data(context), textAlign: TextAlign.right),
              ),
            ],
          ),
          Gap.v8,
          SoftBar(value: score / maxScore(subscale), color: c, height: 2),
        ],
      ),
    );
  }
}

/// A printed horizontal timeline: reproductive, early transition, late
/// transition, postmenopause, with an ink marker on the estimate.
class _StageTrack extends StatelessWidget {
  const _StageTrack({required this.stage});
  final MenoStage stage;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    const steps = [
      (MenoStage.reproductive, 'Reproductive'),
      (MenoStage.earlyTransition, 'Early\ntransition'),
      (MenoStage.lateTransition, 'Late\ntransition'),
      (MenoStage.postmenopause, 'Post-\nmenopause'),
    ];
    final idx = steps.indexWhere((s) => s.$1 == stage);

    return Semantics(
      label: idx < 0 ? 'Stage not estimated yet' : 'Estimated stage: ${steps[idx].$2.replaceAll(RegExp(r'-?\n'), ' ')}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 22,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The rule, ink up to the estimate.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 14,
                          child: Container(height: i <= idx ? 1.5 : 1, color: i <= idx ? p.ink : p.hairline),
                        ),
                        Positioned(left: 0, top: 9, child: Container(width: 1, height: 11, color: p.ink2)),
                        if (i == idx)
                          Positioned(
                            left: 0,
                            top: 0,
                            child: CustomPaint(size: const Size(10, 22), painter: _MarkerPainter(p.ink)),
                          ),
                      ],
                    ),
                  ),
                  Gap.v8,
                  Padding(
                    padding: const EdgeInsets.only(right: Space.xs),
                    child: Text(indexNumber(i + 1), style: Almanac.label(context, color: i == idx ? p.ink : null)),
                  ),
                  Gap.v4,
                  Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: Text(
                      steps[i].$2,
                      maxLines: 2,
                      style: i == idx
                          ? Almanac.italic(context, size: 14, color: p.ink)
                          : Almanac.sans(size: 12, color: p.ink2, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(-5, 0)
      ..lineTo(5, 0)
      ..lineTo(0, 7)
      ..close();
    canvas.drawPath(path, Paint()..color = ink);
    canvas.drawLine(
      const Offset(0, 6),
      Offset(0, size.height),
      Paint()
        ..color = ink
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.ink != ink;
}

class ScoreChart extends StatelessWidget {
  const ScoreChart({super.key, required this.scores});
  final List<ScoreResult> scores;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final first = scores.first.date;
    final axis = Almanac.data(context, size: 10.5);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxScore().toDouble(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 11,
          getDrawingHorizontalLine: (_) => FlLine(color: p.hairline, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: p.ink.withValues(alpha: 0.6))),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => p.ink,
            getTooltipItems: (spots) => [
              for (final s in spots) LineTooltipItem('${s.y.round()}', Almanac.mono(size: 11.5, color: p.paper)),
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
                child: Text(meta.formattedValue, style: axis),
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
                child: Text(fmtShort(addDays(first, v.round())), style: axis),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final s in scores) FlSpot(daysBetween(first, s.date).toDouble(), s.total.toDouble())],
            color: p.ink,
            barWidth: 1.5,
            isCurved: true,
            preventCurveOverShooting: true,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (_, _, _, _) =>
                  FlDotCirclePainter(radius: 2.5, color: p.ink, strokeWidth: 1.5, strokeColor: p.paper),
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
    final p = BloomColors.of(context);
    final answered = _answers.where((a) => a != null).length;
    final complete = answered == _answers.length;
    return ModePage(
      eyebrow: 'Perimenopause',
      title: 'Check-in',
      subtitle: 'How much has each of these bothered you over the past two weeks?',
      children: [
        Row(
          children: [
            Expanded(child: SoftBar(value: answered / _answers.length)),
            Gap.h12,
            Text('$answered of ${_answers.length}', style: Almanac.data(context)),
          ],
        ),
        for (var i = 0; i < kScoreItems.length; i++)
          BloomCard(
            padding: const EdgeInsets.symmetric(vertical: Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 40,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          indexNumber(i + 1),
                          style: Almanac.label(context, size: 11, color: _answers[i] != null ? p.ink : null),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kScoreItems[i].title, style: t.textTheme.titleLarge),
                          const SizedBox(height: Space.xxs),
                          Text(kScoreItems[i].question, style: t.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                Gap.v12,
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: UnderlineTabs<int?>(
                    options: [for (var v = 0; v < kAnswerLabels.length; v++) (v, kAnswerLabels[v])],
                    selected: _answers[i],
                    onChanged: (v) => setState(() => _answers[i] = v),
                  ),
                ),
              ],
            ),
          ),
        InkButton(
          label: complete ? 'See my score' : 'Answer all ${kScoreItems.length} questions',
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
      eyebrow: 'Perimenopause · Your score',
      title: 'Your score',
      header: _ScoreSummary(result: result, large: true),
      children: [
        const SectionHeader('By area', label: 'Subscales'),
        Column(
          children: [for (final s in Subscale.values) _SubscaleBar(subscale: s, score: result.subscore(s))],
        ),
        Gap.v8,
        InkButton(
          label: 'See relief options',
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
    final p = BloomColors.of(context);
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

    return ModePage(
      eyebrow: 'Perimenopause',
      title: 'Relief options',
      subtitle: filter == 'mine'
          ? 'Matched to: ${top.map(itemTitle).join(', ')}'
          : 'Ways to ease perimenopause symptoms.',
      children: [
        UnderlineTabs<String>(
          options: [
            if (top.isNotEmpty) ('mine', 'For my symptoms'),
            ('all', 'All'),
            for (final c in kReliefCategories) (c, c),
          ],
          selected: filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        AnimatedSwitcher(
          duration: Motion.medium,
          child: Column(
            key: ValueKey(filter),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (options.isEmpty)
                const EmptyState(title: 'Nothing here yet', body: 'Try another filter to see more options.'),
              for (var n = 0; n < options.length; n++)
                Builder(
                  builder: (context) {
                    final o = options[n];
                    final tags = o.tags.toList();
                    return BloomCard(
                      padding: const EdgeInsets.symmetric(vertical: Space.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MonoLabel('${indexNumber(n + 1)} · ${o.category}'),
                          Gap.v8,
                          Text(o.title, style: t.textTheme.headlineSmall),
                          Gap.v8,
                          Text(o.body, style: t.textTheme.bodyMedium!.copyWith(height: 1.6)),
                          Gap.v12,
                          Text.rich(
                            TextSpan(
                              children: [
                                for (var i = 0; i < tags.length; i++) ...[
                                  if (i > 0) TextSpan(text: '  ·  ', style: Almanac.label(context)),
                                  TextSpan(
                                    text: itemTitle(tags[i]).toUpperCase(),
                                    style: Almanac.label(context, color: top.contains(tags[i]) ? p.ink : null).copyWith(
                                      decoration: top.contains(tags[i]) ? TextDecoration.underline : null,
                                      decorationColor: p.ink,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
