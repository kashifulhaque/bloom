/// Educational self-assessment questionnaires for PCOS, endometriosis, and
/// uterine fibroids. Results are saved under the `checker` feature key as
/// `{checkerId: {level, score, max, date, answers}}`.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../insights/article_screen.dart';
import '../insights/widgets.dart';

/// A hint drawn from logged data. When [suggestYes] is true, the answer
/// starts as "Yes".
class CheckerHint {
  const CheckerHint(this.text, {this.suggestYes = false});
  final String text;
  final bool suggestYes;
}

class CheckerQuestion {
  const CheckerQuestion(this.text, {this.weight = 1, this.hint});
  final String text;
  final int weight;
  final CheckerHint? Function(AppStore s)? hint;
}

class Checker {
  const Checker({
    required this.id,
    required this.title,
    required this.emoji,
    required this.intro,
    required this.articleId,
    required this.questions,
    required this.results,
  });
  final String id;
  final String title;
  final String emoji;
  final String intro;
  final String articleId;
  final List<CheckerQuestion> questions;

  /// Explanations for `few`, `some`, and `many`.
  final Map<String, String> results;
}

enum Answer { no, unsure, yes }

// ------------------------------------------------------------ data hints

int _countDays(AppStore s, int days, bool Function(DayLog l) test) {
  final t = s.engine.today;
  return s.logsBetween(addDays(t, -days), t).where(test).length;
}

int _duringPeriods(AppStore s, bool Function(DayLog l) test) {
  var n = 0;
  for (final p in s.engine.periods.reversed.take(3)) {
    n += s.logsBetween(p.start, p.end).where(test).length;
  }
  return n;
}

CheckerHint? _longCycles(AppStore s) {
  final lens = s.engine.cycleLengths.reversed.take(6).toList();
  if (lens.isEmpty) return null;
  final long = lens.where((l) => l > 35).length;
  return CheckerHint(
    long == 0
        ? 'None of your last ${lens.length} logged cycles were longer than 35 days.'
        : '$long of your last ${lens.length} logged cycles were longer than 35 days.',
    suggestYes: long >= 2,
  );
}

CheckerHint? _variation(AppStore s) {
  final h = s.engine.health();
  if (!h.enoughData) return null;
  return CheckerHint('Your recent cycles vary by ${h.variation} days (more than 7 counts as irregular).',
      suggestYes: !h.regular);
}

CheckerHint? Function(AppStore) _logged(String what, int days, bool Function(DayLog) test, {int yesAt = 3}) =>
    (s) {
      final n = _countDays(s, days, test);
      if (n == 0) return null;
      return CheckerHint('You logged $what on $n day${n == 1 ? '' : 's'} in the last $days days.',
          suggestYes: n >= yesAt);
    };

CheckerHint? Function(AppStore) _loggedInPeriods(String what, bool Function(DayLog) test, {int yesAt = 3}) =>
    (s) {
      if (s.engine.periods.isEmpty) return null;
      final n = _duringPeriods(s, test);
      if (n == 0) return null;
      return CheckerHint('You logged $what on $n day${n == 1 ? '' : 's'} during your recent periods.',
          suggestYes: n >= yesAt);
    };

CheckerHint? _longPeriods(AppStore s) {
  if (s.engine.periods.length < 2) return null;
  final avg = s.engine.avgPeriodLength;
  return CheckerHint('Your periods last about $avg days on average.', suggestYes: avg > 7);
}

CheckerHint? _condition(AppStore s, String c) =>
    s.profile.conditions.map((x) => x.toLowerCase()).contains(c)
        ? const CheckerHint('You listed this in your profile.', suggestYes: true)
        : null;

// ------------------------------------------------------------ questionnaires

