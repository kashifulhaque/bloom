/// Quiz player, set like a printed exam paper: standard multiple choice,
/// and a pass-the-phone couples mode.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'content.dart';
import 'insights_data.dart';
import 'widgets.dart';

void openQuiz(BuildContext context, String id) {
  final q = quizById(id);
  if (q == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => q.couples ? CouplesQuizScreen(quiz: q) : QuizScreen(quiz: q)));
}

/// "Puzzle No. 3", from the quiz's place in the list.
String _puzzleNo(Quiz q) => 'No. ${kQuizzes.indexOf(q) + 1}';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.quiz});
  final Quiz quiz;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _picked;
  int _score = 0;
  bool _done = false;

  void _pick(int i) {
    if (_picked != null) return;
    Almanac.tick();
    setState(() {
      _picked = i;
      if (i == widget.quiz.questions[_index].correct) _score++;
    });
  }

  void _next() {
    if (_index + 1 >= widget.quiz.questions.length) {
      InsightsData.saveQuizResult(context.read<AppStore>(), widget.quiz.id, _score, widget.quiz.questions.length);
      setState(() => _done = true);
    } else {
      setState(() {
        _index++;
        _picked = null;
      });
    }
  }

  void _restart() => setState(() {
        _index = 0;
        _picked = null;
        _score = 0;
        _done = false;
      });

  @override
  Widget build(BuildContext context) {
    final q = widget.quiz;
    final total = q.questions.length;

    final List<Widget> content;
    if (_done) {
      final pct = _score / total;
      content = [
        _ResultHero(
          score: _score,
          total: total,
          lead: '${_cap(Almanac.spell(_score))} of ${Almanac.spell(total)},',
          italic: pct >= .8
              ? 'well read.'
              : pct >= .5
                  ? 'nicely done.'
                  : 'a fine beginning.',
          message: pct >= .8
              ? 'You know this subject well. Pass it on to someone who might not.'
              : pct >= .5
                  ? 'Good work. You picked up something new today.'
                  : 'Every question is a small lesson. Try again whenever you like.',
        ),
        Row(children: [
          InkButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          Gap.h16,
          InkLink('Play again', onTap: _restart),
        ]),
      ];
    } else {
      final qq = q.questions[_index];
      final answered = _picked != null;
      final right = _picked == qq.correct;
      content = [
        _PaperProgress(
          label: 'Question ${_index + 1} of $total',
          trailing: '$_score correct',
          value: (_index + (answered ? 1 : 0)) / total,
        ),
        AnimatedSwitcher(
          duration: Motion.medium,
          transitionBuilder: _fade,
          child: Column(
            key: ValueKey(_index),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuestionText(number: _index + 1, text: qq.prompt),
              Gap.v20,
              for (var i = 0; i < qq.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: _OptionBox(
                    letter: String.fromCharCode(65 + i),
                    label: qq.options[i],
                    state: _picked == null
                        ? _OptState.idle
                        : i == qq.correct
                            ? _OptState.correct
                            : i == _picked
                                ? _OptState.wrong
                                : _OptState.dim,
                    onTap: answered ? null : () => _pick(i),
                  ),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: !answered
              ? const SizedBox(width: double.infinity)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Verdict(
                    word: right ? 'Correct.' : 'Not quite.',
                    color: right ? BloomColors.fertile : BloomColors.period,
                    explanation: qq.explanation,
                  ),
                  Gap.v20,
                  Row(children: [
                    InkButton(label: _index + 1 >= total ? 'See results' : 'Next question', onPressed: _next),
                  ]),
                ]),
        ),
      ];
    }

    return Scaffold(
      body: BloomPage(
        eyebrow: 'Puzzle ${_puzzleNo(q)} · ${q.questions.length} questions',
        title: q.title,
        children: content,
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Widget _fade(Widget child, Animation<double> anim) => FadeTransition(opacity: anim, child: child);

/// "QUESTION 2 OF 5" in mono with a rule-thin progress line.
class _PaperProgress extends StatelessWidget {
  const _PaperProgress({required this.label, required this.value, this.trailing});
  final String label;
  final String? trailing;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: MonoLabel(label)),
        if (trailing != null) MonoLabel(trailing!, color: BloomColors.of(context).ink),
      ]),
      Gap.v8,
      RuleProgress(value: value),
    ]);
  }
}

/// A numbered question: a serif numeral in the margin and the prompt.
class _QuestionText extends StatelessWidget {
  const _QuestionText({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 36, child: Text('$number.', style: Almanac.serif(size: 23, weight: 330, color: p.ink2, height: 1.25))),
        Expanded(child: Text(text, style: Almanac.serif(size: 23, weight: 370, color: p.ink, height: 1.25))),
      ]),
    );
  }
}

