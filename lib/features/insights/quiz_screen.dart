/// Quiz player: standard multiple choice, and a pass-the-phone couples mode.
library;

import 'dart:math' as math;

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
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final total = q.questions.length;

    final List<Widget> content;
    if (_done) {
      final pct = _score / total;
      content = [
        _ResultHero(
          emoji: pct >= .8 ? '🏆' : pct >= .5 ? '🌟' : '🌱',
          value: pct,
          big: '$_score/$total',
          title: 'You scored $_score of $total',
          message: pct >= .8
              ? 'Impressive. You know this topic well.'
              : pct >= .5
                  ? 'Nice work. You learned something new today.'
                  : 'Every question is a chance to learn. Try again any time.',
          celebrate: pct >= .5,
        ),
        GradientButton(label: 'Done', expanded: true, onPressed: () => Navigator.pop(context)),
        Center(
          child: TextButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: const Text('Play again'),
          ),
        ),
      ];
    } else {
      final qq = q.questions[_index];
      final answered = _picked != null;
      final right = _picked == qq.correct;
      content = [
        _QuizProgress(
          label: 'Question ${_index + 1} of $total',
          trailing: '$_score correct',
          value: (_index + (answered ? 1 : 0)) / total,
        ),
        AnimatedSwitcher(
          duration: Motion.medium,
          transitionBuilder: _slideFade,
          child: Column(
            key: ValueKey(_index),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(qq.prompt, style: t.headlineSmall?.copyWith(height: 1.25)),
              Gap.v20,
              for (var i = 0; i < qq.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: _OptionCard(
                    letter: String.fromCharCode(65 + i),
                    label: qq.options[i],
                    state: _picked == null
                        ? _OptState.idle
                        : i == qq.correct
                            ? _OptState.correct
                            : i == _picked
                                ? _OptState.wrong
                                : _OptState.dim,
                    onTap: () => _pick(i),
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
                  InfoBanner(
                    tone: right ? BannerTone.success : BannerTone.warning,
                    icon: right ? Icons.celebration_rounded : Icons.lightbulb_rounded,
                    title: right ? 'Correct!' : 'Not quite',
                    message: qq.explanation,
                  ),
                  Gap.v16,
                  FilledButton(
                    onPressed: _next,
                    child: Text(_index + 1 >= total ? 'See results' : 'Next'),
                  ),
                ]),
        ),
      ];
    }

    return Scaffold(
      body: BloomPage(
        eyebrow: '${q.emoji}  QUIZ',
        title: q.title,
        children: content,
      ),
    );
  }
}

Widget _slideFade(Widget child, Animation<double> anim) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
        child: child,
      ),
    );

/// "Question 2 of 5" with a slim gradient progress bar.
class _QuizProgress extends StatelessWidget {
  const _QuizProgress({required this.label, required this.value, this.trailing});
  final String label;
  final String? trailing;
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(label, style: t.labelLarge?.copyWith(color: BloomTokens.of(context).muted))),
        if (trailing != null) Text(trailing!, style: t.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
      ]),
      Gap.v8,
      SoftProgressBar(value: value, gradient: BloomGradients.brand, height: 10),
    ]);
  }
}

enum _OptState { idle, correct, wrong, dim }