final List<Checker> kCheckers = [
  Checker(
    id: 'pcos',
    title: 'PCOS',
    emoji: '🫧',
    intro: 'Polycystic ovary syndrome (PCOS) is a common hormonal condition. It can affect your cycle, skin, '
        'hair, weight, and fertility. These questions cover common signs.',
    articleId: 'cond-pcos',
    questions: [
      CheckerQuestion('Are your cycles often longer than 35 days, or do you have fewer than nine periods a year?',
          weight: 3, hint: _longCycles),
      CheckerQuestion('Does the length of your cycle change a lot from month to month?', weight: 2, hint: _variation),
      const CheckerQuestion('Do you have more hair than you would like on your face, chest, belly, or back?',
          weight: 2),
      CheckerQuestion('Do you have acne that has lasted past your teens, especially along your jaw?',
          hint: _logged('acne', 90, (l) => l.has('symptoms', 'acne'), yesAt: 6)),
      const CheckerQuestion('Is the hair on your scalp thinning, especially at the crown or temples?'),
      const CheckerQuestion('Have you gained weight easily, especially around your middle, or found it hard to lose?'),
      const CheckerQuestion('Do you have patches of darker, velvety skin on your neck, armpits, or groin?'),
      const CheckerQuestion('Does a parent or sibling have PCOS or type 2 diabetes?'),
      const CheckerQuestion('Has a scan ever shown many small follicles on your ovaries?', weight: 2),
      CheckerQuestion('Have you had trouble getting pregnant, or rarely see signs of ovulation?',
          hint: (s) {
            final tests = _countDays(s, 120, (l) => l.get('ovulation_test').any((o) => o == 'positive' || o == 'negative'));
            if (tests < 3) return null;
            final pos = _countDays(s, 120, (l) => l.has('ovulation_test', 'positive'));
            return CheckerHint(
                'You logged $tests ovulation tests in the last four months, $pos of them positive.',
                suggestYes: pos == 0);
          }),
      CheckerQuestion('Has a clinician told you before that you might have PCOS?',
          weight: 2, hint: (s) => _condition(s, 'pcos')),
    ],
    results: {
      'few': 'You reported few common signs of PCOS. That makes it less likely, but it can\'t rule it out. '
          'If your cycles change or you have concerns, talk to a clinician.',
      'some': 'You reported some common signs of PCOS. Many of these signs have other causes too. A clinician can '
          'check with a history, an exam, blood tests, and sometimes an ultrasound.',
      'many': 'You reported many common signs of PCOS. This is not a diagnosis, but it\'s a good reason to book a '
          'visit. PCOS is very manageable, and treatment can help your cycle, skin, and long-term health.',
    },
  ),
  Checker(
    id: 'endometriosis',
    title: 'Endometriosis',
    emoji: '🌸',
    intro: 'Endometriosis is when tissue similar to the uterine lining grows outside the uterus. It often causes '
        'pain and can take years to diagnose. These questions cover common signs.',
    articleId: 'cond-endometriosis',
    questions: [
      CheckerQuestion('Is your period pain bad enough to make you miss school, work, or plans?',
          weight: 3, hint: _loggedInPeriods('cramps', (l) => l.has('symptoms', 'cramps'), yesAt: 5)),
      const CheckerQuestion('Do pain relievers often fail to control your period pain?', weight: 2),
      const CheckerQuestion('Does your pain start a day or more before bleeding, or continue after it ends?'),
      const CheckerQuestion('Do you have deep pain during or after sex?', weight: 2),
      const CheckerQuestion('Do you have pain when you poop or pee, especially during your period?', weight: 2),
      CheckerQuestion('Do you have pelvic or belly pain at other times of the month?',
          weight: 2,
          hint: (s) {
            final t = s.engine.today;
            final n = s
                .logsBetween(addDays(t, -90), t)
                .where((l) => l.has('symptoms', 'abdominal_pain') && !s.engine.isOnPeriod(l.date))
                .length;
            if (n == 0) return null;
            return CheckerHint('You logged belly pain outside your period on $n days in the last 90 days.',
                suggestYes: n >= 3);
          }),
      CheckerQuestion('Do you get bloating, nausea, diarrhea, or constipation around your period?',
          hint: _loggedInPeriods('digestive symptoms', (l) => l.get('digestion').isNotEmpty)),
      CheckerQuestion('Do you have heavy periods or spotting between periods?',
          hint: _loggedInPeriods('heavy flow', (l) => l.has('flow', 'heavy'))),
      CheckerQuestion('Do you often feel very tired, especially around your period?',
          hint: _loggedInPeriods('fatigue', (l) => l.has('symptoms', 'fatigue'))),
      const CheckerQuestion('Have you had trouble getting pregnant?'),
      const CheckerQuestion('Does a parent or sibling have endometriosis?'),
      CheckerQuestion('Has a clinician told you before that you might have endometriosis?',
          weight: 2, hint: (s) => _condition(s, 'endometriosis')),
    ],
    results: {
      'few': 'You reported few common signs of endometriosis. If period pain still bothers you, it\'s worth '
          'discussing. Pain that affects your life is never something you just have to accept.',
      'some': 'You reported some common signs of endometriosis. These can have other causes, so bring your answers '
          'and your symptom log to a clinician. Ask what could be causing your pain and what can help.',
      'many': 'You reported many common signs of endometriosis. This is not a diagnosis, but it\'s a strong reason '
          'to see a clinician, ideally one experienced in pelvic pain. Treatments can reduce pain, even before a '
          'formal diagnosis.',
    },
  ),
  Checker(
    id: 'fibroids',
    title: 'Uterine fibroids',
    emoji: '🔵',
    intro: 'Fibroids are non-cancerous growths in the wall of the uterus. They are very common, and many cause no '
        'symptoms. When they do, heavy periods and pressure are the most common signs.',
    articleId: 'cond-fibroids',
    questions: [
      CheckerQuestion('Are your periods very heavy, for example soaking a pad or tampon every hour or two?',
          weight: 3, hint: _loggedInPeriods('heavy flow', (l) => l.has('flow', 'heavy'))),
      CheckerQuestion('Do your periods often last longer than seven days?', weight: 2, hint: _longPeriods),
      CheckerQuestion('Do you pass blood clots larger than a coin?',
          weight: 2, hint: _loggedInPeriods('blood clots', (l) => l.has('clots', 'clots'), yesAt: 2)),
      const CheckerQuestion('Do you feel pressure, fullness, or heaviness in your lower belly?', weight: 2),
      const CheckerQuestion('Do you need to pee often, or feel like your bladder doesn\'t empty?'),
      CheckerQuestion('Do you often have constipation or pressure on your bowel?',
          hint: _logged('constipation', 90, (l) => l.has('digestion', 'constipation'), yesAt: 6)),
      CheckerQuestion('Do you have lower back or leg pain that isn\'t explained by anything else?',
          hint: _logged('backache', 90, (l) => l.has('symptoms', 'backache'), yesAt: 6)),
      CheckerQuestion('Do you often feel tired, dizzy, or short of breath, or have you been told you are anemic?',
          weight: 2,
          hint: _logged('fatigue or dizziness', 60,
              (l) => l.has('symptoms', 'fatigue') || l.has('symptoms', 'dizziness'), yesAt: 8)),
      const CheckerQuestion('Does your belly look swollen, or has a clinician said your uterus feels enlarged?',
          weight: 2),
      const CheckerQuestion('Does a parent or sibling have fibroids?'),
      CheckerQuestion('Has a clinician told you before that you might have fibroids?',
          weight: 2, hint: (s) => _condition(s, 'fibroids')),
    ],
    results: {
      'few': 'You reported few common signs of fibroids. If your bleeding or pain changes, keep logging it and '
          'mention it at your next checkup.',
      'some': 'You reported some common signs of fibroids. Heavy bleeding and pressure have several possible causes. '
          'A clinician can check with an exam and an ultrasound, and a blood test for anemia.',
      'many': 'You reported many common signs of fibroids. This is not a diagnosis, but it\'s a good reason to see a '
          'clinician. Heavy bleeding can cause anemia, and many treatments are available.',
    },
  ),
];

