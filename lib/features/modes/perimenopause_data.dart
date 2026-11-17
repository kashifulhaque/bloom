/// Perimenopause score questionnaire, severity bands, stage estimate,
/// and the relief options library. Original, educational content.
library;

import '../../core/dates.dart';

enum Subscale { somatic, psychological, urogenital }

extension SubscaleLabel on Subscale {
  String get label => switch (this) {
    Subscale.somatic => 'Body',
    Subscale.psychological => 'Mind and mood',
    Subscale.urogenital => 'Bladder and intimate health',
  };
}

class ScoreItem {
  const ScoreItem(this.id, this.subscale, this.title, this.question);
  final String id;
  final Subscale subscale;
  final String title;
  final String question;
}

/// The 11 items, each answered 0 (none) to 4 (very severe).
const List<ScoreItem> kScoreItems = [
  ScoreItem(
    'hot_flashes',
    Subscale.somatic,
    'Hot flashes and sweating',
    'Sudden waves of heat, flushing, or sweating, by day or at night',
  ),
  ScoreItem('sleep', Subscale.somatic, 'Sleep problems', 'Trouble falling asleep, staying asleep, or waking too early'),
  ScoreItem('mood', Subscale.psychological, 'Low mood', 'Feeling down, sad, tearful, or lacking motivation'),
  ScoreItem(
    'irritability',
    Subscale.psychological,
    'Irritability',
    'Feeling on edge, short-tempered, or easily annoyed',
  ),
  ScoreItem('anxiety', Subscale.psychological, 'Anxiety', 'Feeling nervous, restless, worried, or panicky'),
  ScoreItem('fatigue', Subscale.psychological, 'Exhaustion', 'Low energy, tiredness, poor focus, or forgetfulness'),
  ScoreItem('sexual', Subscale.urogenital, 'Sexual concerns', 'Changes in desire, arousal, or satisfaction with sex'),
  ScoreItem('bladder', Subscale.urogenital, 'Bladder changes', 'Needing to pee more often or urgently, or leaking'),
  ScoreItem('dryness', Subscale.urogenital, 'Vaginal dryness', 'Dryness, burning, or discomfort, including during sex'),
  ScoreItem('joint', Subscale.somatic, 'Joint and muscle aches', 'Aches, stiffness, or pain in joints or muscles'),
  ScoreItem(
    'heart',
    Subscale.somatic,
    'Heart discomfort',
    'Being aware of your heartbeat, a racing or skipping heart, or chest tightness',
  ),
];

const List<String> kAnswerLabels = ['None', 'Mild', 'Moderate', 'Severe', 'Very severe'];

enum Severity { minimal, mild, moderate, severe }

extension SeverityLabel on Severity {
  String get label => switch (this) {
    Severity.minimal => 'Minimal',
    Severity.mild => 'Mild',
    Severity.moderate => 'Moderate',
    Severity.severe => 'Severe',
  };
}

/// Lower bounds for mild, moderate, and severe.
const Map<Subscale?, List<int>> _cutoffs = {
  null: [5, 9, 17], // total, 0-44
  Subscale.somatic: [3, 5, 9], // 0-16
  Subscale.psychological: [2, 4, 7], // 0-16
  Subscale.urogenital: [1, 2, 4], // 0-12
};

/// Bands a total score (when [subscale] is null) or a subscale score.
Severity bandFor(int score, [Subscale? subscale]) {
  final c = _cutoffs[subscale]!;
  if (score >= c[2]) return Severity.severe;
  if (score >= c[1]) return Severity.moderate;
  if (score >= c[0]) return Severity.mild;
  return Severity.minimal;
}

int maxScore([Subscale? s]) => 4 * (s == null ? kScoreItems.length : kScoreItems.where((i) => i.subscale == s).length);

/// One completed questionnaire.
class ScoreResult {
  ScoreResult(this.date, this.answers) : assert(answers.length == kScoreItems.length);
  final DateTime date;

  /// One value 0-4 per item, in [kScoreItems] order.
  final List<int> answers;

  int get total => answers.fold(0, (a, b) => a + b);

  int subscore(Subscale s) {
    var sum = 0;
    for (var i = 0; i < kScoreItems.length; i++) {
      if (kScoreItems[i].subscale == s) sum += answers[i];
    }
    return sum;
  }

