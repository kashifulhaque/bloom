/// Rule-based, on-device daily insights and the well-being score.
///
/// Everything here is a pure function of the [AppStore] contents, so it's
/// easy to test with `AppStore.memory`.
library;

import 'dart:math' as math;

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import 'content.dart';
import 'insights_data.dart';

enum InsightKind { wellbeing, period, fertile, pattern, cycle, habit, tip, quiz, article }

/// One story card in the daily insights strip.
class InsightCard {
  const InsightCard({
    required this.id,
    required this.kind,
    required this.emoji,
    required this.title,
    required this.body,
    this.articleId,
    this.quizId,
    this.wellbeing,
  });

  /// Stable id for the day, used to track which stories were seen.
  final String id;
  final InsightKind kind;
  final String emoji;
  final String title;
  final String body;

  /// Linked article, opened from the story viewer.
  final String? articleId;

  /// Linked quiz, opened directly when tapped.
  final String? quizId;

  /// Set on the well-being card.
  final WellbeingScore? wellbeing;
}

/// One input to the well-being score.
class WellbeingFactor {
  const WellbeingFactor(this.name, this.emoji, this.points, this.max, this.note, {this.hasData = true});
  final String name;
  final String emoji;
  final int points;
  final int max;
  final String note;

  /// False when nothing was logged and a neutral value was used.
  final bool hasData;
}

/// A 0-100 "energy battery" with a per-factor breakdown.
class WellbeingScore {
  const WellbeingScore(this.score, this.factors);
  final int score;
  final List<WellbeingFactor> factors;

  String get label => score >= 75
      ? 'Charged'
      : score >= 55
          ? 'Steady'
          : score >= 35
              ? 'Running low'
              : 'Needs recharging';
}

const _positiveMoods = {'calm', 'happy', 'energetic', 'frisky'};
const _negativeMoods = {
  'swings', 'irritated', 'sad', 'anxious', 'depressed', 'guilty', 'obsessive', 'apathetic', 'confused',
  'self_critical', 'low_energy',
};

double? _avgMetric(List<DayLog> logs, String id) {
  final v = [for (final l in logs) if (l.metrics[id] != null) l.metrics[id]!];
  if (v.isEmpty) return null;
  return v.reduce((a, b) => a + b) / v.length;
}