Checker? checkerById(String id) {
  for (final c in kCheckers) {
    if (c.id == id) return c;
  }
  return null;
}

/// Scores answers: yes counts the full weight, unsure half. Returns the
/// level (`few`, `some`, `many`), the score, and the maximum.
({String level, double score, int max}) scoreChecker(Checker c, List<Answer> answers) {
  var score = 0.0;
  var max = 0;
  for (var i = 0; i < c.questions.length; i++) {
    final w = c.questions[i].weight;
    max += w;
    final a = i < answers.length ? answers[i] : Answer.no;
    if (a == Answer.yes) score += w;
    if (a == Answer.unsure) score += w / 2;
  }
  final ratio = max == 0 ? 0 : score / max;
  final level = ratio < .3
      ? 'few'
      : ratio < .6
          ? 'some'
          : 'many';
  return (level: level, score: score, max: max);
}

String levelLabel(String level) => switch (level) {
      'many' => 'Many signs',
      'some' => 'Some signs',
      _ => 'Few signs',
    };

Map<String, dynamic>? savedCheckerResult(AppStore s, String id) {
  final m = s.feature<Map>('checker');
  final r = m?[id];
  return r == null ? null : Map<String, dynamic>.from(r as Map);
}

void openChecker(BuildContext context, String id) {
  final c = checkerById(id);
  if (c == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SymptomCheckerScreen(checker: c)));
}

