/// Data-driven definitions of every daily-log tracker and its options.
///
/// Labels live here so they stay editable in one place. Option ids are
/// stored in `DayLog.selections` and must never change once released.
library;

import 'models.dart';

class LogOption {
  const LogOption(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;
}

enum CategoryKind { single, multi }

class LogCategory {
  const LogCategory({
    required this.id,
    required this.title,
    required this.emoji,
    required this.options,
    this.kind = CategoryKind.multi,
    this.hiddenIn = const {},
    this.onlyIn,
    this.colorHex = 0xFFE85A79,
  });

  final String id;
  final String title;
  final String emoji;
  final List<LogOption> options;
  final CategoryKind kind;

  /// Goals in which this tracker is hidden.
  final Set<Goal> hiddenIn;

  /// When set, the tracker appears only in these goals.
  final Set<Goal>? onlyIn;

  /// Accent color used for chips in this category.
  final int colorHex;

  bool visibleFor(Goal g) => !hiddenIn.contains(g) && (onlyIn == null || onlyIn!.contains(g));

  LogOption? option(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }
}

/// Numeric trackers. Values are stored in metric units in `DayLog.metrics`.
class MetricDef {
  const MetricDef(this.id, this.title, this.emoji, this.unit, this.min, this.max, this.step,
      {this.hiddenIn = const {}});
  final String id;
  final String title;
  final String emoji;