/// One answer. Correct answers pop, wrong ones shake.
class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.letter, required this.label, required this.state, required this.onTap});
  final String letter;
  final String label;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final tokens = BloomTokens.of(context);
    final cs = theme.colorScheme;
    final accent = switch (state) {
      _OptState.correct => BloomColors.success,
      _OptState.wrong => cs.error,
      _ => cs.primary,
    };
    final tinted = state == _OptState.correct || state == _OptState.wrong;
    final bg = tinted ? accent.withValues(alpha: dark ? 0.22 : 0.12) : theme.cardTheme.color;
    final border = tinted ? accent.withValues(alpha: 0.8) : tokens.border;
    final fg = state == _OptState.dim ? tokens.muted : cs.onSurface;

    Widget card = AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.curve,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.mdAll,
        border: Border.all(color: border, width: tinted ? 2 : 1.2),
        boxShadow: state == _OptState.idle ? tokens.cardShadow : const [],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md + 2),
            child: Row(children: [
              AnimatedContainer(
                duration: Motion.medium,
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tinted ? accent : tokens.subtle,
                  borderRadius: Radii.smAll,
                ),
                child: tinted
                    ? Icon(state == _OptState.correct ? Icons.check_rounded : Icons.close_rounded,
                        size: 20, color: BloomColors.onColor(accent))
                    : Text(letter, style: theme.textTheme.labelLarge?.copyWith(color: fg)),
              ),
              Gap.h12,
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: Motion.medium,
                  style: theme.textTheme.bodyLarge!.copyWith(color: fg, fontWeight: tinted ? FontWeight.w700 : null),
                  child: Text(label),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    if (state == _OptState.correct) {
      card = TweenAnimationBuilder<double>(
        key: const ValueKey('pop'),
        tween: Tween(begin: 0.94, end: 1),
        duration: Motion.slow,
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: card,
      );
    } else if (state == _OptState.wrong) {
      card = TweenAnimationBuilder<double>(
        key: const ValueKey('shake'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        builder: (_, v, child) =>
            Transform.translate(offset: Offset(math.sin(v * math.pi * 5) * 8 * (1 - v), 0), child: child),
        child: card,
      );
    }
    return card;
  }
}

/// The results hero: a ring with the score and a burst of confetti.
class _ResultHero extends StatelessWidget {
  const _ResultHero({
    required this.emoji,
    required this.value,
    required this.big,
    required this.title,
    required this.message,
    this.celebrate = true,
    this.gradient = BloomGradients.dusk,
  });

  final String emoji;
  final double value;
  final String big;
  final String title;
  final String message;
  final bool celebrate;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const white = Colors.white;
    return BloomCard.gradient(
      gradient: gradient,
      padding: EdgeInsets.zero,
      child: Stack(children: [
        if (celebrate) const Positioned.fill(child: IgnorePointer(child: _Confetti())),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xxxl, Space.xxl, Space.xxl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(width: double.infinity),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: Motion.slow,
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Text(emoji, style: const TextStyle(fontSize: 56, height: 1)),
            ),
            Gap.v16,
            ProgressRing(
              value: value,
              size: 128,
              stroke: 10,
              color: white,
              trackColor: ringTrackOn(gradient),
              child: Text(big, style: t.headlineMedium?.copyWith(color: white)),
            ),
            Gap.v20,
            Text(title, textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(color: white)),
            Gap.v8,
            Text(message, textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: white.withValues(alpha: 0.92))),
          ]),
        ),
      ]),
    );
  }
}

