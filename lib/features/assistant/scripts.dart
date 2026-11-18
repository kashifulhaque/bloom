/// Offline, scripted assistant: decision trees personalized with local data.
///
/// Each node id maps to a [BotStep]: the messages the assistant sends and
/// the quick replies it offers. [buildStep] is pure, so it's easy to test.
library;

import 'dart:math' as math;

import '../../core/catalog.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../insights/content.dart';

/// A quick reply. Exactly one of [next], [articleId], or [checkerId] is set.
class BotOption {
  const BotOption(this.label, {this.next, this.articleId, this.checkerId});
  final String label;

  /// Node to go to.
  final String? next;

  /// Article to open.
  final String? articleId;

  /// Symptom checker to open: `pcos`, `endometriosis`, or `fibroids`.
  final String? checkerId;
}

class BotStep {
  const BotStep(this.id, this.messages, this.options);
  final String id;
  final List<String> messages;
  final List<BotOption> options;
}

const _menuOpt = BotOption('Other topics', next: 'menu');
const _urgentOpt = BotOption('Urgent warning signs', next: 'urgent');

/// Main menu topics.
const List<BotOption> kTopics = [
  BotOption('My period is late', next: 'late'),
  BotOption('Spotting between periods', next: 'spotting'),
  BotOption('Painful periods', next: 'pain'),
  BotOption('Am I ovulating?', next: 'ovulating'),
  BotOption('Trying to conceive tips', next: 'ttc'),
  BotOption('Explain my cycle', next: 'report'),
  BotOption('Birth control questions', next: 'bc'),
  BotOption('PMS & mood', next: 'pms'),
  BotOption('Perimenopause signs', next: 'peri'),
  BotOption('Discharge changes', next: 'discharge'),
  BotOption('Symptom checker', next: 'checker'),
];

// ------------------------------------------------------------ data helpers

String _days(int n) => '$n day${n == 1 ? '' : 's'}';

/// Logs from the start of the current cycle (or the last 35 days) to today.
List<DayLog> _currentCycleLogs(AppStore s) {
  final e = s.engine;
  final start = e.currentCycle?.start ?? addDays(e.today, -35);
  return s.logsBetween(start, e.today);
}

List<DateTime> _daysWith(List<DayLog> logs, String cat, String opt) =>
    [for (final l in logs) if (l.has(cat, opt)) l.date];

String _dateList(List<DateTime> d) {
  final shown = d.take(4).map(fmtShort).join(', ');
  return d.length > 4 ? '$shown and ${d.length - 4} more' : shown;
}

/// Counts logged options across [cats] in [logs], most frequent first.
List<(String cat, String opt, int n)> topOptions(List<DayLog> logs, List<String> cats, {int limit = 5}) {
  final counts = <(String, String), int>{};
  for (final l in logs) {
    for (final c in cats) {
      for (final o in l.get(c)) {
        if (o == 'fine' || o == 'none') continue;
        counts[(c, o)] = (counts[(c, o)] ?? 0) + 1;
      }
    }
  }
  final list = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in list.take(limit)) (e.key.$1, e.key.$2, e.value)];
}

/// Logged spotting days that are not period days, in the last [days] days.
List<DateTime> spottingOutsidePeriod(AppStore s, {int days = 60}) {
  final t = s.engine.today;
  return [
    for (final l in s.logsBetween(addDays(t, -days), t))
      if ((l.has('flow', 'spotting') || l.has('discharge', 'spotting')) && !s.engine.isOnPeriod(l.date)) l.date,
  ];
}

/// Count of days with [opt] logged during period days of the last three periods.
int _duringRecentPeriods(AppStore s, String cat, String opt) {
  var n = 0;
  for (final p in s.engine.periods.reversed.take(3)) {
    n += _daysWith(s.logsBetween(p.start, p.end), cat, opt).length;
  }
  return n;
}

int? _age(AppStore s) => s.profile.birthYear == null ? null : s.engine.today.year - s.profile.birthYear!;

/// The "extended cycle report": averages, regularity, last six cycles, and
/// top symptoms, as chat messages.
List<String> cycleReport(AppStore s) {
  final e = s.engine;
  if (!e.hasData) {
    return [
      "I don't have any periods logged yet, so there's nothing to report. "
          'Log your last period from the calendar and I can start building your report.',
    ];
  }
  final h = e.health();
  final out = <String>[];
  final completed = e.cycleLengths.length;
  out.add('Here is your cycle report.\n\n'
      '**Average cycle:** ${_days(e.avgCycleLength)}${completed == 0 ? ' (from your settings until you log more cycles)' : ' (from $completed completed cycle${completed == 1 ? '' : 's'})'}\n'
      '**Average period:** ${_days(e.avgPeriodLength)}\n'
      '${e.nextPeriodStart != null ? '**Next period:** ${e.isLate ? '${_days(e.daysLate)} late (was due ${fmtShort(e.nextPeriodStart!)})' : 'around ${fmtShort(e.nextPeriodStart!)}'}' : ''}');

  if (!h.enoughData) {
    out.add('**Regularity:** I need at least two completed cycles to judge regularity. Keep logging your periods.');
  } else {
    final parts = <String>[
      h.regular
          ? 'Your recent cycle lengths vary by ${_days(h.variation)}, which is within the typical range of up to 7 days. Your cycles look regular.'
          : 'Your recent cycle lengths vary by ${_days(h.variation)}. A difference of more than 7 days counts as irregular.',
      h.cycleNormal
          ? 'Every recent cycle was between 21 and 35 days, the usual adult range.'
          : 'At least one recent cycle was shorter than 21 or longer than 35 days.',
      h.periodNormal
          ? 'Your periods last between 2 and 7 days, which is typical.'
          : 'At least one recent period was shorter than 2 or longer than 7 days.',
    ];
    out.add('**Regularity:** ${parts.join(' ')}');
  }

  final recent = e.cycles.reversed.take(6).toList();
  final rows = [
    for (final c in recent)
      '- ${fmtShort(c.start)}: ${c.length == null ? 'current, day ${daysBetween(c.start, e.today) + 1}' : _days(c.length!)}, period ${_days(c.period.length)}',
  ];
  out.add('**Last ${recent.length} cycle${recent.length == 1 ? '' : 's'}:**\n${rows.join('\n')}');

  final from = recent.last.start;
  final top = topOptions(s.logsBetween(from, e.today), const ['symptoms', 'digestion', 'mood', 'menopause']);
  if (top.isEmpty) {
    out.add('**Top symptoms:** none logged in these cycles yet.');
  } else {
    out.add('**Top symptoms:**\n${[for (final t in top) '- ${optionLabel(t.$1, t.$2)}: ${_days(t.$3)}'].join('\n')}');
  }
  if (h.enoughData && (!h.regular || !h.cycleNormal || !h.periodNormal)) {
    out.add('Some of these numbers are outside the typical ranges. That can be normal for you, '
        'but it is worth mentioning to a clinician, especially if it is new.');
  }
  return out;
}