  Severity get severity => bandFor(total);

  /// Item ids scoring 2 or more, highest first, at most [n].
  List<String> topSymptoms([int n = 3]) {
    final idx = [
      for (var i = 0; i < answers.length; i++)
        if (answers[i] >= 2) i,
    ]..sort((a, b) => answers[b].compareTo(answers[a]));
    return [for (final i in idx.take(n)) kScoreItems[i].id];
  }

  Map<String, dynamic> toJson() => {'date': dayKey(date), 'answers': answers, 'total': total};

  static ScoreResult fromJson(Map j) =>
      ScoreResult(parseDayKey(j['date']), [for (final a in j['answers'] as List) (a as num).toInt()]);
}

// ------------------------------------------------------------------ stage

enum MenoStage { unknown, reproductive, earlyTransition, lateTransition, postmenopause }

class StageEstimate {
  const StageEstimate(this.stage, this.title, this.explanation, {this.note});
  final MenoStage stage;
  final String title;
  final String explanation;
  final String? note;
}

/// Educational stage estimate using STRAW+10-style bleeding criteria.
///
/// - 12 months or more since the last period: postmenopause.
/// - A gap of 60 days or more between periods (or since the last one): late transition.
/// - A persistent difference of 7 days or more between consecutive cycle
///   lengths (seen at least twice in the last 10 cycles): early transition.
StageEstimate estimateStage({
  required List<DateTime> periodStarts,
  required List<int> cycleLengths,
  required DateTime today,
  int? age,
}) {
  if (periodStarts.isEmpty) {
    return const StageEstimate(
      MenoStage.unknown,
      'Not enough data yet',
      'Log your periods for a few months to get an estimate of your stage.',
    );
  }
  final starts = [...periodStarts]..sort();
  final sinceLast = daysBetween(starts.last, today);
  String? ageNote;
  if (age != null && age < 40) {
    ageNote = 'Menopause changes before 40 are uncommon. If your cycles have changed, please see a clinician.';
  }

  if (sinceLast >= 365) {
    return StageEstimate(
      MenoStage.postmenopause,
      'Postmenopause',
      'It has been 12 months or more since your last logged period. Menopause is defined as 12 months '
          'in a row without a period, so you are likely past it.',
      note: ageNote ?? 'Any bleeding after menopause should be checked by a clinician.',
    );
  }

  var longGap = sinceLast >= 60;
  for (var i = 1; i < starts.length; i++) {
    if (daysBetween(starts[i], today) > 365) continue;
    if (daysBetween(starts[i - 1], starts[i]) >= 60) longGap = true;
  }
  if (longGap) {
    return StageEstimate(
      MenoStage.lateTransition,
      'Late menopause transition',
      'You have had a gap of 60 days or more between periods. This usually means the final period is '
          'getting closer, often within the next one to three years. Hot flashes are often most common now.',
      note: ageNote,
    );
  }

  final recent = cycleLengths.length > 10 ? cycleLengths.sublist(cycleLengths.length - 10) : cycleLengths;
  var bigChanges = 0;
  for (var i = 1; i < recent.length; i++) {
    if ((recent[i] - recent[i - 1]).abs() >= 7) bigChanges++;
  }
  if (bigChanges >= 2) {
    return StageEstimate(
      MenoStage.earlyTransition,
      'Early menopause transition',
      'Your cycle length keeps changing by 7 days or more from one cycle to the next. This kind of '
          'variability is a typical early sign of perimenopause.',
      note: ageNote,
    );
  }

  return StageEstimate(
    MenoStage.reproductive,
    recent.length < 3 ? 'Too early to tell' : 'Regular cycles',
    recent.length < 3
        ? 'Your logged cycles don\'t show transition patterns yet. Keep logging to refine this estimate.'
        : 'Your cycles look fairly steady. Symptoms can still start before cycles change, and many people '
              'notice changes in their 40s.',
    note: ageNote,
  );
}

// ------------------------------------------------------------------ relief

class ReliefOption {
  const ReliefOption(this.title, this.category, this.tags, this.body);
  final String title;

  /// One of `Lifestyle`, `Self-care`, `Therapy`, `Medical`.
  final String category;

  /// Score item ids this option can help with.
  final Set<String> tags;
  final String body;
}

const List<String> kReliefCategories = ['Lifestyle', 'Self-care', 'Therapy', 'Medical'];