  /// Storage unit label (metric). Convert for display with `units.dart`.
  final String unit;
  final double min;
  final double max;
  final double step;
  final Set<Goal> hiddenIn;
}

const _noPregnancy = {Goal.trackPregnancy};

const List<LogCategory> kCategories = [
  LogCategory(
    id: 'flow',
    title: 'Menstrual flow',
    emoji: '🩸',
    kind: CategoryKind.single,
    hiddenIn: _noPregnancy,
    colorHex: 0xFFE53958,
    options: [
      LogOption('spotting', 'Spotting', '·'),
      LogOption('light', 'Light', '💧'),
      LogOption('medium', 'Medium', '💧💧'),
      LogOption('heavy', 'Heavy', '💧💧💧'),
    ],
  ),
  LogCategory(
    id: 'clots',
    title: 'Period details',
    emoji: '🔴',
    hiddenIn: _noPregnancy,
    colorHex: 0xFFE53958,
    options: [
      LogOption('clots', 'Blood clots', '🔴'),
      LogOption('dark', 'Dark blood', '🟤'),
      LogOption('bright', 'Bright red', '❤️'),
    ],
  ),
  LogCategory(
    id: 'sex',
    title: 'Sex and sex drive',
    emoji: '❤️',
    colorHex: 0xFFE84F8A,
    options: [
      LogOption('none', "Didn't have sex", '🚫'),
      LogOption('protected', 'Protected sex', '🛡️'),
      LogOption('unprotected', 'Unprotected sex', '💞'),
      LogOption('oral', 'Oral sex', '👄'),
      LogOption('anal', 'Anal sex', '🍑'),
      LogOption('masturbation', 'Masturbation', '✋'),
      LogOption('touch', 'Sensual touch', '🤲'),
      LogOption('toys', 'Sex toys', '🎀'),
      LogOption('orgasm', 'Orgasm', '✨'),
      LogOption('high_drive', 'High sex drive', '🔥'),
      LogOption('neutral_drive', 'Neutral sex drive', '😐'),
      LogOption('low_drive', 'Low sex drive', '🧊'),
    ],
  ),
  LogCategory(
    id: 'mood',
    title: 'Mood',
    emoji: '😊',
    colorHex: 0xFFF2A13B,
    options: [
      LogOption('calm', 'Calm', '😌'),
      LogOption('happy', 'Happy', '😊'),
      LogOption('energetic', 'Energetic', '⚡'),
      LogOption('frisky', 'Frisky', '😏'),
      LogOption('swings', 'Mood swings', '🎢'),
      LogOption('irritated', 'Irritated', '😤'),
      LogOption('sad', 'Sad', '😢'),
      LogOption('anxious', 'Anxious', '😰'),
      LogOption('depressed', 'Depressed', '😞'),
      LogOption('guilty', 'Feeling guilty', '😣'),
      LogOption('obsessive', 'Obsessive thoughts', '🌀'),
      LogOption('apathetic', 'Apathetic', '😶'),
      LogOption('confused', 'Confused', '😵‍💫'),
      LogOption('self_critical', 'Very self-critical', '🪞'),
      LogOption('low_energy', 'Low energy', '🪫'),
    ],
  ),
  LogCategory(
    id: 'symptoms',
    title: 'Symptoms',
    emoji: '🤕',
    colorHex: 0xFF8E6CEF,
    options: [
      LogOption('fine', 'Everything is fine', '👍'),
      LogOption('cramps', 'Cramps', '〰️'),
      LogOption('tender_breasts', 'Tender breasts', '🫶'),
      LogOption('headache', 'Headache', '🤕'),
      LogOption('acne', 'Acne', '🔴'),
      LogOption('backache', 'Backache', '🔙'),
      LogOption('fatigue', 'Fatigue', '😴'),
      LogOption('cravings', 'Cravings', '🍫'),
      LogOption('insomnia', 'Insomnia', '🌙'),
      LogOption('abdominal_pain', 'Abdominal pain', '😖'),
      LogOption('perineum_pain', 'Perineum pain', '⚡'),
      LogOption('swelling', 'Swelling', '🎈'),
      LogOption('joint_pain', 'Joint pain', '🦴'),
      LogOption('dizziness', 'Dizziness', '💫'),
      LogOption('migraine', 'Migraine', '🧠'),
      LogOption('disease', 'Disease or injury', '🩹'),
    ],
  ),
  LogCategory(
    id: 'digestion',
    title: 'Digestion and stool',
    emoji: '🫃',
    colorHex: 0xFF5BB98C,
    options: [
      LogOption('nausea', 'Nausea', '🤢'),
      LogOption('bloating', 'Bloating', '🎈'),
      LogOption('constipation', 'Constipation', '🧱'),
      LogOption('diarrhea', 'Diarrhea', '💨'),
      LogOption('gas', 'Gas', '🌬️'),
    ],
  ),
  LogCategory(
    id: 'discharge',
    title: 'Vaginal discharge',
    emoji: '💧',
    colorHex: 0xFF3FB6C9,
    options: [
      LogOption('none', 'No discharge', '⭕'),
      LogOption('creamy', 'Creamy', '🥛'),
      LogOption('watery', 'Watery', '💧'),
      LogOption('sticky', 'Sticky', '🍯'),
      LogOption('egg_white', 'Egg white', '🥚'),
      LogOption('spotting', 'Spotting', '🩸'),
      LogOption('unusual', 'Unusual', '❓'),
      LogOption('clumpy', 'Clumpy white', '☁️'),
      LogOption('gray', 'Gray', '🩶'),
    ],
  ),
  LogCategory(
    id: 'pregnancy_test',
    title: 'Pregnancy test',
    emoji: '🧪',
    colorHex: 0xFF5AA0E8,
    hiddenIn: {Goal.trackPregnancy, Goal.perimenopause},
    kind: CategoryKind.single,
    options: [
      LogOption('none', "Didn't take tests", '🚫'),
      LogOption('positive', 'Positive', '➕'),
      LogOption('negative', 'Negative', '➖'),
      LogOption('faint', 'Faint line', '〰️'),
    ],
  ),
  LogCategory(
    id: 'ovulation_test',
    title: 'Ovulation test',
    emoji: '🥚',
    colorHex: 0xFF2BB3A3,
    hiddenIn: {Goal.trackPregnancy, Goal.perimenopause, Goal.postpartum},
    kind: CategoryKind.single,
    options: [
      LogOption('none', "Didn't take tests", '🚫'),
      LogOption('positive', 'Test: positive', '➕'),
      LogOption('negative', 'Test: negative', '➖'),
      LogOption('my_method', 'Ovulation: my method', '🔎'),
    ],
  ),
  LogCategory(
    id: 'activity',
    title: 'Physical activity',
    emoji: '🏃',
    colorHex: 0xFF4C9F6B,
    options: [
      LogOption('none', "Didn't exercise", '🛋️'),
      LogOption('yoga', 'Yoga', '🧘'),
      LogOption('gym', 'Gym', '🏋️'),
      LogOption('aerobics', 'Aerobics and dancing', '💃'),
      LogOption('swimming', 'Swimming', '🏊'),
      LogOption('team_sports', 'Team sports', '⚽'),
      LogOption('running', 'Running', '🏃'),
      LogOption('cycling', 'Cycling', '🚴'),
      LogOption('walking', 'Walking', '🚶'),
    ],
  ),
  LogCategory(
    id: 'pill',
    title: 'Oral contraceptives',
    emoji: '💊',
    colorHex: 0xFF7A7FE0,
    hiddenIn: {Goal.trackPregnancy, Goal.getPregnant},
    kind: CategoryKind.single,
    options: [
      LogOption('taken', 'Taken on time', '✅'),
      LogOption('late', 'Taken late', '⏰'),
      LogOption('missed', 'Missed', '❌'),
      LogOption('double', 'Double dose', '✌️'),
    ],
  ),
  LogCategory(
    id: 'products',
    title: 'Menstrual products',
    emoji: '🧺',
    colorHex: 0xFFD7708F,
    hiddenIn: _noPregnancy,
    options: [
      LogOption('pad', 'Pad', '🩹'),
      LogOption('tampon', 'Tampon', '🧵'),
      LogOption('cup', 'Menstrual cup', '🥤'),
      LogOption('underwear', 'Period underwear', '🩲'),
      LogOption('liner', 'Liner', '📏'),
      LogOption('disc', 'Menstrual disc', '💿'),
    ],
  ),
  LogCategory(
    id: 'pregnancy_symptoms',
    title: 'Pregnancy symptoms',
    emoji: '🤰',
    colorHex: 0xFFF0A53C,
    onlyIn: {Goal.trackPregnancy},
    options: [
      LogOption('morning_sickness', 'Morning sickness', '🤢'),
      LogOption('heartburn', 'Heartburn', '🔥'),
      LogOption('leg_cramps', 'Leg cramps', '🦵'),
      LogOption('frequent_urination', 'Frequent urination', '🚻'),
      LogOption('braxton_hicks', 'Braxton Hicks', '〰️'),
      LogOption('back_pain', 'Back pain', '🔙'),
      LogOption('swollen_feet', 'Swollen feet', '🦶'),
      LogOption('baby_moves', 'Baby is moving', '👶'),
      LogOption('food_aversion', 'Food aversion', '🙅'),
      LogOption('stretch_marks', 'Stretch marks', '〰️'),
    ],
  ),
  LogCategory(
    id: 'postpartum',
    title: 'Recovery',
    emoji: '🍼',
    colorHex: 0xFFF0A53C,
    onlyIn: {Goal.postpartum},
    options: [
      LogOption('lochia_heavy', 'Heavy bleeding (lochia)', '🩸'),
      LogOption('lochia_light', 'Light bleeding (lochia)', '💧'),
      LogOption('breastfeeding', 'Breastfeeding', '🤱'),
      LogOption('sore_nipples', 'Sore nipples', '😣'),
      LogOption('engorgement', 'Breast engorgement', '🎈'),
      LogOption('stitches_pain', 'Stitches pain', '🩹'),
      LogOption('baby_blues', 'Baby blues', '🌧️'),
      LogOption('sleep_deprived', 'Sleep deprived', '😵'),
    ],
  ),
  LogCategory(
    id: 'menopause',
    title: 'Perimenopause',
    emoji: '🌡️',
    colorHex: 0xFFE07A5F,
    onlyIn: {Goal.perimenopause},
    options: [
      LogOption('hot_flashes', 'Hot flashes', '🔥'),
      LogOption('night_sweats', 'Night sweats', '💦'),
      LogOption('brain_fog', 'Brain fog', '🌫️'),
      LogOption('vaginal_dryness', 'Vaginal dryness', '🏜️'),
      LogOption('palpitations', 'Heart palpitations', '💓'),
      LogOption('irregular_period', 'Irregular period', '❔'),
      LogOption('hair_thinning', 'Hair thinning', '💇'),
      LogOption('low_libido', 'Low libido', '🧊'),
      LogOption('itchy_skin', 'Itchy skin', '🖐️'),
    ],
  ),
  LogCategory(
    id: 'other',
    title: 'Other',
    emoji: '📌',
    colorHex: 0xFF8C8FA3,
    options: [
      LogOption('travel', 'Travel', '✈️'),
      LogOption('stress', 'Stress', '😫'),
      LogOption('meditation', 'Meditation', '🧘'),
      LogOption('alcohol', 'Alcohol', '🍷'),
      LogOption('journaling', 'Journaling', '📓'),
      LogOption('illness', 'Illness', '🤒'),
      LogOption('kegels', 'Kegel exercises', '💪'),
    ],
  ),
];

const List<MetricDef> kMetrics = [
  MetricDef('water', 'Water', '💧', 'ml', 0, 5000, 250),
  MetricDef('sleep', 'Sleep', '🌙', 'h', 0, 16, 0.5),
  MetricDef('weight', 'Weight', '⚖️', 'kg', 25, 250, 0.1),
  MetricDef('bbt', 'Basal temperature', '🌡️', '°C', 35.0, 38.5, 0.05, hiddenIn: _noPregnancy),
  MetricDef('steps', 'Steps', '👟', 'steps', 0, 60000, 500),
  MetricDef('energy', 'Energy level', '🔋', '/5', 1, 5, 1),
];

LogCategory? categoryById(String id) {
  for (final c in kCategories) {
    if (c.id == id) return c;
  }
  return null;
}

MetricDef? metricById(String id) {
  for (final m in kMetrics) {
    if (m.id == id) return m;
  }
  return null;
}

/// Human label for a logged option, e.g. `('mood', 'happy')` → `Happy`.
String optionLabel(String categoryId, String optionId) =>
    categoryById(categoryId)?.option(optionId)?.label ?? optionId;