// ------------------------------------------------------------ the tree

/// Builds the step for node [id] using the user's data.
BotStep buildStep(String id, AppStore s) {
  final e = s.engine;
  final cur = _currentCycleLogs(s);

  switch (id) {
    case 'start':
      final name = s.profile.name.trim();
      return BotStep(id, [
        'Hi${name.isEmpty ? '' : ' $name'}! I am Bloom\'s offline assistant. I use what you have logged on this '
            'device to answer common questions. Nothing leaves your phone.',
        'I am not a doctor and I can\'t diagnose anything. If you ever have severe pain, very heavy bleeding, '
            'fainting, or thoughts of harming yourself, contact emergency services right away.',
        'What would you like to talk about?',
      ], kTopics);

    case 'menu':
      return const BotStep('menu', ['What would you like to talk about?'], kTopics);

    case 'urgent':
      return const BotStep('urgent', [
        '**Get urgent medical care now** (call your local emergency number or go to an emergency department) if you have:\n'
            '- Sudden, severe pain in your belly or pelvis, especially on one side\n'
            '- Bleeding that soaks a pad or tampon every hour for two hours or more\n'
            '- Fainting, dizziness, or a racing heart with bleeding\n'
            '- A positive pregnancy test with pain or bleeding\n'
            '- Fever with pelvic pain or unusual discharge\n'
            '- Bleeding after menopause that is heavy, or any bleeding with these signs\n'
            '- Thoughts of harming yourself',
        'If something feels very wrong, trust that feeling and get help.',
      ], [_menuOpt]);

    case 'crisis':
      return const BotStep('crisis', [
        'I am really glad you told me. You deserve support right now.',
        'If you might act on thoughts of harming yourself, **call your local emergency number now**, or contact a '
            'suicide and crisis line in your country. If you can, reach out to someone you trust and let them know '
            'how you feel.',
        'Mood changes linked to your cycle, such as PMDD, are real and treatable. A clinician can help.',
      ], [BotOption('About PMDD', articleId: 'cond-pmdd'), _menuOpt]);

    // ---------------------------------------------------------- late period
    case 'late':
      if (!e.hasData) {
        return const BotStep('late', [
          "I don't have a period logged yet, so I can't tell if you're late. Log your last period in the calendar "
              'and I can work it out.',
          'In the meantime, I can explain common reasons periods come late.',
        ], [
          BotOption('Could I be pregnant?', next: 'late_preg'),
          BotOption('Other reasons for a delay', next: 'late_causes'),
          _menuOpt,
        ]);
      }
      final due = e.nextPeriodStart!;
      final msgs = <String>[];
      if (e.isLate) {
        msgs.add('Based on your average cycle of ${_days(e.avgCycleLength)}, your period was due on '
            '${fmtShort(due)}. That makes it **${_days(e.daysLate)} late**.');
        msgs.add(e.daysLate <= 7
            ? 'A delay of up to a week happens to most people now and then.'
            : 'A delay of more than a week is worth looking into.');
      } else if (e.isOnPeriod(e.today)) {
        msgs.add('You have a period logged for today, so it doesn\'t look late. If this bleeding feels different '
            'from your usual period, tell me more under "Spotting between periods".');
      } else {
        msgs.add('By my estimate your period isn\'t late yet. It\'s due around ${fmtShort(due)}, '
            'in ${_days(e.daysUntilNextPeriod!)}.');
        msgs.add('Cycles often shift by a few days, so a period up to a week after the estimate is common.');
      }
      if (s.profile.irregular || (e.health().enoughData && !e.health().regular)) {
        msgs.add('Your cycles vary quite a bit, so my estimate is less certain than usual.');
      }
      return BotStep('late', msgs, const [
        BotOption('Could I be pregnant?', next: 'late_preg'),
        BotOption('Other reasons for a delay', next: 'late_causes'),
        BotOption('When should I see someone?', next: 'late_doctor'),
        _menuOpt,
      ]);

    case 'late_preg':
      final unprotected = _daysWith(cur, 'sex', 'unprotected');
      final protected = _daysWith(cur, 'sex', 'protected');
      final positive = _daysWith(cur, 'pregnancy_test', 'positive') + _daysWith(cur, 'pregnancy_test', 'faint');
      final negative = _daysWith(cur, 'pregnancy_test', 'negative');
      final missedPill = _daysWith(cur, 'pill', 'missed');
      final msgs = <String>[];
      if (positive.isNotEmpty) {
        msgs.add('You logged a positive or faint pregnancy test on ${_dateList(positive)}. A faint line usually '
            'still means positive.');
      } else if (unprotected.isNotEmpty) {
        msgs.add('You logged unprotected sex this cycle on ${_dateList(unprotected)}, so pregnancy is possible.');
      } else if (protected.isNotEmpty) {
        msgs.add('You logged only protected sex this cycle. Condoms and other methods work well but are not '
            'perfect, so a test can still give you peace of mind.');
      } else {
        msgs.add('I don\'t see sex logged this cycle. If you had sex that wasn\'t logged, pregnancy may still be possible.');
      }
      if (missedPill.isNotEmpty) {
        msgs.add('You also logged a missed pill on ${_dateList(missedPill)}, which can lower protection.');
      }
      if (negative.isNotEmpty && positive.isEmpty) {
        msgs.add('You logged a negative test on ${_dateList(negative)}.');
      }
      msgs.add('Home tests are most reliable from the first day your period was due. Testing with your first '
          'morning urine gives the strongest result.');
      return BotStep('late_preg', msgs, const [
        BotOption('My test was negative', next: 'late_negative'),
        BotOption('My test was positive', next: 'late_positive'),
        BotOption("I haven't tested yet", next: 'late_test_tips'),
        _menuOpt,
      ]);

    case 'late_test_tips':
      return const BotStep('late_test_tips', [
        'A few tips for an accurate home test:\n'
            '- Wait until the day your period is due, or later\n'
            '- Use first morning urine if you can\n'
            '- Read the result in the time window on the pack, not hours later\n'
            '- Any visible second line, even a faint one, usually means positive',
        'If it\'s negative and your period still hasn\'t come, test again in a few days.',
      ], [
        BotOption('My test was negative', next: 'late_negative'),
        BotOption('My test was positive', next: 'late_positive'),
        _menuOpt,
      ]);

    case 'late_negative':
      return const BotStep('late_negative', [
        'A negative test right around a missed period can be too early. If your period hasn\'t started, '
            'test again in three to five days.',
        'If you get two negative tests a few days apart, pregnancy is unlikely, and the delay probably has '
            'another cause.',
      ], [
        BotOption('Other reasons for a delay', next: 'late_causes'),
        BotOption('When should I see someone?', next: 'late_doctor'),
        _menuOpt,
      ]);

    case 'late_positive':
      return BotStep('late_positive', [
        'Thank you for sharing that. However you feel right now is valid.',
        'Next steps:\n'
            '- Book a visit with a clinician to confirm the pregnancy and talk through your options\n'
            '- If you plan to continue, start a daily folic acid supplement if you haven\'t already\n'
            '- If you are tracking the pregnancy here, you can switch your goal to "Track pregnancy" in your profile',
        '**Get urgent care** if you have a positive test with sharp pain on one side, shoulder-tip pain, '
            'fainting, or heavy bleeding. These can be signs of an ectopic pregnancy.',
      ], [
        const BotOption('Early pregnancy signs', articleId: 'early-pregnancy-signs'),
        if (s.profile.goal != Goal.trackPregnancy) const BotOption('First trimester basics', articleId: 'first-trimester-basics'),
        _menuOpt,
      ]);

    case 'late_causes':
      final recent = s.logsBetween(addDays(e.today, -35), e.today);
      final stress = _daysWith(recent, 'other', 'stress').length;
      final travel = _daysWith(recent, 'other', 'travel').length;
      final ill = _daysWith(recent, 'other', 'illness').length;
      final personal = <String>[
        if (stress > 0) 'stress on ${_days(stress)}',
        if (travel > 0) 'travel on ${_days(travel)}',
        if (ill > 0) 'illness on ${_days(ill)}',
      ];
      return BotStep('late_causes', [
        'Besides pregnancy, common reasons for a late period include:\n'
            '- Stress, which can delay ovulation and so delay your period\n'
            '- Illness, travel, or big changes in sleep or routine\n'
            '- Big changes in weight, eating, or exercise\n'
            '- Starting, stopping, or changing hormonal birth control\n'
            '- Breastfeeding\n'
            '- Conditions such as PCOS or thyroid problems\n'
            '- Perimenopause, usually in your 40s',
        if (personal.isNotEmpty)
          'In the last five weeks you logged ${personal.join(', ')}. That may have played a part.',
        if ((_age(s) ?? 0) >= 40) 'At your age, perimenopause can also make cycles less predictable.',
      ], const [
        BotOption('When should I see someone?', next: 'late_doctor'),
        BotOption('PCOS symptom checker', checkerId: 'pcos'),
        BotOption('Read: stress and your cycle', articleId: 'mood-stress-and-cycle'),
        _menuOpt,
      ]);

    case 'late_doctor':
      return const BotStep('late_doctor', [
        'Consider seeing a clinician if:\n'
            '- You have missed three periods in a row and are not pregnant\n'
            '- Your cycles are often longer than 35 days\n'
            '- Your periods stopped after being regular\n'
            '- You have a positive pregnancy test\n'
            '- A late period comes with unusual pain, fever, or very heavy bleeding',
        'Bring your cycle history from this app. The doctor report can help.',
      ], [_urgentOpt, _menuOpt]);

    // ---------------------------------------------------------- spotting
    case 'spotting':
      final spots = spottingOutsidePeriod(s);
      return BotStep('spotting', [
        'Spotting is light bleeding outside your period, often just a few drops of pink or brown. It is common '
            'and often harmless, but it is worth understanding.',
        spots.isEmpty
            ? 'I don\'t see spotting outside your periods in the last two months.'
            : 'You logged spotting outside your period on ${_dateList(spots)} in the last two months.',
        'When does your spotting usually happen?',
      ], const [
        BotOption('Mid-cycle', next: 'spot_ovulation'),
        BotOption('Just before my period', next: 'spot_before'),
        BotOption('After sex', next: 'spot_sex'),
        BotOption("I'm on hormonal birth control", next: 'spot_bc'),
        BotOption("I'm pregnant", next: 'spot_preg'),
        BotOption('No clear pattern', next: 'spot_doctor'),
      ]);

    case 'spot_ovulation':
      final ov = e.currentCycle?.ovulation;
      return BotStep('spot_ovulation', [
        'Light spotting around ovulation happens to some people. A brief dip in estrogen can cause a day or two '
            'of pink or brown discharge.',
        if (ov != null) 'For your current cycle, I estimate ovulation around ${fmtShort(ov)}.',
        'If it lasts more than a couple of days or happens every cycle, mention it at your next checkup.',
      ], const [
        BotOption('When should I get it checked?', next: 'spot_doctor'),
        BotOption('Read: spotting between periods', articleId: 'spotting-between-periods'),
        _menuOpt,
      ]);

    case 'spot_before':
      return const BotStep('spot_before', [
        'Brown spotting a day or two before your period is often just the start of your period. '
            'Some people log it as their first day, others wait for a steady flow. Either is fine if you are consistent.',
        'Spotting for many days before every period can sometimes point to low progesterone, polyps, or '
            'endometriosis, so it\'s worth raising with a clinician.',
      ], [
        BotOption('Endometriosis symptom checker', checkerId: 'endometriosis'),
        BotOption('When should I get it checked?', next: 'spot_doctor'),
        _menuOpt,
      ]);

    case 'spot_sex':
      return const BotStep('spot_sex', [
        'Bleeding after sex can come from friction or dryness, but it can also be caused by infections, '
            'cervical changes, or polyps.',
        'If it happens more than once, see a clinician. Make sure your cervical screening is up to date, '
            'and consider an STI test if you have a new partner.',
      ], [
        BotOption('Read: painful sex', articleId: 'painful-sex'),
        _urgentOpt,
        _menuOpt,
      ]);

    case 'spot_bc':
      final missed = _daysWith(cur, 'pill', 'missed') + _daysWith(cur, 'pill', 'late');
      return BotStep('spot_bc', [
        'Breakthrough bleeding is common in the first three months of a new hormonal method, and with '
            'implants, hormonal IUDs, and continuous pills.',
        if (missed.isNotEmpty)
          'You logged a missed or late pill on ${_dateList(missed)}. Missed pills often cause spotting, and they '
              'can also lower protection, so check your pack leaflet.'
        else
          'Taking pills at the same time each day helps reduce spotting.',
        'If spotting continues after three months, is heavy, or comes with pain, talk to your clinician. '
            'A different method may suit you better.',
      ], const [
        BotOption('Missed pill help', next: 'bc_missed'),
        _menuOpt,
      ]);

    case 'spot_preg':
      return const BotStep('spot_preg', [
        'Light spotting in early pregnancy is fairly common, for example around the time of implantation or '
            'after a cervical exam or sex.',
        'Always tell your pregnancy care team about any bleeding. **Get urgent care** if the bleeding is heavy, '
            'or comes with cramping, one-sided pain, shoulder-tip pain, or dizziness.',
      ], [_urgentOpt, _menuOpt]);

    case 'spot_doctor':
      return const BotStep('spot_doctor', [
        'See a clinician about spotting if:\n'
            '- It happens in more than one cycle\n'
            '- It happens after sex\n'
            '- You are pregnant\n'
            '- You have gone through menopause (any bleeding after 12 months without a period)\n'
            '- It comes with pain, fever, or unusual discharge',
        'Logging when it happens helps your clinician spot a pattern.',
      ], [
        BotOption('Read: spotting between periods', articleId: 'spotting-between-periods'),
        _menuOpt,
      ]);

    // ---------------------------------------------------------- pain
    case 'pain':
      final cramps = _duringRecentPeriods(s, 'symptoms', 'cramps');
      final periodsCount = math.min(3, e.periods.length);
      return BotStep('pain', [
        'Period cramps happen when the uterus contracts to shed its lining. Mild to moderate cramps in the '
            'first day or two are very common.',
        if (periodsCount > 0)
          cramps == 0
              ? 'You haven\'t logged cramps during your last ${periodsCount == 1 ? 'period' : '$periodsCount periods'}.'
              : 'You logged cramps on ${_days(cramps)} during your last ${periodsCount == 1 ? 'period' : '$periodsCount periods'}.',
        'How bad is your pain usually?',
      ], const [
        BotOption('Uncomfortable but manageable', next: 'pain_relief'),
        BotOption('It stops me doing things', next: 'pain_severe'),
        BotOption('Sudden, severe, or with fever', next: 'urgent'),
      ]);

    case 'pain_relief':
      return const BotStep('pain_relief', [
        'Things that help many people:\n'
            '- Heat on your lower belly or back, or a warm bath\n'
            '- Over-the-counter anti-inflammatory pain relief, started early, if it is safe for you (check the label or ask a pharmacist)\n'
            '- Gentle movement, such as walking, stretching, or yoga\n'
            '- Rest, hydration, and regular meals\n'
            '- Hormonal birth control, which can reduce cramps for some people',
        'If your pain is getting worse over time, talk to a clinician.',
      ], [
        BotOption('Read: easing cramps', articleId: 'easing-cramps'),
        BotOption('It stops me doing things', next: 'pain_severe'),
        _menuOpt,
      ]);

    case 'pain_severe':
      return const BotStep('pain_severe', [
        'Pain that makes you miss school, work, or plans is not something you just have to live with.',
        'Severe period pain can be a sign of conditions such as endometriosis, adenomyosis, or fibroids. '
            'A clinician can look into it and offer treatment.',
        'A symptom checker can help you organize what to tell them.',
      ], [
        BotOption('Endometriosis checker', checkerId: 'endometriosis'),
        BotOption('Fibroids checker', checkerId: 'fibroids'),
        _urgentOpt,
        _menuOpt,
      ]);

    // ---------------------------------------------------------- ovulation
    case 'ovulating':
      final msgs = <String>[];
      final c = e.currentCycle;
      if (c == null) {
        msgs.add('Log your last period and I can estimate when you ovulate.');
      } else {
        final positiveLh = _daysWith(cur, 'ovulation_test', 'positive');
        final eggWhite = _daysWith(cur, 'discharge', 'egg_white');
        final ovPast = !c.ovulation.isAfter(e.today);
        msgs.add('For your current cycle, I estimate ovulation ${ovPast ? 'happened' : 'will happen'} around '
            '**${fmtShort(c.ovulation)}**, with your fertile window from ${fmtShort(c.fertileStart)} to '
            '${fmtShort(c.fertileEnd)}.');
        if (positiveLh.isNotEmpty) {
          msgs.add('You logged a positive ovulation test on ${_dateList(positiveLh)}. Ovulation usually follows '
              'within about a day or so, which is a good sign that you ovulated.');
        }
        if (eggWhite.isNotEmpty) {
          msgs.add('You logged egg-white discharge on ${_dateList(eggWhite)}. That stretchy, clear discharge is '
              'a typical fertile sign.');
        }
        if (positiveLh.isEmpty && eggWhite.isEmpty) {
          msgs.add('This estimate is based on your cycle length. Logging ovulation tests, basal temperature, or '
              'discharge makes it more accurate.');
        }
      }
      msgs.add('Most people with regular cycles between 21 and 35 days ovulate most months.');
      return BotStep('ovulating', msgs, const [
        BotOption('Signs of ovulation', next: 'ov_signs'),
        BotOption('How to confirm it', next: 'ov_confirm'),
        BotOption('My cycles are irregular', next: 'ov_irregular'),
        _menuOpt,
      ]);

    case 'ov_signs':
      return const BotStep('ov_signs', [
        'Common signs that ovulation is near:\n'
            '- Clear, slippery, stretchy discharge like raw egg white\n'
            '- A positive ovulation (LH) test\n'
            '- Higher sex drive\n'
            '- Mild one-sided pelvic twinge for some people\n'
            '- A small rise in basal temperature after ovulation',
      ], [
        BotOption('How to confirm it', next: 'ov_confirm'),
        BotOption('Read: fertile signs', articleId: 'fertile-signs'),
        _menuOpt,
      ]);

    case 'ov_confirm':
      final bbtDays = cur.where((l) => l.metrics['bbt'] != null).length;
      return BotStep('ov_confirm', [
        'Ways to check:\n'
            '- **Ovulation tests** detect the LH surge 1-2 days before ovulation\n'
            '- **Basal body temperature**, taken right after waking, rises slightly after ovulation and stays up\n'
            '- **Discharge** becomes clear and stretchy near ovulation\n'
            '- A **blood test** for progesterone about a week before your period can confirm it',
        bbtDays == 0
            ? 'You haven\'t logged temperatures this cycle. Log them daily and I\'ll look for the rise.'
            : 'You logged your temperature on ${_days(bbtDays)} this cycle. I look for three readings higher than the six before them.',
      ], const [_menuOpt]);

    case 'ov_irregular':
      final h = e.health();
      return BotStep('ov_irregular', [
        if (h.enoughData)
          'Your recent cycles vary by ${_days(h.variation)}${h.regular ? ', which is still in the typical range.' : ', which counts as irregular.'}',
        'With irregular cycles, ovulation is harder to predict and may not happen every month. '
            'Ovulation tests and temperature tracking help more than calendar estimates.',
        'Common causes include PCOS, thyroid problems, stress, big weight changes, and perimenopause. '
            'A clinician can check if your cycles are often longer than 35 days.',
      ], const [
        BotOption('PCOS symptom checker', checkerId: 'pcos'),
        BotOption('Read: thyroid and your cycle', articleId: 'cond-thyroid'),
        _menuOpt,
      ]);

    // ---------------------------------------------------------- TTC
    case 'ttc':
      final msgs = <String>['Trying to conceive can be exciting and stressful. Here is what matters most.'];
      final next = e.futureCycles(1);
      final c = e.currentCycle;
      if (c != null && !c.fertileEnd.isBefore(e.today)) {
        msgs.add('Your current fertile window is estimated from **${fmtShort(c.fertileStart)}** to '
            '**${fmtShort(c.fertileEnd)}**.');
      } else if (next.isNotEmpty) {
        final ov = next.first.ovulation;
        msgs.add('Your next fertile window is estimated around **${fmtShort(addDays(ov, -5))}** to '
            '**${fmtShort(addDays(ov, 1))}**.');
      } else {
        msgs.add('Log your period so I can estimate your fertile window.');
      }
      return BotStep('ttc', msgs, const [
        BotOption('Timing sex', next: 'ttc_timing'),
        BotOption('Healthy habits', next: 'ttc_lifestyle'),
        BotOption('How long before getting help?', next: 'ttc_doctor'),
        _menuOpt,
      ]);

    case 'ttc_timing':
      final unprotected = _daysWith(cur, 'sex', 'unprotected');
      final c = e.currentCycle;
      final inWindow = c == null
          ? 0
          : unprotected.where((d) => !d.isBefore(c.fertileStart) && !d.isAfter(c.fertileEnd)).length;
      return BotStep('ttc_timing', [
        'Sperm can live up to about five days, and an egg about a day. So the best days are the few days before '
            'ovulation and the day of ovulation.',
        'Sex every one to two days during your fertile window gives good chances, without the pressure of '
            'hitting one exact day.',
        if (unprotected.isNotEmpty)
          'This cycle you logged unprotected sex on ${_days(unprotected.length)}, with $inWindow in your estimated fertile window.',
      ], const [
        BotOption('Read: timing sex', articleId: 'timing-sex-ttc'),
        BotOption('Am I ovulating?', next: 'ovulating'),
        _menuOpt,
      ]);

    case 'ttc_lifestyle':
      return const BotStep('ttc_lifestyle', [
        'Habits that support fertility for both partners:\n'
            '- Take a daily folic acid supplement, ideally starting before conception\n'
            '- Stop smoking and limit alcohol\n'
            '- Aim for a healthy weight with balanced meals and regular activity\n'
            '- Keep caffeine moderate\n'
            '- Review any medicines with a clinician\n'
            '- Look after your sleep and stress levels',
      ], [
        BotOption('Read: preconception checklist', articleId: 'preconception-checklist'),
        _menuOpt,
      ]);

    case 'ttc_doctor':
      final age = _age(s);
      return BotStep('ttc_doctor', [
        'General guidance is to talk to a clinician if you have been trying for:\n'
            '- 12 months if you are under 35\n'
            '- 6 months if you are 35 or older\n'
            '- Sooner if you are over 40, have irregular or absent periods, known conditions like PCOS or '
            'endometriosis, or a partner with known fertility concerns',
        if (age != null) 'Based on your birth year, you are about $age, so the ${age >= 35 ? '6-month' : '12-month'} guide applies to you.',
        if (e.health().enoughData && !e.health().regular)
          'Your cycles look irregular, which is a good reason to check in earlier.',
      ], const [_menuOpt]);

    // ---------------------------------------------------------- report
    case 'report':
      return BotStep('report', cycleReport(s), const [
        BotOption("What's a normal cycle?", articleId: 'normal-cycle'),
        BotOption('Am I ovulating?', next: 'ovulating'),
        _menuOpt,
      ]);

    // ---------------------------------------------------------- birth control
    case 'bc':
      return const BotStep('bc', [
        'I can help with common birth control questions. What would you like to know?',
      ], [
        BotOption('Comparing methods', next: 'bc_methods'),
        BotOption('I missed a pill', next: 'bc_missed'),
        BotOption('Emergency contraception', next: 'bc_ec'),
        BotOption('Bleeding on birth control', next: 'spot_bc'),
        _menuOpt,
      ]);

    case 'bc_methods':
      return const BotStep('bc_methods', [
        'Methods differ most in how much they depend on you remembering them:\n'
            '- **Implant and IUDs** last for years and are the most effective in everyday use\n'
            '- **Injection** every few months\n'
            '- **Pill, patch, and ring** need daily, weekly, or monthly attention\n'
            '- **Condoms** are the only method that also protects against STIs\n'
            '- **Fertility awareness** needs careful daily tracking and is less effective in typical use',
        'A clinician or sexual health service can help you pick one that suits your health and plans.',
      ], [
        BotOption('Read: methods overview', articleId: 'contra-methods-overview'),
        BotOption('Read: long-acting methods', articleId: 'contra-long-acting'),
        _menuOpt,
      ]);

    case 'bc_missed':
      final missed = _daysWith(s.logsBetween(addDays(e.today, -7), e.today), 'pill', 'missed');
      return BotStep('bc_missed', [
        if (missed.isNotEmpty) 'You logged a missed pill on ${_dateList(missed)}.',
        'Rules differ by pill type, so **check your pack leaflet** first. As a general guide:\n'
            '- Take the missed pill as soon as you remember, even if that means two in one day\n'
            '- Keep taking the rest of the pack as usual\n'
            '- Use condoms or avoid sex for the next seven days if the leaflet says your protection may be reduced\n'
            '- If you had unprotected sex in the last few days, emergency contraception may be an option',
        'A pharmacist can quickly tell you what applies to your pill.',
      ], const [
        BotOption('Emergency contraception', next: 'bc_ec'),
        BotOption('Read: missed pills', articleId: 'contra-pill-missed'),
        _menuOpt,
      ]);

    case 'bc_ec':
      return const BotStep('bc_ec', [
        'Emergency contraception can prevent pregnancy after unprotected sex or a contraception mistake. '
            '**The sooner you use it, the better it works.**',
        'Options include emergency pills, available from pharmacies in many countries, and a copper IUD fitted by '
            'a clinician, which is the most effective option and can be used up to about five days after sex.',
        'It is not an abortion pill and will not affect an existing pregnancy.',
      ], [
        BotOption('Read: emergency contraception', articleId: 'contra-emergency'),
        _menuOpt,
      ]);

    // ---------------------------------------------------------- PMS
    case 'pms':
      final msgs = <String>[
        'PMS is a mix of physical and emotional changes in the week or two before your period. '
            'It usually eases within a few days of bleeding.',
      ];
      final luteal = <DayLog>[];
      for (final p in e.periods.reversed.take(3)) {
        luteal.addAll(s.logsBetween(addDays(p.start, -7), addDays(p.start, -1)));
      }
      final top = topOptions(luteal, const ['mood', 'symptoms', 'digestion'], limit: 3)
          .where((t) => !{'calm', 'happy', 'energetic', 'frisky'}.contains(t.$2))
          .toList();
      if (top.isNotEmpty) {
        msgs.add('In the week before your recent periods, you most often logged: '
            '${top.map((t) => optionLabel(t.$1, t.$2).toLowerCase()).join(', ')}.');
      }
      final until = e.daysUntilNextPeriod;
      if (until != null && until >= 0 && until <= 7) {
        msgs.add('Your period is due in about ${_days(until)}, so you may be in your PMS window now.');
      }
      return BotStep('pms', msgs, const [
        BotOption('What helps?', next: 'pms_relief'),
        BotOption('It feels severe', next: 'pms_pmdd'),
        _menuOpt,
      ]);

    case 'pms_relief':
      return const BotStep('pms_relief', [
        'Things that often help:\n'
            '- Regular movement, even short walks\n'
            '- Steady meals with protein and fiber, and less salt, caffeine, and alcohol\n'
            '- Consistent sleep\n'
            '- Planning lighter days when you know PMS is likely\n'
            '- Telling the people close to you what you need',
        'If symptoms affect your work or relationships, a clinician can suggest treatments.',
      ], [
        BotOption('Read: PMS vs everyday moods', articleId: 'mood-pms-vs-everyday'),
        _menuOpt,
      ]);

    case 'pms_pmdd':
      return const BotStep('pms_pmdd', [
        'When mood symptoms before your period are severe, such as deep sadness, hopelessness, anger, or anxiety '
            'that disrupts your life, it may be PMDD (premenstrual dysphoric disorder).',
        'PMDD is a real, treatable condition. Tracking your moods for two cycles helps a clinician recognize it.',
        'If you ever have thoughts of harming yourself, **contact emergency services or a crisis line now**.',
      ], [
        BotOption('Read: PMDD', articleId: 'cond-pmdd'),
        BotOption('I need support now', next: 'crisis'),
        _menuOpt,
      ]);

    // ---------------------------------------------------------- perimenopause
    case 'peri':
      final age = _age(s);
      final h = e.health();
      final logged = topOptions(s.logsBetween(addDays(e.today, -60), e.today), const ['menopause'], limit: 3);
      return BotStep('peri', [
        'Perimenopause is the transition before your periods stop for good. It often starts in your 40s and '
            'can last several years.',
        'Common signs:\n'
            '- Cycles that get shorter, longer, or less predictable\n'
            '- Hot flashes and night sweats\n'
            '- Trouble sleeping, mood changes, or brain fog\n'
            '- Vaginal dryness or lower sex drive\n'
            '- Heavier or lighter periods',
        if (age != null) 'You are about $age${age >= 40 ? ', an age when these changes are common.' : '. Perimenopause before 40 is less common, so mention symptoms to a clinician.'}',
        if (h.enoughData && !h.regular) 'Your recent cycles vary by ${_days(h.variation)}, which is more than typical.',
        if (logged.isNotEmpty)
          'In the last two months you logged: ${logged.map((t) => '${optionLabel(t.$1, t.$2).toLowerCase()} (${_days(t.$3)})').join(', ')}.',
      ], const [
        BotOption('Managing hot flashes', articleId: 'peri-hot-flashes'),
        BotOption('Do I still need contraception?', next: 'peri_bc'),
        BotOption('When to see someone', next: 'peri_doctor'),
        _menuOpt,
      ]);

    case 'peri_bc':
      return const BotStep('peri_bc', [
        'Yes, pregnancy is still possible during perimenopause, even with irregular periods.',
        'General guidance is to keep using contraception until you have gone 12 months without a period if you '
            'are over 50, or 2 years if you are under 50. A clinician can advise on what suits you.',
      ], [_menuOpt]);

    case 'peri_doctor':
      return const BotStep('peri_doctor', [
        'See a clinician if:\n'
            '- Symptoms affect your sleep, work, or relationships\n'
            '- Periods become very heavy, or come closer than every three weeks\n'
            '- You bleed after sex or between periods\n'
            '- You have any bleeding after 12 months without a period',
        'Many treatments, from lifestyle changes to hormone therapy, can help. You don\'t have to put up with it.',
      ], [
        BotOption('Read: what is perimenopause', articleId: 'peri-what-is-it'),
        _menuOpt,
      ]);

    // ---------------------------------------------------------- discharge
    case 'discharge':
      final logged = topOptions(cur, const ['discharge'], limit: 4);
      return BotStep('discharge', [
        'Discharge changes through your cycle. It\'s often dry or sticky after your period, creamy as estrogen '
            'rises, and clear and stretchy around ovulation.',
        if (logged.isNotEmpty)
          'This cycle you logged: ${logged.map((t) => '${optionLabel(t.$1, t.$2).toLowerCase()} (${_days(t.$3)})').join(', ')}.',
        'What are you noticing?',
      ], const [
        BotOption('Clear and stretchy', next: 'dis_normal'),
        BotOption('Thick, white, itchy', next: 'dis_yeast'),
        BotOption('Gray or fishy smell', next: 'dis_bv'),
        BotOption('Yellow, green, or with pain', next: 'dis_sti'),
        BotOption('Brown', next: 'dis_brown'),
      ]);

    case 'dis_normal':
      return const BotStep('dis_normal', [
        'Clear, slippery, stretchy discharge is a normal sign of your fertile window. It helps sperm travel and '
            'usually lasts a few days around ovulation.',
      ], [
        BotOption('Am I ovulating?', next: 'ovulating'),
        _menuOpt,
      ]);

    case 'dis_yeast':
      return const BotStep('dis_yeast', [
        'Thick, white, clumpy discharge with itching or soreness often points to a yeast infection.',
        'Pharmacies sell treatments, but see a clinician if it\'s your first time, you are pregnant, it keeps '
            'coming back, or treatment doesn\'t help.',
      ], [_menuOpt]);

    case 'dis_bv':
      return const BotStep('dis_bv', [
        'Thin gray or white discharge with a fishy smell, often stronger after sex, is a common sign of bacterial '
            'vaginosis (BV).',
        'BV usually needs treatment from a clinician, and it\'s important to treat if you are pregnant. '
            'Avoid douching, which can make it worse.',
      ], [_menuOpt]);

    case 'dis_sti':
      return const BotStep('dis_sti', [
        'Yellow or green discharge, a frothy texture, a bad smell, or discharge with pain when you pee or during '
            'sex can be signs of an infection, including some STIs.',
        'Please see a clinician or sexual health service for a test. **Get urgent care** if you also have fever or '
            'strong pelvic pain.',
      ], [_urgentOpt, _menuOpt]);

    case 'dis_brown':
      return const BotStep('dis_brown', [
        'Brown discharge is usually old blood. It is common just before or after your period.',
        'If it happens often between periods, after sex, during pregnancy, or after menopause, check in with a '
            'clinician.',
      ], [
        BotOption('Spotting between periods', next: 'spotting'),
        _menuOpt,
      ]);

    // ---------------------------------------------------------- checker
    case 'checker':
      return const BotStep('checker', [
        'The symptom checkers are short, educational questionnaires. They show how many common signs of a '
            'condition you have. They can\'t diagnose anything, but they can help you prepare for a visit.',
        'Which one would you like to take?',
      ], [
        BotOption('PCOS', checkerId: 'pcos'),
        BotOption('Endometriosis', checkerId: 'endometriosis'),
        BotOption('Uterine fibroids', checkerId: 'fibroids'),
        _menuOpt,
      ]);
  }
  return buildStep('menu', s);
}