const List<ReliefOption> kReliefOptions = [
  ReliefOption(
    'Move every day',
    'Lifestyle',
    {'mood', 'sleep', 'joint', 'fatigue', 'anxiety'},
    'Aim for regular moderate activity, like brisk walking or cycling, plus strength training twice a week. '
        'It supports mood, sleep, bones, and joints.',
  ),
  ReliefOption(
    'Keep cool',
    'Lifestyle',
    {'hot_flashes', 'sleep'},
    'Dress in layers, keep a fan or cold drink nearby, and keep the bedroom cool. Note what sets off your hot '
        'flashes: spicy food, alcohol, caffeine, and stress are common triggers.',
  ),
  ReliefOption(
    'Food and drink',
    'Lifestyle',
    {'hot_flashes', 'sleep', 'heart', 'joint'},
    'Cutting back on alcohol and caffeine, especially later in the day, can ease flushes and help sleep. '
        'A balanced diet with enough calcium and vitamin D protects your bones.',
  ),
  ReliefOption(
    'Sleep habits',
    'Self-care',
    {'sleep', 'fatigue', 'mood'},
    'Keep regular sleep and wake times, limit screens before bed, and use the bed only for sleep and sex. '
        'If you wake hot, try cotton or moisture-wicking bedding.',
  ),
  ReliefOption(
    'Breathing and mindfulness',
    'Self-care',
    {'anxiety', 'irritability', 'mood', 'hot_flashes'},
    'Slow, paced breathing when a flush starts and short daily mindfulness practice can reduce stress and '
        'help you feel more in control.',
  ),
  ReliefOption(
    'Lubricants and moisturizers',
    'Self-care',
    {'dryness', 'sexual'},
    'Water- or silicone-based lubricants make sex more comfortable. Vaginal moisturizers used a few times a '
        'week help with everyday dryness. Both are available without a prescription.',
  ),
  ReliefOption(
    'Pelvic floor training',
    'Self-care',
    {'bladder', 'sexual'},
    'Regular pelvic floor exercises can reduce leaks and urgency. A pelvic health physiotherapist can check '
        'your technique.',
  ),
  ReliefOption(
    'Talk about it',
    'Self-care',
    {'mood', 'irritability', 'sexual', 'anxiety'},
    'Sharing what you are going through with a partner, friends, or a support group can ease the load and '
        'help others understand.',
  ),
  ReliefOption(
    'Cognitive behavioral therapy (CBT)',
    'Therapy',
    {'hot_flashes', 'sleep', 'mood', 'anxiety'},
    'CBT is a talking therapy with good evidence for reducing how much hot flashes and night sweats bother '
        'you, and for improving sleep and low mood. It is available in person, online, and as self-help.',
  ),
  ReliefOption(
    'Hormone therapy (MHT or HRT)',
    'Medical',
    {'hot_flashes', 'sleep', 'dryness', 'mood', 'joint'},
    'Hormone therapy is the most effective treatment for hot flashes and night sweats for many people. '
        'Benefits and risks depend on your age, health, and history. Discuss whether it suits you with a doctor.',
  ),
  ReliefOption(
    'Non-hormonal medicines',
    'Medical',
    {'hot_flashes', 'sleep', 'mood'},
    'Several non-hormonal prescription options can reduce hot flashes, including some antidepressants and '
        'newer targeted medicines. A doctor can explain which might suit you.',
  ),
  ReliefOption(
    'Vaginal estrogen',
    'Medical',
    {'dryness', 'bladder', 'sexual'},
    'Low-dose estrogen applied in the vagina treats dryness and can reduce urinary symptoms. Very little '
        'reaches the bloodstream. Ask a doctor or nurse about it.',
  ),
  ReliefOption(
    'Check your heart symptoms',
    'Medical',
    {'heart'},
    'Palpitations are common in perimenopause, but tell a doctor about them. Seek urgent help for chest pain, '
        'fainting, or shortness of breath.',
  ),
];

/// Maps `menopause` log options to score item ids.
const Map<String, String> kLogToItem = {
  'hot_flashes': 'hot_flashes',
  'night_sweats': 'hot_flashes',
  'brain_fog': 'fatigue',
  'vaginal_dryness': 'dryness',
  'palpitations': 'heart',
  'low_libido': 'sexual',
};