void openCheckerList(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CheckerListScreen()));
}

// ------------------------------------------------------------ screens

/// The tone of a result level. Kept for callers that color a level; the
/// Almanac screens draw levels in ink and use oxblood only for "many".
Color levelColor(String level) => switch (level) {
      'many' => BloomColors.period,
      'some' => BloomColors.warning,
      _ => BloomColors.success,
    };

class CheckerListScreen extends StatelessWidget {
  const CheckerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = BloomColors.of(context);
    return Scaffold(
      body: BloomPage(
        eyebrow: 'Ask · Self-checks',
        title: 'Symptom checker',
        subtitle: 'Short questionnaires that draw on what you have logged.',
        children: [
          Column(children: [
            for (var i = 0; i < kCheckers.length; i++) ...[
              const Hairline(),
              Builder(builder: (context) {
                final c = kCheckers[i];
                final r = savedCheckerResult(store, c.id);
                final level = r?['level'] as String? ?? 'few';
                return Pressable(
                  semanticLabel: '${c.title} check, ${c.questions.length} questions',
                  onTap: () => openChecker(context, c.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.lg),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 44,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Form ${String.fromCharCode(65 + i)}', style: Almanac.data(context, size: 11)),
                        ),
                      ),
                      Gap.h8,
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.title, style: Almanac.serif(size: 20, weight: 380, color: p.ink)),
                          Gap.v4,
                          MonoLabel('${c.questions.length} questions · about 2 min', size: 10),
                          if (r != null) ...[
                            Gap.v8,
                            Text(
                              'Last time: ${levelLabel(level).toLowerCase()}, ${fmtShort(parseDayKey(r['date'] as String))}.',
                              style: Almanac.italic(context, size: 15, color: p.ink2),
                            ),
                          ],
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.arrow_forward, size: 18, color: p.ink2),
                      ),
                    ]),
                  ),
                );
              }),
            ],
            const Hairline(),
          ]),
          Gap.v8,
          const Footnote('These questionnaires are educational. They can\'t diagnose a condition. '
              'Talk to a clinician about your results.'),
        ],
      ),
    );
  }
}

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key, required this.checker});
  final Checker checker;

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  late final List<Answer?> _answers;
  late final List<CheckerHint?> _hints;
  bool _started = false;
  int _index = 0;
  Timer? _advance;
  ({String level, double score, int max})? _result;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _hints = [for (final q in widget.checker.questions) q.hint?.call(store)];
    _answers = [for (final h in _hints) (h?.suggestYes ?? false) ? Answer.yes : null];
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  bool get _isLast => _index + 1 >= widget.checker.questions.length;

  void _answer(Answer a) {
    _advance?.cancel();
    Almanac.tick();
    setState(() => _answers[_index] = a);
    if (_isLast) return;
    _advance = Timer(const Duration(milliseconds: 280), () {
      if (mounted) _go(1);
    });
  }

  void _go(int delta) {
    _advance?.cancel();
    final i = (_index + delta).clamp(0, widget.checker.questions.length - 1);
    if (i == _index) return;
    setState(() => _index = i);
  }

  void _finish() {
    _advance?.cancel();
    final answers = [for (final a in _answers) a ?? Answer.no];
    final r = scoreChecker(widget.checker, answers);
    final store = context.read<AppStore>();
    final all = Map<String, dynamic>.from(store.feature<Map>('checker') ?? const {});
    all[widget.checker.id] = {
      'level': r.level,
      'score': r.score,
      'max': r.max,
      'date': dayKey(today()),
      'answers': [for (final a in answers) a.name],
    };
    store.setFeature('checker', all);
    setState(() => _result = r);
  }

  String get _conditionName {
    final c = widget.checker;
    return c.title.toLowerCase() == 'pcos' ? 'PCOS' : c.title.toLowerCase();
  }

  List<Widget> _intro(BuildContext context) {
    final c = widget.checker;
    final p = BloomColors.of(context);
    return [
      Text(c.intro, style: Almanac.italic(context, size: 19, color: p.ink).copyWith(height: 1.45)),
      Column(children: [
        const Hairline(),
        Gap.v12,
        Marginalia(label: 'Length', labelWidth: 72, child: Text('${c.questions.length} questions, about 2 minutes.')),
        Gap.v12,
        const Marginalia(
          label: 'Hints',
          labelWidth: 72,
          child: Text('Where you have logged related data, you\'ll see it as a note, and some answers may be '
              'filled in for you. You can change any answer.'),
        ),
        Gap.v12,
        const Marginalia(label: 'Privacy', labelWidth: 72, child: Text('Your answers stay on this device.')),
        Gap.v12,
        const Hairline(),
      ]),
      Gap.v8,
      InkButton(label: 'Start', icon: Icons.arrow_forward, expanded: true, onPressed: () => setState(() => _started = true)),
      Gap.v8,
      const Footnote('This is an educational self-check, not a diagnosis. Only a clinician can diagnose a condition.'),
    ];
  }

  List<Widget> _question(BuildContext context) {
    final c = widget.checker;
    final p = BloomColors.of(context);
    final total = c.questions.length;
    final answered = _answers.where((a) => a != null).length;
    final q = c.questions[_index];
    final hint = _hints[_index];
    final unanswered = total - answered;

    return [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: MonoLabel('Question ${_index + 1} of $total')),
          MonoLabel('$answered answered', color: p.ink),
        ]),
        Gap.v8,
        RuleProgress(value: (_index + 1) / total),
      ]),
      AnimatedSwitcher(
        duration: Motion.medium,
        switchInCurve: Motion.curve,
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
        child: Column(
          key: ValueKey(_index),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap.v12,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 40,
                child: Text('${_index + 1}.', style: Almanac.serif(size: 23, weight: 330, color: p.ink2, height: 1.3)),
              ),
              Expanded(child: Text(q.text, style: Almanac.serif(size: 23, weight: 370, color: p.ink, height: 1.3))),
            ]),
            if (hint != null) ...[
              Gap.v16,
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const MonoLabel('From your logs', size: 9.5),
                  Gap.v4,
                  Text(hint.text, style: Almanac.italic(context, size: 16, color: p.ink2).copyWith(height: 1.4)),
                ]),
              ),
            ],
            Gap.v24,
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                for (final a in [Answer.yes, Answer.no, Answer.unsure])
                  _AnswerBox(answer: a, selected: _answers[_index] == a, onTap: () => _answer(a)),
              ]),
            ),
          ],
        ),
      ),
      if (_isLast && unanswered > 0)
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Text(
            '$unanswered unanswered question${unanswered == 1 ? '' : 's'} will count as "No".',
            style: Almanac.italic(context, size: 15, color: p.ink2),
          ),
        ),
      Gap.v8,
      const Hairline(),
      Row(children: [
        InkButton.outlined(label: 'Back', dense: true, icon: Icons.arrow_back, onPressed: _index == 0 ? null : () => _go(-1)),
        const Spacer(),
        _isLast
            ? InkButton(label: 'See my result', dense: true, onPressed: _finish)
            : InkButton(label: _answers[_index] == null ? 'Skip' : 'Next', dense: true, onPressed: () => _go(1)),
      ]),
    ];
  }

  List<Widget> _resultView(BuildContext context) {
    final c = widget.checker;
    final r = _result!;
    final p = BloomColors.of(context);
    final steps = [
      'Bring your cycle history and symptom log from this app.',
      'Describe how symptoms affect your daily life, not just what they are.',
      'Ask what could be causing them and which tests could help.',
      'If you feel dismissed, it\'s okay to ask for a second opinion.',
    ];

    return [
      Text.rich(
        TextSpan(children: [
          TextSpan(text: '${levelLabel(r.level)}\n', style: Almanac.serif(size: 36, weight: 300, italic: true, color: p.ink, height: 1.1)),
          TextSpan(text: 'of $_conditionName.', style: Almanac.serif(size: 36, weight: 300, italic: true, color: p.ink2, height: 1.1)),
        ]),
      ),
      _LevelMeter(ratio: r.max == 0 ? 0 : r.score / r.max, level: r.level),
      Text(c.results[r.level]!, style: Theme.of(context).textTheme.bodyLarge!.copyWith(height: 1.6)),
      const SectionHeader('Talking to a clinician', label: 'Clinician note', padding: EdgeInsets.only(top: Space.xl)),
      Column(children: [
        for (var i = 0; i < steps.length; i++) ...[
          const Hairline(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 32, child: Text('${i + 1}.', style: Almanac.serif(size: 17, weight: 330, color: p.ink2, height: 1.4))),
              Expanded(child: Text(steps[i], style: Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.5))),
            ]),
          ),
        ],
        const Hairline(),
      ]),
      const InfoBanner(
        tone: BannerTone.error,
        title: 'Get urgent care',
        message: 'For sudden severe pelvic pain, fainting, or bleeding that soaks a pad every hour.',
      ),
      Row(children: [
        InkButton(label: 'Done', onPressed: () => Navigator.pop(context)),
        Gap.h16,
        Flexible(child: InkLink('Read about ${c.title}', arrow: true, onTap: () => openArticle(context, c.articleId))),
      ]),
      Gap.v8,
      const Footnote('This is an educational self-check, not a diagnosis.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.checker;
    final List<Widget> children;
    if (!_started) {
      children = _intro(context);
    } else if (_result == null) {
      children = _question(context);
    } else {
      children = _resultView(context);
    }

    return Scaffold(
      body: BloomPage(
        eyebrow: _result == null ? 'Symptom checker · Questionnaire' : 'Your result · ${fmtShort(today())}',
        title: _started && _result == null ? c.title : '${c.title} check',
        actions: [
          if (_started && _result == null) InkLink('Finish now', size: 13.5, onTap: _finish),
        ],
        children: children,
      ),
    );
  }
}