/// Computes the well-being score for [day] (default: the engine's today)
/// from the last few days of sleep, energy, mood, symptoms, activity, water,
/// and the cycle phase.
WellbeingScore computeWellbeing(AppStore store, {DateTime? day}) {
  final d = dayOf(day ?? store.engine.today);
  final last3 = store.logsBetween(addDays(d, -2), d);
  final last7 = store.logsBetween(addDays(d, -6), d);
  final factors = <WellbeingFactor>[];

  // Sleep, 20 points.
  final sleep = _avgMetric(last3, 'sleep');
  if (sleep == null) {
    factors.add(const WellbeingFactor('Sleep', '🌙', 12, 20, 'No sleep logged lately, so this uses a neutral value.',
        hasData: false));
  } else {
    final p = sleep >= 7 && sleep <= 9.5
        ? 20
        : sleep >= 6
            ? 14
            : sleep >= 5
                ? 8
                : 3;
    factors.add(WellbeingFactor('Sleep', '🌙', p, 20,
        'About ${sleep.toStringAsFixed(1)} h a night lately. Most adults feel best with 7-9 hours.'));
  }

  // Energy, 15 points.
  final energy = _avgMetric(last3, 'energy');
  if (energy == null) {
    factors.add(const WellbeingFactor('Energy', '🔋', 9, 15, 'No energy level logged lately.', hasData: false));
  } else {
    final p = (energy.clamp(1, 5) / 5 * 15).round();
    factors.add(WellbeingFactor('Energy', '🔋', p, 15, 'You rated your energy ${energy.toStringAsFixed(1)} out of 5.'));
  }

  // Mood, 15 points.
  var pos = 0, neg = 0;
  for (final l in last3) {
    pos += l.get('mood').where(_positiveMoods.contains).length;
    neg += l.get('mood').where(_negativeMoods.contains).length;
  }
  if (pos + neg == 0) {
    factors.add(const WellbeingFactor('Mood', '😊', 10, 15, 'No moods logged lately.', hasData: false));
  } else {
    final p = (3 + 12 * pos / (pos + neg)).round();
    factors.add(WellbeingFactor('Mood', '😊', p, 15,
        neg > pos ? 'More tough moods than good ones lately. Be kind to yourself.' : 'Mostly positive moods lately.'));
  }

  // Symptoms, 15 points.
  final last2 = store.logsBetween(addDays(d, -1), d);
  var symptoms = 0;
  var anyLog = false;
  for (final l in last2) {
    anyLog = true;
    symptoms += l.get('symptoms').where((o) => o != 'fine').length;
    symptoms += l.get('digestion').length;
    symptoms += l.get('menopause').length;
  }
  if (!anyLog) {
    factors.add(const WellbeingFactor('Symptoms', '🤕', 11, 15, 'No symptoms logged in the last two days.',
        hasData: false));
  } else {
    final p = math.max(0, 15 - symptoms * 3);
    factors.add(WellbeingFactor('Symptoms', '🤕', p, 15,
        symptoms == 0 ? 'No symptoms logged. Nice.' : '$symptoms symptom${symptoms == 1 ? '' : 's'} logged in the last two days.'));
  }

  // Activity, 10 points.
  var activeDays = 0;
  var activityLogged = false;
  for (final l in last7) {
    final act = l.get('activity');
    final steps = l.metrics['steps'];
    if (act.isNotEmpty || steps != null) activityLogged = true;
    if (act.any((o) => o != 'none') || (steps ?? 0) >= 5000) activeDays++;
  }
  if (!activityLogged) {
    factors.add(const WellbeingFactor('Activity', '🏃', 5, 10, 'No activity logged this week.', hasData: false));
  } else {
    final p = (math.min(activeDays, 4) / 4 * 10).round();
    factors.add(WellbeingFactor('Activity', '🏃', p, 10,
        'Active on $activeDays of the last 7 days. Even a short walk counts.'));
  }

  // Water, 10 points.
  final water = _avgMetric(last3, 'water');
  if (water == null) {
    factors.add(const WellbeingFactor('Water', '💧', 5, 10, 'No water logged lately.', hasData: false));
  } else {
    final p = (math.min(water, 2000) / 2000 * 10).round();
    factors.add(WellbeingFactor('Water', '💧', p, 10, 'About ${water.round()} ml a day lately.'));
  }

  // Cycle phase, 15 points.
  final goal = store.profile.goal;
  final info = store.engine.info(d);
  final phase = info.phase;
  final until = store.engine.daysUntilNextPeriod;
  int phasePoints;
  String phaseNote;
  if (goal == Goal.trackPregnancy || goal == Goal.postpartum || phase == null) {
    phasePoints = 11;
    phaseNote = goal == Goal.trackPregnancy
        ? 'Pregnancy changes energy from week to week, so this uses a neutral value.'
        : goal == Goal.postpartum
            ? 'Recovery after birth takes energy, so this uses a neutral value.'
            : 'Log a period to factor in your cycle phase.';
  } else {
    switch (phase) {
      case Phase.menstrual:
        phasePoints = 8;
        phaseNote = 'Many people have less energy during their period.';
      case Phase.follicular:
        phasePoints = 15;
        phaseNote = 'Rising estrogen often brings more energy in the follicular phase.';
      case Phase.ovulation:
        phasePoints = 14;
        phaseNote = 'Energy and mood often peak around ovulation.';
      case Phase.luteal:
        final late = until != null && until <= 3;
        phasePoints = late ? 9 : 11;
        phaseNote = late
            ? 'Your period is close. PMS can lower energy for a few days.'
            : 'Progesterone can make you a little more tired in the luteal phase.';
    }
  }
  factors.add(WellbeingFactor('Cycle phase', '🔄', phasePoints, 15, phaseNote, hasData: phase != null));

  final total = factors.fold<int>(0, (a, f) => a + f.points).clamp(0, 100);
  return WellbeingScore(total, factors);
}

/// Articles ranked for the user's goal and today's phase. Unread first.
List<Article> recommendedArticles(AppStore store, {int limit = 8}) {
  final goal = store.profile.goal.name;
  final phase = store.engine.info(store.engine.today).phase?.name;
  final read = InsightsData.readIds(store);
  final conditions = store.profile.conditions.map((c) => c.toLowerCase()).toSet();
  final scored = <(Article, int)>[];
  for (var i = 0; i < kArticles.length; i++) {
    final a = kArticles[i];
    var s = 0;
    if (a.tags.contains(goal)) s += 4;
    if (phase != null && a.tags.contains(phase)) s += 2;
    if (a.tags.any(conditions.contains)) s += 3;
    if (read.contains(a.id)) s -= 5;
    scored.add((a, s * 1000 - i));
  }
  scored.sort((x, y) => y.$2.compareTo(x.$2));
  return [for (final s in scored.take(limit)) s.$1];
}

