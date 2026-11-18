import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/features/modes/goal_screen.dart';
import 'package:bloom/features/modes/perimenopause_data.dart';
import 'package:bloom/features/modes/perimenopause_home.dart';
import 'package:bloom/features/modes/postpartum_home.dart';
import 'package:bloom/features/modes/pregnancy_content.dart';
import 'package:bloom/features/modes/pregnancy_home.dart';
import 'package:bloom/features/modes/pregnancy_math.dart';
import 'package:bloom/features/modes/pregnancy_tools.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Widget _wrap(AppStore store, Widget child) => ChangeNotifierProvider.value(
  value: store,
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  group('pregnancy math', () {
    test('due date is LMP + 280 days and round-trips', () {
      final lmp = DateTime(2026, 1, 1);
      expect(dueFromLmp(lmp), DateTime(2026, 10, 8));
      expect(lmpFromDue(dueFromLmp(lmp)), lmp);
      expect(lmpFromConception(DateTime(2026, 1, 15)), lmp);
    });

    test('gestational age weeks, days, and trimester', () {
      final lmp = DateTime(2026, 1, 1);
      final a = gestationalAge(lmp, addDays(lmp, 87));
      expect(a.weeks, 12);
      expect(a.days, 3);
      expect(a.label, 'Week 12, day 3');
      expect(a.trimester, 1);
      expect(gestationalAge(lmp, addDays(lmp, 14 * 7)).trimester, 2);
      expect(gestationalAge(lmp, addDays(lmp, 28 * 7)).trimester, 3);
      expect(gestationalAge(lmp, addDays(lmp, 140)).progress, closeTo(0.5, 1e-9));
      expect(gestationalAge(lmp, addDays(lmp, 42 * 7)).isOverdue, isTrue);
      expect(gestationalAge(lmp, addDays(lmp, 50 * 7)).contentWeek, 42);
    });

    test('PregnancyData parses dueDate-only input and keeps unknown keys', () {
      final p = PregnancyData.fromJson({'dueDate': '2026-10-08', 'note': 'x'})!;
      expect(p.lmp, DateTime(2026, 1, 1));
      expect(p.babies, 1);
      expect(p.toJson()['note'], 'x');
      expect(p.toJson()['dueDate'], '2026-10-08');
    });

    test('onboarding fallback and archiving', () {
      final store = AppStore.memory();
      store.setFeature('onboarding', {'pregnancyLmp': '2026-03-01'});
      expect(readPregnancy(store)!.lmp, DateTime(2026, 3, 1));
      archivePregnancy(store, outcome: 'loss');
      expect(store.feature('pregnancy'), isNull);
      expect((store.feature<List>('pregnancy_history')!).single['outcome'], 'loss');
      // The onboarding answer no longer counts once a pregnancy was archived.
      expect(readPregnancy(store), isNull);
    });

    test('baby sizes cover weeks 4-42', () {
      expect(babySizeForWeek(3), isNull);
      for (var w = 4; w <= 42; w++) {
        expect(babySizeForWeek(w), isNotNull, reason: 'week $w');
      }
      for (var w = 1; w <= 42; w++) {
        expect(kWeeks[w], isNotNull, reason: 'week $w');
      }
    });

    test('5-1-1 rule', () {
      final t0 = DateTime(2026, 5, 1, 10);
      final regular = [
        for (var i = 0; i < 14; i++)
          Contraction(t0.add(Duration(minutes: 5 * i)), t0.add(Duration(minutes: 5 * i, seconds: 65))),
      ];
      expect(meets511(regular), isTrue);
      final short = [
        for (var i = 0; i < 14; i++)
          Contraction(t0.add(Duration(minutes: 5 * i)), t0.add(Duration(minutes: 5 * i, seconds: 30))),
      ];
      expect(meets511(short), isFalse);
      expect(meets511(regular.take(5).toList()), isFalse);
    });
  });

  group('perimenopause', () {
    test('total score banding', () {
      expect(bandFor(0), Severity.minimal);
      expect(bandFor(4), Severity.minimal);
      expect(bandFor(5), Severity.mild);
      expect(bandFor(8), Severity.mild);
      expect(bandFor(9), Severity.moderate);
      expect(bandFor(16), Severity.moderate);
      expect(bandFor(17), Severity.severe);
      expect(bandFor(44), Severity.severe);
    });

    test('subscale banding and sums', () {
      expect(bandFor(2, Subscale.somatic), Severity.minimal);
      expect(bandFor(9, Subscale.somatic), Severity.severe);
      expect(bandFor(1, Subscale.psychological), Severity.minimal);
      expect(bandFor(4, Subscale.psychological), Severity.moderate);
      expect(bandFor(0, Subscale.urogenital), Severity.minimal);
      expect(bandFor(1, Subscale.urogenital), Severity.mild);
      final r = ScoreResult(DateTime(2026, 1, 1), [4, 0, 1, 1, 1, 1, 2, 0, 3, 0, 0]);
      expect(r.total, 13);
      expect(r.severity, Severity.moderate);
      expect(r.subscore(Subscale.somatic), 4);
      expect(r.subscore(Subscale.psychological), 4);
      expect(r.subscore(Subscale.urogenital), 5);
      expect(r.topSymptoms(), ['hot_flashes', 'dryness', 'sexual']);
      expect(maxScore(), 44);
    });

    test('stage estimate', () {
      final now = DateTime(2026, 6, 1);
      expect(estimateStage(periodStarts: [], cycleLengths: [], today: now).stage, MenoStage.unknown);
      expect(
        estimateStage(periodStarts: [DateTime(2025, 5, 1)], cycleLengths: [], today: now).stage,
        MenoStage.postmenopause,
      );
      expect(
        estimateStage(periodStarts: [DateTime(2026, 1, 1), DateTime(2026, 3, 15)], cycleLengths: [], today: now).stage,
        MenoStage.lateTransition,
      );
      final starts = [DateTime(2026, 2, 1), DateTime(2026, 3, 1), DateTime(2026, 4, 5), DateTime(2026, 5, 1)];
      expect(
        estimateStage(periodStarts: starts, cycleLengths: [28, 36, 26], today: now).stage,
        MenoStage.earlyTransition,
      );
      expect(estimateStage(periodStarts: starts, cycleLengths: [28, 29, 28], today: now).stage, MenoStage.reproductive);
    });
  });

  group('widgets', () {
    testWidgets('PregnancyHome renders week and due date', (tester) async {
      final store = AppStore.memory(profile: Profile(goal: Goal.trackPregnancy, onboarded: true));
      final lmp = addDays(today(), -87);
      store.setFeature('pregnancy', {'lmp': dayKey(lmp), 'dueDate': dayKey(dueFromLmp(lmp)), 'babies': 1});
      await tester.pumpWidget(_wrap(store, const PregnancyHome()));
      expect(find.text('Week twelve,\nday three.'), findsOneWidget);
      expect(find.text('Week 12 · Day 3'), findsOneWidget);
      expect(find.text('FIRST TRIMESTER'), findsOneWidget);
      expect(find.textContaining('193 days to go'), findsOneWidget);
      expect(find.textContaining('a lime'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Kick counter'), findsOneWidget);
      // Let the store's debounced save timer fire.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('PregnancyHome shows overdue prompt after 42 weeks', (tester) async {
      final store = AppStore.memory();
      store.setFeature('pregnancy', {'lmp': dayKey(addDays(today(), -300)), 'babies': 1});
      await tester.pumpWidget(_wrap(store, const PregnancyHome()));
      expect(find.text('Has your baby arrived?'), findsOneWidget);
      // Let the store's debounced save timer fire.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('PregnancyHome without data offers setup', (tester) async {
      await tester.pumpWidget(_wrap(AppStore.memory(), const PregnancyHome()));
      expect(find.text('Set up pregnancy'), findsOneWidget);
      // Let the store's debounced save timer fire.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('PostpartumHome and PerimenopauseHome render', (tester) async {
      final store = AppStore.memory();
      store.setFeature('postpartum', {'birthDate': dayKey(addDays(today(), -17))});
      await tester.pumpWidget(_wrap(store, const PostpartumHome()));
      expect(find.text('2 weeks, 3 days old'), findsOneWidget);
      await tester.pumpWidget(_wrap(store, const PerimenopauseHome()));
      expect(find.text('Perimenopause score'), findsOneWidget);
      expect(find.text('Your stage'), findsOneWidget);
      // Let the store's debounced save timer fire.
      await tester.pump(const Duration(seconds: 1));
    });
    testWidgets('mode screens build at phone width', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = AppStore.memory(profile: Profile(goal: Goal.trackPregnancy, onboarded: true));
      final lmp = addDays(today(), -200);
      store.setFeature('pregnancy', {'lmp': dayKey(lmp), 'babies': 2});
      store.setMetric(addDays(lmp, 10), 'weight', 60);
      store.setMetric(addDays(lmp, 150), 'weight', 66);
      store.setFeature('postpartum', {
        'birthDate': dayKey(addDays(today(), -10)),
        'feeds': [
          {'start': DateTime.now().toIso8601String(), 'end': DateTime.now().toIso8601String(), 'type': 'left'},
        ],
      });
      store.setFeature('perimenopause', {
        'scores': [
          ScoreResult(addDays(today(), -30), [2, 2, 1, 1, 1, 1, 0, 0, 1, 1, 0]).toJson(),
          ScoreResult(today(), [3, 2, 2, 1, 1, 2, 0, 0, 1, 1, 0]).toJson(),
        ],
      });
      final screens = <Widget>[
        const GoalScreen(),
        const PregnancySettingsScreen(),
        const PregnancyActivationScreen(),
        const PregnancyLossScreen(),
        const WeekDetailScreen(week: 28),
        const KickCounterScreen(),
        const ContractionTimerScreen(),
        const PregnancyWeightScreen(),
        const PregnancyChecklistScreen(),
        const AppointmentsScreen(),
        const RecoveryTimelineScreen(currentWeek: 1),
        const RecoveryChecklistScreen(),
        const FeedingLogScreen(),
        const PerimenopauseScoreScreen(),
        const ReliefOptionsScreen(),
      ];
      for (final s in screens) {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: store,
            child: MaterialApp(theme: buildTheme(Brightness.light), home: s),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: s.runtimeType.toString());
      }
      await tester.pumpWidget(_wrap(store, const PerimenopauseHome()));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