/// One answer on the form: a small square checkbox and a label in a
/// hairline box. The selected answer is outlined in ink with a filled box.
class _AnswerBox extends StatelessWidget {
  const _AnswerBox({required this.answer, required this.selected, required this.onTap});
  final Answer answer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final label = switch (answer) {
      Answer.yes => 'Yes',
      Answer.no => 'No',
      Answer.unsure => 'Not sure',
    };
    return Pressable(
      selected: selected,
      onTap: onTap,
      borderRadius: Radii.mdAll,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.curve,
        constraints: const BoxConstraints(minHeight: 48, minWidth: 92),
        padding: const EdgeInsets.symmetric(horizontal: Space.md + 2, vertical: Space.sm),
        decoration: BoxDecoration(
          borderRadius: Radii.mdAll,
          border: Border.all(color: selected ? p.ink : p.hairline, width: selected ? 1.3 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: Motion.medium,
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: selected ? p.ink : Colors.transparent,
              borderRadius: Radii.xsAll,
              border: Border.all(color: selected ? p.ink : p.ink2, width: 1),
            ),
            child: selected ? Icon(Icons.check, size: 11, color: p.paper) : null,
          ),
          Gap.h8,
          Text(label, style: Almanac.sans(size: 15, weight: selected ? FontWeight.w600 : FontWeight.w500, color: p.ink, height: 1.2)),
        ]),
      ),
    );
  }
}