/// A one-shot burst of falling confetti.
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_c.value)));
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;

  static const _colors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFD36E),
    Color(0xFFFFB3C7),
    Color(0xFFB9F3E8),
    Color(0xFFD9CCFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 42; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final drift = (rnd.nextDouble() - 0.5) * 80;
      final speed = 0.6 + rnd.nextDouble() * 0.6;
      final delay = rnd.nextDouble() * 0.25;
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final y = -12 + p * speed * (size.height + 24);
      final x = x0 + drift * p + math.sin(p * 10 + i) * 6;
      paint.color = _colors[i % _colors.length].withValues(alpha: (1 - p) * 0.95);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * 8 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -2, 8, 4), const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EmptyState(
        emoji: '📱',
        color: BloomColors.coral,
        title: 'Pass the phone to $name',
        body: note,
        action: GradientButton(label: "I'm $name, ready", icon: Icons.visibility_rounded, onPressed: onReady),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quiz;
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final total = q.questions.length;
    final qq = q.questions[_index];

    final Widget content = switch (_stage) {
      _Stage.setup => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(q.description, style: t.bodyLarge),
          Gap.v16,
          const InfoBanner(
            tone: BannerTone.brand,
            icon: Icons.favorite_rounded,
            title: 'How it works',
            message: 'The first partner answers each question about themself without showing the screen. '
                'Then the second partner guesses. Each match scores a point.',
          ),
          Gap.v24,
          TextField(
            controller: _aCtrl,
            decoration: const InputDecoration(labelText: 'Answers about themself', prefixIcon: Icon(Icons.person_rounded)),
          ),
          Gap.v12,
          TextField(
            controller: _bCtrl,
            decoration: const InputDecoration(labelText: 'Guesses', prefixIcon: Icon(Icons.psychology_rounded)),
          ),
          Gap.v24,
          GradientButton(label: 'Start', icon: Icons.play_arrow_rounded, expanded: true, onPressed: () => _go(_Stage.handToA)),
        ]),
      _Stage.handToA => _handoff(_nameA, 'Question ${_index + 1} of $total. Answer honestly about yourself.',
          () => _go(_Stage.answerA)),
      _Stage.handToB => _handoff(_nameB, 'Guess what $_nameA answered.', () => _go(_Stage.guessB)),
      _Stage.answerA || _Stage.guessB => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _QuizProgress(label: 'Question ${_index + 1} of $total', trailing: '$_matches matches', value: _index / total),
          Gap.v20,
          PillChip(
            _stage == _Stage.answerA ? '$_nameA, answer for yourself' : '$_nameB, what did $_nameA pick?',
            icon: _stage == _Stage.answerA ? Icons.person_rounded : Icons.psychology_rounded,
            color: _stage == _Stage.answerA ? BloomColors.coral : BloomColors.luteal,
          ),
          Gap.v12,
          Text(_stage == _Stage.answerA ? qq.prompt : qq.prompt.replaceAll(RegExp(r'\bI\b'), _nameA),
              style: t.headlineSmall?.copyWith(height: 1.25)),
          Gap.v20,
          for (var i = 0; i < qq.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: _OptionCard(
                letter: String.fromCharCode(65 + i),
                label: qq.options[i],
                state: _OptState.idle,
                onTap: () {
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
          Text(_a == _b ? '💞 It\'s a match!' : '🙈 Not this time', textAlign: TextAlign.center, style: t.headlineSmall),
          Gap.v16,
          Text(qq.prompt, style: t.titleMedium),
          Gap.v12,
          for (var i = 0; i < qq.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: _OptionCard(
                letter: String.fromCharCode(65 + i),
                label: '${qq.options[i]}${i == _a ? '  ($_nameA)' : ''}${i == _b ? '  ($_nameB)' : ''}',
                state: i == _a
                    ? _OptState.correct
                    : i == _b
                        ? _OptState.wrong
                        : _OptState.dim,
                onTap: null,
              ),
            ),
          InfoBanner(tone: BannerTone.info, icon: Icons.lightbulb_rounded, title: 'Tip', message: qq.explanation),
          Gap.v16,
          Center(child: PillChip('Matches so far: $_matches', icon: Icons.favorite_rounded, color: BloomColors.coral)),
          Gap.v16,
          FilledButton(onPressed: _nextQuestion, child: Text(_index + 1 >= total ? 'See results' : 'Next question')),
        ]),
      _Stage.done => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ResultHero(
            emoji: '💞',
            value: total == 0 ? 0 : _matches / total,
            big: '$_matches/$total',
            title: '$_matches of $total matches',
            message: _matches >= total - 1
                ? '$_nameB knows $_nameA really well.'
                : 'Every miss is a conversation starter. Talk about the answers that surprised you.',
            celebrate: _matches >= total - 1,
            gradient: BloomGradients.brand,
          ),
          Gap.v20,
          GradientButton(label: 'Swap roles and play again', icon: Icons.swap_horiz_rounded, expanded: true, onPressed: _swap),
          Gap.v8,
          Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
        ]),
    };

    return Scaffold(
      body: BloomPage(
        eyebrow: '${q.emoji}  FOR TWO',
        title: q.title,
        children: [
          AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: _slideFade,
            child: KeyedSubtree(key: ValueKey('$_stage$_index'), child: content),
          ),
        ],
      ),
    );
  }
}