// ------------------------------------------------------------ free text

const _crisisWords = ['suicid', 'kill myself', 'self-harm', 'self harm', 'hurt myself', 'end my life', 'want to die'];
const _urgentWords = [
  'emergency', 'faint', 'passed out', 'unbearable', 'severe pain', 'soaking', 'hemorrhag', 'can\'t breathe',
  'chest pain', 'ectopic', 'high fever',
];

const _topicWords = <String, List<String>>{
  'late': ['late', 'missed period', 'no period', 'pregnan', 'test', 'delay'],
  'spotting': ['spot', 'bleeding between', 'brown blood', 'breakthrough'],
  'pain': ['cramp', 'pain', 'hurt', 'ache'],
  'ovulating': ['ovulat', 'lh', 'bbt', 'temperature'],
  'ttc': ['conceive', 'ttc', 'trying for', 'get pregnant', 'fertil', 'baby'],
  'report': ['report', 'my cycle', 'average', 'regular', 'cycle length', 'explain'],
  'bc': ['pill', 'birth control', 'contracept', 'condom', 'iud', 'implant', 'morning after', 'plan b'],
  'pms': ['pms', 'mood', 'irritab', 'anx', 'sad', 'cry', 'pmdd'],
  'peri': ['menopause', 'hot flash', 'night sweat', 'perimeno'],
  'discharge': ['discharge', 'mucus', 'itch', 'smell', 'yeast'],
  'checker': ['pcos', 'endometriosis', 'endo', 'fibroid', 'checker', 'quiz me'],
};