/// The italic verdict after an answer ("Correct." in sage, "Not quite." in
/// oxblood) followed by the explanation.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.word, required this.color, required this.explanation});
  final String word;
  final Color color;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final c = BloomColors.resolve(context, color);
    return Container(
      margin: const EdgeInsets.only(top: Space.md),
      padding: const EdgeInsets.only(left: Space.md),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: c, width: 2))),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$word ', style: Almanac.italic(context, size: 20, color: c)),
        TextSpan(text: explanation, style: Almanac.sans(size: 15, color: p.ink, height: 1.55)),
      ])),
    );
  }
}

enum _OptState { idle, correct, wrong, dim, marked }

/// One lettered answer in a hairline box. A correct answer gets a sage
/// tick; a wrong pick is struck through in oxblood.
class _OptionBox extends StatelessWidget {
  const _OptionBox({required this.letter, required this.label, required this.state, required this.onTap, this.note});
  final String letter;
  final String label;
  final _OptState state;
  final VoidCallback? onTap;

  /// A small mono note at the end of the row (a partner's name).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final sage = p.fertile;
    final oxblood = p.period;
    final border = switch (state) {
      _OptState.correct => sage,
      _OptState.wrong => oxblood,
      _OptState.marked => p.ink,
      _ => p.hairline,
    };
    final fg = state == _OptState.dim ? p.ink2 : p.ink;
    final textStyle = Almanac.sans(size: 15.5, color: fg, height: 1.4).copyWith(
      decoration: state == _OptState.wrong ? TextDecoration.lineThrough : null,
      decorationColor: oxblood,
      decorationThickness: 1.6,
    );

    return Semantics(
      button: onTap != null,
      label: switch (state) {
        _OptState.correct => 'Correct answer',
        _OptState.wrong => 'Your answer, wrong',
        _ => null,
      },
      child: Pressable(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: Space.md + 2, vertical: Space.md),
          decoration: BoxDecoration(
            borderRadius: Radii.mdAll,
            border: Border.all(color: border, width: state == _OptState.idle || state == _OptState.dim ? 1 : 1.3),
          ),
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Text(letter, style: Almanac.data(context, size: 12.5, color: state == _OptState.dim ? p.ink2 : p.ink)),
            ),
            Expanded(child: Text(label, style: textStyle)),
            if (note != null) ...[Gap.h8, MonoLabel(note!, size: 9.5)],
            SizedBox(
              width: 28,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  child: switch (state) {
                    _OptState.correct => Icon(Icons.check, key: const ValueKey('c'), size: 20, color: sage),
                    _OptState.wrong => Icon(Icons.close, key: const ValueKey('w'), size: 18, color: oxblood),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The result, in serif: a large score numeral, a two-part headline, and a
/// short note.
class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.score, required this.total, required this.lead, required this.italic, required this.message});
  final int score;
  final int total;
  final String lead;
  final String italic;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const MonoLabel('Result'),
      Gap.v12,
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$score', style: Almanac.numeral(context, size: 88)),
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm, left: Space.xs),
          child: Text('/ $total', style: Almanac.numeral(context, size: 30, color: p.ink2)),
        ),
      ]),
      Gap.v16,
      const Hairline(),
      Gap.v16,
      PhaseTitle(lead: lead, italic: italic, size: 28),
      Gap.v12,
      Text(message, style: Theme.of(context).textTheme.bodyLarge),
    ]);
  }
}

/// Pass-the-phone couples quiz. Partner A answers about themself in private,
/// then partner B guesses. Matches score a point.
class CouplesQuizScreen extends StatefulWidget {
  const CouplesQuizScreen({super.key, required this.quiz});
  final Quiz quiz;

  @override
  State<CouplesQuizScreen> createState() => _CouplesQuizScreenState();
}

enum _Stage { setup, handToA, answerA, handToB, guessB, reveal, done }

class _CouplesQuizScreenState extends State<CouplesQuizScreen> {
  final _aCtrl = TextEditingController(text: 'Partner 1');
  final _bCtrl = TextEditingController(text: 'Partner 2');
  _Stage _stage = _Stage.setup;
  int _index = 0;
  int? _a;
  int? _b;
  int _matches = 0;

  String get _nameA => _aCtrl.text.trim().isEmpty ? 'Partner 1' : _aCtrl.text.trim();
  String get _nameB => _bCtrl.text.trim().isEmpty ? 'Partner 2' : _bCtrl.text.trim();