int _dayIndex(DateTime d) => daysBetween(DateTime(2024, 1, 1), d);

const _phaseTips = <Phase, List<(String, String, String)>>{
  Phase.menstrual: [
    ('🫖', 'Warmth helps', 'A heat pad or warm bath relaxes the uterine muscles and can ease cramps.'),
    ('🥬', 'Top up on iron', 'Bleeding uses iron. Leafy greens, beans, lentils, and lean meat help restore it.'),
    ('🛌', 'Rest is productive', 'If your energy is low, plan lighter tasks and go to bed a little earlier.'),
  ],
  Phase.follicular: [
    ('⚡', 'Ride the energy', 'Rising estrogen often lifts energy. It can be a good week to try something new.'),
    ('🏋️', 'Try a harder workout', 'Many people find strength and endurance training feel easier now.'),
    ('🧠', 'Plan and start', 'Focus often improves in this phase. Use it to plan the weeks ahead.'),
  ],
  Phase.ovulation: [
    ('💧', 'Notice your discharge', 'Clear, stretchy discharge is a common sign that ovulation is near.'),
    ('🗣️', 'Social battery charged', 'Confidence and sociability often peak around ovulation.'),
    ('🌡️', 'Track the shift', 'Your basal temperature rises slightly after ovulation. Logging it confirms the change.'),
  ],
  Phase.luteal: [
    ('🍫', 'Cravings are normal', 'Pair a treat with protein or fiber to keep your energy steadier.'),
    ('🧘', 'Wind down early', 'Progesterone can affect sleep. A calm evening routine helps.'),
    ('🧂', 'Ease off salt', 'Less salt and more water can reduce bloating before your period.'),
  ],
};

const _goalTips = <Goal, List<(String, String, String)>>{
  Goal.trackCycle: [
    ('📝', 'Log a little every day', 'Even one tap a day makes your predictions and patterns more accurate.'),
    ('📈', 'Know your normal', 'Cycles between 21 and 35 days are typical. Tracking shows what is normal for you.'),
  ],
  Goal.getPregnant: [
    ('🌱', 'Take folic acid', 'Most clinicians suggest a daily folic acid supplement before conception.'),
    ('💞', 'Every 1-2 days', 'Sex every one to two days in your fertile window gives good odds without strict timing.'),
  ],
  Goal.trackPregnancy: [
    ('🤰', 'Small, frequent meals', 'Eating little and often can ease nausea and heartburn.'),
    ('🚶', 'Keep moving', 'Gentle, regular activity like walking supports energy and sleep in pregnancy.'),
  ],
  Goal.postpartum: [
    ('🍼', 'Accept help', 'Recovery takes weeks. Let others cook, clean, or hold the baby while you rest.'),
    ('💬', 'Check in on your mood', 'Low mood that lasts more than two weeks is worth raising with a clinician.'),
  ],
  Goal.perimenopause: [
    ('🌡️', 'Layer up', 'Dressing in layers makes hot flashes easier to manage.'),
    ('🦴', 'Protect your bones', 'Calcium, vitamin D, and strength training support bone health in midlife.'),
  ],
};

String _plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';