/// A rule-thin meter with three bands (few, some, many), tick marks at the
/// band edges, and an ink marker at [ratio].
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.ratio, required this.level});
  final double ratio;
  final String level;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final mark = level == 'many' ? p.period : p.ink;
    return Column(children: [
      LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        return SizedBox(
          height: 20,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(left: 0, right: 0, top: 9, child: Container(height: 1, color: p.hairline)),
            for (final edge in const [0.0, 0.3, 0.6, 1.0])
              Positioned(left: (w * edge - 0.5).clamp(0.0, w - 1), top: 5, child: Container(width: 1, height: 9, color: p.ink2)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
              duration: Motion.slow,
              curve: Motion.curve,
              builder: (_, v, _) => Stack(clipBehavior: Clip.none, children: [
                Positioned(left: 0, top: 8, child: Container(width: w * v, height: 3, color: mark)),
                Positioned(
                  left: (w * v - 5).clamp(0.0, w - 10),
                  top: 4.5,
                  child: Container(width: 10, height: 10, decoration: BoxDecoration(color: mark, shape: BoxShape.circle)),
                ),
              ]),
            ),
          ]),
        );
      }),
      Gap.v8,
      Row(children: [
        Expanded(flex: 3, child: MonoLabel('Few', size: 9.5, color: level == 'few' ? p.ink : null)),
        Expanded(flex: 3, child: MonoLabel('Some', size: 9.5, color: level == 'some' ? p.ink : null)),
        Expanded(flex: 4, child: MonoLabel('Many', size: 9.5, color: level == 'many' ? p.ink : null)),
      ]),
    ]);
  }
}