/// Returns the local safety response when [text] mentions a crisis or an
/// emergency, or null otherwise. These messages always get the scripted
/// answer and are never sent to an AI model.
BotStep? safetyStep(String text, AppStore s) {
  final q = text.toLowerCase();
  if (_crisisWords.any(q.contains)) return buildStep('crisis', s);
  if (_urgentWords.any(q.contains)) return buildStep('urgent', s);
  return null;
}

/// Responds to free text: safety words first, then topic keywords, then
/// matching articles, then a fallback.
BotStep respondToText(String text, AppStore s) {
  final safety = safetyStep(text, s);
  if (safety != null) return safety;
  final q = text.toLowerCase();

  String? best;
  var bestScore = 0;
  for (final e in _topicWords.entries) {
    final score = e.value.where(q.contains).length;
    if (score > bestScore) {
      best = e.key;
      bestScore = score;
    }
  }
  if (best != null) return buildStep(best, s);

  final articles = searchArticles(text).take(3).toList();
  if (articles.isNotEmpty) {
    return BotStep('search', [
      'I don\'t have a scripted answer for that, but these articles might help.',
    ], [
      for (final a in articles) BotOption(a.title, articleId: a.id),
      _menuOpt,
    ]);
  }
  return const BotStep('fallback', [
    'Sorry, I didn\'t quite understand. I work offline with a set of topics, so try one of these.',
  ], kTopics);
}