/// Symptoms or moods logged in the 3 days before at least 2 of the last
/// 3 period starts. Returns the best match.
({String category, String option, int hits, int of})? _preperiodPattern(AppStore store) {
  final periods = store.engine.periods;
  if (periods.length < 3) return null;
  final starts = periods.reversed.take(3).map((p) => p.start).toList();
  final counts = <(String, String), int>{};
  for (final s in starts) {
    final seen = <(String, String)>{};
    for (final l in store.logsBetween(addDays(s, -3), addDays(s, -1))) {
      for (final cat in const ['symptoms', 'digestion', 'mood']) {
        for (final o in l.get(cat)) {
          if (o == 'fine' || _positiveMoods.contains(o)) continue;
          seen.add((cat, o));
        }
      }
    }
    for (final k in seen) {
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  (String, String)? best;
  var bestN = 0;
  for (final e in counts.entries) {
    if (e.value > bestN) {
      best = e.key;
      bestN = e.value;
    }
  }
  if (best == null || bestN < 2) return null;
  return (category: best.$1, option: best.$2, hits: bestN, of: starts.length);
}

/// Builds 4-6 personalized story cards for today. The well-being card is
/// always first.
List<InsightCard> buildInsights(AppStore store) {
  final e = store.engine;
  final now = e.today;
  final goal = store.profile.goal;
  final info = e.info(now);
  final cycleGoal = goal == Goal.trackCycle || goal == Goal.getPregnant || goal == Goal.perimenopause;
  final idx = _dayIndex(now);

  final wb = computeWellbeing(store);
  final cards = <InsightCard>[
    InsightCard(
      id: 'wellbeing',
      kind: InsightKind.wellbeing,
      emoji: '🔋',
      title: 'Well-being ${wb.score}/100',
      body: '${wb.label}. Your score blends recent sleep, energy, mood, symptoms, activity, water, and cycle phase.',
      wellbeing: wb,
    ),
  ];

  final data = <InsightCard>[];

  // Period timing.
  if (cycleGoal && e.hasData) {
    final until = e.daysUntilNextPeriod;
    if (e.isLate) {
      data.add(InsightCard(
        id: 'period-late',
        kind: InsightKind.period,
        emoji: '⏳',
        title: 'Period ${_plural(e.daysLate, 'day')} late',
        body: e.daysLate <= 7
            ? 'Cycles shift by a few days for many reasons, such as stress, travel, or illness. '
                'If you could be pregnant, a home test is most reliable from the day your period was due.'
            : 'A delay of more than a week is worth a closer look. Consider a pregnancy test, '
                'and talk to a clinician if your period stays away.',
        articleId: 'normal-cycle',
      ));
    } else if (e.isOnPeriod(now)) {
      final p = e.periods.last;
      final day = daysBetween(p.start, now) + 1;
      data.add(InsightCard(
        id: 'period-today',
        kind: InsightKind.period,
        emoji: '🩸',
        title: 'Period day $day',
        body: 'Your periods usually last about ${_plural(e.avgPeriodLength, 'day')}. '
            'Warmth, gentle movement, and rest can ease cramps.',
        articleId: 'easing-cramps',
      ));
    } else if (until != null && until >= 0 && until <= 5) {
      data.add(InsightCard(
        id: 'period-soon',
        kind: InsightKind.period,
        emoji: '👜',
        title: until == 0
            ? 'Period expected today'
            : until == 1
                ? 'Period likely tomorrow'
                : 'Period likely in $until days',
        body: 'Pack pads, tampons, a cup, or period underwear so you are ready. '
            'PMS symptoms are common in these last days of your cycle.',
        articleId: 'mood-pms-vs-everyday',
      ));
    }
  }

  // Fertile window.
  if (cycleGoal && (info.isFertile || info.isOvulation)) {
    final ttc = goal == Goal.getPregnant;
    data.add(InsightCard(
      id: 'fertile',
      kind: InsightKind.fertile,
      emoji: info.isOvulation ? '🥚' : '🌱',
      title: info.isOvulation ? 'Ovulation is likely today' : "You're in your fertile window",
      body: ttc
          ? 'This is the best time to try. Sex every one to two days during the window gives good chances.'
          : 'Your chance of pregnancy is higher now. Use contraception if you are not trying to conceive.',
      articleId: ttc ? 'timing-sex-ttc' : 'fertile-signs',
    ));
  }

  // Symptom pattern before periods.
  if (cycleGoal) {
    final pat = _preperiodPattern(store);
    if (pat != null) {
      final label = optionLabel(pat.category, pat.option).toLowerCase();
      final what = pat.hits == pat.of ? 'your last ${pat.of} periods' : '${pat.hits} of your last ${pat.of} periods';
      data.add(InsightCard(
        id: 'pattern-${pat.category}-${pat.option}',
        kind: InsightKind.pattern,
        emoji: categoryById(pat.category)?.option(pat.option)?.emoji ?? '🔁',
        title: 'You logged $label before $what',
        body: 'Patterns like this are common in the days before a period. Knowing it is coming '
            'lets you plan ahead. If it disrupts your life, mention it to a clinician.',
        articleId: pat.category == 'mood' ? 'mood-pms-vs-everyday' : 'cycle-hormones',
      ));
    }
  }

  // Cycle length compared with the average.
  if (cycleGoal && e.cycleLengths.length >= 2) {
    final last = e.cycleLengths.last;
    final diff = last - e.avgCycleLength;
    if (diff.abs() >= 4) {
      data.add(InsightCard(
        id: 'cycle-length',
        kind: InsightKind.cycle,
        emoji: '📏',
        title: 'Last cycle was ${_plural(diff.abs(), 'day')} ${diff > 0 ? 'longer' : 'shorter'} than your average',
        body: 'Your last cycle lasted $last days, compared with your average of ${e.avgCycleLength}. '
            'One-off changes are common. If it keeps happening, note it for your next checkup.',
        articleId: 'normal-cycle',
      ));
    }
  }

  // Habits over the last week.
  final week = store.logsBetween(addDays(now, -6), now);
  final waterDays = [for (final l in week) if (l.metrics['water'] != null) l.metrics['water']!];
  final sleepDays = [for (final l in week) if (l.metrics['sleep'] != null) l.metrics['sleep']!];
  if (waterDays.length >= 3 && waterDays.reduce((a, b) => a + b) / waterDays.length < 1500) {
    final avg = (waterDays.reduce((a, b) => a + b) / waterDays.length).round();
    data.add(InsightCard(
      id: 'water-low',
      kind: InsightKind.habit,
      emoji: '💧',
      title: 'Low water intake this week',
      body: 'You averaged about $avg ml a day. Keeping a bottle nearby and drinking with each meal '
          'can help with energy, headaches, and bloating.',
      articleId: 'nutrition-sleep-hydration-basics',
    ));
  } else if (sleepDays.length >= 3 && sleepDays.reduce((a, b) => a + b) / sleepDays.length < 6.5) {
    final avg = sleepDays.reduce((a, b) => a + b) / sleepDays.length;
    data.add(InsightCard(
      id: 'sleep-low',
      kind: InsightKind.habit,
      emoji: '🌙',
      title: 'Short on sleep this week',
      body: 'You averaged ${avg.toStringAsFixed(1)} hours. A steady bedtime and less screen time '
          'before bed can help you get closer to 7-9 hours.',
      articleId: 'nutrition-sleep-hydration-basics',
    ));
  }

  cards.addAll(data.take(3));

  // Fillers: tip, quiz, article.
  final fillers = <InsightCard>[];
  final phase = cycleGoal ? info.phase : null;
  if (phase != null) {
    final tips = _phaseTips[phase]!;
    final t = tips[idx % tips.length];
    fillers.add(InsightCard(
        id: 'tip-phase', kind: InsightKind.tip, emoji: t.$1, title: '${phase.label}: ${t.$2}', body: t.$3));
  }
  final goalTips = _goalTips[goal]!;
  final g = goalTips[idx % goalTips.length];
  fillers.add(InsightCard(id: 'tip-goal', kind: InsightKind.tip, emoji: g.$1, title: g.$2, body: g.$3));

  final quizzes = kQuizzes.where((q) => !q.couples).toList();
  final suited = quizzes.where((q) => q.tags.contains(goal.name)).toList();
  final pool = suited.isEmpty ? quizzes : suited;
  if (pool.isNotEmpty) {
    final q = pool[idx % pool.length];
    fillers.add(InsightCard(
      id: 'quiz-of-day',
      kind: InsightKind.quiz,
      emoji: q.emoji,
      title: 'Quiz of the day: ${q.title}',
      body: q.description,
      quizId: q.id,
    ));
  }

  final recs = recommendedArticles(store, limit: 5);
  if (recs.isNotEmpty) {
    final a = recs[idx % recs.length];
    fillers.add(InsightCard(
      id: 'article-of-day',
      kind: InsightKind.article,
      emoji: a.emoji,
      title: 'Read: ${a.title}',
      body: '${a.category.label} · ${a.minutes} min read',
      articleId: a.id,
    ));
  }

  // Keep the quiz and article, then the tips, within six cards in total.
  final room = 6 - cards.length;
  final priority = [
    ...fillers.where((c) => c.kind == InsightKind.quiz || c.kind == InsightKind.article),
    ...fillers.where((c) => c.kind == InsightKind.tip),
  ].take(room).toSet();
  cards.addAll(fillers.where(priority.contains));
  return cards;
}
