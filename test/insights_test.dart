import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/features/assistant/scripts.dart';
import 'package:bloom/features/assistant/symptom_checker.dart';
import 'package:bloom/features/insights/content.dart';
import 'package:bloom/features/insights/insight_rules.dart';
import 'package:bloom/features/assistant/assistant_screen.dart';
import 'package:bloom/features/insights/article_screen.dart';
import 'package:bloom/features/insights/daily_insights.dart';
import 'package:bloom/features/insights/insights_screen.dart';
import 'package:bloom/features/insights/quiz_screen.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

AppStore _store({Goal goal = Goal.trackCycle}) =>
    AppStore.memory(profile: Profile(onboarded: true, goal: goal, name: 'Test'));

/// Four 28-day cycles; the latest period started [lastStartAgo] days ago.
AppStore _withCycles({int lastStartAgo = 25, Goal goal = Goal.trackCycle}) {
  final s = _store(goal: goal);
  final t = today();
  for (var k = 3; k >= 0; k--) {
    s.startPeriod(addDays(t, -lastStartAgo - 28 * k), length: 5);
  }
  return s;
}

int _words(String s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

void main() {
  group('buildInsights', () {
    test('period soon, pre-period pattern, and low water', () {
      final s = _withCycles(lastStartAgo: 25);
      final t = today();
      for (final p in s.engine.periods.reversed.take(3)) {
        s.toggleOption(addDays(p.start, -2), 'symptoms', 'headache');
      }
      for (var i = 0; i < 4; i++) {
        s.setMetric(addDays(t, -i), 'water', 800);
      }

      final cards = buildInsights(s);
      expect(cards.length, inInclusiveRange(4, 6));
      expect(cards.first.kind, InsightKind.wellbeing);
      expect(cards.first.wellbeing, isNotNull);

      final soon = cards.firstWhere((c) => c.id == 'period-soon');
      expect(soon.title, contains('3 days'));

      final pattern = cards.firstWhere((c) => c.kind == InsightKind.pattern);
      expect(pattern.title.toLowerCase(), contains('headache'));
      expect(pattern.title, contains('last 3 periods'));

      expect(cards.any((c) => c.id == 'water-low'), isTrue);
      expect(cards.map((c) => c.id).toSet().length, cards.length, reason: 'card ids are unique');
    });

    test('late period', () {
      final s = _withCycles(lastStartAgo: 35);
      final cards = buildInsights(s);
      final late = cards.firstWhere((c) => c.id == 'period-late');
      expect(late.title, contains('7 days late'));
    });

    test('fertile window', () {
      final s = _withCycles(lastStartAgo: 12, goal: Goal.getPregnant);
      final cards = buildInsights(s);
      expect(cards.any((c) => c.kind == InsightKind.fertile), isTrue);
    });

    test('cycle longer than average', () {
      final s = _store();
      final t = today();
      // Cycles of 28, 28, 28, then 36 days.
      final starts = [-130, -102, -74, -46, -10];
      for (final d in starts) {
        s.startPeriod(addDays(t, d), length: 5);
      }
      final cards = buildInsights(s);
      final c = cards.firstWhere((c) => c.kind == InsightKind.cycle);
      expect(c.title, contains('longer'));
    });

    test('empty store and pregnancy goal still give 4-6 cards', () {
      for (final s in [_store(), _withCycles(goal: Goal.trackPregnancy), _store(goal: Goal.postpartum)]) {
        final cards = buildInsights(s);
        expect(cards.length, inInclusiveRange(4, 6));
        expect(cards.first.kind, InsightKind.wellbeing);
      }
      final preg = buildInsights(_withCycles(goal: Goal.trackPregnancy));
      expect(preg.any((c) => c.kind == InsightKind.period || c.kind == InsightKind.fertile), isFalse);
    });

    test('linked articles and quizzes exist', () {
      for (final s in [_store(), _withCycles(), _withCycles(lastStartAgo: 35), _withCycles(lastStartAgo: 12)]) {
        for (final c in buildInsights(s)) {
          if (c.articleId != null) expect(articleById(c.articleId!), isNotNull, reason: c.articleId);
          if (c.quizId != null) expect(quizById(c.quizId!), isNotNull, reason: c.quizId);
        }
      }
    });
  });

  group('well-being score', () {
    void checkBounds(WellbeingScore w) {
      expect(w.score, inInclusiveRange(0, 100));
      expect(w.factors.fold<int>(0, (a, f) => a + f.max), 100);
      for (final f in w.factors) {
        expect(f.points, inInclusiveRange(0, f.max), reason: f.name);
      }
    }

    test('empty store', () => checkBounds(computeWellbeing(_store())));

    test('great and poor days', () {
      final t = today();
      final good = _withCycles(lastStartAgo: 8);
      final bad = _withCycles(lastStartAgo: 1);
      for (var i = 0; i < 7; i++) {
        final d = addDays(t, -i);
        good
          ..setMetric(d, 'sleep', 8)
          ..setMetric(d, 'energy', 5)
          ..setMetric(d, 'water', 2500)
          ..toggleOption(d, 'mood', 'happy')
          ..toggleOption(d, 'activity', 'running');
        bad
          ..setMetric(d, 'sleep', 3)
          ..setMetric(d, 'energy', 1)
          ..setMetric(d, 'water', 0)
          ..toggleOption(d, 'mood', 'sad')
          ..toggleOption(d, 'activity', 'none');
        for (final sym in ['cramps', 'headache', 'fatigue', 'backache', 'acne', 'migraine']) {
          bad.toggleOption(d, 'symptoms', sym);
        }
      }
      final g = computeWellbeing(good);
      final b = computeWellbeing(bad);
      checkBounds(g);
      checkBounds(b);
      expect(g.score, greaterThan(85));
      expect(b.score, lessThan(30));
    });
  });

  group('content', () {
    test('articles are complete and unique', () {
      expect(kArticles.length, greaterThanOrEqualTo(36));
      final ids = <String>{};
      for (final a in kArticles) {
        expect(ids.add(a.id), isTrue, reason: 'duplicate id ${a.id}');
        expect(a.id.trim(), isNotEmpty);
        expect(a.title.trim(), isNotEmpty, reason: a.id);
        expect(a.emoji.trim(), isNotEmpty, reason: a.id);
        expect(a.tags, isNotEmpty, reason: a.id);
        expect(a.minutes, greaterThan(0), reason: a.id);
        expect(_words(a.body), inInclusiveRange(150, 350), reason: a.id);
      }
      for (final c in ArticleCategory.values) {
        expect(articlesIn(c), isNotEmpty, reason: c.label);
      }
    });

    test('quizzes are complete and unique', () {
      expect(kQuizzes.length, greaterThanOrEqualTo(10));
      expect(kQuizzes.any((q) => q.couples), isTrue);
      final ids = <String>{};
      for (final q in kQuizzes) {
        expect(ids.add(q.id), isTrue, reason: 'duplicate id ${q.id}');
        expect(q.title.trim(), isNotEmpty);
        expect(q.description.trim(), isNotEmpty);
        expect(q.emoji.trim(), isNotEmpty);
        expect(q.questions.length, inInclusiveRange(3, 6), reason: q.id);
        for (final qq in q.questions) {
          expect(qq.prompt.trim(), isNotEmpty);
          expect(qq.explanation.trim(), isNotEmpty);
          expect(qq.options.length, greaterThanOrEqualTo(2));
          expect(qq.options.every((o) => o.trim().isNotEmpty), isTrue);
          if (q.couples) {
            expect(qq.correct, isNull);
          } else {
            expect(qq.correct, isNotNull, reason: qq.prompt);
            expect(qq.correct, inInclusiveRange(0, qq.options.length - 1));
          }
        }
      }
    });

    test('search finds articles', () {
      expect(searchArticles('cramps'), isNotEmpty);
      expect(searchArticles('pcos').first.id, 'cond-pcos');
      expect(searchArticles(''), isEmpty);
    });
  });

  group('assistant', () {
    test('every reachable node builds and links exist', () {
      for (final s in [_store(), _withCycles(), _withCycles(lastStartAgo: 40)]) {
        final seen = <String>{};
        final queue = ['start'];
        while (queue.isNotEmpty) {
          final id = queue.removeLast();
          if (!seen.add(id)) continue;
          final step = buildStep(id, s);
          expect(step.messages, isNotEmpty, reason: id);
          expect(step.options, isNotEmpty, reason: id);
          for (final o in step.options) {
            if (o.next != null) queue.add(o.next!);
            if (o.articleId != null) expect(articleById(o.articleId!), isNotNull, reason: '$id → ${o.articleId}');
            if (o.checkerId != null) expect(checkerById(o.checkerId!), isNotNull, reason: o.checkerId);
          }
        }
        expect(seen.length, greaterThan(40));
      }
    });

    test('late branch is personalized', () {
      final s = _withCycles(lastStartAgo: 33);
      s.toggleOption(addDays(today(), -20), 'sex', 'unprotected');
      expect(buildStep('late', s).messages.join(' '), contains('5 days late'));
      expect(buildStep('late_preg', s).messages.join(' '), contains('unprotected sex'));
    });

    test('cycle report', () {
      final r = cycleReport(_withCycles()).join('\n');
      expect(r, contains('28 days'));
      expect(r, contains('regular'));
    });

    test('free text routing', () {
      final s = _store();
      expect(respondToText('I want to kill myself', s).id, 'crisis');
      expect(respondToText('I am soaking a pad every hour', s).id, 'urgent');
      expect(respondToText('my period is late', s).id, 'late');
      expect(respondToText('weird discharge', s).id, 'discharge');
      expect(respondToText('zzzz qqqq', s).id, 'fallback');
    });

    test('symptom checker scoring', () {
      for (final c in kCheckers) {
        expect(c.questions.length, inInclusiveRange(8, 12), reason: c.id);
        expect(articleById(c.articleId), isNotNull);
        expect(scoreChecker(c, List.filled(c.questions.length, Answer.yes)).level, 'many');
        expect(scoreChecker(c, List.filled(c.questions.length, Answer.no)).level, 'few');
        expect(scoreChecker(c, List.filled(c.questions.length, Answer.unsure)).level, 'some');
      }
    });
  });

  group('widgets', () {
    Future<void> pump(WidgetTester tester, AppStore s, Widget child, {Size size = const Size(400, 800)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: child)),
      ));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('insights screen tabs render', (tester) async {
      final s = _withCycles();
      await pump(tester, s, const InsightsScreen());
      for (final tab in ['Explore', 'Saved', 'Quizzes', 'Journal']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('daily strip, stories, and well-being', (tester) async {
      final s = _withCycles();
      await pump(tester, s, const Column(children: [DailyInsightsStrip()]));
      expect(find.textContaining('Well-being'), findsOneWidget);
      final cards = buildInsights(s);
      await pump(tester, s, StoryViewer(cards: cards, start: 1));
      await tester.tap(find.byType(StoryViewer), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      await pump(tester, s, const WellbeingScreen());
      expect(find.text('Sleep'), findsOneWidget);
      await pump(tester, s, const SizedBox());
    });

    testWidgets('article and quiz screens', (tester) async {
      final s = _store();
      await pump(tester, s, ArticleScreen(article: kArticles.first));
      await tester.scrollUntilVisible(find.text('Mark as read'), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as read'));
      await tester.pump();
      expect(s.feature<Map>('insights')?['read'], contains(kArticles.first.id));
      final quiz = kQuizzes.firstWhere((q) => !q.couples);
      await pump(tester, s, QuizScreen(quiz: quiz));
      await tester.tap(find.text(quiz.questions.first.options.first));
      await tester.pump();
      expect(find.textContaining(RegExp('Correct|Not quite')), findsOneWidget);
      await pump(tester, s, CouplesQuizScreen(quiz: kQuizzes.firstWhere((q) => q.couples)));
      await tester.scrollUntilVisible(find.text('Start'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pass the phone to'), findsOneWidget);
    });

    testWidgets('assistant chat and checker', (tester) async {
      final s = _withCycles();
      await pump(tester, s, const AssistantScreen(), size: const Size(1200, 900));
      expect(find.text('My period is late'), findsOneWidget);
      await tester.tap(find.byTooltip('Explain my cycle'));
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      final saved = s.feature<Map>('assistant');
      expect((saved?['messages'] as List).length, greaterThan(3));
      expect(saved?['node'], 'report');
      await pump(tester, s, SymptomCheckerScreen(checker: kCheckers.first));
      await tester.scrollUntilVisible(find.text('Start'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      // One question per screen: answer "No" until the last question.
      for (var i = 0; i < kCheckers.first.questions.length && find.text('See my result').evaluate().isEmpty; i++) {
        await tester.scrollUntilVisible(find.text('No'), 300, scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(find.text('See my result'), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('See my result'));
      await tester.pump();
      final saved2 = s.feature<Map>('checker')?['pcos'] as Map?;
      expect(saved2, isNotNull);
      expect(saved2?['answers'], everyElement(isIn(['no', 'yes'])));
      expect(find.text('Talking to a clinician'), findsOneWidget);
    });
  });
}