  @override
  void dispose() {
    _aCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  void _go(_Stage s) => setState(() => _stage = s);

  void _nextQuestion() {
    if (_index + 1 >= widget.quiz.questions.length) {
      InsightsData.saveQuizResult(context.read<AppStore>(), widget.quiz.id, _matches, widget.quiz.questions.length);
      _go(_Stage.done);
    } else {
      setState(() {
        _index++;
        _a = null;
        _b = null;
        _stage = _Stage.handToA;
      });
    }
  }

  void _swap() {
    final a = _aCtrl.text;
    _aCtrl.text = _bCtrl.text;
    _bCtrl.text = a;
    setState(() {
      _index = 0;
      _a = null;
      _b = null;
      _matches = 0;
      _stage = _Stage.handToA;
    });
  }

  Widget _handoff(String name, String note, VoidCallback onReady) {
    return EmptyState(
      glyph: Botanical.flower,
      title: 'Pass the phone to $name',
      body: note,
      action: InkButton(label: "I'm $name, ready", icon: Icons.visibility_outlined, onPressed: onReady),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quiz;
    final p = BloomColors.of(context);
    final t = Theme.of(context).textTheme;
    final total = q.questions.length;
    final qq = q.questions[_index];

    final Widget content = switch (_stage) {
      _Stage.setup => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(q.description, style: Almanac.italic(context, size: 19).copyWith(height: 1.4)),
          Gap.v20,
          const Hairline(),
          Gap.v12,
          const Marginalia(
            label: 'Rules',
            labelWidth: 72,
            child: Text('The first partner answers each question about themself without showing the screen. '
                'Then the second partner guesses. Each match scores a point.'),
          ),
          Gap.v12,
          const Hairline(),
          Gap.v20,
          TextField(
            controller: _aCtrl,
            decoration: const InputDecoration(labelText: 'Answers about themself'),
          ),
          Gap.v16,
          TextField(
            controller: _bCtrl,
            decoration: const InputDecoration(labelText: 'Guesses'),
          ),
          Gap.v32,
          InkButton(label: 'Start', expanded: true, onPressed: () => _go(_Stage.handToA)),
        ]),
      _Stage.handToA => _handoff(_nameA, 'Question ${_index + 1} of $total. Answer honestly about yourself.',
          () => _go(_Stage.answerA)),
      _Stage.handToB => _handoff(_nameB, 'Guess what $_nameA answered.', () => _go(_Stage.guessB)),
      _Stage.answerA || _Stage.guessB => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PaperProgress(label: 'Question ${_index + 1} of $total', trailing: '$_matches matches', value: _index / total),
          Gap.v20,
          Text(
            _stage == _Stage.answerA ? '$_nameA, answer for yourself.' : '$_nameB, what did $_nameA pick?',
            style: Almanac.italic(context, size: 17, color: p.ink2),
          ),
          _QuestionText(
            number: _index + 1,
            text: _stage == _Stage.answerA ? qq.prompt : qq.prompt.replaceAll(RegExp(r'\bI\b'), _nameA),
          ),
          Gap.v20,
          for (var i = 0; i < qq.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: _OptionBox(
                letter: String.fromCharCode(65 + i),
                label: qq.options[i],
                state: _OptState.idle,
                onTap: () {
                  Almanac.tick();
                  if (_stage == _Stage.answerA) {
                    setState(() {
                      _a = i;
                      _stage = _Stage.handToB;
                    });
                  } else {
                    setState(() {
                      _b = i;
                      if (_a == i) _matches++;
                      _stage = _Stage.reveal;
                    });
                  }
                },
              ),
            ),
        ]),
      _Stage.reveal => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PhaseTitle(
            italic: _a == _b ? 'A match.' : 'Not this time.',
            color: _a == _b ? BloomColors.fertile : null,
            size: 30,
          ),
          Gap.v16,
          _QuestionText(number: _index + 1, text: qq.prompt),
          Gap.v16,
          for (var i = 0; i < qq.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: _OptionBox(
                letter: String.fromCharCode(65 + i),
                label: qq.options[i],
                note: [if (i == _a) _nameA, if (i == _b) _nameB].join(' · ').ifEmpty,
                state: i == _a
                    ? _OptState.correct
                    : i == _b
                        ? _OptState.wrong
                        : _OptState.dim,
                onTap: null,
              ),
            ),
          Gap.v8,
          Marginalia(label: 'Note', child: Text(qq.explanation, style: t.bodyMedium)),
          Gap.v16,
          MonoLabel('Matches so far: $_matches of ${_index + 1}'),
          Gap.v16,
          Row(children: [
            InkButton(label: _index + 1 >= total ? 'See results' : 'Next question', onPressed: _nextQuestion),
          ]),
        ]),
      _Stage.done => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ResultHero(
            score: _matches,
            total: total,
            lead: '${_cap(Almanac.spell(_matches))} of ${Almanac.spell(total)}',
            italic: _matches >= total - 1 ? 'in step.' : 'and much to talk about.',
            message: _matches >= total - 1
                ? '$_nameB knows $_nameA really well.'
                : 'Every miss is a conversation starter. Talk about the answers that surprised you.',
          ),
          Gap.v24,
          InkButton(label: 'Swap roles and play again', icon: Icons.swap_horiz, expanded: true, onPressed: _swap),
          Gap.v8,
          Center(child: InkLink('Done', onTap: () => Navigator.pop(context))),
        ]),
    };

    return Scaffold(
      body: BloomPage(
        eyebrow: 'Puzzle ${_puzzleNo(q)} · For two',
        title: q.title,
        children: [
          AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: _fade,
            child: KeyedSubtree(key: ValueKey('$_stage$_index'), child: content),
          ),
        ],
      ),
    );
  }
}

extension on String {
  /// Null when empty.
  String? get ifEmpty => isEmpty ? null : this;
}
